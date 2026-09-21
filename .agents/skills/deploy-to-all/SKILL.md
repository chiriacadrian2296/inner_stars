---
name: deploy-to-all
description: Deploy Victory Stars to both targets in one go — the phone (USB if plugged in, else wireless) and the browser — running the shared checks once, then both deploys, then a combined report.
argument-hint: "[debug|release]"
allowed-tools: Bash(flutter *) Bash(adb *) Bash(taskkill *) PowerShell(Get-Process *) PowerShell(Get-CimInstance *)
disable-model-invocation: true
---

# Deploy Victory Stars everywhere

Runs the **Deploy to Phone** and **Deploy to Web** skills back to back against the same build mode,
sharing the analyze/test check between them instead of running it twice.

Build mode: use the argument if given (`debug` or `release`), otherwise default to **debug** —
matching Deploy to Phone's own default (the user's standing preference while the app's under active
development; see that skill's own reasoning). Deploy to Web already always deploys as debug
regardless of this, so nothing changes for it either way.

## Steps

1. **Checks once:** `flutter analyze` then `flutter test`, stopping to report and ask before
   continuing if either fails (same judgment call as the individual skills: don't be rigid about an
   unrelated failing test if the user clearly just wants to see a WIP change on both targets).

2. **Phone:** follow the **Deploy to Phone** skill's own steps 2–4 exactly (build, get a device
   connected — USB checked first, wireless as the fallback, emulator as the last resort — install,
   launch). Don't re-run the checks step, already done above.

3. **Web:** follow the **Deploy to Web** skill's own steps 2–4 exactly (kill the previous
   flutter-web Chrome window and process, relaunch fresh, wait for it to connect). Don't re-run the
   checks step, already done above. This step is independent of the phone step and can happen in
   either order — if the phone step is waiting on the user (e.g. reading out a wireless-debugging
   IP:port), do the web relaunch while waiting rather than blocking on it.

4. **Report, combined:** one summary covering both — which build mode, which phone (USB/wireless/
   emulator) got the install and whether it launched, and that the browser window now shows the
   latest build (with the same "test data won't be there" note Deploy to Web's own report gives).
   If either target failed, say exactly which one and why — a partial success (e.g. phone updated,
   web relaunch failed) should be reported as exactly that, not glossed over as a full success.
