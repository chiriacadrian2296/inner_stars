import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// History entries [installWebBackGuard] added on top of the engine's own.
int _extraEntries = 0;
bool _installed = false;
JSFunction? _beforeUnloadListener;

JSObject get _history => globalContext['history']! as JSObject;

/// The browser's Back button from the Galaxy should ask "Exit the App?" like
/// the system Back does on a phone, instead of dropping the person on the
/// page they came from.
///
/// Flutter web catches Back by keeping an extra history entry of its own on
/// top of the one the app landed on. Chrome's history-manipulation
/// intervention, though, makes Back *skip* any entry a page added before the
/// person had interacted with it — and the engine adds its entry at startup —
/// so Back went straight past the app and to the landing page. Pushing the
/// same pair of entries again on the first real tap, click or key press (which
/// the browser counts as an interaction) gives Back one it can't skip; the
/// engine then handles it exactly as before: it sends the app a pop, which
/// the Galaxy's exit guard turns into the dialog, and sets its entry up again.
void installWebBackGuard() {
  if (_installed) return;
  _installed = true;
  late final JSFunction listener;

  // Some embedded browser controls can jump past same-document pushState
  // entries instead of dispatching the one-step popstate Flutter expects.
  // Keep a document-level fallback so that jump cannot silently leave the
  // app. Browsers intentionally provide their own localized message here.
  void onBeforeUnload(JSObject event) {
    event.callMethod('preventDefault'.toJS);
    event['returnValue'] = ''.toJS;
  }

  _beforeUnloadListener = onBeforeUnload.toJS;
  globalContext.callMethod(
    'addEventListener'.toJS,
    'beforeunload'.toJS,
    _beforeUnloadListener!,
  );

  void onInput(JSObject event) {
    final type = (event['type'] as JSString?)?.toDart;
    final pointerType = (event['pointerType'] as JSString?)?.toDart;
    // Only the events a browser counts as a user activation: a mouse press, a
    // touch release, a key press.
    final activates =
        (type == 'pointerdown' && pointerType == 'mouse') ||
        (type == 'pointerup' && pointerType != 'mouse') ||
        type == 'keydown';
    if (!activates) return;
    final state = _history['state'];
    final onFlutterEntry =
        state.isA<JSObject>() && (state as JSObject)['flutter'] != null;
    // Not on the engine's entry right now (a page change, a sign-in that
    // moved the history): wait for the next tap instead of giving up for the
    // whole session, which used to leave Back unguarded on some phones.
    if (!onFlutterEntry) return;
    for (final name in const ['pointerdown', 'pointerup', 'keydown']) {
      globalContext.callMethod(
        'removeEventListener'.toJS,
        name.toJS,
        listener,
        true.toJS,
      );
    }
    _history.callMethod(
      'pushState'.toJS,
      <String, Object?>{'origin': true, 'state': null}.jsify(),
      'origin'.toJS,
    );
    _history.callMethod(
      'pushState'.toJS,
      <String, Object?>{'flutter': true}.jsify(),
      'flutter'.toJS,
    );
    _extraEntries += 2;
  }

  listener = onInput.toJS;
  for (final name in const ['pointerdown', 'pointerup', 'keydown']) {
    globalContext.callMethod(
      'addEventListener'.toJS,
      name.toJS,
      listener,
      true.toJS,
    );
  }
}

/// Goes back past the app (the engine's two entries and ours) to the page it
/// was opened from. If there is no such page, stays put.
void leaveWebApp() {
  final steps = _extraEntries + 2;
  final length = (_history['length'] as JSNumber?)?.toDartInt ?? 0;
  if (length > steps) {
    final beforeUnloadListener = _beforeUnloadListener;
    if (beforeUnloadListener != null) {
      globalContext.callMethod(
        'removeEventListener'.toJS,
        'beforeunload'.toJS,
        beforeUnloadListener,
      );
      _beforeUnloadListener = null;
    }
    _history.callMethod('go'.toJS, (-steps).toJS);
  }
}
