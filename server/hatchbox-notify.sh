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

  # $REVISION is the sha Hatchbox actually deployed; trust it over whatever
  # HEAD happens to be in the current directory (which may be a stale cache).
  sha="${REVISION:-}"
  [ -z "$sha" ] && sha=$(git rev-parse HEAD 2>/dev/null || true)
  sha=$(printf '%s' "${sha:-unknown}" | cut -c1-7)

  # Release dirs are exported without a .git, so read the subject from the
  # repo cache Hatchbox keeps at <app>/repo; fall back to cwd just in case.
  msg=$(git -C "$app_dir/repo" log -1 --format=%s ${REVISION:+"$REVISION"} 2>/dev/null || true)
  [ -z "$msg" ] && msg=$(git log -1 --format=%s 2>/dev/null || true)
  [ -z "$msg" ] && msg="(unknown commit)"

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
