#!/bin/bash
# Removes the launchd agent and installed files. Keeps ~/.config/hatchbox-notify
# (your secret key) unless you delete it yourself.
set -euo pipefail

PLIST_LABEL="com.hatchbox-notify"

launchctl bootout "gui/$(id -u)/$PLIST_LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"
rm -rf "$HOME/.local/share/hatchbox-notify"
echo "Uninstalled. Config kept at ~/.config/hatchbox-notify (delete manually if unwanted)."
