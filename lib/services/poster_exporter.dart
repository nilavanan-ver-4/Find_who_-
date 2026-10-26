import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

class ExportException implements Exception {
  const ExportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Turns the poster currently on screen into a high-resolution PNG.
class PosterExporter {
  /// [boundaryKey] must belong to a [RepaintBoundary] that wraps *only* the
  /// poster. The poster is rendered at [targetWidth] pixels wide regardless of
  /// the phone's screen density, so output is always sharp and the same size.
  static Future<Uint8List> capturePng(
    GlobalKey boundaryKey, {
    double targetWidth = 1080,
  }) async {
    final ctx = boundaryKey.currentContext;
    final render = ctx?.findRenderObject();
    if (render is! RenderRepaintBoundary) {
      throw const ExportException('The poster is not ready yet. Try again.');
    }
    if (render.debugNeedsPaint) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final width = render.size.width;
    if (width <= 0) throw const ExportException('Poster has no size.');
    final ui.Image image = await render.toImage(pixelRatio: targetWidth / width);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw const ExportException('Could not encode image.');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }
}
