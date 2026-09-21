---
name: deploy-to-phone
description: Build Victory Stars, run analyze/tests, and install the APK on the user's real Android phone — over USB if it's plugged in, otherwise over wireless adb (falls back to a connected emulator if no phone is reachable at all) — then always launch the app.
argument-hint: "[debug|release]"
allowed-tools: Bash(flutter *) Bash(adb *)
disable-model-invocation: true
---

# Deploy Victory Stars to the phone

Build mode: use the argument if given (`debug` or `release`), otherwise default to **debug** — the
user's own standing preference while the app is under active development, so debug-only tooling
(inspector, hot-reload-adjacent affordances, etc.) stays available on-device without asking each
time. Reach for release only when the user actually says so (testing a release build occasionally,
or explicitly asking to check something release-specific) — release is still the build type that
surfaces plugin/resource bugs debug mode hides (see the `tools:keep` fix in
`android/app/src/main/res/raw/keep.xml`, a real bug that only ever showed up in release builds), so
don't skip a release check entirely before something like a store submission.

Package name: `com.example.victory_stars`. Main activity exported name for a manual relaunch:
`.MainActivity`.

## 1. Checks first

Run, in order, stopping to report and ask before continuing if either fails:
- `flutter analyze`
- `flutter test`

Don't silently deploy on top of a failing check — but don't be rigid about it either; if the user
clearly just wants to see a WIP change on-device, a failing test unrelated to the change at hand
isn't necessarily a blocker. Use judgment, and say what failed either way.

## 2. Build

- Debug: `flutter build apk --debug` → `build/app/outputs/flutter-apk/app-debug.apk`
- Release: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`

## 3. Get a device connected

**USB always wins over wireless when it's available — check for it explicitly first, don't just
grab whatever `adb devices` happens to list.**

Run `adb devices -l`.

- **USB check (do this first):** look for a non-`emulator-*` device listed as `device` (not
  `offline`/`unauthorized`) whose serial is a plain hardware ID, *not* an `ip:port` pair — e.g.
  `c2abd67f`, not `192.168.1.23:5555`. That's the phone over USB. If one shows up, use it directly
  and skip straight to step 4.
  - If `adb devices` shows nothing at all for a phone that's actually plugged in, it may just need
    its USB mode switched to "File Transfer" (charge-only mode doesn't expose adb) — worth
    mentioning to the user if USB seems plugged in but isn't showing up.
- **No USB → try wireless:** if no USB device is present, fall back to wireless debugging instead
  of giving up.
  - If an `ip:port`-style device is already listed as `device`, use it directly.
  - Otherwise the phone's wireless-debugging connection has likely expired (its port changes each
    time). Ask the user to open **Settings → Developer options → Wireless debugging** on the phone
    and read out the IP:port shown on that main screen, then run `adb connect <ip>:<port>`.
    - If `adb connect` succeeds, proceed.
    - If it's refused/fails (pairing itself expired, not just the connection), ask the user to open
      "Pair device with pairing code" instead, read out that screen's IP:port and 6-digit code, run
      `adb pair <ip>:<port> <code>`, then `adb connect` using the *main* wireless-debugging screen's
      IP:port (a different port from the pairing one).
- If there's truly no phone reachable at all (neither USB nor wireless), fall back to whatever
  emulator `adb devices` shows and say so explicitly — don't silently install to a different target
  than the user expects.

## 4. Install and launch

- `adb -s <device-serial> install -r build/app/outputs/flutter-apk/app-<mode>.apk`
- **Always launch it afterward, no matter which path (USB, wireless, or emulator) got you the
  device connected — this isn't optional, do it every time:**
  `adb -s <device-serial> shell monkey -p com.example.victory_stars -c android.intent.category.LAUNCHER 1`

## 5. Report

State plainly: which build mode, which device it went to (and whether that was over USB or
wireless), and whether analyze/tests passed clean. If anything failed along the way, say exactly
what and where — don't leave the user guessing whether "deploy to phone" actually means it's on the
phone now, open and ready to look at.
