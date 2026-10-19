/// A keyed text value whose empty/deleted state can be synchronized.
class SyncTextValue {
  const SyncTextValue({
    required this.value,
    required this.updatedAt,
    this.deleted = false,
  });
  final String value;
  final DateTime updatedAt;
  final bool deleted;

  factory SyncTextValue.fromJson(Map<String, dynamic> json) => SyncTextValue(
    value: json['value'] as String,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    deleted: json['deleted'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'value': value,
    'updatedAt': updatedAt.toIso8601String(),
    'deleted': deleted,
  };
}
