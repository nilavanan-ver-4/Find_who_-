import 'dart:ui';

import 'poster_doc.dart';
import 'poster_models.dart';

class MemeCategory {
  const MemeCategory({required this.id, required this.name, required this.emoji});
  final String id;
  final String name;
  final String emoji;

  factory MemeCategory.fromJson(Map<String, dynamic> j) => MemeCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: (j['emoji'] as String?) ?? '😂',
      );
}

/// A default text layer of a meme template.
class MemeLayer {
  const MemeLayer({
    required this.role,
    required this.text,
    this.dx = 0.5,
    this.dy = 0.5,
    this.size = 28,
    this.color = const Color(0xFFFFFFFF),
    this.outlineColor = const Color(0xFF000000),
    this.outline = 4,
    this.font = 'MuktaMalar',
    this.align = 1,
  });

  /// `top` and `bottom` follow the image edges when the format changes;
  /// `free` keeps `dx` / `dy`.
  final String role;
  final String text;
  final double dx;
  final double dy;
  final double size;
  final Color color;
  final Color outlineColor;
  final double outline;
  final String font;
  final int align;

  factory MemeLayer.fromJson(Map<String, dynamic> j) => MemeLayer(
        role: (j['role'] as String?) ?? 'free',
        text: (j['text'] as String?) ?? '',
        dx: (j['dx'] as num?)?.toDouble() ?? 0.5,
        dy: (j['dy'] as num?)?.toDouble() ?? 0.5,
        size: (j['size'] as num?)?.toDouble() ?? 28,
        color: j['color'] == null ? const Color(0xFFFFFFFF) : colorFromHex(j['color'] as String),
        outlineColor: j['outlineColor'] == null ? const Color(0xFF000000) : colorFromHex(j['outlineColor'] as String),
        outline: (j['outline'] as num?)?.toDouble() ?? 4,
        font: (j['font'] as String?) ?? 'MuktaMalar',
        align: (j['align'] as int?) ?? 1,
      );
}

class MemeTemplate {
  const MemeTemplate({
    required this.id,
    required this.title,
    required this.category,
    required this.imageRef,
    this.actor = '',
    this.source = '',
    this.aspect = 1,
    this.tags = const [],
    this.captions = const [],
    this.layers = const [],
    this.license = '',
    this.referenceNote = '',
    this.referenceUrl = '',
    this.isUser = false,
    this.pack = '',
  });

  final String id;
  final String title;
  final String category;

  /// `asset:<path>` for bundled images, otherwise an absolute file path.
  final String imageRef;
  final String actor;
  final String source;

  /// width / height of the blank image.
  final double aspect;
  final List<String> tags;
  final List<String> captions;
  final List<MemeLayer> layers;
  final String license;
  final String referenceNote;
  final String referenceUrl;

  /// Added by the user inside the app.
  final bool isUser;

  /// Name of the template pack it came from.
  final String pack;

  bool get isAsset => imageRef.startsWith('asset:');
  String get assetPath => imageRef.substring('asset:'.length);

  /// "Vadivelu · Tamil cinema comedy" style subtitle.
  String get subtitle => [actor, source].where((e) => e.trim().isNotEmpty).join(' · ');

  bool matches(String query, {String categoryName = ''}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    bool has(String v) => v.toLowerCase().contains(q);
    return has(id) ||
        has(title) ||
        has(actor) ||
        has(source) ||
        has(categoryName) ||
        tags.any(has) ||
        captions.any(has);
  }

  /// Parses one template. [imageResolver] turns the `image` value from JSON
  /// into an `imageRef` (bundled packs use `asset:`, external packs absolute paths).
  factory MemeTemplate.fromJson(
    Map<String, dynamic> j, {
    required String Function(String image) imageResolver,
    bool isUser = false,
    String pack = '',
  }) {
    List<String> strings(dynamic v) => ((v as List?) ?? const []).map((e) => e.toString()).toList();
    final ref = (j['reference'] as Map?)?.cast<String, dynamic>() ?? const {};
    return MemeTemplate(
      id: j['id'] as String,
      title: j['title'] as String,
      category: (j['category'] as String?) ?? 'relatable',
      imageRef: imageResolver(j['image'] as String),
      actor: (j['actor'] as String?) ?? '',
      source: (j['source'] as String?) ?? '',
      aspect: ((j['aspect'] as num?)?.toDouble() ?? 1).clamp(0.3, 3.0).toDouble(),
      tags: strings(j['tags']),
      captions: strings(j['captions']),
      layers: ((j['layers'] as List?) ?? const [])
          .map((e) => MemeLayer.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      license: (j['license'] as String?) ?? '',
      referenceNote: (ref['note'] as String?) ?? '',
      referenceUrl: (ref['url'] as String?) ?? '',
      isUser: isUser,
      pack: pack,
    );
  }

  Map<String, dynamic> toUserJson() => {
        'id': id,
        'title': title,
        'category': category,
        'image': imageRef,
        'actor': actor,
        'source': source,
        'aspect': aspect,
        'tags': tags,
        'captions': captions,
        'license': license,
        'layers': [
          for (final l in layers) {'role': l.role, 'text': l.text},
        ],
      };
}

class MemeCatalog {
  const MemeCatalog({required this.categories, required this.templates});
  final List<MemeCategory> categories;
  final List<MemeTemplate> templates;

  static const empty = MemeCatalog(categories: [], templates: []);

  MemeCategory? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  MemeTemplate? byId(String id) {
    for (final t in templates) {
      if (t.id == id) return t;
    }
    return null;
  }

  MemeCatalog merged(MemeCatalog other) {
    final ids = templates.map((t) => t.id).toSet();
    final catIds = categories.map((c) => c.id).toSet();
    return MemeCatalog(
      categories: [...categories, ...other.categories.where((c) => !catIds.contains(c.id))],
      templates: [...templates, ...other.templates.where((t) => !ids.contains(t.id))],
    );
  }
}

/// Parses a template pack (`pack.json`). Invalid templates are skipped and
/// reported in [problems] instead of breaking the whole pack.
class MemePackParser {
  MemePackParser({required this.imageResolver, this.imageExists, this.isUser = false});
  final String Function(String image) imageResolver;

  /// Optional check that the resolved image exists (used for external packs).
  final bool Function(String imageRef)? imageExists;
  final bool isUser;
  final List<String> problems = [];

  MemeCatalog parse(Map<String, dynamic> json) {
    final pack = (json['pack'] as String?) ?? 'pack';
    final cats = <MemeCategory>[];
    for (final c in (json['categories'] as List?) ?? const []) {
      try {
        cats.add(MemeCategory.fromJson((c as Map).cast<String, dynamic>()));
      } catch (e) {
        problems.add('$pack: bad category ($e)');
      }
    }
    final seen = <String>{};
    final out = <MemeTemplate>[];
    for (final t in (json['templates'] as List?) ?? const []) {
      try {
        final tpl = MemeTemplate.fromJson((t as Map).cast<String, dynamic>(),
            imageResolver: imageResolver, isUser: isUser, pack: pack);
        if (!seen.add(tpl.id)) {
          problems.add('$pack: duplicate id ${tpl.id}');
          continue;
        }
        if (imageExists != null && !imageExists!(tpl.imageRef)) {
          problems.add('$pack: missing image for ${tpl.id}');
          continue;
        }
        out.add(tpl);
      } catch (e) {
        problems.add('$pack: bad template ($e)');
      }
    }
    return MemeCatalog(categories: cats, templates: out);
  }
}

/// Builds the poster for a meme template and re-flows it when the output
/// format changes. All numbers are on the 360 pt design grid.
class MemeDocBuilder {
  /// Distance from the image edge to the caption's centre (grid units); leaves
  /// room for two lines of text without touching the edge.
  static const captionMargin = 52.0;

  static PosterDoc build(MemeTemplate t, {PosterLayout layout = PosterLayout.square}) {
    final layers = t.layers.isEmpty
        ? const [MemeLayer(role: 'top', text: ''), MemeLayer(role: 'bottom', text: '')]
        : t.layers;
    final elements = <PosterElement>[
      PosterElement(
        id: kMemeImageId,
        kind: ElementKind.photo,
        text: t.imageRef,
        size: 360,
        aspect: t.aspect,
        shape: PhotoShape.plain,
      ),
      for (var i = 0; i < layers.length; i++)
        PosterElement(
          id: layers[i].role == 'top'
              ? 'cap_top'
              : layers[i].role == 'bottom'
                  ? 'cap_bottom'
                  : 'cap_$i',
          kind: ElementKind.text,
          text: layers[i].text,
          dx: layers[i].dx,
          dy: layers[i].dy,
          size: layers[i].size,
          color: layers[i].color,
          font: layers[i].font,
          outline: layers[i].outline,
          outlineColor: layers[i].outlineColor,
          align: layers[i].align,
        ),
    ];
    return reflow(
      PosterDoc(
        templateId: t.id,
        layout: layout,
        colors: const [Color(0xFF101114), Color(0xFF101114)],
        pattern: PosterPattern.none,
        elements: elements,
      ),
      layout,
    );
  }

  /// Positions the image and the top / bottom captions for [layout].
  static PosterDoc reflow(PosterDoc doc, PosterLayout layout) {
    final img = doc.elementById(kMemeImageId);
    if (img == null) return doc.copyWith(layout: layout);
    final h = 360 / layout.aspect; // poster height on the grid
    // contain the image inside the poster
    final width = 360 / img.aspect > h ? h * img.aspect : 360.0;
    final ih = width / img.aspect;
    final top = (h - ih) / 2;
    final bar = top; // empty bar above and below the image
    double capTop;
    double capBottom;
    if (bar >= 70) {
      // roomy bars (story): captions sit in the bars
      capTop = bar / 2;
      capBottom = h - bar / 2;
    } else {
      capTop = top + captionMargin;
      capBottom = top + ih - captionMargin;
    }
    return doc.copyWith(
      layout: layout,
      elements: [
        for (final e in doc.elements)
          if (e.id == kMemeImageId)
            e.copyWith(size: width, dx: 0.5, dy: 0.5)
          else if (e.id == 'cap_top')
            e.copyWith(dx: 0.5, dy: capTop / h)
          else if (e.id == 'cap_bottom')
            e.copyWith(dx: 0.5, dy: capBottom / h)
          else
            e,
      ],
    );
  }
}
