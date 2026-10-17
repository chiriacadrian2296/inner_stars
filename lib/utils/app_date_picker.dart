import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import '../widgets/app_field.dart';
import 'proper_case.dart';

Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  var selected = initialDate;
  var inputMode = false;
  while (true) {
    final result = await showDialog<_DatePickerResult>(
      context: context,
      builder: (_) => inputMode
          ? _AppDateInputDialog(
              initialDate: selected,
              firstDate: firstDate,
              lastDate: lastDate,
            )
          : _AppDatePickerDialog(
              initialDate: selected,
              firstDate: firstDate,
              lastDate: lastDate,
            ),
    );
    if (result == null) return null;
    selected = result.date;
    if (result.switchMode) {
      inputMode = !inputMode;
      continue;
    }
    return selected;
  }
}

class _DatePickerResult {
  const _DatePickerResult(this.date, {this.switchMode = false});

  final DateTime date;
  final bool switchMode;
}

class _AppDatePickerDialog extends StatefulWidget {
  const _AppDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_AppDatePickerDialog> createState() => _AppDatePickerDialogState();
}

class _AppDatePickerDialogState extends State<_AppDatePickerDialog> {
  late DateTime _selected = widget.initialDate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final material = MaterialLocalizations.of(context);
    return _PickerShell(
      title: toProperCase(
        material.datePickerHelpText,
        context.strings.languageCode,
      ),
      modeButton: IconButton(
        tooltip: material.inputDateModeButtonLabel,
        onPressed: () =>
            Navigator.of(context)
                .pop(_DatePickerResult(_selected, switchMode: true)),
        icon: Icon(Icons.edit_outlined, color: colors.muted),
      ),
      onConfirm: () => Navigator.of(context).pop(_DatePickerResult(_selected)),
      child: SizedBox(
        height: 350,
        child: CalendarDatePicker(
          initialDate: _selected,
          firstDate: widget.firstDate,
          lastDate: widget.lastDate,
          onDateChanged: (date) => _selected = date,
        ),
      ),
    );
  }
}

class _AppDateInputDialog extends StatefulWidget {
  const _AppDateInputDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_AppDateInputDialog> createState() => _AppDateInputDialogState();
}

class _AppDateInputDialogState extends State<_AppDateInputDialog> {
  late DateTime _selected = widget.initialDate;
  late final _dayController = TextEditingController(
    text: _selected.day.toString().padLeft(2, '0'),
  );
  late final _monthController = TextEditingController(
    text: _selected.month.toString().padLeft(2, '0'),
  );
  late final _yearController = TextEditingController(
    text: _selected.year.toString(),
  );
  final _dayFocus = FocusNode();
  final _monthFocus = FocusNode();
  final _yearFocus = FocusNode();

  /// One message per wrong part, in the order the boxes are shown.
  List<String> _errors = const [];
  Set<_DatePart> _invalidParts = const {};
  bool _switchingMode = false;

  /// Day, month, year as laid out on screen: month first in English.
  bool get _monthFirst => Localizations.localeOf(context).languageCode == 'en';

  Future<void> _switchToCalendar() async {
    if (_switchingMode) return;
    setState(() => _switchingMode = true);
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');

    // The two modes are separate dialogs. Do not construct the taller
    // calendar while Android is still reporting the IME-constrained height.
    final stopwatch = Stopwatch()..start();
    while (mounted &&
        MediaQuery.viewInsetsOf(context).bottom > 0 &&
        stopwatch.elapsed < const Duration(seconds: 2)) {
      await Future.any<void>([
        WidgetsBinding.instance.endOfFrame,
        Future<void>.delayed(const Duration(milliseconds: 16)),
      ]);
    }
    if (!mounted) return;
    Navigator.of(context).pop(_DatePickerResult(_selected, switchMode: true));
  }

  /// Any edit takes back the last error: it described the old values.
  void _clearError() {
    if (_errors.isEmpty && _invalidParts.isEmpty) return;
    setState(() {
      _invalidParts = const {};
      _errors = const [];
    });
  }

  bool _saveInput() {
    final strings = context.strings;
    final day = int.tryParse(_dayController.text);
    final month = int.tryParse(_monthController.text);
    final year = int.tryParse(_yearController.text);

    final yearValid =
        year != null &&
        year >= widget.firstDate.year &&
        year <= widget.lastDate.year;
    final monthValid = month != null && month >= 1 && month <= 12;
    // The real length of the month typed — with the year when it's usable
    // (February in a leap year), otherwise the longest that month can be.
    final maxDay = !monthValid
        ? 31
        : DateUtils.getDaysInMonth(yearValid ? year : 2024, month);
    final dayValid = day != null && day >= 1 && day <= maxDay;

    final messages = <_DatePart, String>{
      if (!dayValid) _DatePart.day: strings.dateInputDayRange(maxDay),
      if (!monthValid) _DatePart.month: strings.dateInputMonthRange,
      if (!yearValid)
        _DatePart.year: strings.dateInputYearRange(
          widget.firstDate.year,
          widget.lastDate.year,
        ),
    };
    if (messages.isNotEmpty) {
      final order = _monthFirst
          ? const [_DatePart.month, _DatePart.day, _DatePart.year]
          : const [_DatePart.day, _DatePart.month, _DatePart.year];
      setState(() {
        _invalidParts = messages.keys.toSet();
        _errors = [for (final part in order) ?messages[part]];
      });
      return false;
    }

    // A real date, but on the wrong side of what this field allows: a
    // victory can't be in the future, a goal's target can't be in the past.
    final candidate = DateTime(year!, month!, day!);
    final tooLate = candidate.isAfter(widget.lastDate);
    if (tooLate || candidate.isBefore(widget.firstDate)) {
      setState(() {
        _invalidParts = const {_DatePart.day, _DatePart.month, _DatePart.year};
        _errors = [
          tooLate
              ? strings.dateInputPickPastDate
              : strings.dateInputPickFutureDate,
        ];
      });
      return false;
    }
    _selected = candidate;
    setState(() {
      _invalidParts = const {};
      _errors = const [];
    });
    return true;
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    _dayFocus.dispose();
    _monthFocus.dispose();
    _yearFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final material = MaterialLocalizations.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final monthFirst = _monthFirst;
    final separator = language == 'ro' ? '.' : '/';
    final day = _DateSegment(
      controller: _dayController,
      focusNode: _dayFocus,
      nextFocus: monthFirst ? _yearFocus : _monthFocus,
      nextController: monthFirst ? _yearController : _monthController,
      digits: 2,
      width: 62,
      invalid: _invalidParts.contains(_DatePart.day),
      onEdited: _clearError,
    );
    final month = _DateSegment(
      controller: _monthController,
      focusNode: _monthFocus,
      nextFocus: monthFirst ? _dayFocus : _yearFocus,
      nextController: monthFirst ? _dayController : _yearController,
      digits: 2,
      width: 62,
      invalid: _invalidParts.contains(_DatePart.month),
      onEdited: _clearError,
    );
    final year = _DateSegment(
      controller: _yearController,
      focusNode: _yearFocus,
      digits: 4,
      width: 96,
      invalid: _invalidParts.contains(_DatePart.year),
      onEdited: _clearError,
    );
    return _PickerShell(
      title: toProperCase(
        material.dateInputLabel,
        context.strings.languageCode,
      ),
      modeButton: IconButton(
        tooltip: material.calendarModeButtonLabel,
        onPressed: _switchingMode ? null : _switchToCalendar,
        icon: Icon(Icons.calendar_month, color: colors.muted),
      ),
      onConfirm: () {
        if (_saveInput()) {
          Navigator.of(context).pop(_DatePickerResult(_selected));
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (monthFirst) month else day,
                _DateSeparator(separator),
                if (monthFirst) day else month,
                _DateSeparator(separator),
                year,
              ],
            ),
          ),
          if (_errors.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final (i, error) in _errors.indexed) ...[
              if (i > 0) const SizedBox(height: 6),
              Center(child: AppErrorMessage(error, center: true)),
            ],
          ],
        ],
      ),
    );
  }
}

class _DateSegment extends StatelessWidget {
  const _DateSegment({
    required this.controller,
    required this.focusNode,
    required this.digits,
    required this.width,
    required this.invalid,
    required this.onEdited,
    this.nextFocus,
    this.nextController,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocus;
  final TextEditingController? nextController;
  final int digits;
  final double width;
  final bool invalid;
  final VoidCallback onEdited;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: false,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      onTap: () {
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
      },
      onChanged: (value) {
        onEdited();
        if (value.length == digits && nextFocus != null) {
          nextFocus!.requestFocus();
          final target = nextController;
          if (target != null) {
            target.selection = TextSelection(
              baseOffset: 0,
              extentOffset: target.text.length,
            );
          }
        }
      },
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(digits),
      ],
      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        isDense: true,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        enabledBorder: invalid ? appErrorBorder(context.colors) : null,
        focusedBorder: invalid ? appErrorBorder(context.colors) : null,
      ),
    ),
  );
}

enum _DatePart { day, month, year }

class _DateSeparator extends StatelessWidget {
  const _DateSeparator(this.value);

  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 7),
    child: Text(
      value,
      style: TextStyle(
        color: context.colors.muted,
        fontSize: 28,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _PickerShell extends StatelessWidget {
  const _PickerShell({
    required this.title,
    required this.child,
    required this.modeButton,
    required this.onConfirm,
  });

  final String title;
  final Widget child;
  final Widget modeButton;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final material = MaterialLocalizations.of(context);
    return Dialog(
      backgroundColor: colors.night,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.nightBorder),
        borderRadius: BorderRadius.circular(kRadiusCard),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: colors.gold,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              child,
              const SizedBox(height: 20),
              Row(
                children: [
                  modeButton,
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: AppButtonLabel(material.cancelButtonLabel),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: onConfirm,
                    child: AppButtonLabel(material.okButtonLabel),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
