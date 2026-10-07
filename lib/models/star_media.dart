/// What kind of extra memory a [StarMedia] holds, attached to a victory on
/// top of its cover photo.
enum StarMediaKind { voice, photo, video, link }

/// Most extras a single victory can carry.
const int kMaxStarMedia = 10;

/// One optional extra attached to a lit star: a voice note, a secondary
/// photo, a short video, or a link. File-backed kinds keep an opaque file
/// name in [path] (resolved by `StarMediaStorage`); a link keeps its address
/// in [url].
class StarMedia {
  const StarMedia({
    required this.id,
    required this.kind,
    this.path,
    this.url,
    this.label,
    this.durationMs,
    required this.createdAt,
  }) : assert(
         kind == StarMediaKind.link ? url != null : path != null,
         'a link needs a url, every other kind needs a path',
       );

  final String id;
  final StarMediaKind kind;
  final String? path;
  final String? url;
  final String? label;
  final int? durationMs;
  final DateTime createdAt;

  bool get isFile => kind != StarMediaKind.link;

  /// Null for an item whose kind this version doesn't know (e.g. one saved
  /// by a build that had a kind since removed), so loading a star never
  /// fails over a leftover extra.
  static StarMedia? tryFromJson(Map<String, dynamic> json) {
    final kind = StarMediaKind.values
        .where((k) => k.name == json['kind'])
        .firstOrNull;
    if (kind == null) return null;
    return StarMedia(
      id: json['id'] as String,
      kind: kind,
      path: json['path'] as String?,
      url: json['url'] as String?,
      label: json['label'] as String?,
      durationMs: json['durationMs'] as int?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'path': path,
    'url': url,
    'label': label,
    'durationMs': durationMs,
    'createdAt': createdAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is StarMedia &&
      other.id == id &&
      other.kind == kind &&
      other.path == path &&
      other.url == url &&
      other.label == label &&
      other.durationMs == durationMs &&
      other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(id, kind, path, url, label, durationMs, createdAt);
}
