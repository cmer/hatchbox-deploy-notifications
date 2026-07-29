# hatchbox-deploy-notifications — deploy notification hook (server side)
# https://github.com/cmer/hatchbox-deploy-notifications
#
# This file is SOURCED with an argument from your Hatchbox app's deploy hooks:
#
#   Post-deploy script:    source ~/.hatchbox-notify.sh success 2>/dev/null || true
#   Failed deploy script:  source ~/.hatchbox-notify.sh failure 2>/dev/null || true
#
# It publishes one message (app name, git sha, commit subject) to your secret
# ntfy topic. It always returns 0 — a notification failure can never fail a
# deploy hook.
#
# Uses Hatchbox deploy variables when present ($DIR, $REVISION):
# https://hatchbox.relationkit.io/articles/73-deploy-script-variables

hb_notify() {
  local status="$1"
  local topic app app_dir sha msg title priority tags

  topic=$(cat "$HOME/.config/hatchbox-notify/topic" 2>/dev/null || true)
  [ -z "$topic" ] && return 0

  # App name: $DIR is /home/deploy/<app>; fall back to stripping /releases/…
  # from $PWD. HB_NOTIFY_APP overrides if you want a custom display name.
  app_dir="${DIR:-${PWD%%/releases/*}}"
  app="${HB_NOTIFY_APP:-$(basename "$app_dir")}"

  sha=$(git rev-parse --short HEAD 2>/dev/null || echo "${REVISION:-unknown}" | cut -c1-7)
  msg=$(git log -1 --format=%s 2>/dev/null || echo "(unknown commit)")

  case "$status" in
    success)
      title="$app deployed"
      priority="default"
      tags="white_check_mark"
      ;;
    failure|failed)
      title="$app deploy FAILED"
      priority="high"
      tags="x"
      ;;
    *)
      echo "hatchbox-notify: usage: source ~/.hatchbox-notify.sh success|failure" >&2
      return 0
      ;;
  esac

  curl -fsS -m 10 \
    -H "Title: $title" \
    -H "Priority: $priority" \
    -H "Tags: $tags" \
    -H "Click: https://app.hatchbox.io/" \
    -d "$sha — $msg" \
    "https://ntfy.sh/$topic" >/dev/null 2>&1 || true

  return 0
}
hb_notify "${1:-}"
