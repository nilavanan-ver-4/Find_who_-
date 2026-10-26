import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Stores poster images and friend photos in the app's private directory.
/// Nothing leaves the device unless the user shares it.
class FileStore {
  Directory? _root;

  Future<Directory> _dir(String name) async {
    _root ??= await getApplicationDocumentsDirectory();
    final d = Directory(p.join(_root!.path, name));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<String> savePoster(String id, Uint8List png) async {
    final d = await _dir('posters');
    final f = File(p.join(d.path, '$id.png'));
    await f.writeAsBytes(png, flush: true);
    return f.path;
  }

  /// Copies a picked photo into private storage so it survives cache cleaning.
  Future<String> importPhoto(String sourcePath) async {
    final d = await _dir('photos');
    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final dest = File(p.join(d.path, '${DateTime.now().microsecondsSinceEpoch}$ext'));
    await File(sourcePath).copy(dest.path);
    return dest.path;
  }

  Future<void> delete(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<void> clearPosters() async => _wipe('posters');
  Future<void> clearPhotos() async => _wipe('photos');

  Future<void> _wipe(String name) async {
    final d = await _dir(name);
    if (await d.exists()) {
      await d.delete(recursive: true);
    }
  }
}
