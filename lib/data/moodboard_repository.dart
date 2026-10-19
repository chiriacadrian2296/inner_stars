import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/life_area.dart';
import 'moodboard_storage.dart';
import 'repository_write.dart';

const kMaxMoodboardItems = 12;
const moodboardStorageKey = 'moodboard-items-v2';
const legacyMoodboardPrefix = 'area-moodboard-v1:';

class MoodboardLimitException implements Exception {
  const MoodboardLimitException();
}

enum MoodboardKind { photo, video, quote }

enum MoodboardQuoteStyle {
  celestial,
  aurora,
  editorial,
  constellation,
  minimal,
}

class MoodboardItem {
  const MoodboardItem({
    required this.id,
    required this.kind,
    required this.content,
    this.author = '',
    this.quoteStyle = MoodboardQuoteStyle.celestial,
    this.area,
    this.position = 0,
    // Public named argument; the getter supplies the legacy fallback.
    DateTime? updatedAt,
    this.deleted = false,
    // ignore: prefer_initializing_formals
  }) : _updatedAt = updatedAt;
  final String id;
  final MoodboardKind kind;
  final String content;
  final String author;
  final MoodboardQuoteStyle quoteStyle;
  final LifeArea? area;
  final int position;
  final DateTime? _updatedAt;
  DateTime get updatedAt =>
      _updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  final bool deleted;

  MoodboardItem copyWith({
    String? id,
    LifeArea? area,
    int? position,
    DateTime? updatedAt,
    bool? deleted,
  }) => MoodboardItem(
    id: id ?? this.id,
    kind: kind,
    content: content,
    author: author,
    quoteStyle: quoteStyle,
    area: area ?? this.area,
    position: position ?? this.position,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'content': content,
    if (area != null) 'area': area!.name,
    'position': position,
    'updatedAt': updatedAt.toIso8601String(),
    'deleted': deleted,
    if (author.isNotEmpty) 'author': author,
    if (kind == MoodboardKind.quote) 'quoteStyle': quoteStyle.name,
  };
  factory MoodboardItem.fromJson(Map<String, dynamic> json) {
    final rawStyle = json['quoteStyle'] as String?;
    return MoodboardItem(
      id: json['id'] as String,
      kind: MoodboardKind.values.byName(json['kind'] as String),
      content: json['content'] as String,
      area: json['area'] == null
          ? null
          : LifeArea.values.byName(json['area'] as String),
      position: json['position'] as int? ?? 0,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      deleted: json['deleted'] as bool? ?? false,
      author: json['author'] as String? ?? '',
      quoteStyle:
          MoodboardQuoteStyle.values
              .where((style) => style.name == rawStyle)
              .firstOrNull ??
          MoodboardQuoteStyle.celestial,
    );
  }
}

class MoodboardRepository {
  MoodboardRepository(this.prefs);
  final SharedPreferences prefs;
  static Future<MoodboardRepository> create() async =>
      MoodboardRepository(await SharedPreferences.getInstance());

  List<MoodboardItem> getAll({bool includeDeleted = false}) {
    final raw = prefs.getString(moodboardStorageKey);
    final List<MoodboardItem> all;
    if (raw != null) {
      all = (jsonDecode(raw) as Map<String, dynamic>).entries.map((entry) {
        final item = MoodboardItem.fromJson(
          entry.value as Map<String, dynamic>,
        );
        if (item.id != entry.key || item.area == null) {
          throw const FormatException('Invalid moodboard record');
        }
        return item;
      }).toList();
    } else {
      all = [for (final area in LifeArea.values) ..._legacyItems(area)];
    }
    return all.where((item) => includeDeleted || !item.deleted).toList();
  }

  List<MoodboardItem> _legacyItems(LifeArea area) {
    final raw = prefs.getString('$legacyMoodboardPrefix${area.name}');
    if (raw == null) return [];
    final values = jsonDecode(raw) as List;
    return [
      for (var i = 0; i < values.length; i++)
        MoodboardItem.fromJson(
          Map<String, dynamic>.from(values[i] as Map),
        ).copyWith(area: area, position: i, deleted: i >= kMaxMoodboardItems),
    ];
  }

  List<MoodboardItem> getItems(LifeArea area) {
    final items = getAll().where((item) => item.area == area).toList()
      ..sort((a, b) {
        final byPosition = a.position.compareTo(b.position);
        return byPosition != 0 ? byPosition : a.id.compareTo(b.id);
      });
    return items.take(kMaxMoodboardItems).toList();
  }

  Future<void> save(LifeArea area, List<MoodboardItem> items) async {
    if (items.length > kMaxMoodboardItems) {
      throw const MoodboardLimitException();
    }
    final all = getAll();
    final previous = {for (final item in all) item.id: item};
    final ids = <String>{};
    for (final item in items) {
      if (!ids.add(item.id)) throw StateError('Duplicate moodboard identity');
      final existing = previous[item.id];
      if (existing != null && existing.area != area) {
        throw StateError('Moodboard identity belongs to another area');
      }
      if (item.kind == MoodboardKind.video &&
          (existing == null ||
              existing.kind != MoodboardKind.video ||
              existing.content != item.content)) {
        throw UnsupportedError('New moodboard videos are not supported');
      }
    }
    await _saveAll({
      for (final item in all)
        if (item.area != area) item.id: item,
      for (var i = 0; i < items.length; i++)
        items[i].id: items[i].copyWith(area: area, position: i, deleted: false),
    });
  }

  Future<void> _saveAll(Map<String, MoodboardItem> items) async {
    if (!prefs.containsKey(moodboardStorageKey) &&
        prefs.getKeys().any((key) => key.startsWith(legacyMoodboardPrefix))) {
      throw StateError('Migrate legacy moodboard data before writing');
    }
    await writeSyncMap<MoodboardItem>(
      prefs,
      moodboardStorageKey,
      items,
      encode: (item) => item.toJson(),
      decode: MoodboardItem.fromJson,
    );
  }

  Future<void> clear() async {
    final items = getAll();
    await _saveAll({});
    for (final item in items) {
      if (item.kind != MoodboardKind.quote) {
        await MoodboardStorage.delete(item.content);
      }
    }
  }
}
