import 'package:flutter/material.dart';

import '../theme/app_style.dart';

/// The small white dot that separates two groups of action buttons in a dock
/// or reader bar: one dot per gap, [kActionGroupGap] wide in total.
class ActionGroupDot extends StatelessWidget {
  const ActionGroupDot({super.key, this.width = kActionGroupGap});

  /// Layout width this takes. Inside a [Wrap], which already adds its own
  /// spacing either side, pass only the extra; the dot stays centred.
  final double width;

  static const _size = 4.0;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: _size,
    child: OverflowBox(
      minWidth: 0,
      maxWidth: _size,
      minHeight: 0,
      maxHeight: _size,
      child: Center(
        child: Container(
          width: _size,
          height: _size,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      ),
    ),
  );
}
