# hatchbox-deploy-notifications

Native macOS notifications when a [Hatchbox.io](https://hatchbox.io) deployment
succeeds or fails — with the app name, git sha, commit message, and deploy
duration.

> ✅ **myapp-production deployed**
> `a1b2c3d` — Fix checkout race condition

## How it works

Hatchbox runs a **post-deploy script** after every successful deployment and a
**failed deploy script** after every failed one. This project plugs into both:

- **Server**: a tiny hook (`~/.hatchbox-notify.sh`) is sourced from those two
  fields. It publishes one message (app name, git sha, commit subject) to a
  secret topic on [ntfy.sh](https://ntfy.sh) (free pub/sub, no account). It
  always exits 0, so a notification failure can never fail a deploy. The app
  name is derived automatically from Hatchbox's `$DIR` variable.
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

For each app, open the app's deploy script settings in
[Hatchbox](https://app.hatchbox.io) and fill in these two fields, then click
**Update Deploy Scripts**:

**Post-deploy script** (runs after successful deploys):

```bash
source ~/.hatchbox-notify.sh success 2>/dev/null || true
```

**Failed deploy script** (runs after failed deploys):

```bash
source ~/.hatchbox-notify.sh failure 2>/dev/null || true
```

That's the only per-app change, and it's identical for every app.

**Adding an app later?** You don't need to come back here — SSH into the
server and run the hook with no argument. It prints those two lines back,
along with your secret key:

```sh
bash ~/.hatchbox-notify.sh
```

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

## Troubleshooting

**No notifications appear.** First check whether the daemon actually received
the message:

```sh
tail ~/Library/Logs/hatchbox-notify.log
curl -d test https://ntfy.sh/YOUR-KEY
```

If a `notification:` line shows up in the log, the daemon is fine and macOS is
suppressing the notification. Two usual causes:

- **Focus mode** silently swallows notifications — including deploy failures.
  To let deploys through while staying in Focus: System Settings → Focus →
  *your Focus* → Allowed Notifications → Apps → add **terminal-notifier**.
- **Notification permission**: System Settings → Notifications →
  **terminal-notifier** (or **Script Editor** if terminal-notifier isn't
  installed) → allow notifications.

If no `notification:` line appears, the Mac and the server are probably using
different keys — compare `~/.config/hatchbox-notify/config.json` on the Mac
with `~/.config/hatchbox-notify/topic` on the server.

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
- **Custom app name**: set `HB_NOTIFY_APP="pretty name"` before the `source`
  line to override the auto-detected one.
- **Click target**: notifications open the app's Hatchbox page, falling back to
  the dashboard. Set `HB_NOTIFY_URL` before the `source` line to point somewhere
  else. Requires `terminal-notifier`; the AppleScript fallback can't attach a
  URL.
- **Logs** (Mac): `~/Library/Logs/hatchbox-notify.log`
