import 'package:flutter/material.dart';

import '../data/shooting_star_wish_repository.dart';
import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import 'app_field.dart';
import 'pill_action_button.dart';

class SkyShootingStarTooltip extends StatefulWidget {
  const SkyShootingStarTooltip({
    super.key,
    required this.repository,
    required this.onClose,
    required this.onCreateActivity,
    required this.onReflectOnArea,
  });

  final ShootingStarWishRepository repository;
  final VoidCallback onClose;
  final Future<void> Function() onCreateActivity;
  final Future<void> Function() onReflectOnArea;

  @override
  State<SkyShootingStarTooltip> createState() => _SkyShootingStarTooltipState();
}

class _SkyShootingStarTooltipState extends State<SkyShootingStarTooltip> {
  late final _controller = TextEditingController(
    text: widget.repository.wish ?? '',
  )..addListener(_onEdited);
  bool _saving = false;

  bool get _changed =>
      _controller.text.trim() != (widget.repository.wish ?? '');
  bool get _canSave => _controller.text.trim().isNotEmpty && _changed;
  bool get _hasExpressedWish =>
      widget.repository.wish != null && !_changed && !_saving;

  void _onEdited() => setState(() {});

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    await widget.repository.save(_controller.text);
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _takeStep(Future<void> Function() action) async {
    if (!_hasExpressedWish) return;
    await action();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onEdited)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colors = context.colors;
    final hasWish = _hasExpressedWish;
    return Material(
      color: colors.nightPanel,
      borderRadius: BorderRadius.circular(kRadiusCard),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: colors.gold, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.shootingStarWishTitle,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: widget.onClose,
                  icon: Icon(Icons.close, color: colors.muted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              strings.shootingStarWishPrompt,
              style: TextStyle(color: colors.muted, height: 1.35),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _controller,
              minLines: 2,
              maxLines: 4,
              maxLength: 300,
              showCounter: true,
              hintText: strings.shootingStarWishHint,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.center,
              child: SaveActionButton(
                label: strings.shootingStarWishSave,
                lit: _canSave && !_saving,
                onPressed: _canSave && !_saving ? _save : null,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              strings.shootingStarStepTitle,
              style: TextStyle(
                color: hasWish ? colors.text : colors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SaveActionButton(
                      label: strings.shootingStarCreateActivity,
                      icon: Icons.star_outline,
                      lit: hasWish,
                      onPressed: hasWish
                          ? () => _takeStep(widget.onCreateActivity)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: PillActionButton(
                      icon: Icons.psychology_outlined,
                      label: strings.shootingStarReflectOnArea,
                      onTap: hasWish
                          ? () => _takeStep(widget.onReflectOnArea)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
