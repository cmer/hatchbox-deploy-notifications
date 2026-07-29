# hatchbox-deploy-notifications

Native macOS notifications when a [Hatchbox.io](https://hatchbox.io) deployment
succeeds or fails — with the app name, git sha, commit message, and deploy
duration.

> ✅ **myapp-production deployed**
> `a1b2c3d` — Fix checkout race condition (74s)

## How it works

Hatchbox has no built-in outbound notifications, but each app's deploy script
is fully editable. This project uses that:

- **Server**: a tiny hook (`~/.hatchbox-notify.sh`) is sourced from the top of
  your deploy scripts. It sets a bash `EXIT` trap, so whether the deploy
  succeeds or fails it publishes one message to a secret topic on
  [ntfy.sh](https://ntfy.sh) (free pub/sub, no account). It never changes the
  deploy's exit code, and a notification failure can never fail a deploy. The
  app name is derived automatically from Hatchbox's `$DIR` variable.
- **Mac**: a stdlib-only Ruby daemon (managed by `launchd`, survives reboots)
  streams the topic and posts native notifications. Failures get a ❌ and a
  distinct sound. If your Mac was asleep or offline, missed messages replay on
  reconnect (ntfy caches ~12h) — exactly once.

## Install

### 1. On your Hatchbox server

SSH in as the `deploy` user and run:

```sh
curl -fsSL https://raw.githubusercontent.com/cmer/hatchbox-deploy-notifications/main/install-server.sh | bash
```

This installs the hook, generates a secret key at
`~/.config/hatchbox-notify/topic` if one doesn't exist, and prints your key
plus the exact next steps.

**More than one server?** Reuse the same key so every deploy reaches your Mac:

```sh
curl -fsSL https://raw.githubusercontent.com/cmer/hatchbox-deploy-notifications/main/install-server.sh | HB_NOTIFY_TOPIC=your-key bash
```

### 2. In Hatchbox

For each app, open the app's **Deploy Script** setting in
[Hatchbox](https://app.hatchbox.io) and add this line at the very **top**,
above the existing commands:

```bash
source ~/.hatchbox-notify.sh 2>/dev/null || true
```

That's the only per-app change, and it's identical for every app.

### 3. On your Mac

```sh
curl -fsSL https://raw.githubusercontent.com/cmer/hatchbox-deploy-notifications/main/install-macos.sh | bash
```

Paste the secret key when prompted. The installer starts the notifier via
launchd and sends a test notification. If nothing pops up, allow notifications
for **terminal-notifier** (or **Script Editor**) in System Settings →
Notifications.

If Homebrew is installed, the installer also installs
[terminal-notifier](https://github.com/julienXX/terminal-notifier)
automatically (nicer notifications; clicking one opens Hatchbox). Without it,
plain AppleScript notifications are used. Bonus: subscribe to the same topic in the
[ntfy mobile app](https://ntfy.sh/app) to get the same notifications on your
phone for free.

## Updating

- **Mac**: re-run the macOS installer (it pulls the latest version).
- **Server**: re-run the server installer (your key is kept).

## Uninstall

- **Mac**: `~/.local/share/hatchbox-notify/uninstall-macos.sh`
- **Server**: `rm ~/.hatchbox-notify.sh && rm -rf ~/.config/hatchbox-notify`,
  and remove the `source` line from your deploy scripts.

## Notes

- **Security**: the random key is the only credential — anyone who knows it can
  read your deploy messages (app name, sha, commit subject — no code). Treat it
  like a token. You can self-host ntfy or add auth later by changing `server`
  in `~/.config/hatchbox-notify/config.json` (Mac) and the URL in
  `~/.hatchbox-notify.sh` (server).
- **Coverage caveat**: the trap fires for any failure *inside* the deploy
  script. If Hatchbox fails before your script runs at all (e.g. the git fetch
  itself fails), no notification is sent.
- **Custom app name**: set `HB_NOTIFY_APP="pretty name"` before the `source`
  line to override the auto-detected one.
- **Logs** (Mac): `~/Library/Logs/hatchbox-notify.log`
