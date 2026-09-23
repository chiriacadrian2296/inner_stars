import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/life_area.dart';
import 'moodboard_storage.dart';

enum MoodboardKind { photo, video, quote }

class MoodboardItem {
  const MoodboardItem({
    required this.id,
    required this.kind,
    required this.content,
  });
  final String id;
  final MoodboardKind kind;
  final String content;
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'content': content,
  };
  factory MoodboardItem.fromJson(Map<String, dynamic> json) => MoodboardItem(
    id: json['id'] as String,
    kind: MoodboardKind.values.byName(json['kind'] as String),
    content: json['content'] as String,
  );
}

class MoodboardRepository {
  MoodboardRepository(this.prefs);
  final SharedPreferences prefs;
  static const _prefix = 'area-moodboard-v1:';
  static Future<MoodboardRepository> create() async =>
      MoodboardRepository(await SharedPreferences.getInstance());

  List<MoodboardItem> getItems(LifeArea area) {
    final raw = prefs.getString('$_prefix${area.name}');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => MoodboardItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(LifeArea area, List<MoodboardItem> items) async {
    if (!await prefs.setString(
      '$_prefix${area.name}',
      jsonEncode(items.map((e) => e.toJson()).toList()),
    )) {
      throw StateError('Could not save moodboard');
    }
  }

  Future<void> clear() async {
    for (final area in LifeArea.values) {
      final items = getItems(area);
      if (!await prefs.remove('$_prefix${area.name}')) {
        throw StateError('Could not clear moodboard');
      }
      for (final item in items) {
        if (item.kind != MoodboardKind.quote) {
          await MoodboardStorage.delete(item.content);
        }
      }
    }
  }
}
