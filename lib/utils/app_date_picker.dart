import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';

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
      title: material.datePickerHelpText,
      child: SizedBox(
        height: 350,
        child: CalendarDatePicker(
          initialDate: _selected,
          firstDate: widget.firstDate,
          lastDate: widget.lastDate,
          onDateChanged: (date) => _selected = date,
        ),
      ),
      modeButton: IconButton(
        tooltip: material.inputDateModeButtonLabel,
        onPressed: () =>
            Navigator.of(context)
                .pop(_DatePickerResult(_selected, switchMode: true)),
        icon: Icon(Icons.edit_outlined, color: colors.muted),
      ),
      onConfirm: () => Navigator.of(context).pop(_DatePickerResult(_selected)),
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
  String? _error;
  Set<_DatePart> _invalidParts = const {};

  bool _saveInput() {
    final strings = context.strings;
    final day = int.tryParse(_dayController.text);
    final month = int.tryParse(_monthController.text);
    final year = int.tryParse(_yearController.text);
    final invalid = <_DatePart>{};
    if (year == null ||
        year < widget.firstDate.year ||
        year > widget.lastDate.year) {
      invalid.add(_DatePart.year);
    }
    if (month == null || month < 1 || month > 12) {
      invalid.add(_DatePart.month);
    }
    if (day == null || day < 1) invalid.add(_DatePart.day);
    if (invalid.isNotEmpty) {
      final detail = invalid.contains(_DatePart.year)
          ? strings.dateInputInvalidYear(
              widget.firstDate.year,
              widget.lastDate.year,
            )
          : invalid.contains(_DatePart.month)
          ? strings.dateInputInvalidMonth
          : strings.dateInputInvalidDay;
      setState(() {
        _invalidParts = invalid;
        _error = detail;
      });
      return false;
    }
    final candidate = DateTime(year!, month!, day!);
    final isRealDate =
        candidate.year == year &&
        candidate.month == month &&
        candidate.day == day;
    if (!isRealDate) {
      setState(() {
        _invalidParts = const {_DatePart.day};
        _error = strings.dateInputInvalidDay;
      });
      return false;
    }
    if (candidate.isBefore(widget.firstDate) ||
        candidate.isAfter(widget.lastDate)) {
      setState(() {
        _invalidParts = const {_DatePart.day, _DatePart.month, _DatePart.year};
        _error = strings.dateInputOutsideRange;
      });
      return false;
    }
    _selected = candidate;
    setState(() {
      _invalidParts = const {};
      _error = null;
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
    final monthFirst = language == 'en';
    final separator = language == 'ro' ? '.' : '/';
    final day = _DateSegment(
      controller: _dayController,
      focusNode: _dayFocus,
      nextFocus: monthFirst ? _yearFocus : _monthFocus,
      nextController: monthFirst ? _yearController : _monthController,
      digits: 2,
      width: 62,
      invalid: _invalidParts.contains(_DatePart.day),
    );
    final month = _DateSegment(
      controller: _monthController,
      focusNode: _monthFocus,
      nextFocus: monthFirst ? _dayFocus : _yearFocus,
      nextController: monthFirst ? _dayController : _yearController,
      digits: 2,
      width: 62,
      invalid: _invalidParts.contains(_DatePart.month),
    );
    final year = _DateSegment(
      controller: _yearController,
      focusNode: _yearFocus,
      digits: 4,
      width: 96,
      invalid: _invalidParts.contains(_DatePart.year),
    );
    return _PickerShell(
      title: material.dateInputLabel,
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
          if (_error != null) ...[
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Text(
                    '${context.strings.dateInputInvalidValues}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      modeButton: IconButton(
        tooltip: material.calendarModeButtonLabel,
        onPressed: () =>
            Navigator.of(context)
                .pop(_DatePickerResult(_selected, switchMode: true)),
        icon: Icon(Icons.calendar_month, color: colors.muted),
      ),
      onConfirm: () {
        if (_saveInput()) {
          Navigator.of(context).pop(_DatePickerResult(_selected));
        }
      },
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
        enabledBorder: invalid
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(kRadiusField),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.error,
                  width: kBorderWidthActive,
                ),
              )
            : null,
        focusedBorder: invalid
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(kRadiusField),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.error,
                  width: kBorderWidthActive,
                ),
              )
            : null,
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
