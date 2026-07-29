# hatchbox-deploy-notifications — deploy notification hook (server side)
# https://github.com/cmer/hatchbox-deploy-notifications
#
# This file is SOURCED (not executed) from the top of a Hatchbox deploy script:
#
#   source ~/.hatchbox-notify.sh 2>/dev/null || true
#
# It installs an EXIT trap in the deploy script's shell, so when the deploy
# finishes — success or failure — it publishes one message (app name, git sha,
# commit subject, duration) to your secret ntfy topic. It never changes the
# deploy's exit code, and a notification failure can never fail a deploy.
#
# Uses Hatchbox deploy variables when present ($DIR, $REVISION):
# https://hatchbox.relationkit.io/articles/73-deploy-script-variables

hb_notify() {
  local exit_code=$?
  local topic app app_dir sha msg title priority tags

  topic=$(cat "$HOME/.config/hatchbox-notify/topic" 2>/dev/null || true)
  [ -z "$topic" ] && return $exit_code

  # App name: $DIR is /home/deploy/<app>; fall back to stripping /releases/…
  # from $PWD. HB_NOTIFY_APP overrides if you want a custom display name.
  app_dir="${DIR:-${PWD%%/releases/*}}"
  app="${HB_NOTIFY_APP:-$(basename "$app_dir")}"

  sha=$(git rev-parse --short HEAD 2>/dev/null || echo "${REVISION:-unknown}" | cut -c1-7)
  msg=$(git log -1 --format=%s 2>/dev/null || echo "(unknown commit)")

  if [ "$exit_code" -eq 0 ]; then
    title="$app deployed"
    priority="default"
    tags="white_check_mark"
  else
    title="$app deploy FAILED (exit $exit_code)"
    priority="high"
    tags="x"
  fi

  curl -fsS -m 10 \
    -H "Title: $title" \
    -H "Priority: $priority" \
    -H "Tags: $tags" \
    -H "Click: https://app.hatchbox.io/" \
    -d "$sha — $msg (${SECONDS}s)" \
    "https://ntfy.sh/$topic" >/dev/null 2>&1 || true

  return $exit_code
}
trap hb_notify EXIT
