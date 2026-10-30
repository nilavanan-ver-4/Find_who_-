import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:find_who/app.dart';
import 'package:find_who/core/providers.dart';
import 'package:find_who/models/content.dart';
import 'package:find_who/models/meme_template.dart';
import 'package:find_who/services/local_db.dart';
import 'package:shared_preferences/shared_preferences.dart';

AppContent loadTestContent() {
  final files = <String, Map<String, dynamic>>{};
  for (final name in AppContent.fileNames) {
    files[name] = jsonDecode(File('assets/data/$name.json').readAsStringSync()) as Map<String, dynamic>;
  }
  return AppContent.fromJson(files);
}

MemeCatalog loadTestMemes() {
  final json = jsonDecode(File('assets/data/tamil_memes.json').readAsStringSync()) as Map<String, dynamic>;
  return MemePackParser(imageResolver: (img) => 'asset:$img').parse(json);
}

Future<ProviderScope> buildTestApp({String location = '/home', LocalDb? db}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      contentProvider.overrideWithValue(loadTestContent()),
      memeCatalogProvider.overrideWithValue(loadTestMemes()),
      prefsProvider.overrideWithValue(prefs),
      dbProvider.overrideWithValue(db ?? MemoryDb()),
    ],
    child: FindWhoApp(key: UniqueKey(), initialLocation: location),
  );
}

/// Phone-sized surface.
void usePhoneSize(WidgetTester tester, {Size size = const Size(412, 892)}) {
  tester.view.physicalSize = size * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
