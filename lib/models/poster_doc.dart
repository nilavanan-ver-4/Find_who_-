import 'dart:math';
import 'dart:ui';

import 'poster_models.dart';

enum PosterLayout {
  square('Square', '1:1', 1.0),
  portrait('Portrait', '4:5', 4 / 5),
  story('Story', '9:16', 9 / 16);

  const PosterLayout(this.label, this.ratioLabel, this.aspect);
  final String label;
  final String ratioLabel;

  /// width / height
  final double aspect;

  /// Export size in pixels.
  Size get exportSize => switch (this) {
        PosterLayout.square => const Size(1080, 1080),
        PosterLayout.portrait => const Size(1080, 1350),
        PosterLayout.story => const Size(1080, 1920),
      };
}

enum PosterBorder { none, solid, dashed, double, rounded }

enum ElementKind { text, sticker }

/// Width of the design grid that font sizes refer to.
const double kPosterBaseWidth = 360;

class PosterElement {
  const PosterElement({
    required this.id,
    required this.kind,
    required this.text,
    this.dx = 0.5,
    this.dy = 0.5,
    this.size = 24,
    this.color = const Color(0xFFFFFFFF),
    this.font = 'sans-serif',
    this.bold = true,
  });

  final String id;
  final ElementKind kind;
  final String text;

  /// Center position as a fraction (0..1) of poster width / height.
  final double dx;
  final double dy;

  /// Font size on the 360 pt design grid.
  final double size;
  final Color color;
  final String font;
  final bool bold;

  PosterElement copyWith({
    String? text,
    double? dx,
    double? dy,
    double? size,
    Color? color,
    String? font,
    bool? bold,
  }) =>
      PosterElement(
        id: id,
        kind: kind,
        text: text ?? this.text,
        dx: (dx ?? this.dx).clamp(0.0, 1.0),
        dy: (dy ?? this.dy).clamp(0.0, 1.0),
        size: size ?? this.size,
        color: color ?? this.color,
        font: font ?? this.font,
        bold: bold ?? this.bold,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'text': text,
        'dx': dx,
        'dy': dy,
        'size': size,
        'color': color.toARGB32(),
        'font': font,
        'bold': bold,
      };

  factory PosterElement.fromJson(Map<String, dynamic> j) => PosterElement(
        id: j['id'] as String,
        kind: ElementKind.values.firstWhere((k) => k.name == j['kind'],
            orElse: () => ElementKind.text),
        text: j['text'] as String? ?? '',
        dx: (j['dx'] as num?)?.toDouble() ?? 0.5,
        dy: (j['dy'] as num?)?.toDouble() ?? 0.5,
        size: (j['size'] as num?)?.toDouble() ?? 24,
        color: Color((j['color'] as int?) ?? 0xFFFFFFFF),
        font: j['font'] as String? ?? 'sans-serif',
        bold: j['bold'] as bool? ?? true,
      );
}

/// Complete, serialisable description of a poster. Immutable: every edit
/// creates a new instance which makes undo trivial.
class PosterDoc {
  const PosterDoc({
    this.templateId,
    this.layout = PosterLayout.portrait,
    this.colors = const [Color(0xFFFF6B9D), Color(0xFFC2185B)],
    this.pattern = PosterPattern.dots,
    this.photoPath,
    this.border = PosterBorder.none,
    this.borderColor = const Color(0xFFFFFFFF),
    this.elements = const [],
  });

  final String? templateId;
  final PosterLayout layout;
  final List<Color> colors;
  final PosterPattern pattern;
  final String? photoPath;
  final PosterBorder border;
  final Color borderColor;
  final List<PosterElement> elements;

  PosterDoc copyWith({
    PosterLayout? layout,
    List<Color>? colors,
    PosterPattern? pattern,
    Object? photoPath = _unset,
    PosterBorder? border,
    Color? borderColor,
    List<PosterElement>? elements,
  }) =>
      PosterDoc(
        templateId: templateId,
        layout: layout ?? this.layout,
        colors: colors ?? this.colors,
        pattern: pattern ?? this.pattern,
        photoPath: identical(photoPath, _unset)
            ? this.photoPath
            : photoPath as String?,
        border: border ?? this.border,
        borderColor: borderColor ?? this.borderColor,
        elements: elements ?? this.elements,
      );

  PosterDoc updateElement(PosterElement e) => copyWith(
        elements: [for (final x in elements) x.id == e.id ? e : x],
      );

  PosterDoc removeElement(String id) =>
      copyWith(elements: elements.where((e) => e.id != id).toList());

  PosterElement? elementById(String? id) {
    for (final e in elements) {
      if (e.id == id) return e;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'templateId': templateId,
        'layout': layout.name,
        'colors': colors.map((c) => c.toARGB32()).toList(),
        'pattern': pattern.name,
        'photoPath': photoPath,
        'border': border.name,
        'borderColor': borderColor.toARGB32(),
        'elements': elements.map((e) => e.toJson()).toList(),
      };

  factory PosterDoc.fromJson(Map<String, dynamic> j) => PosterDoc(
        templateId: j['templateId'] as String?,
        layout: PosterLayout.values.firstWhere((l) => l.name == j['layout'],
            orElse: () => PosterLayout.portrait),
        colors: ((j['colors'] as List?) ?? const [0xFFFF6B9D, 0xFFC2185B])
            .map((c) => Color(c as int))
            .toList(),
        pattern: patternFromName(j['pattern'] as String?),
        photoPath: j['photoPath'] as String?,
        border: PosterBorder.values.firstWhere((b) => b.name == j['border'],
            orElse: () => PosterBorder.none),
        borderColor: Color((j['borderColor'] as int?) ?? 0xFFFFFFFF),
        elements: ((j['elements'] as List?) ?? const [])
            .map((e) => PosterElement.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Builds a poster from a template and the user's inputs.
  factory PosterDoc.fromTemplate(
    PosterTemplate t, {
    PosterInputs inputs = const PosterInputs(),
    PosterLayout layout = PosterLayout.portrait,
    String? photoPath,
  }) {
    final a = inputs.displayA;
    final b = inputs.displayB;
    final title = fillPlaceholders(t.title, a: a, b: b);
    final caption = fillPlaceholders(t.caption, a: a, b: b);
    final hasPhoto = photoPath != null;
    return PosterDoc(
      templateId: t.id,
      layout: layout,
      colors: t.colors,
      pattern: t.pattern,
      photoPath: photoPath,
      elements: [
        PosterElement(
          id: 'emoji',
          kind: ElementKind.sticker,
          text: t.emoji,
          dy: hasPhoto ? 0.14 : 0.27,
          size: hasPhoto ? 56 : 96,
        ),
        PosterElement(
          id: 'title',
          kind: ElementKind.text,
          text: title,
          dy: hasPhoto ? 0.66 : 0.55,
          size: title.length > 28 ? 28 : 34,
          color: t.textColor,
          font: t.font,
        ),
        PosterElement(
          id: 'caption',
          kind: ElementKind.text,
          text: caption,
          dy: hasPhoto ? 0.84 : 0.77,
          size: 18,
          color: t.textColor,
          font: t.font,
          bold: false,
        ),
      ],
    );
  }

  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(9999)}';
}

const Object _unset = Object();
