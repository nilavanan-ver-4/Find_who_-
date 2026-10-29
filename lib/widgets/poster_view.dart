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
  if (e.isPhoto) {
    final w = e.size * scale;
    return Size(w, w / e.aspect);
  }
  final tp = TextPainter(
    text: TextSpan(text: e.text, style: posterTextStyle(e, scale)),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout(maxWidth: posterWidth * kElementMaxWidthFraction);
  final size = Size(tp.width, tp.height);
  tp.dispose();
  return size;
}

/// Pixel-space centre of an element on a poster of the given size.
Offset elementCenter(PosterElement e, Size poster) =>
    Offset(e.dx * poster.width, e.dy * poster.height);

/// Colour matrix for the photo brightness / saturation adjustments.
List<double> photoColorMatrix(double brightness, double saturation) {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final s = saturation;
  final o = brightness * 255;
  return [
    lr * (1 - s) + s, lg * (1 - s), lb * (1 - s), 0, o,
    lr * (1 - s), lg * (1 - s) + s, lb * (1 - s), 0, o,
    lr * (1 - s), lg * (1 - s), lb * (1 - s) + s, 0, o,
    0, 0, 0, 1, 0,
  ];
}

/// A photo frame (shape, flip, colour adjustments) at an exact pixel size.
class PosterPhoto extends StatelessWidget {
  const PosterPhoto({super.key, required this.element, required this.size, this.cacheWidth = 1080});
  final PosterElement element;
  final Size size;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final e = element;
    final radius = switch (e.shape) {
      PhotoShape.square => 0.0,
      PhotoShape.rounded => size.shortestSide * 0.12,
      PhotoShape.circle => size.shortestSide,
    };
    Widget image = Image.file(
      File(e.text),
      fit: BoxFit.cover,
      width: size.width,
      height: size.height,
      cacheWidth: cacheWidth,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0x33000000),
        child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.white70)),
      ),
    );
    if (e.brightness != 0 || e.saturation != 1) {
      image = ColorFiltered(
        colorFilter: ColorFilter.matrix(photoColorMatrix(e.brightness, e.saturation)),
        child: image,
      );
    }
    if (e.flipped) image = Transform.flip(flipX: true, child: image);
    return SizedBox(
      width: size.width,
      height: size.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: Colors.white, width: size.width * 0.012),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: image,
        ),
      ),
    );
  }
}

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
          final h = c.maxHeight;
          final scale = w / kPosterBaseWidth;
          return ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: PosterBackgroundPainter(doc.colors, doc.pattern)),
                if (doc.border != PosterBorder.none)
                  CustomPaint(painter: BorderPainter(doc.border, doc.borderColor, scale)),
                for (final e in doc.elements)
                  Positioned(
                    left: e.dx * w,
                    top: e.dy * h,
                    child: FractionalTranslation(
                      translation: const Offset(-0.5, -0.5),
                      child: Transform.rotate(
                        angle: e.rotation,
                        child: e.isPhoto
                            ? PosterPhoto(
                                element: e,
                                size: measureElement(e, w),
                                cacheWidth: photoCacheWidth,
                              )
                            : ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: w * kElementMaxWidthFraction),
                                child: Text(
                                  e.text,
                                  textAlign: TextAlign.center,
                                  style: posterTextStyle(e, scale),
                                ),
                              ),
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
