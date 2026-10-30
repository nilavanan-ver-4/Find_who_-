import 'poster_doc.dart';

class SavedPoster {
  const SavedPoster({
    required this.id,
    required this.title,
    required this.imagePath,
    required this.doc,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String imagePath;
  final PosterDoc doc;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'imagePath': imagePath,
        'doc': doc.toJson(),
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory SavedPoster.fromJson(Map<String, dynamic> j) => SavedPoster(
        id: j['id'] as String,
        title: j['title'] as String? ?? 'Poster',
        imagePath: j['imagePath'] as String,
        doc: PosterDoc.fromJson(j['doc'] as Map<String, dynamic>),
        createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int),
      );
}

enum HistoryKind { game, template, meme }

class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.kind,
    required this.refId,
    required this.title,
    this.detail = '',
    required this.at,
  });

  final String id;
  final HistoryKind kind;
  final String refId;
  final String title;
  final String detail;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'refId': refId,
        'title': title,
        'detail': detail,
        'at': at.millisecondsSinceEpoch,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        id: j['id'] as String,
        kind: HistoryKind.values.firstWhere((k) => k.name == j['kind']),
        refId: j['refId'] as String,
        title: j['title'] as String,
        detail: j['detail'] as String? ?? '',
        at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
      );
}
