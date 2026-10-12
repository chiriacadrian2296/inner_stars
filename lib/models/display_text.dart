import 'habit.dart';
import 'project.dart';
import 'star.dart';

/// Upper-cases the first character, leaving the rest as typed. Names and
/// titles are stored exactly as the user wrote them; this is only applied
/// where they are shown.
String capitalizeFirst(String text) {
  if (text.isEmpty) return text;
  return text.substring(0, 1).toUpperCase() + text.substring(1);
}

extension StarDisplayTitle on Star {
  String get displayTitle => capitalizeFirst(title);
}

extension HabitDisplayTitle on Habit {
  String get displayTitle => capitalizeFirst(title);
}

extension ProjectDisplayName on Project {
  String get displayName => capitalizeFirst(name);
}
