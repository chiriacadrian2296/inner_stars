import 'package:flutter/material.dart';

import '../l10n/strings_scope.dart';
import '../theme/app_colors.dart';
import '../theme/app_style.dart';
import 'photo_image.dart';
import 'staggered_entrance.dart';

/// Either an empty tappable placeholder (no photo yet) or a preview of the
/// current photo, with a small remove button over its corner. Shared by
/// every place a star's photo gets picked/replaced — the add/edit form and
/// the reader's quick "mark achieved" sheet.
class PhotoPicker extends StatelessWidget {
  const PhotoPicker({
    super.key,
    required this.photoPath,
    required this.onPick,
    required this.onRemove,
  });

  final String? photoPath;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final strings = context.strings;
    final path = photoPath;

    if (path == null) {
      return StaggeredEntrance(
        index: 0,
        child: InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(kRadiusField),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            // Empty: the same dark, waiting field every other empty field is.
            decoration: fieldDecoration(colors, FieldState.empty),
            child: Column(
              children: [
                Icon(Icons.add_a_photo_outlined, color: colors.muted, size: 22),
                const SizedBox(height: 8),
                Text(
                  strings.addPhotoHint,
                  style: TextStyle(color: colors.muted, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final borderRadius = BorderRadius.circular(kRadiusField);
    final previewWidth = MediaQuery.sizeOf(context).width * 0.88;
    final previewHeight = previewWidth * 16 / 9;
    return StaggeredEntrance(
      index: 0,
      child: SizedBox(
        width: double.infinity,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              InkWell(
                onTap: onPick,
                borderRadius: borderRadius,
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: PhotoImage(
                    photoPath: path,
                    width: previewWidth,
                    height: previewHeight,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: InkWell(
                  onTap: onRemove,
                  customBorder: const CircleBorder(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.night,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.gold),
                    ),
                    child: Icon(Icons.close, size: 22, color: colors.gold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
