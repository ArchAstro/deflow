<p align="center"><img src="docs/icon.png" width="128" alt="Deflow icon"></p>
<h1 align="center">Deflow</h1>
<p align="center"><b>Never miss the meeting.</b><br>
A macOS menu bar app that takes over your whole screen when a Google Calendar meeting starts.</p>

![Deflow taking over the screen 41 seconds before a meeting](docs/takeover.png)

## Why

Desktop notifications are easy to miss when you are deep in flow. Deflow is not: at meeting time it
covers every display, shows the call details, and stays there until you join, snooze or deliberately
dismiss it.

## What it does

1. **Watches Google Calendar** (read-only) for the next 24 hours of meetings on calendars you own.
2. **Takes over every display** 1 minute before the start (0, 2 or 5 minutes are options), above
   full-screen apps, with the Dock and app switcher disabled.
3. **Shows what you need**: countdown, title, time, attendees, and the Zoom / Meet / Teams / Webex link
   with meeting ID and passcode.
4. **Gives you three ways out**:

   | Key | Action |
   | --- | --- |
   | `↩` | Join the call (opens the Zoom app directly when installed) |
   | `S` | Snooze for 1 minute |
   | hold `esc` | Dismiss (a tap does nothing, so you cannot swat it away by reflex) |

5. **Gets louder when you are late**: the screen shifts from amber to red, the countdown becomes
   "2:14 ago", and it chimes every 20 seconds.

It skips all-day events, cancelled events, events you declined, and out-of-office blocks.

<p align="center"><img src="docs/menu.png" width="360" alt="Deflow menu bar panel"></p>

## Install

1. Download `Deflow.dmg` from [Releases](../../releases) and drag Deflow to Applications.
2. Open Deflow. It lives in the menu bar, not the Dock.
3. Click the menu bar icon, then **Sign in with Google**, and approve read-only calendar access.
4. Click **Test takeover** to see what a meeting will look like.

Requires macOS 15 or later.

> Google has not verified this app yet, so sign-in shows a "Google hasn't verified this app" screen.
> Choose **Advanced**, then **Go to Deflow**. Deflow only requests read-only calendar access.

## Privacy

Deflow talks only to Google, directly from your Mac. There is no Deflow server, no analytics and no
account. See [PRIVACY.md](PRIVACY.md).

## Build from source

Needs Xcode 16 or later.

```sh
./scripts/build-app.sh --run      # build build/Deflow.app and launch it
swift test                        # unit tests
./scripts/make-dmg.sh             # Developer ID signed DMG (set NOTARY_PROFILE to notarize)
```

How it fits together:

```
Google Calendar API ──60s poll──▶ CalendarMonitor ──▶ TakeoverController ──▶ Join / Snooze / Dismiss
        ▲                                                                          │
   OAuth (PKCE, no client secret)                    ◀──────── snooze 60s ─────────┘
   refresh token in the macOS Keychain
```

| Path | What lives there |
| --- | --- |
| `Sources/DeflowCore` | Pure logic: Google Calendar parsing, meeting-link detection, trigger timing |
| `Sources/Deflow` | The app: OAuth, polling, takeover windows, menu panel, brand art |
| `Tests/DeflowCoreTests` | Unit tests for the core logic |
| `scripts` | App bundle and DMG builds |

The Google OAuth client ID in `GoogleAuth.swift` is a public identifier for an installed app. It has no
client secret; sign-in uses PKCE.

## License

[MIT](LICENSE)
