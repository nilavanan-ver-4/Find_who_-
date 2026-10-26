import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

enum GalleryResult { saved, denied, noSpace, failed }

class ShareService {
  /// Opens Android's native share sheet (WhatsApp, Instagram, Telegram...).
  Future<void> shareImage(String path, {String? text}) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path, mimeType: 'image/png')], text: text),
    );
  }

  Future<void> shareText(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<GalleryResult> saveToGallery(Uint8List png, String name) async {
    try {
      await Gal.putImageBytes(png, name: name, album: 'Find Who');
      return GalleryResult.saved;
    } on GalException catch (e) {
      return switch (e.type) {
        GalExceptionType.accessDenied => GalleryResult.denied,
        GalExceptionType.notEnoughSpace => GalleryResult.noSpace,
        _ => GalleryResult.failed,
      };
    } catch (_) {
      return GalleryResult.failed;
    }
  }
}
