#!/bin/bash
# hatchbox-deploy-notifications — macOS installer
# Run this on your Mac:
#
#   curl -fsSL https://raw.githubusercontent.com/cmer/hatchbox-deploy-notifications/main/install-macos.sh | bash
#
# It asks for the secret key printed by the server install (or reads
# HB_NOTIFY_TOPIC from the environment / an existing config), installs the
# notifier under ~/.local/share/hatchbox-notify, and starts it via launchd.
# Re-run any time to update to the latest version.
set -euo pipefail

REPO_URL="https://github.com/cmer/hatchbox-deploy-notifications.git"
INSTALL_DIR="$HOME/.local/share/hatchbox-notify"
CONFIG_DIR="$HOME/.config/hatchbox-notify"
CONFIG_FILE="$CONFIG_DIR/config.json"
PLIST_LABEL="com.hatchbox-notify"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"

# Styling (disabled when stdout isn't a terminal)
if [ -t 1 ]; then
  B=$'\033[1m'; D=$'\033[2m'; C=$'\033[36m'; Y=$'\033[1;33m'; G=$'\033[32m'; R=$'\033[0m'
else
  B=""; D=""; C=""; Y=""; G=""; R=""
fi

echo "🚀 ${B}Installing hatchbox-deploy-notifications...${R}"

# --- get the files (local checkout if run from the repo, else clone/pull) ----
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]:-}" ]; then
  SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
fi

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/macos/hatchbox-notifier" ]; then
  echo "📦 Installing from local checkout: ${B}$SCRIPT_DIR${R}"
  mkdir -p "$INSTALL_DIR/macos"
  cp "$SCRIPT_DIR/macos/hatchbox-notifier" "$SCRIPT_DIR/macos/$PLIST_LABEL.plist" "$INSTALL_DIR/macos/"
  cp "$SCRIPT_DIR/uninstall-macos.sh" "$INSTALL_DIR/"
elif [ -d "$INSTALL_DIR/.git" ]; then
  echo "📦 Updating ${B}$INSTALL_DIR${R}..."
  git -C "$INSTALL_DIR" fetch -q origin main
  git -C "$INSTALL_DIR" reset -q --hard origin/main
else
  echo "📦 Cloning into ${B}$INSTALL_DIR${R}..."
  rm -rf "$INSTALL_DIR"
  git clone -q "$REPO_URL" "$INSTALL_DIR"
fi
chmod +x "$INSTALL_DIR/macos/hatchbox-notifier"

# --- secret key --------------------------------------------------------------
TOPIC="${HB_NOTIFY_TOPIC:-}"
if [ -z "$TOPIC" ] && [ -f "$CONFIG_FILE" ]; then
  TOPIC=$(/usr/bin/ruby -rjson -e 'puts JSON.parse(File.read(ARGV[0]))["topic"]' "$CONFIG_FILE" 2>/dev/null || true)
  [ -n "$TOPIC" ] && echo "🔑 Using existing secret key from ${B}$CONFIG_FILE${R}"
fi
if [ -z "$TOPIC" ]; then
  printf "🔑 Paste your secret key ${D}(printed by the server install)${R}, then press ${B}Enter${R}: " > /dev/tty
  read -r TOPIC < /dev/tty
fi
if [ -z "$TOPIC" ]; then
  echo "❌ No secret key provided — aborting." >&2
  exit 1
fi
echo "🔑 Key accepted."

mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_FILE" <<JSON
{
  "server": "https://ntfy.sh",
  "topic": "$TOPIC"
}
JSON
chmod 600 "$CONFIG_FILE"
echo "✅ Saved config to ${B}$CONFIG_FILE${R}"

# --- terminal-notifier (optional: better notifications + click-to-open) ------
have_tn() { [ -x /opt/homebrew/bin/terminal-notifier ] || [ -x /usr/local/bin/terminal-notifier ]; }
if ! have_tn && command -v brew >/dev/null 2>&1; then
  echo "🔔 Installing terminal-notifier via Homebrew ${D}(enables click-to-open, may take a minute)${R}..."
  brew install terminal-notifier </dev/null || echo "⚠️  brew install failed — continuing without terminal-notifier."
fi

# --- launchd agent -----------------------------------------------------------
echo "⚙️  Starting the notifier (launchd agent)..."
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
sed -e "s|__INSTALL_DIR__|$INSTALL_DIR|g" -e "s|__HOME__|$HOME|g" \
  "$INSTALL_DIR/macos/$PLIST_LABEL.plist" > "$PLIST_DEST"

# bootout is asynchronous — wait for the old agent to fully unload before
# bootstrapping, and retry once since launchd can still return EIO briefly.
launchctl bootout "gui/$(id -u)/$PLIST_LABEL" 2>/dev/null || true
for _ in 1 2 3 4 5 6 7 8 9 10; do
  launchctl print "gui/$(id -u)/$PLIST_LABEL" >/dev/null 2>&1 || break
  sleep 1
done
launchctl bootstrap "gui/$(id -u)" "$PLIST_DEST" 2>/dev/null ||
  { sleep 2; launchctl bootstrap "gui/$(id -u)" "$PLIST_DEST"; }
launchctl kickstart -k "gui/$(id -u)/$PLIST_LABEL"
echo "✅ Notifier is running ${D}(label: $PLIST_LABEL)${R}"

# --- test notification -------------------------------------------------------
echo "📨 Sending a test notification..."
sleep 3
curl -fsS -m 10 \
  -H "Title: hatchbox-notify installed" \
  -H "Tags: white_check_mark" \
  -d "Your Mac will now get a notification for every Hatchbox deploy." \
  "https://ntfy.sh/$TOPIC" > /dev/null

cat <<EOF

${G}${B}✅ Done!${R} You should see a macOS notification within a few seconds.

   ${B}No notification?${R} Allow notifications for ${B}terminal-notifier${R} (or
   ${B}Script Editor${R}) in System Settings → Notifications, then rerun:
     ${C}curl -d test https://ntfy.sh/$TOPIC${R}

   ${D}📄 Logs:      ~/Library/Logs/hatchbox-notify.log
   🔄 Update:    re-run this installer
   🗑️  Uninstall: $INSTALL_DIR/uninstall-macos.sh${R}
EOF
if ! have_tn; then
  echo "   ${B}💡 Recommended:${R} ${C}brew install terminal-notifier${R} — nicer notifications;"
  echo "      clicking one opens Hatchbox. Install Homebrew first: https://brew.sh"
fi
