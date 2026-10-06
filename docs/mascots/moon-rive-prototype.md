# Moon — parked Rive prototype

This experiment is intentionally not part of the Flutter app runtime. Moon's
in-app implementation lives in `lib/widgets/moon_mascot.dart` and uses Flutter
animation primitives plus the vector body asset.

Keep the Rive prototype for a possible interactive website or landing-page
version:

- Editor file: https://editor.rive.app/file/untitled/2607132
- File and artboard: `Moon`
- Timeline: `Blink`
- State machine: `MoonController`
- Imported source: `assets/mascots/moon.svg`
- Motion: the `moon-eyes` group scales vertically to blink and loops through
  the state machine.

No `.riv` export is committed. Add a Rive runtime only to the target that will
actually render the future website version, and export a fresh production file
from the editor when that work begins.
