---
name: deploy-to-web
description: Build Victory Stars, run analyze/tests, and (re)launch it as a headless web server so the user can preview it inside VS Code's own Simple Browser panel — never in a separate, external Chrome window.
argument-hint: "[debug|release]"
allowed-tools: Bash(flutter *) Bash(taskkill *) PowerShell(Get-Process *) PowerShell(Get-CimInstance *)
disable-model-invocation: true
---

# Deploy Victory Stars to the browser

Build mode: use the argument if given (`debug` or `release`), otherwise default to **debug** — the
web target has no separate real-device install step the way the phone does, so debug's hot-reload
dev server is the normal way to look at it, not just a fallback.

## The user previews this inside VS Code, not in a pop-up Chrome window

The user wants the app **inside the editor** — VS Code's own Simple Browser panel, docked in a
side pane — not a separate OS-level Chrome window off to the side. There is no tool available here
that can open or control that panel directly (no VS Code command access from this environment), so
this skill only gets the app served; the user opens it in Simple Browser themselves (Command
Palette → "Simple Browser: Show", paste the URL — or the preview icon on the port in the **PORTS**
panel, if VS Code auto-detects it as forwarded).

Use **`flutter run -d web-server`**, not `-d chrome` — it serves the app over plain HTTP without
launching *any* browser window of its own, which is exactly what makes a VS Code-side preview
possible instead of a competing external one.

Always pin the same port (`--web-port=8765`) rather than letting Flutter pick a random one each
time. Two reasons: the user can leave the same Simple Browser tab pointed at it and just refresh
after a redeploy instead of re-finding a new URL every time, and — since this origin is now stable
across runs — `localStorage` (projects/stars/constellations, all backed by `shared_preferences`)
actually **persists** across redeploys as long as the user keeps reloading that same tab, unlike
the old `-d chrome` workflow's disposable temp profile which started empty every single time.

## Reuse the same server, don't pile up new ones

Same underlying limitation as before: there is no way to hot-reload a *backgrounded* `flutter run`
process from this environment (stdin isn't wired to it; a raw Win32 `WriteConsoleInput` keystroke
injection was tried and confirmed not to work). "Update the preview" still means **kill the
previous flutter-web process, then start a fresh one on the same port** — never leave two web
servers running at once fighting over `8765`.

### Steps

1. **Checks first** — same as the phone skill: run `flutter analyze` then `flutter test`, in order,
   stopping to report and ask before continuing if either fails (unless the user clearly just wants
   to eyeball a WIP change).

2. **Find and kill any previous flutter-web session:** the `dart.exe` process running
   `flutter run -d web-server` (its command line contains `web-server` and this project's path;
   `Get-CimInstance Win32_Process -Filter "Name='dart.exe'"` and filter on `CommandLine`), or just
   kill by the background task's own process id if you started it yourself this session. It's fine
   to be a little aggressive — this is always a disposable dev-server process, never something with
   unsaved user work in it.

3. **Launch fresh:** run `flutter run -d web-server --web-port=8765` (add `--release` if release
   mode was requested) as a background command. Wait for `lib\main.dart is being served at
   http://localhost:8765` in its output before considering it ready — that's the signal the web
   app has actually loaded, not just that the process started.

4. **Report:** which build mode, the URL, and — only the first time in a session, not on every
   redeploy — the one-time reminder of how to open it in Simple Browser (Command Palette → "Simple
   Browser: Show", or the PORTS panel's preview icon). On a redeploy, a simple "reload the tab" is
   enough since it's the same URL as before.

Don't seed localStorage, don't take screenshots, don't drive the page via CDP as part of this
skill — that's testing infrastructure for a *different* purpose (verifying a specific bug fix),
not part of a plain "deploy" request. Just get the server running and hand over the URL.
