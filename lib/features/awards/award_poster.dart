import 'package:flutter/material.dart';

import '../../models/content.dart';
import '../../models/poster_doc.dart';
import '../../models/poster_models.dart';

/// Builds an award certificate poster for [name].
PosterDoc buildAwardPoster(AwardItem award, String name,
    {PosterLayout layout = PosterLayout.portrait}) {
  const dark = Color(0xFF3E2723);
  return PosterDoc(
    layout: layout,
    colors: const [Color(0xFFFFE082), Color(0xFFFFA000)],
    pattern: PosterPattern.rays,
    border: PosterBorder.double,
    borderColor: dark,
    elements: [
      const PosterElement(id: 'head', kind: ElementKind.text, text: 'OFFICIAL AWARD', dy: 0.09, size: 16, color: dark),
      PosterElement(id: 'emoji', kind: ElementKind.sticker, text: award.emoji, dy: 0.25, size: 88),
      PosterElement(id: 'title', kind: ElementKind.text, text: award.title, dy: 0.43, size: 30, color: dark, font: 'serif'),
      const PosterElement(id: 'pre', kind: ElementKind.text, text: 'proudly presented to', dy: 0.56, size: 15, color: dark, bold: false),
      PosterElement(id: 'name', kind: ElementKind.text, text: name, dy: 0.65, size: 38, color: dark, font: 'cursive'),
      PosterElement(id: 'blurb', kind: ElementKind.text, text: award.blurb, dy: 0.80, size: 16, color: dark, bold: false),
      const PosterElement(id: 'foot', kind: ElementKind.text, text: '⭐ Certified by the Squad ⭐', dy: 0.92, size: 14, color: dark),
    ],
  );
}
