import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/providers.dart';
import 'models/content.dart';
import 'models/meme_template.dart';
import 'repositories/meme_repository.dart';
import 'services/local_db.dart';

Future<AppContent> loadContent(AssetBundle bundle) async {
  final files = <String, Map<String, dynamic>>{};
  for (final name in AppContent.fileNames) {
    final raw = await bundle.loadString('assets/data/$name.json');
    files[name] = jsonDecode(raw) as Map<String, dynamic>;
  }
  return AppContent.fromJson(files);
}

/// Bundled templates plus any packs found in the app's `meme_packs` folder.
Future<MemeCatalog> loadMemeCatalog(AssetBundle bundle) async {
  final bundled = await MemeRepository.loadBundled(bundle);
  final external = await MemeRepository.loadExternal();
  return bundled.merged(external);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final results = await Future.wait<Object>([
      loadContent(rootBundle),
      SharedPreferences.getInstance(),
      SqliteDb.open(),
      loadMemeCatalog(rootBundle),
    ]);
    runApp(ProviderScope(
      overrides: [
        contentProvider.overrideWithValue(results[0] as AppContent),
        prefsProvider.overrideWithValue(results[1] as SharedPreferences),
        dbProvider.overrideWithValue(results[2] as LocalDb),
        memeCatalogProvider.overrideWithValue(results[3] as MemeCatalog),
      ],
      child: const FindWhoApp(),
    ));
  } catch (e) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Find Who could not start.\n\n$e', textAlign: TextAlign.center),
          ),
        ),
      ),
    ));
  }
}
