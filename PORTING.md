# macOS 13 / Intel (x86_64) source port

This repository is an **unofficial source-level port** of
[Vorssaint](https://github.com/vorssaint/vorssaint-utils) for Intel Macs running
macOS 13.3 or newer. It is based on upstream commit `89d2626` and is **not
affiliated with, endorsed by, or supported by the Vorssaint project**. For the
official app (macOS 14+, Apple Silicon), use the upstream repository.

The source is GPL-3.0-or-later. The Vorssaint name, icon, bundle identity and
signing identity belong to the upstream project; see `TRADEMARKS.md`. Builds
from this repository are intended for personal testing.

## What changed

- Deployment target lowered to macOS 13.3; default build target is
  `x86_64-apple-macosx13.3`.
- Added `Sources/Vorssaint/Support/MacOS13Compat.swift`:
  - `onChange` compatibility for the hundreds of two-parameter call sites
  - symbol-effect / key-press / focus-ring / popover fallbacks
  - `CADisplayLink` fallback (Timer on macOS 13)
  - `SCScreenshotManager` fallback through a single-frame `SCStream`
  - Calendar access, app activation and small SwiftUI API fallbacks
- Intel SMC temperature support: `TC*` CPU keys and `TCGC` GPU key.
- Permission fixes for macOS 13:
  - `NSCalendarsUsageDescription` so Calendar requests prompt and list the app
  - Finder/Music Automation consent is requested before opening Settings
  - the permissions portal refreshes while visible
  - unsupported system-audio capture is hidden
- Feature hub performance on macOS 13: groups start collapsed and rows use a
  lazy stack.
- Upstream auto-update is disabled in x86_64 builds so an arm64 release can
  never replace the local build.

## Build

Requirements: macOS 13.3+, Xcode with a macOS 26/27 SDK, Swift 5.9+ toolchain.

```sh
./build.sh
```

The app is produced at `build/stage/Vorssaint.app`, targeting `x86_64` and
macOS 13.3. For stable TCC permissions across rebuilds, run
`Tools/setup-signing.sh` once; `build.sh` then uses the local
`Vorssaint Utils Signing` identity.

## Known limitations

- Per-app volume, per-app output routing, the notch audio visualizer and system
  audio recording require macOS 14.4 Core Audio process taps and are unavailable
  on macOS 13.
- Screenshots and window previews use the `SCStream` fallback and need Screen
  Recording permission.
- Fan control is beta and has not been validated by writing to Intel SMC fans.
- Dynamic Island features are intended for notched Macs; they can be disabled.
- Automatic updates are disabled.

## Keeping up with upstream

The fork's `main` mirrors the upstream default branch and is never modified.
All porting work lives on `macos13-intel`.

As of 2026-11-19 the branch is based on upstream `faada18`; the original port
started from `89d2626`, and 22 upstream commits were brought in by rebase.

Sync procedure:

```sh
# origin points at the upstream repository in this checkout; on a fork clone
# use UPSTREAM_REMOTE=upstream.
git fetch origin main
git rebase origin/main macos13-intel
./build.sh
git push --force-with-lease <fork-remote> macos13-intel
```

`Tools/sync-upstream.sh` runs the fetch, rebase and build in one step and
prints the push command. Conflicts are expected only in files both sides
touched; keep the macOS 13 compatibility layer and re-run `./build.sh` plus
the diagnostics afterwards.

## Diagnostics

The app accepts a few hidden flags:

```sh
Vorssaint.app/Contents/MacOS/Vorssaint --selftest
Vorssaint.app/Contents/MacOS/Vorssaint --sensors
Vorssaint.app/Contents/MacOS/Vorssaint --permissions-test
```

`--clipboard-test`, `--capture-test`, `--window-test` and `--monitor-test` write
their result to `/tmp/vorssaint-*.txt` so they can be launched through `open`.
