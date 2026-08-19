#!/bin/bash
# hatchbox-deploy-notifications — server installer
# Run this on your Hatchbox server (as the deploy user):
#
#   curl -fsSL https://raw.githubusercontent.com/cmer/hatchbox-deploy-notifications/main/install-server.sh | bash
#
# Installs ~/.hatchbox-notify.sh and generates a secret key at
# ~/.config/hatchbox-notify/topic if one doesn't exist. To reuse an existing
# key (e.g. on a second server), pass it in:
#
#   curl -fsSL .../install-server.sh | HB_NOTIFY_TOPIC=your-key bash
set -euo pipefail

RAW="${HB_NOTIFY_RAW:-https://raw.githubusercontent.com/cmer/hatchbox-deploy-notifications/main}"
LIB="$HOME/.hatchbox-notify.sh"
CONFIG_DIR="$HOME/.config/hatchbox-notify"
TOPIC_FILE="$CONFIG_DIR/topic"

# Styling (disabled when stdout isn't a terminal)
if [ -t 1 ]; then
  B=$'\033[1m'; D=$'\033[2m'; C=$'\033[36m'; Y=$'\033[1;33m'; G=$'\033[32m'; R=$'\033[0m'
else
  B=""; D=""; C=""; Y=""; G=""; R=""
fi

echo "🚀 ${B}Installing hatchbox-deploy-notifications...${R}"
curl -fsSL "$RAW/server/hatchbox-notify.sh" -o "$LIB"
chmod +x "$LIB"
echo "✅ Installed ${B}$LIB${R}"

mkdir -p "$CONFIG_DIR"
if [ -n "${HB_NOTIFY_TOPIC:-}" ]; then
  printf '%s\n' "$HB_NOTIFY_TOPIC" > "$TOPIC_FILE"
  chmod 600 "$TOPIC_FILE"
  echo "🔑 Saved provided secret key to ${B}$TOPIC_FILE${R}"
elif [ -f "$TOPIC_FILE" ]; then
  echo "🔑 Keeping existing secret key at ${B}$TOPIC_FILE${R}"
else
  openssl rand -hex 12 | sed 's/^/hatchbox-deploys-/' > "$TOPIC_FILE"
  chmod 600 "$TOPIC_FILE"
  echo "🔑 Generated a new secret key at ${B}$TOPIC_FILE${R}"
fi

TOPIC=$(cat "$TOPIC_FILE")

cat <<EOF

${G}${B}✅ Server installed!${R} ${B}Two steps left:${R}

${B}1️⃣  In Hatchbox${R} ${D}(https://app.hatchbox.io)${R}

   For ${B}each app${R} on this server, open the app's deploy script settings,
   fill in these two fields, then click ${B}"Update Deploy Scripts"${R}:

   ${B}Post-deploy script${R} ${D}(runs after successful deploys)${R}
     ${C}source ~/.hatchbox-notify.sh success 2>/dev/null || true${R}

   ${B}Failed deploy script${R} ${D}(runs after failed deploys)${R}
     ${C}source ~/.hatchbox-notify.sh failure 2>/dev/null || true${R}

${B}2️⃣  On your Mac${R}, install the notifier:

     ${C}curl -fsSL https://raw.githubusercontent.com/cmer/hatchbox-deploy-notifications/main/install-macos.sh | bash${R}

   When it asks for your secret key, paste:

     ${Y}$TOPIC${R}

${D}💡 Forgot these later? Run the hook with no argument to print them again:
     ~/.hatchbox-notify.sh

➕ More servers? Install with the SAME key so all deploys reach your Mac:
     curl -fsSL https://raw.githubusercontent.com/cmer/hatchbox-deploy-notifications/main/install-server.sh | HB_NOTIFY_TOPIC=$TOPIC bash${R}

EOF
