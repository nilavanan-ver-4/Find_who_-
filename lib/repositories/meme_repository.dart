import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/meme_template.dart';

/// Loads meme templates from the bundled pack and from packs the user (or a
/// developer) dropped into the app's `meme_packs` folder. Neither needs any
/// change to the application source code.
class MemeRepository {
  static const bundledPack = 'assets/data/tamil_memes.json';

  /// Problems found while loading packs (shown in Settings > Template packs).
  static final List<String> loadProblems = [];

  static Future<MemeCatalog> loadBundled(AssetBundle bundle) async {
    final json = jsonDecode(await bundle.loadString(bundledPack)) as Map<String, dynamic>;
    final parser = MemePackParser(imageResolver: (img) => 'asset:$img');
    final catalog = parser.parse(json);
    loadProblems.addAll(parser.problems);
    return catalog;
  }

  /// Folder where extra packs live. On Android this is
  /// `/sdcard/Android/data/<app id>/files/meme_packs`, reachable with a file
  /// manager or `adb push` without rooting the phone.
  static Future<Directory?> packsDirectory({bool create = false}) async {
    try {
      final base = (!kIsWeb && Platform.isAndroid ? await getExternalStorageDirectory() : null) ??
          await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(base.path, 'meme_packs'));
      if (create && !await dir.exists()) await dir.create(recursive: true);
      return dir;
    } catch (_) {
      return null;
    }
  }

  /// Each sub-folder with a `pack.json` is a pack. Image paths in it are
  /// relative to that folder.
  static Future<MemeCatalog> loadExternal({Directory? dir}) async {
    var result = MemeCatalog.empty;
    final root = dir ?? await packsDirectory();
    if (root == null || !await root.exists()) return result;
    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final file = File(p.join(entity.path, 'pack.json'));
      if (!await file.exists()) continue;
      try {
        final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        json.putIfAbsent('pack', () => p.basename(entity.path));
        final parser = MemePackParser(
          imageResolver: (img) => p.isAbsolute(img) ? img : p.join(entity.path, img),
          imageExists: (ref) => File(ref).existsSync(),
        );
        result = result.merged(parser.parse(json));
        loadProblems.addAll(parser.problems);
      } catch (e) {
        loadProblems.add('${p.basename(entity.path)}: could not read pack.json ($e)');
      }
    }
    return result;
  }
}
