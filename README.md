# Claude Usage — macOS menu bar widget

A tiny menu bar app that shows your **Claude Code** rate limits at a glance — the 5-hour
session limit and the weekly limit — and opens into a panel with token statistics for the
last 7 days, 30 days and all time.

Inspired by the menu-bar layout of [Hot.app](https://github.com/macmade/Hot).

![Menu bar](docs/menubar.png)

![Menu panel](docs/menu.png)

## What it shows

**In the menu bar** — session %, weekly %, or both. Turns orange above 80 % and red above 95 %.

**In the panel**

| Section | Contents |
| --- | --- |
| Limits | Session (5 h), Weekly, and any model-scoped weekly bucket — percentage, progress bar, countdown to reset |
| Chart | Tokens per day for the last 14 / 30 / 60 days |
| Totals | Tokens over 7 days, 30 days, all time |
| Details | Input / output tokens, cache read / write, sessions and messages, top model of the last 7 days |

## Where the numbers come from

Everything is read from files Claude Code already writes on your Mac. The app makes **no
network requests**, reads **no credentials**, and touches **no Keychain items**.

| File | Used for |
| --- | --- |
| `~/.claude.json` → `cachedUsageUtilization` | session / weekly limit percentages and reset times |
| `~/.claude/stats-cache.json` | per-day token counts, per-model totals, session and message counts |

### One caveat worth knowing

`cachedUsageUtilization` is a **cache**. Claude Code refreshes it while it runs — it does not
update on its own while Claude Code is closed. The panel therefore always shows how old the
numbers are, and warns explicitly once they are more than 15 minutes stale.

`stats-cache.json` is recomputed by Claude Code periodically, so the chart usually ends on
yesterday. The panel prints the date it was last computed.

## Requirements

- macOS 13 Ventura or newer
- Xcode Command Line Tools (`xcode-select --install`) — full Xcode is **not** required
- Claude Code, having run at least once

## Install

```bash
git clone https://github.com/LiberaFatum/macOS-Claude-Code-usage-widget.git
cd macOS-Claude-Code-usage-widget
./install.sh
```

This builds the app, copies it to `/Applications/Claude Usage.app` and launches it.
The build is ad-hoc signed locally, so Gatekeeper does not get in the way.

To build without installing:

```bash
./build.sh          # produces build/Claude Usage.app
```

## Start at login

Open the menu → **Preferences → Start at login**, or from the terminal:

```bash
"/Applications/Claude Usage.app/Contents/MacOS/ClaudeUsage" --enable-login-item
```

That writes `~/Library/LaunchAgents/com.liberafatum.claude-usage-widget.plist` and loads it
with `launchctl`, so the widget comes back after a reboot. Turning the option off removes
the plist again.

## Preferences

All in the menu, all stored in `UserDefaults`:

- **Menu bar shows** — Session, Weekly, both, or whichever is higher
- **Refresh every** — 10 s, 30 s, 1 min, 5 min
- **Chart range** — 14, 30 or 60 days
- **Show menu bar icon** — hide the gauge glyph for a text-only readout
- **Start at login**

## Uninstall

```bash
./uninstall.sh
```

Removes the app, the login item and the stored preferences.

## Project layout

```
Sources/ClaudeUsage/
  main.swift          NSStatusItem, menu construction, refresh timer, CLI flags
  UsageReader.swift   parses cachedUsageUtilization out of ~/.claude.json
  StatsReader.swift   parses ~/.claude/stats-cache.json into daily/model series
  PopoverView.swift   SwiftUI panel: limit rows, sparkline, totals
  Formatting.swift    token/percentage/countdown formatting
  Preferences.swift   UserDefaults-backed settings
  LaunchAtLogin.swift LaunchAgent plist handling
  Preview.swift       renders docs/menu.png via --render-preview
Tools/make-icon.swift draws AppIcon.iconset at build time (no binary blobs in the repo)
```

Regenerate the panel screenshot with:

```bash
"/Applications/Claude Usage.app/Contents/MacOS/ClaudeUsage" --render-preview docs/menu.png
```

## Privacy

The app is read-only against two local JSON files, keeps nothing but its own preferences,
and never talks to the network. If Anthropic changes the shape of those files the app
degrades to an explanatory message rather than showing wrong numbers — it falls back to the
older `five_hour` / `seven_day` fields when the newer `limits` array is absent.

## License

MIT — see [LICENSE](LICENSE).
