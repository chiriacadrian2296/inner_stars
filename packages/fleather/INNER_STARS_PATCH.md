# Fleather compatibility patch

Source: pub.dev fleather 1.28.0 (upstream lib and license preserved, except
src/widgets/editor_input_client_mixin.dart and src/widgets/controller.dart). The local manifest removes the
upstream development-only sibling override and absent screenshot, and disables
publishing.

Flutter 3.47.1's SemanticsTextEditingStrategy does not register beforeinput or
composition listeners, so DeltaTextInputClient receives non-text deltas when
accessibility is enabled on web. The package otherwise does not expose a
configuration switch or a working full-value input handler.

The patch selects the full-value protocol only for accessible web input and
converts each input update into one controller.replaceText call, preserving
unchanged styles, toggled styles, selection, composing state and undo history.
Other platforms and ordinary web input continue using the upstream delta path.
The optional controller inputUsesDeltaModel override exercises the same protocol
in VM regression tests, without relying on the deprecated Flutter Chrome runner.

AppRichTextEditor supplies the editable Semantics node and refreshes the input
configuration after an accessibility-mode change. Regression tests live in
root test/widgets/rich_text_input_protocol_test.dart and the shared editor tests.

Remove this override when upstream Fleather/Flutter supports accessible delta
input. Re-run the accessible web regression and browser smoke checks first.
