import 'dart:async';
import 'dart:convert';

import 'package:fleather/fleather.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart' as fleather_ui;
import 'package:url_launcher/url_launcher.dart';

import 'app_field.dart';
import '../l10n/strings_scope.dart';
import '../models/rich_text_document.dart';
import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import '../theme/app_style.dart';

class AppRichTextController extends FleatherController {
  AppRichTextController({
    String legacy = '',
    RichTextDocument? richText,
    super.inputUsesDeltaModel,
  }) : super(
         document: RichTextDocument.resolve(legacy, richText),
         autoFormats: AutoFormats(autoFormats: [const AutoFormatLinks()]),
       ) {
    _initial = jsonEncode(document.toJson());
  }
  late final String _initial;
  bool interacting = false;
  bool semanticsKeyboardFocus = true;
  bool _disposed = false;
  int _focusRequest = 0;

  // Accessible HTML buttons receive DOM focus even when Flutter's editor
  // retains input focus. Refresh only the accessible focus flag across frames;
  // the editor FocusNode, selection and visual focus state remain unchanged.
  void restoreAccessibleFocus() {
    if (!kIsWeb || !SemanticsBinding.instance.semanticsEnabled) return;
    final request = ++_focusRequest;
    semanticsKeyboardFocus = false;
    notifyListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || request != _focusRequest) return;
      semanticsKeyboardFocus = true;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool get hasChanges => jsonEncode(document.toJson()) != _initial;
  String get plainText => RichTextDocument.visibleText(document);
  int get characterCount => plainText.characters.length;
  bool get isEmpty => plainText.trim().isEmpty;
  RichTextDocument get snapshot => RichTextDocument.capture(document);

  /// The accessible field uses document offsets, including divider placeholders.
  String get accessibleText {
    final value = document.toPlainText();
    return value.substring(0, value.length - 1);
  }

  /// Screen readers supply a whole new value. Apply only its changed range so
  /// unchanged runs retain their native attributes and history.
  void replaceAccessibleText(String value) {
    final old = accessibleText;
    if (old == value) return;
    var start = 0;
    while (start < old.length &&
        start < value.length &&
        old.codeUnitAt(start) == value.codeUnitAt(start)) {
      start++;
    }
    // Do not split a UTF-16 surrogate pair at a shared prefix boundary.
    if (start > 0 &&
        start < old.length &&
        old.codeUnitAt(start - 1) >= 0xD800 &&
        old.codeUnitAt(start - 1) <= 0xDBFF) {
      start--;
    }
    var oldEnd = old.length;
    var newEnd = value.length;
    while (oldEnd > start &&
        newEnd > start &&
        old.codeUnitAt(oldEnd - 1) == value.codeUnitAt(newEnd - 1)) {
      oldEnd--;
      newEnd--;
    }
    if (oldEnd < old.length &&
        oldEnd > start &&
        old.codeUnitAt(oldEnd - 1) >= 0xD800 &&
        old.codeUnitAt(oldEnd - 1) <= 0xDBFF) {
      oldEnd++;
      newEnd++;
    }
    replaceText(
      start,
      oldEnd - start,
      value.substring(start, newEnd),
      selection: TextSelection.collapsed(offset: newEnd),
    );
  }

  void setInteracting(bool value) {
    if (interacting == value) return;
    interacting = value;
    notifyListeners();
  }
}

bool richTextToolbarAtBottom() =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// Keeps page actions and backdrop fixed while only the writing viewport avoids
/// the keyboard. Native tools occupy that viewport only while the IME is open.
class AppRichTextPageLayout extends StatefulWidget {
  const AppRichTextPageLayout({
    super.key,
    required this.header,
    required this.editor,
    required this.toolbar,
    required this.actions,
    required this.backdrop,
  });

  final Widget header;
  final Widget editor;
  final Widget toolbar;
  final Widget actions;
  final Widget backdrop;

  @override
  State<AppRichTextPageLayout> createState() => _AppRichTextPageLayoutState();
}

class _AppRichTextPageLayoutState extends State<AppRichTextPageLayout> {
  Timer? _keyboardSettled;
  double _keyboard = 0;
  bool _showTools = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboard == _keyboard) return;
    _keyboard = keyboard;
    _keyboardSettled?.cancel();
    // Any movement hides tools immediately, including the first closing frame.
    // Repeated IME frames postpone showing them until the opening has settled.
    _showTools = false;
    if (keyboard > 0 && richTextToolbarAtBottom()) {
      _keyboardSettled = Timer(const Duration(milliseconds: 180), () {
        if (mounted) setState(() => _showTools = true);
      });
    }
  }

  @override
  void dispose() {
    _keyboardSettled?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const actionsHeight = 80.0;
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final bottom = keyboard > 0
        ? (keyboard - media.viewPadding.bottom).clamp(
            actionsHeight,
            double.infinity,
          )
        : actionsHeight;
    final nativeTools = richTextToolbarAtBottom();
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(child: widget.backdrop),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: actionsHeight,
          child: widget.actions,
        ),
        Positioned.fill(
          bottom: bottom,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: widget.header),
                    if (!nativeTools) SliverToBoxAdapter(child: widget.toolbar),
                    SliverLayoutBuilder(
                      builder: (context, constraints) => SliverToBoxAdapter(
                        child: SizedBox(
                          // Keep the complete header and let the page scroll
                          // on short viewports instead of compacting its text.
                          height: constraints.remainingPaintExtent.clamp(
                            160.0,
                            double.infinity,
                          ),
                          child: widget.editor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (nativeTools && _showTools) widget.toolbar,
            ],
          ),
        ),
      ],
    );
  }
}

FleatherThemeData appDocumentTheme(
  BuildContext context, {
  double fontSize = 21,
}) {
  final base = FleatherThemeData.fallback(context);
  final style = TextStyle(
    fontFamily: kFontStarTitle,
    color: context.colors.text,
    fontSize: fontSize,
    height: 1.6,
  );
  TextBlockTheme block(double size, {FontWeight? weight}) => TextBlockTheme(
    style: style.copyWith(fontSize: size, fontWeight: weight),
    spacing: const VerticalSpacing(top: 4, bottom: 8),
  );
  return base.copyWith(
    paragraph: block(fontSize),
    lists: block(fontSize),
    quote: TextBlockTheme(
      style: style.copyWith(fontStyle: FontStyle.italic),
      spacing: const VerticalSpacing(top: 8, bottom: 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: context.colors.gold, width: 2)),
      ),
    ),
    heading1: block(fontSize * 1.6, weight: FontWeight.w700),
    heading2: block(fontSize * 1.35, weight: FontWeight.w700),
    heading3: block(fontSize * 1.15, weight: FontWeight.w700),
    link: TextStyle(
      color: context.colors.gold,
      decoration: TextDecoration.underline,
    ),
  );
}

/// Shared editor body and keyboard/selection integration for both writing flows.
class AppRichTextEditor extends StatefulWidget {
  const AppRichTextEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.editorKey,
    required this.hint,
    this.readOnly = false,
    this.maxLength,
  });
  final AppRichTextController controller;
  final FocusNode focusNode;
  final GlobalKey<EditorState> editorKey;
  final String hint;
  final bool readOnly;
  final int? maxLength;
  @override
  State<AppRichTextEditor> createState() => _AppRichTextEditorState();
}

class _AppRichTextEditorState extends State<AppRichTextEditor> {
  late FleatherThemeData _theme;
  @override
  void initState() {
    super.initState();
    SemanticsBinding.instance.addSemanticsEnabledListener(_refreshInputMode);
  }

  void _refreshInputMode() {
    if (!kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = widget.editorKey.currentState;
      if (state is RawEditorState) state.updateConnectionConfig();
    });
  }

  @override
  void dispose() {
    SemanticsBinding.instance.removeSemanticsEnabledListener(_refreshInputMode);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _theme = appDocumentTheme(context);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.controller, widget.focusNode]),
    builder: (context, _) {
      final over =
          widget.maxLength != null &&
          widget.controller.characterCount > widget.maxLength!;
      return Column(
        children: [
          Expanded(
            child: TapRegion(
              groupId: widget.focusNode,
              onTapOutside: (_) {
                if (!widget.controller.interacting) widget.focusNode.unfocus();
              },
              child: FleatherTheme(
                data: _theme,
                child: Stack(
                  children: [
                    if (widget.controller.isEmpty)
                      ExcludeSemantics(
                        child: IgnorePointer(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              widget.hint,
                              style: TextStyle(
                                color: context.colors.muted,
                                fontFamily: kFontStarTitle,
                                fontSize: 21,
                                height: 1.6,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Semantics(
                      textField: true,
                      enabled: !widget.readOnly,
                      multiline: true,
                      focusable: true,
                      focused:
                          widget.focusNode.hasFocus &&
                          widget.controller.semanticsKeyboardFocus,
                      readOnly: widget.readOnly,
                      label: widget.hint,
                      value: widget.controller.accessibleText,
                      excludeSemantics: true,
                      onFocus: () =>
                          widget.editorKey.currentState?.requestKeyboard(),
                      onTap: () =>
                          widget.editorKey.currentState?.requestKeyboard(),
                      onSetText: widget.readOnly
                          ? null
                          : widget.controller.replaceAccessibleText,
                      onSetSelection: (selection) {
                        final length = widget.controller.accessibleText.length;
                        widget.controller.updateSelection(
                          TextSelection(
                            baseOffset: selection.baseOffset.clamp(0, length),
                            extentOffset: selection.extentOffset.clamp(
                              0,
                              length,
                            ),
                          ),
                        );
                      },
                      child: fleather_ui.TextSelectionTheme(
                        data: fleather_ui.TextSelectionThemeData(
                          cursorColor: context.colors.gold,
                          selectionColor: context.colors.gold.withValues(
                            alpha: 0.3,
                          ),
                          selectionHandleColor: context.colors.gold,
                        ),
                        child: FleatherEditor(
                          controller: widget.controller,
                          expands: true,
                          focusNode: widget.focusNode,
                          editorKey: widget.editorKey,
                          readOnly: widget.readOnly,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          onLaunchUrl: launchDocumentLink,
                          contextMenuBuilder: appDocumentContextMenu,
                          linkActionPickerDelegate: (context, link) async {
                            widget.controller.setInteracting(true);
                            final result = await showDocumentLinkMenu(
                              context,
                              link,
                              canRemove: !widget.readOnly,
                            );
                            if (mounted) {
                              widget.editorKey.currentState?.requestKeyboard();
                              widget.controller.setInteracting(false);
                            }
                            return result;
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (over)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '${context.strings.editorTooLong} '
                '${widget.controller.characterCount}/${widget.maxLength}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      );
    },
  );
}

void launchDocumentLink(String? value) {
  final uri = Uri.tryParse(value ?? '');
  if (uri != null && ['https', 'http', 'mailto'].contains(uri.scheme)) {
    launchUrl(uri);
  }
}

/// Use Flutter's localized Material selection menu with Fleather's native actions.
Widget appDocumentContextMenu(BuildContext context, EditorState state) =>
    AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: state.contextMenuButtonItems,
    );

Future<LinkMenuAction> showDocumentLinkMenu(
  BuildContext context,
  String link, {
  required bool canRemove,
}) async {
  final s = context.strings;
  return await showDialog<LinkMenuAction>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(link),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, LinkMenuAction.none),
              style: TextButton.styleFrom(
                foregroundColor: context.colors.muted,
              ),
              child: AppButtonLabel(s.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, LinkMenuAction.copy),
              child: AppButtonLabel(s.editorCopyLink),
            ),
            if (canRemove)
              TextButton(
                onPressed: () => Navigator.pop(ctx, LinkMenuAction.remove),
                child: AppButtonLabel(s.editorRemoveLink),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, LinkMenuAction.launch),
              child: AppButtonLabel(s.editorOpenLink),
            ),
          ],
        ),
      ) ??
      LinkMenuAction.none;
}

class AppRichTextToolbar extends StatelessWidget {
  const AppRichTextToolbar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.editorKey,
    this.enabled = true,
  });
  final AppRichTextController controller;
  final FocusNode focusNode;
  final GlobalKey<EditorState> editorKey;
  final bool enabled;
  void _keyboard() {
    editorKey.currentState?.requestKeyboard();
    controller.restoreAccessibleFocus();
  }

  Future<void> _link(BuildContext context) async {
    final strings = context.strings;
    final selection = controller.selection;
    final initial = controller
        .getSelectionStyle()
        .get(ParchmentAttribute.link)
        ?.value;
    final input = TextEditingController(text: initial);
    controller.setInteracting(true);
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(strings.editorLink),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppFieldLabel(strings.editorLinkHint),
              const SizedBox(height: kFieldLabelGap),
              AppTextField(
                controller: input,
                autofocus: true,
                keyboardType: TextInputType.url,
                textCapitalization: TextCapitalization.none,
                errorText: error,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                foregroundColor: context.colors.muted,
              ),
              child: AppButtonLabel(strings.cancel),
            ),
            if (initial != null)
              TextButton(
                onPressed: () => Navigator.pop(ctx, ''),
                child: AppButtonLabel(strings.editorRemoveLink),
              ),
            TextButton(
              onPressed: () {
                final value = input.text.trim();
                final uri = Uri.tryParse(value);
                if (uri == null ||
                    !['https', 'http', 'mailto'].contains(uri.scheme) ||
                    (uri.scheme == 'mailto'
                        ? uri.path.isEmpty
                        : uri.host.isEmpty)) {
                  setState(() => error = strings.editorInvalidLink);
                  return;
                }
                Navigator.pop(ctx, value);
              },
              child: AppButtonLabel(strings.saveChanges),
            ),
          ],
        ),
      ),
    );
    // Wait for the dialog route to release its TextField before disposing it.
    WidgetsBinding.instance.addPostFrameCallback((_) => input.dispose());
    if (!context.mounted) {
      controller.setInteracting(false);
      return;
    }
    controller.updateSelection(selection);
    if (result != null) {
      controller.formatSelection(
        result.isEmpty
            ? ParchmentAttribute.link.unset
            : ParchmentAttribute.link.fromString(result),
      );
    }
    _keyboard();
    controller.setInteracting(false);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final colors = context.colors;
    Widget toggle(ParchmentAttribute attribute, IconData icon, String label) =>
        ToggleStyleButton(
          attribute: attribute,
          icon: icon,
          controller: controller,
          childBuilder: (context, attribute, icon, selected, onPressed) =>
              IconButton(
                tooltip: label,
                isSelected: selected,
                icon: Icon(icon, color: selected ? colors.gold : colors.text),
                onPressed: enabled && onPressed != null
                    ? () {
                        onPressed();
                        _keyboard();
                      }
                    : null,
              ),
        );
    Widget button(IconData icon, String label, VoidCallback? action) =>
        IconButton(
          tooltip: label,
          icon: Icon(icon),
          onPressed: enabled ? action : null,
        );
    Widget menu(
      String label,
      IconData icon,
      List<(String, ParchmentAttribute)> items,
    ) => PopupMenuButton<int>(
      tooltip: label,
      // Popup routes avoid safe-area padding, but not the keyboard inset.
      // Anchor the complete menu above the native bottom toolbar instead.
      offset:
          richTextToolbarAtBottom() &&
              MediaQuery.viewInsetsOf(context).bottom > 0
          ? Offset(0, -(items.length * kMinInteractiveDimension + 16))
          : Offset.zero,
      constraints: MediaQuery.viewInsetsOf(context).bottom > 0
          ? BoxConstraints(
              maxHeight:
                  (MediaQuery.sizeOf(context).height -
                          MediaQuery.viewInsetsOf(context).bottom -
                          MediaQuery.viewPaddingOf(context).top -
                          24)
                      .clamp(kMinInteractiveDimension, double.infinity),
            )
          : null,
      requestFocus: false,
      enabled: enabled,
      icon: Icon(icon),
      onOpened: () => controller.setInteracting(true),
      onCanceled: () => controller.setInteracting(false),
      onSelected: (i) {
        controller.formatSelection(items[i].$2);
        _keyboard();
        controller.setInteracting(false);
      },
      itemBuilder: (_) => [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem(
            value: i,
            child: TapRegion(groupId: focusNode, child: Text(items[i].$1)),
          ),
      ],
    );
    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: colors.night,
        iconTheme: IconThemeData(color: colors.text),
        disabledColor: colors.muted,
      ),
      child: TapRegion(
        groupId: focusNode,
        child: TextFieldTapRegion(
          child: Focus(
            canRequestFocus: false,
            descendantsAreFocusable: false,
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) => FleatherToolbar(
                editorKey: editorKey,
                children: [
                  toggle(
                    ParchmentAttribute.bold,
                    Icons.format_bold,
                    s.visionBold,
                  ),
                  toggle(
                    ParchmentAttribute.italic,
                    Icons.format_italic,
                    s.visionItalic,
                  ),
                  toggle(
                    ParchmentAttribute.underline,
                    Icons.format_underlined,
                    s.visionUnderline,
                  ),
                  toggle(
                    ParchmentAttribute.strikethrough,
                    Icons.format_strikethrough,
                    s.editorStrike,
                  ),
                  menu(s.visionHeading, Icons.title, [
                    (s.editorNormal, ParchmentAttribute.heading.unset),
                    for (var level = 1; level <= 3; level++)
                      (
                        '${s.visionHeading} $level',
                        ParchmentAttribute.heading.withValue(level),
                      ),
                  ]),
                  toggle(
                    ParchmentAttribute.ol,
                    Icons.format_list_numbered,
                    s.visionNumberedList,
                  ),
                  toggle(
                    ParchmentAttribute.ul,
                    Icons.format_list_bulleted,
                    s.visionBulletList,
                  ),
                  toggle(
                    ParchmentAttribute.block.quote,
                    Icons.format_quote,
                    s.editorQuote,
                  ),
                  button(
                    Icons.link,
                    s.editorLink,
                    controller.selection.isCollapsed
                        ? null
                        : () => _link(context),
                  ),
                  button(Icons.horizontal_rule, s.visionDivider, () {
                    final start = controller.selection.start;
                    controller.replaceText(
                      start,
                      controller.selection.end - start,
                      BlockEmbed.horizontalRule,
                      selection: TextSelection.collapsed(offset: start + 2),
                    );
                    _keyboard();
                  }),
                  menu(s.editorAlignment, Icons.format_align_left, [
                    (s.editorAlignLeft, ParchmentAttribute.left),
                    (s.editorAlignCenter, ParchmentAttribute.center),
                    (s.editorAlignRight, ParchmentAttribute.right),
                    (s.editorAlignJustify, ParchmentAttribute.justify),
                  ]),
                  button(
                    Icons.undo,
                    s.visionUndo,
                    controller.canUndo
                        ? () {
                            controller.undo();
                            _keyboard();
                          }
                        : null,
                  ),
                  button(
                    Icons.redo,
                    s.visionRedo,
                    controller.canRedo
                        ? () {
                            controller.redo();
                            _keyboard();
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
