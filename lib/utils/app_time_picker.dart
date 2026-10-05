import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_style.dart';

Future<TimeOfDay?> showAppTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) async {
  var selected = initialTime;
  var inputMode = false;
  final use24Hours = MediaQuery.alwaysUse24HourFormatOf(context);
  while (true) {
    final result = await showDialog<_TimePickerResult>(
      context: context,
      builder: (_) => inputMode
          ? _AppTimeInputDialog(initialTime: selected, use24Hours: use24Hours)
          : _AppTimePickerDialog(initialTime: selected),
    );
    if (result == null) return null;
    selected = result.time;
    if (result.switchMode) {
      inputMode = !inputMode;
      continue;
    }
    return selected;
  }
}

class _TimePickerResult {
  const _TimePickerResult(this.time, {this.switchMode = false});

  final TimeOfDay time;
  final bool switchMode;
}

class _AppTimePickerDialog extends StatefulWidget {
  const _AppTimePickerDialog({required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<_AppTimePickerDialog> createState() => _AppTimePickerDialogState();
}

class _AppTimePickerDialogState extends State<_AppTimePickerDialog> {
  late TimeOfDay _time = widget.initialTime;
  bool _minutes = false;

  bool get _use24Hours => MediaQuery.alwaysUse24HourFormatOf(context);

  void _setTime(TimeOfDay value) {
    setState(() {
      _time = value;
    });
  }

  void _setDayPeriod(DayPeriod period) {
    final hourOfPeriod = _time.hourOfPeriod;
    _setTime(
      TimeOfDay(
        hour: hourOfPeriod + (period == DayPeriod.pm ? 12 : 0),
        minute: _time.minute,
      ),
    );
  }

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
                material.timePickerDialHelpText,
                style: TextStyle(
                  color: colors.gold,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _TimeHeader(
                time: _time,
                use24Hours: _use24Hours,
                minutesSelected: _minutes,
                onHours: () => setState(() => _minutes = false),
                onMinutes: () => setState(() => _minutes = true),
                onPeriod: _setDayPeriod,
              ),
              // This is the deliberately isolated central breathing room:
              // it does not alter the dialog, title, or footer padding.
              const SizedBox(height: 24),
              SizedBox(
                height: 280,
                child: _TimeDial(
                  time: _time,
                  minutes: _minutes,
                  use24Hours: _use24Hours,
                  onChanged: _setTime,
                  onSelectionEnd: () {
                    if (!_minutes) setState(() => _minutes = true);
                  },
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  IconButton(
                    tooltip: material.inputTimeModeButtonLabel,
                    onPressed: () =>
                        Navigator.of(context)
                            .pop(_TimePickerResult(_time, switchMode: true)),
                    icon: Icon(Icons.keyboard_outlined, color: colors.muted),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: AppButtonLabel(material.cancelButtonLabel),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_TimePickerResult(_time)),
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

class _AppTimeInputDialog extends StatefulWidget {
  const _AppTimeInputDialog({
    required this.initialTime,
    required this.use24Hours,
  });

  final TimeOfDay initialTime;
  final bool use24Hours;

  @override
  State<_AppTimeInputDialog> createState() => _AppTimeInputDialogState();
}

class _AppTimeInputDialogState extends State<_AppTimeInputDialog> {
  late final _hourController = TextEditingController(
    text:
        (widget.use24Hours
                ? widget.initialTime.hour
                : widget.initialTime.hourOfPeriod == 0
                ? 12
                : widget.initialTime.hourOfPeriod)
            .toString()
            .padLeft(2, '0'),
  );
  late final _minuteController = TextEditingController(
    text: widget.initialTime.minute.toString().padLeft(2, '0'),
  );
  final _hourFocus = FocusNode();
  final _minuteFocus = FocusNode();
  late DayPeriod _period = widget.initialTime.period;
  bool _invalidHour = false;
  bool _invalidMinute = false;

  TimeOfDay? _value() {
    final rawHour = int.tryParse(_hourController.text);
    final minute = int.tryParse(_minuteController.text);
    final invalidHour =
        rawHour == null ||
        (widget.use24Hours
            ? rawHour < 0 || rawHour > 23
            : rawHour < 1 || rawHour > 12);
    final invalidMinute = minute == null || minute < 0 || minute > 59;
    setState(() {
      _invalidHour = invalidHour;
      _invalidMinute = invalidMinute;
    });
    if (invalidHour || invalidMinute) return null;
    final hour = widget.use24Hours
        ? rawHour
        : (rawHour % 12) + (_period == DayPeriod.pm ? 12 : 0);
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    super.dispose();
  }

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
                material.timePickerInputHelpText,
                style: TextStyle(
                  color: colors.gold,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TimeInputSegment(
                    controller: _hourController,
                    focusNode: _hourFocus,
                    nextFocus: _minuteFocus,
                    nextController: _minuteController,
                    invalid: _invalidHour,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      ':',
                      style: TextStyle(color: colors.text, fontSize: 32),
                    ),
                  ),
                  _TimeInputSegment(
                    controller: _minuteController,
                    focusNode: _minuteFocus,
                    invalid: _invalidMinute,
                  ),
                  if (!widget.use24Hours) ...[
                    const SizedBox(width: 10),
                    Column(
                      children: [
                        _PeriodButton(
                          label: 'AM',
                          selected: _period == DayPeriod.am,
                          onTap: () => setState(() => _period = DayPeriod.am),
                        ),
                        const SizedBox(height: 4),
                        _PeriodButton(
                          label: 'PM',
                          selected: _period == DayPeriod.pm,
                          onTap: () => setState(() => _period = DayPeriod.pm),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  IconButton(
                    tooltip: material.dialModeButtonLabel,
                    onPressed: () => Navigator.of(context).pop(
                      _TimePickerResult(widget.initialTime, switchMode: true),
                    ),
                    icon: Icon(Icons.access_time, color: colors.muted),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: AppButtonLabel(material.cancelButtonLabel),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final value = _value();
                      if (value != null) {
                        Navigator.of(context).pop(_TimePickerResult(value));
                      }
                    },
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

class _TimeInputSegment extends StatelessWidget {
  const _TimeInputSegment({
    required this.controller,
    required this.focusNode,
    required this.invalid,
    this.nextFocus,
    this.nextController,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool invalid;
  final FocusNode? nextFocus;
  final TextEditingController? nextController;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 78,
    child: TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: false,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(2),
      ],
      onTap: () => controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      ),
      onChanged: (value) {
        if (value.length == 2 && nextFocus != null) {
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
      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
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

class _TimeHeader extends StatelessWidget {
  const _TimeHeader({
    required this.time,
    required this.use24Hours,
    required this.minutesSelected,
    required this.onHours,
    required this.onMinutes,
    required this.onPeriod,
  });

  final TimeOfDay time;
  final bool use24Hours;
  final bool minutesSelected;
  final VoidCallback onHours;
  final VoidCallback onMinutes;
  final ValueChanged<DayPeriod> onPeriod;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hour = use24Hours
        ? time.hour
        : time.hourOfPeriod == 0
        ? 12
        : time.hourOfPeriod;
    Widget value(String text, bool selected, VoidCallback onTap) => Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadiusField),
        child: Container(
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.nightPanel,
            borderRadius: BorderRadius.circular(kRadiusField),
            border: Border.all(
              color: selected ? colors.gold : colors.nightBorder,
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: selected ? colors.gold : colors.text,
              fontSize: 34,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );

    return Row(
      children: [
        value(hour.toString().padLeft(2, '0'), !minutesSelected, onHours),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(':', style: TextStyle(color: colors.text, fontSize: 30)),
        ),
        value(
          time.minute.toString().padLeft(2, '0'),
          minutesSelected,
          onMinutes,
        ),
        if (!use24Hours) ...[
          const SizedBox(width: 8),
          Column(
            children: [
              _PeriodButton(
                label: 'AM',
                selected: time.period == DayPeriod.am,
                onTap: () => onPeriod(DayPeriod.am),
              ),
              const SizedBox(height: 4),
              _PeriodButton(
                label: 'PM',
                selected: time.period == DayPeriod.pm,
                onTap: () => onPeriod(DayPeriod.pm),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 46,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.gold : colors.nightPanel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? colors.gold : colors.nightBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? colors.onGold : colors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TimeDial extends StatelessWidget {
  const _TimeDial({
    required this.time,
    required this.minutes,
    required this.use24Hours,
    required this.onChanged,
    required this.onSelectionEnd,
  });
  final TimeOfDay time;
  final bool minutes;
  final bool use24Hours;
  final ValueChanged<TimeOfDay> onChanged;
  final VoidCallback onSelectionEnd;

  void _select(Offset position, Size size) {
    final center = size.center(Offset.zero);
    final delta = position - center;
    final turn = (math.atan2(delta.dx, -delta.dy) / (2 * math.pi) + 1) % 1;
    if (minutes) {
      onChanged(TimeOfDay(hour: time.hour, minute: (turn * 60).round() % 60));
      return;
    }
    var hour = (turn * 12).round() % 12;
    if (use24Hours) {
      final inner = delta.distance < size.shortestSide * 0.29;
      if (inner) hour = hour == 0 ? 0 : hour + 12;
    } else if (time.period == DayPeriod.pm) {
      hour += 12;
    }
    onChanged(TimeOfDay(hour: hour, minute: time.minute));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size.square(
        math.min(constraints.maxWidth, constraints.maxHeight),
      );
      return Center(
        child: GestureDetector(
          onTapUp: (details) {
            _select(details.localPosition, size);
            onSelectionEnd();
          },
          onPanUpdate: (details) => _select(details.localPosition, size),
          onPanEnd: (_) => onSelectionEnd(),
          child: SizedBox.fromSize(
            size: size,
            child: CustomPaint(
              painter: _TimeDialPainter(
                time: time,
                minutes: minutes,
                use24Hours: use24Hours,
                colors: context.colors,
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _TimeDialPainter extends CustomPainter {
  const _TimeDialPainter({
    required this.time,
    required this.minutes,
    required this.use24Hours,
    required this.colors,
  });
  final TimeOfDay time;
  final bool minutes;
  final bool use24Hours;
  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas.drawCircle(center, radius, Paint()..color = colors.nightPanel);
    final selectedValue = minutes ? time.minute : time.hour;
    final selectedTurn = minutes
        ? selectedValue / 60
        : (selectedValue % 12) / 12;
    final selectedInner =
        !minutes && use24Hours && (time.hour == 0 || time.hour > 12);
    final handRadius = radius * (selectedInner ? 0.56 : 0.78);
    final angle = selectedTurn * 2 * math.pi - math.pi / 2;
    final selectedCenter =
        center + Offset(math.cos(angle), math.sin(angle)) * handRadius;
    canvas.drawLine(
      center,
      selectedCenter,
      Paint()
        ..color = colors.gold
        ..strokeWidth = 2,
    );
    canvas.drawCircle(selectedCenter, 20, Paint()..color = colors.gold);

    void labels(double ring, List<String> values, {required bool inner}) {
      for (var i = 0; i < 12; i++) {
        final a = i / 12 * 2 * math.pi - math.pi / 2;
        final p = center + Offset(math.cos(a), math.sin(a)) * radius * ring;
        final value = values[i];
        final isSelected = minutes
            ? selectedValue == (i * 5) % 60
            : inner
            ? selectedInner && selectedValue == (i == 0 ? 0 : i + 12)
            : !selectedInner && selectedValue % 12 == i;
        final painter = TextPainter(
          text: TextSpan(
            style: TextStyle(
              color: isSelected ? colors.onGold : colors.text,
              fontSize: inner ? 12 : 14,
              fontWeight: FontWeight.w600,
            ),
            text: value,
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(
          canvas,
          p - Offset(painter.width / 2, painter.height / 2),
        );
      }
    }

    labels(
      0.78,
      minutes
          ? [for (var i = 0; i < 12; i++) (i * 5).toString().padLeft(2, '0')]
          : [for (var i = 0; i < 12; i++) (i == 0 ? 12 : i).toString()],
      inner: false,
    );
    if (!minutes && use24Hours) {
      labels(0.56, [
        for (var i = 0; i < 12; i++)
          (i == 0 ? 0 : i + 12).toString().padLeft(2, '0'),
      ], inner: true);
    }
  }

  @override
  bool shouldRepaint(covariant _TimeDialPainter oldDelegate) =>
      oldDelegate.time != time ||
      oldDelegate.minutes != minutes ||
      oldDelegate.use24Hours != use24Hours ||
      oldDelegate.colors != colors;
}
