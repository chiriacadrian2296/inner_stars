import 'rich_text_document.dart';
import 'life_area.dart';

enum ReflectionOrigin { free, suggested }

/// A single editable reflection, belonging to one area throughout its life.
class Reflection {
  const Reflection({
    required this.id,
    required this.area,
    required this.title,
    required this.body,
    required this.origin,
    required this.createdAt,
    required this.updatedAt,
    this.richText,
    this.questionId,
    this.questionText,
    this.deleted = false,
  });

  final String id;
  final LifeArea area;
  final String title;
  final String body;
  final RichTextDocument? richText;
  final ReflectionOrigin origin;
  final String? questionId;

  /// Original prompt, independent of the user's editable title and locale.
  final String? questionText;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool deleted;

  Reflection edit({
    required String title,
    required String body,
    RichTextDocument? richText,
  }) => Reflection(
    id: id,
    area: area,
    title: title,
    body: body,
    richText: richText ?? (body == this.body ? this.richText : null),
    origin: origin,
    questionId: questionId,
    questionText: questionText,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deleted: deleted,
  );

  factory Reflection.fromJson(Map<String, dynamic> json) => Reflection(
    id: json['id'] as String,
    area: LifeArea.values.byName(json['area'] as String),
    title: json['title'] as String,
    body: json['body'] as String,
    richText: RichTextDocument.tryParse(json['richText']),
    origin: ReflectionOrigin.values.byName(json['origin'] as String),
    questionId: json['questionId'] as String?,
    questionText: json['questionText'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    deleted: json['deleted'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'area': area.name,
    'title': title,
    'body': body,
    if (richText != null) 'richText': richText!.toJson(),
    'origin': origin.name,
    'questionId': questionId,
    if (questionText != null) 'questionText': questionText,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'deleted': deleted,
  };
}
