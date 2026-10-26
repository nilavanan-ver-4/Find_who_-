import 'dart:ui';

Color colorFromHex(String hex) {
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

enum PosterPattern { none, dots, stripes, confetti, grid, rays }

PosterPattern patternFromName(String? n) => PosterPattern.values.firstWhere(
      (p) => p.name == n,
      orElse: () => PosterPattern.none,
    );

class PosterCategory {
  const PosterCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
  });

  final String id;
  final String name;
  final String emoji;
  final Color color;

  factory PosterCategory.fromJson(Map<String, dynamic> j) => PosterCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: j['emoji'] as String,
        color: colorFromHex(j['color'] as String),
      );
}

/// A ready-made poster. Captions may contain `{a}` and `{b}` placeholders
/// that are replaced with the friends' names.
class PosterTemplate {
  const PosterTemplate({
    required this.id,
    required this.category,
    required this.title,
    required this.caption,
    required this.emoji,
    required this.colors,
    required this.pattern,
    required this.textColor,
    required this.font,
    this.trending = false,
  });

  final String id;
  final String category;
  final String title;
  final String caption;
  final String emoji;
  final List<Color> colors;
  final PosterPattern pattern;
  final Color textColor;
  final String font;
  final bool trending;

  bool get usesSecondName => title.contains('{b}') || caption.contains('{b}');

  factory PosterTemplate.fromJson(Map<String, dynamic> j) => PosterTemplate(
        id: j['id'] as String,
        category: j['category'] as String,
        title: j['title'] as String,
        caption: j['caption'] as String,
        emoji: j['emoji'] as String,
        colors:
            (j['colors'] as List).map((e) => colorFromHex(e as String)).toList(),
        pattern: patternFromName(j['pattern'] as String?),
        textColor: colorFromHex((j['textColor'] as String?) ?? '#FFFFFF'),
        font: (j['font'] as String?) ?? 'sans-serif',
        trending: (j['trending'] as bool?) ?? false,
      );

  /// Whether the template matches a free-text search query.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) ||
        caption.toLowerCase().contains(q) ||
        category.toLowerCase().contains(q);
  }
}

String fillPlaceholders(String text, {required String a, required String b}) =>
    text.replaceAll('{a}', a).replaceAll('{b}', b);

class PosterInputs {
  const PosterInputs({this.nameA = '', this.nicknameA = '', this.nameB = ''});
  final String nameA;
  final String nicknameA;
  final String nameB;

  String get displayA {
    final n = nicknameA.trim();
    if (n.isNotEmpty) return n;
    final a = nameA.trim();
    return a.isEmpty ? 'Your Friend' : a;
  }

  String get displayB {
    final b = nameB.trim();
    return b.isEmpty ? 'Bestie' : b;
  }
}
