import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/poster_doc.dart';
import '../models/poster_models.dart';

TextStyle posterTextStyle(PosterElement e, double scale) {
  final isSticker = e.kind == ElementKind.sticker;
  return TextStyle(
    fontSize: e.size * scale,
    color: e.color,
    fontFamily: isSticker ? null : e.font,
    fontWeight: e.bold ? FontWeight.w900 : FontWeight.w600,
    height: isSticker ? 1.1 : 1.2,
    shadows: isSticker || e.color.computeLuminance() > 0.7
        ? [Shadow(color: const Color(0x66000000), blurRadius: 4 * scale, offset: Offset(1.5 * scale, 2 * scale))]
        : null,
  );
}

/// Max width an element may occupy, as a fraction of the poster width.
const double kElementMaxWidthFraction = 0.88;

Size measureElement(PosterElement e, double posterWidth) {
  final scale = posterWidth / kPosterBaseWidth;
  final tp = TextPainter(
    text: TextSpan(text: e.text, style: posterTextStyle(e, scale)),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout(maxWidth: posterWidth * kElementMaxWidthFraction);
  final size = Size(tp.width, tp.height);
  tp.dispose();
  return size;
}

/// Alignment that places an element's centre at (dx, dy) while keeping it
/// fully inside the poster.
Alignment elementAlignment(PosterElement e) => Alignment(e.dx * 2 - 1, e.dy * 2 - 1);

/// Pure rendering of a poster. Used for thumbnails, the live editor preview
/// and export so what you see is exactly what you get.
class PosterView extends StatelessWidget {
  const PosterView({super.key, required this.doc, this.photoCacheWidth = 1080});

  final PosterDoc doc;
  final int photoCacheWidth;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: doc.layout.aspect,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final scale = w / kPosterBaseWidth;
          return ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: PosterBackgroundPainter(doc.colors, doc.pattern)),
                if (doc.photoPath != null) _Photo(path: doc.photoPath!, cacheWidth: photoCacheWidth),
                if (doc.border != PosterBorder.none)
                  CustomPaint(painter: BorderPainter(doc.border, doc.borderColor, scale)),
                for (final e in doc.elements)
                  Align(
                    alignment: elementAlignment(e),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: w * kElementMaxWidthFraction),
                      child: Text(
                        e.text,
                        textAlign: TextAlign.center,
                        style: posterTextStyle(e, scale),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.path, required this.cacheWidth});
  final String path;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
          child: FractionallySizedBox(
            alignment: Alignment.topCenter,
            heightFactor: 0.55,
            widthFactor: 0.8,
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  cacheWidth: cacheWidth,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Color(0x33000000),
                    child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.white70)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PosterBackgroundPainter extends CustomPainter {
  PosterBackgroundPainter(this.colors, this.pattern);
  final List<Color> colors;
  final PosterPattern pattern;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final cs = colors.length >= 2 ? colors : [colors.first, colors.first];
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: cs,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );
    final p = Paint()..color = Colors.white.withValues(alpha: 0.14);
    final u = size.width / 360;
    switch (pattern) {
      case PosterPattern.none:
        break;
      case PosterPattern.dots:
        final step = 28 * u;
        for (double y = step / 2; y < size.height; y += step) {
          final row = (y / step).floor();
          for (double x = (row.isEven ? step / 2 : step); x < size.width; x += step) {
            canvas.drawCircle(Offset(x, y), 4 * u, p);
          }
        }
      case PosterPattern.stripes:
        p
          ..strokeWidth = 14 * u
          ..style = PaintingStyle.stroke;
        for (double d = -size.height; d < size.width; d += 40 * u) {
          canvas.drawLine(Offset(d, 0), Offset(d + size.height, size.height), p);
        }
      case PosterPattern.confetti:
        final r = Random(7);
        final colorsList = [Colors.white, Colors.yellowAccent, Colors.cyanAccent, Colors.pinkAccent];
        for (var i = 0; i < 46; i++) {
          final paint = Paint()..color = colorsList[i % 4].withValues(alpha: 0.35);
          final o = Offset(r.nextDouble() * size.width, r.nextDouble() * size.height);
          canvas.save();
          canvas.translate(o.dx, o.dy);
          canvas.rotate(r.nextDouble() * pi);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: 14 * u, height: 6 * u),
              Radius.circular(2 * u),
            ),
            paint,
          );
          canvas.restore();
        }
      case PosterPattern.grid:
        p
          ..strokeWidth = 1.5 * u
          ..style = PaintingStyle.stroke;
        final step = 30 * u;
        for (double x = 0; x < size.width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
        }
        for (double y = 0; y < size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
      case PosterPattern.rays:
        final c = Offset(size.width / 2, size.height * 0.3);
        final radius = size.longestSide * 1.2;
        const n = 18;
        for (var i = 0; i < n; i += 2) {
          final a1 = i * 2 * pi / n;
          final a2 = (i + 1) * 2 * pi / n;
          final path = Path()
            ..moveTo(c.dx, c.dy)
            ..lineTo(c.dx + radius * cos(a1), c.dy + radius * sin(a1))
            ..lineTo(c.dx + radius * cos(a2), c.dy + radius * sin(a2))
            ..close();
          canvas.drawPath(path, p);
        }
    }
  }

  @override
  bool shouldRepaint(PosterBackgroundPainter old) =>
      old.pattern != pattern || old.colors != colors;
}

class BorderPainter extends CustomPainter {
  BorderPainter(this.style, this.color, this.scale);
  final PosterBorder style;
  final Color color;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = 12 * scale;
    final rect = Rect.fromLTWH(inset, inset, size.width - 2 * inset, size.height - 2 * inset);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * scale;
    switch (style) {
      case PosterBorder.none:
        break;
      case PosterBorder.solid:
        canvas.drawRect(rect, paint);
      case PosterBorder.rounded:
        canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(28 * scale)), paint);
      case PosterBorder.double:
        paint.strokeWidth = 2.5 * scale;
        canvas.drawRect(rect, paint);
        canvas.drawRect(rect.deflate(8 * scale), paint);
      case PosterBorder.dashed:
        final path = Path()..addRect(rect);
        final dash = 14 * scale;
        for (final m in path.computeMetrics()) {
          var d = 0.0;
          while (d < m.length) {
            canvas.drawPath(m.extractPath(d, min(d + dash, m.length)), paint);
            d += dash * 1.8;
          }
        }
    }
  }

  @override
  bool shouldRepaint(BorderPainter old) =>
      old.style != style || old.color != color || old.scale != scale;
}
