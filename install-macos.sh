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

# --- get the files (local checkout if run from the repo, else clone/pull) ----
SCRIPT_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]:-}" ]; then
  SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
fi

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/macos/hatchbox-notifier" ]; then
  echo "Installing from local checkout: $SCRIPT_DIR"
  mkdir -p "$INSTALL_DIR/macos"
  cp "$SCRIPT_DIR/macos/hatchbox-notifier" "$SCRIPT_DIR/macos/$PLIST_LABEL.plist" "$INSTALL_DIR/macos/"
  cp "$SCRIPT_DIR/uninstall-macos.sh" "$INSTALL_DIR/"
elif [ -d "$INSTALL_DIR/.git" ]; then
  echo "Updating $INSTALL_DIR..."
  git -C "$INSTALL_DIR" pull -q
else
  echo "Cloning into $INSTALL_DIR..."
  rm -rf "$INSTALL_DIR"
  git clone -q "$REPO_URL" "$INSTALL_DIR"
fi
chmod +x "$INSTALL_DIR/macos/hatchbox-notifier"

# --- secret key --------------------------------------------------------------
TOPIC="${HB_NOTIFY_TOPIC:-}"
if [ -z "$TOPIC" ] && [ -f "$CONFIG_FILE" ]; then
  TOPIC=$(/usr/bin/ruby -rjson -e 'puts JSON.parse(File.read(ARGV[0]))["topic"]' "$CONFIG_FILE" 2>/dev/null || true)
  [ -n "$TOPIC" ] && echo "Using existing secret key from $CONFIG_FILE"
fi
if [ -z "$TOPIC" ]; then
  printf "Paste your secret key (printed by the server install): " > /dev/tty
  read -r TOPIC < /dev/tty
fi
if [ -z "$TOPIC" ]; then
  echo "No secret key provided — aborting." >&2
  exit 1
fi

mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_FILE" <<JSON
{
  "server": "https://ntfy.sh",
  "topic": "$TOPIC"
}
JSON
chmod 600 "$CONFIG_FILE"

# --- launchd agent -----------------------------------------------------------
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
sed -e "s|__INSTALL_DIR__|$INSTALL_DIR|g" -e "s|__HOME__|$HOME|g" \
  "$INSTALL_DIR/macos/$PLIST_LABEL.plist" > "$PLIST_DEST"

launchctl bootout "gui/$(id -u)/$PLIST_LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_DEST"
launchctl kickstart -k "gui/$(id -u)/$PLIST_LABEL"

# --- test notification -------------------------------------------------------
sleep 3
curl -fsS -m 10 \
  -H "Title: hatchbox-notify installed" \
  -H "Tags: white_check_mark" \
  -d "Your Mac will now get a notification for every Hatchbox deploy." \
  "https://ntfy.sh/$TOPIC" > /dev/null

cat <<EOF

===============================================================================
 Done! You should see a macOS notification within a few seconds.
===============================================================================

 - If you don't, allow notifications for "terminal-notifier" (or "Script
   Editor") in System Settings -> Notifications, then rerun:
     curl -d test https://ntfy.sh/$TOPIC
 - Optional: brew install terminal-notifier (clicking a notification then
   opens Hatchbox).
 - Logs: ~/Library/Logs/hatchbox-notify.log
 - Update: re-run this installer. Uninstall: $INSTALL_DIR/uninstall-macos.sh
EOF
