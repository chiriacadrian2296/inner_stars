import 'rich_text_document.dart';

/// A keyed text value whose empty/deleted state can be synchronized.
class SyncTextValue {
  const SyncTextValue({
    required this.value,
    required this.updatedAt,
    this.deleted = false,
    this.richText,
  });
  final String value;
  final RichTextDocument? richText;
  final DateTime updatedAt;
  final bool deleted;

  factory SyncTextValue.fromJson(Map<String, dynamic> json) => SyncTextValue(
    value: json['value'] as String,
    richText: RichTextDocument.tryParse(json['richText']),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    deleted: json['deleted'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'value': value,
    if (richText != null) 'richText': richText!.toJson(),
    'updatedAt': updatedAt.toIso8601String(),
    'deleted': deleted,
  };
}
