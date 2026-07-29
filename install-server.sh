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

echo "Installing hatchbox-deploy-notifications..."
curl -fsSL "$RAW/server/hatchbox-notify.sh" -o "$LIB"
echo "Installed $LIB"

mkdir -p "$CONFIG_DIR"
if [ -n "${HB_NOTIFY_TOPIC:-}" ]; then
  printf '%s\n' "$HB_NOTIFY_TOPIC" > "$TOPIC_FILE"
  chmod 600 "$TOPIC_FILE"
  echo "Wrote provided secret key to $TOPIC_FILE"
elif [ -f "$TOPIC_FILE" ]; then
  echo "Keeping existing secret key at $TOPIC_FILE"
else
  openssl rand -hex 12 | sed 's/^/hatchbox-deploys-/' > "$TOPIC_FILE"
  chmod 600 "$TOPIC_FILE"
  echo "Generated a new secret key at $TOPIC_FILE"
fi

TOPIC=$(cat "$TOPIC_FILE")

cat <<EOF

===============================================================================
 Done! Two steps left:
===============================================================================

 1. In Hatchbox (https://app.hatchbox.io):

    For EACH app on this server, open the app's deploy script settings
    and fill in these two fields, then click "Update Deploy Scripts":

    Post-deploy script (runs after successful deploys):

      source ~/.hatchbox-notify.sh success 2>/dev/null || true

    Failed deploy script (runs after failed deploys):

      source ~/.hatchbox-notify.sh failure 2>/dev/null || true

 2. On your Mac, install the notifier:

      curl -fsSL https://raw.githubusercontent.com/cmer/hatchbox-deploy-notifications/main/install-macos.sh | bash

    When it asks for your secret key, paste:

      $TOPIC

 More servers? Install with the SAME key so all deploys reach your Mac:

      curl -fsSL https://raw.githubusercontent.com/cmer/hatchbox-deploy-notifications/main/install-server.sh | HB_NOTIFY_TOPIC=$TOPIC bash

===============================================================================
EOF
