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
#
# Clicking a notification opens the app's Hatchbox page when $HATCHBOX_APP_ID is
# exported into the hook, else the dashboard. Set HB_NOTIFY_URL before the
# `source` line to point somewhere else:
#
#   HB_NOTIFY_URL=https://app.hatchbox.io/apps/13656-myapp source ~/.hatchbox-notify.sh success 2>/dev/null || true

hb_notify() {
  local status="$1"
  local topic app app_dir rev sha msg title priority tags click

  topic=$(cat "$HOME/.config/hatchbox-notify/topic" 2>/dev/null || true)
  [ -z "$topic" ] && return 0

  # App name: $DIR is /home/deploy/<app>; fall back to stripping /releases/…
  # from $PWD. HB_NOTIFY_APP overrides if you want a custom display name.
  app_dir="${DIR:-${PWD%%/releases/*}}"
  app="${HB_NOTIFY_APP:-$(basename "$app_dir")}"
  # Click target: an explicit HB_NOTIFY_URL wins, else the app's own page when
  # Hatchbox exports $HATCHBOX_APP_ID (e.g. 13656-myapp, or just 13656 — the
  # slug is decorative), else the dashboard.
  click="${HB_NOTIFY_URL:-}"
  if [ -z "$click" ]; then
    if [ -n "${HATCHBOX_APP_ID:-}" ]; then
      click="https://app.hatchbox.io/apps/${HATCHBOX_APP_ID}"
    else
      click="https://app.hatchbox.io/"
    fi
  fi

  # The sha Hatchbox deployed: $REVISION when it's exported into the hook,
  # else the REVISION file every release directory ships with. Both beat
  # `git rev-parse HEAD`, which reads whatever the cwd happens to be.
  rev="${REVISION:-}"
  [ -z "$rev" ] && rev=$(cat "$PWD/REVISION" 2>/dev/null || true)
  [ -z "$rev" ] && rev=$(git rev-parse HEAD 2>/dev/null || true)
  sha=$(printf '%s' "${rev:-unknown}" | cut -c1-7)

  # Release dirs are exported without a .git, so read the subject from the
  # repo cache Hatchbox keeps at <app>/repo — but only for a known sha, since
  # that cache's HEAD can be a commit that was never deployed here.
  msg=""
  [ -n "$rev" ] && msg=$(git -C "$app_dir/repo" log -1 --format=%s "$rev" 2>/dev/null || true)
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
    -H "Click: $click" \
    -d "$sha — $msg" \
    "https://ntfy.sh/$topic" >/dev/null 2>&1 || true

  return 0
}
hb_notify "${1:-}"
