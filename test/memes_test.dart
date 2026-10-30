import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:find_who/core/providers.dart';
import 'package:find_who/features/memes/memes_screen.dart';
import 'package:find_who/features/posters/editor_controller.dart';
import 'package:find_who/models/meme_template.dart';
import 'package:find_who/models/poster_doc.dart';
import 'package:find_who/repositories/meme_repository.dart';
import 'package:find_who/services/local_db.dart';
import 'package:find_who/services/poster_exporter.dart';
import 'package:find_who/widgets/meme_widgets.dart';
import 'package:find_who/widgets/poster_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  final catalog = loadTestMemes();

  group('bundled Tamil meme pack', () {
    test('has exactly TM001..TM020 in order, all unique', () {
      expect(catalog.templates.map((t) => t.id).toList(), [for (var i = 1; i <= 20; i++) 'TM${i.toString().padLeft(3, '0')}']);
    });

    test('every template has the required metadata', () {
      for (final t in catalog.templates) {
        expect(t.title, isNotEmpty, reason: t.id);
        expect(t.actor, isNotEmpty, reason: t.id);
        expect(t.source, isNotEmpty, reason: t.id);
        expect(catalog.categoryById(t.category), isNotNull, reason: '${t.id} category');
        expect(t.captions, isNotEmpty, reason: t.id);
        expect(t.layers.map((l) => l.role), containsAll(['top', 'bottom']), reason: t.id);
        expect(t.license, contains('Original illustration'), reason: t.id);
        expect(t.referenceUrl, startsWith('https://'), reason: t.id);
        expect(t.referenceUrl, isNot(contains('utm_')), reason: t.id);
        expect(t.isAsset, isTrue);
      }
    });

    test('covers the required personalities and categories', () {
      final actors = catalog.templates.map((t) => t.actor).join('|');
      for (final n in ['Vadivelu', 'Vivek', 'Goundamani', 'Senthil', 'Santhanam', 'Vijay', 'Ajith', 'Rajinikanth', 'Parithabangal']) {
        expect(actors, contains(n));
      }
      final cats = catalog.categories.map((c) => c.id).toSet();
      for (final c in ['cinema_comedy', 'reaction', 'friendship', 'love', 'college', 'office', 'relatable', 'youtube']) {
        expect(cats, contains(c));
        expect(catalog.templates.where((t) => t.category == c), isNotEmpty, reason: c);
      }
    });

    test('all 20 images exist, are 1080x1080 PNGs and stay lightweight', () {
      var total = 0;
      for (final t in catalog.templates) {
        final f = File(t.assetPath);
        expect(f.existsSync(), isTrue, reason: t.assetPath);
        final bytes = f.readAsBytesSync();
        total += bytes.length;
        expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
        final data = ByteData.sublistView(bytes);
        expect(data.getUint32(16), 1080, reason: '${t.id} width');
        expect(data.getUint32(20), 1080, reason: '${t.id} height');
      }
      expect(total, lessThan(2 * 1024 * 1024));
    });

    test('no reference image is bundled', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, isNot(contains('reference_images')));
      expect(File('.gitignore').readAsStringSync(), contains('/reference_images/*'));
    });

    test('the Tamil fonts are bundled with their licences', () {
      for (final f in ['MuktaMalar-Regular', 'MuktaMalar-Bold', 'MuktaMalar-ExtraBold', 'BalooThambi2', 'Anton-Regular', 'Bangers-Regular']) {
        expect(File('assets/fonts/$f.ttf').existsSync(), isTrue, reason: f);
      }
      for (final l in ['muktamalar', 'baloothambi2', 'anton', 'bangers']) {
        expect(File('assets/fonts/OFL-$l.txt').readAsStringSync(), contains('SIL OPEN FONT LICENSE'));
      }
    });
  });

  group('search', () {
    test('matches id, title, actor, caption, tag and category name', () {
      final t = catalog.byId('TM001')!;
      expect(t.matches('tm001'), isTrue);
      expect(t.matches('confused'), isTrue);
      expect(t.matches('VADIVELU'), isTrue);
      expect(t.matches('enna nadakkuthu'), isTrue);
      expect(t.matches('question'), isTrue);
      expect(t.matches('cinema', categoryName: 'Cinema Comedy'), isTrue);
      expect(t.matches('zzzz'), isFalse);
      expect(t.matches('   '), isTrue);
    });

    test('Vadivelu finds exactly his four templates', () {
      expect(catalog.templates.where((t) => t.matches('vadivelu')).map((t) => t.id), ['TM001', 'TM002', 'TM003', 'TM018']);
    });
  });

  group('template packs without code changes', () {
    test('parser skips bad templates and reports problems', () {
      final parser = MemePackParser(
        imageResolver: (i) => '/packs/$i',
        imageExists: (ref) => !ref.contains('missing'),
      );
      final result = parser.parse({
        'pack': 'demo',
        'categories': [{'id': 'c1', 'name': 'One'}],
        'templates': [
          {'id': 'A1', 'title': 'Ok', 'category': 'c1', 'image': 'a.png'},
          {'id': 'A1', 'title': 'Duplicate', 'category': 'c1', 'image': 'b.png'},
          {'id': 'A2', 'title': 'Gone', 'category': 'c1', 'image': 'missing.png'},
          {'title': 'No id', 'image': 'c.png'},
        ],
      });
      expect(result.templates.map((t) => t.id), ['A1']);
      expect(parser.problems.length, 3);
      expect(result.templates.single.imageRef, '/packs/a.png');
      expect(result.templates.single.aspect, 1);
    });

    test('merged catalogs never duplicate ids', () {
      final a = MemeCatalog(categories: const [MemeCategory(id: 'x', name: 'X', emoji: '1')], templates: [catalog.templates.first]);
      final merged = a.merged(MemeCatalog(categories: const [MemeCategory(id: 'x', name: 'X', emoji: '1')], templates: [catalog.templates.first]));
      expect(merged.templates.length, 1);
      expect(merged.categories.length, 1);
    });

    test('external folder packs are discovered; broken ones are reported', () async {
      final dir = await Directory.systemTemp.createTemp('meme_packs_test');
      addTearDown(() => dir.delete(recursive: true));
      final good = Directory('${dir.path}/friends')..createSync();
      File('${good.path}/pic.png').writeAsBytesSync([1, 2, 3]);
      File('${good.path}/pack.json').writeAsStringSync(jsonEncode({
        'categories': [{'id': 'fun', 'name': 'Fun', 'emoji': '🎉'}],
        'templates': [
          {'id': 'EX001', 'title': 'Mine', 'category': 'fun', 'image': 'pic.png', 'captions': ['Hi']},
          {'id': 'EX002', 'title': 'No file', 'category': 'fun', 'image': 'nope.png'},
        ],
      }));
      final bad = Directory('${dir.path}/broken')..createSync();
      File('${bad.path}/pack.json').writeAsStringSync('{ not json');
      MemeRepository.loadProblems.clear();
      final result = await MemeRepository.loadExternal(dir: dir);
      expect(result.templates.map((t) => t.id), ['EX001']);
      expect(result.templates.single.isAsset, isFalse);
      expect(File(result.templates.single.imageRef).existsSync(), isTrue);
      expect(result.categories.single.id, 'fun');
      expect(MemeRepository.loadProblems.length, 2);
      expect(await MemeRepository.loadExternal(dir: Directory('${dir.path}/does_not_exist')), isA<MemeCatalog>());
    });

    test('user templates persist in the database and can be removed', () async {
      final db = MemoryDb();
      final container = ProviderContainer(overrides: [dbProvider.overrideWithValue(db)]);
      addTearDown(container.dispose);
      final t = MemeTemplate(
        id: 'UM1', title: 'My pic', category: 'relatable', imageRef: '/tmp/none.png', aspect: 1.5,
        captions: const ['Hello'], layers: const [MemeLayer(role: 'bottom', text: 'Hello')], isUser: true,
      );
      await container.read(userMemesProvider.future);
      await container.read(userMemesProvider.notifier).add(t);
      // a fresh container reads it back from storage
      final again = ProviderContainer(overrides: [dbProvider.overrideWithValue(db)]);
      addTearDown(again.dispose);
      final loaded = await again.read(userMemesProvider.future);
      expect(loaded.single.id, 'UM1');
      expect(loaded.single.isUser, isTrue);
      expect(loaded.single.aspect, 1.5);
      expect(loaded.single.layers.last.text, 'Hello');
      await container.read(userMemesProvider.notifier).remove(t);
      expect(container.read(userMemesProvider).value, isEmpty);
    });
  });

  group('meme layout', () {
    PosterDoc build(PosterLayout l, {double aspect = 1}) {
      final t = MemeTemplate(
        id: 'T', title: 't', category: 'c', imageRef: 'asset:x.png', aspect: aspect,
        layers: const [MemeLayer(role: 'top', text: 'a'), MemeLayer(role: 'bottom', text: 'b')],
      );
      return MemeDocBuilder.build(t, layout: l);
    }

    test('image and captions stay inside the poster in every format', () {
      for (final aspect in [1.0, 1.5, 0.6]) {
        for (final l in PosterLayout.values) {
          final d = build(l, aspect: aspect);
          final h = 360 / l.aspect;
          final img = d.elementById(kMemeImageId)!;
          final ih = img.size / img.aspect;
          expect(img.size, lessThanOrEqualTo(360.001), reason: '$l $aspect');
          expect(ih, lessThanOrEqualTo(h + 0.001), reason: '$l $aspect');
          final top = d.elementById('cap_top')!;
          final bottom = d.elementById('cap_bottom')!;
          expect(top.dy, lessThan(bottom.dy));
          expect(top.dy, inInclusiveRange(0, 1));
          expect(bottom.dy, inInclusiveRange(0, 1));
        }
      }
    });

    test('story format puts captions in the empty bars', () {
      final d = build(PosterLayout.story);
      final h = 360 / PosterLayout.story.aspect;
      final imageTop = (h - 360) / 2;
      expect(d.elementById('cap_top')!.dy * h, lessThan(imageTop));
      expect(d.elementById('cap_bottom')!.dy * h, greaterThan(imageTop + 360));
    });

    test('square format overlays captions on the image edges', () {
      final d = build(PosterLayout.square);
      expect(d.elementById('cap_top')!.dy, closeTo(MemeDocBuilder.captionMargin / 360, 1e-9));
      expect(d.elementById('cap_bottom')!.dy, closeTo(1 - MemeDocBuilder.captionMargin / 360, 1e-9));
    });

    test('switching format in the editor re-flows memes but not other posters', () {
      final c = EditorController(build(PosterLayout.square));
      c.updateSelected((e) => e, checkpointFirst: false);
      c.setLayout(PosterLayout.story);
      expect(c.doc.layout, PosterLayout.story);
      expect(c.doc.elementById('cap_top')!.dy, lessThan(0.2));
      c.undo();
      expect(c.doc.layout, PosterLayout.square);
      final plain = EditorController(const PosterDoc(elements: [PosterElement(id: 'x', kind: ElementKind.text, text: 'a', dy: 0.3)]));
      plain.setLayout(PosterLayout.story);
      expect(plain.doc.elementById('x')!.dy, 0.3);
    });

    test('outline, alignment and the meme image survive JSON', () {
      final d = build(PosterLayout.portrait);
      final top = d.elementById('cap_top')!.copyWith(outline: 6.5, outlineColor: Colors.red, align: 2);
      final back = PosterDoc.fromJson(d.updateElement(top).toJson());
      final e = back.elementById('cap_top')!;
      expect(e.outline, 6.5);
      expect(e.outlineColor.toARGB32(), Colors.red.toARGB32());
      expect(e.align, 2);
      expect(back.isMeme, isTrue);
      expect(back.elementById(kMemeImageId)!.shape, PhotoShape.plain);
    });
  });

  group('memes screen', () {
    Future<void> pumpMemes(WidgetTester tester) async {
      usePhoneSize(tester);
      await tester.pumpWidget(await buildTestApp(location: '/memes'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the grid, title and count; search narrows it', (tester) async {
      await pumpMemes(tester);
      expect(find.text('Tamil Memes'), findsOneWidget);
      expect(find.textContaining('20 blank templates'), findsOneWidget);
      expect(find.byType(MemeCard), findsWidgets);
      await tester.enterText(find.byType(TextField), 'vadivelu');
      await tester.pumpAndSettle();
      expect(find.text('Confused'), findsOneWidget);
      expect(find.text('Salary Day'), findsNothing);
      await tester.enterText(find.byType(TextField), 'qqqqq');
      await tester.pumpAndSettle();
      expect(find.text('No templates found'), findsOneWidget);
      await tester.tap(find.text('Show all templates'));
      await tester.pumpAndSettle();
      expect(find.byType(MemeCard), findsWidgets);
    });

    testWidgets('category chips filter templates', (tester) async {
      await pumpMemes(tester);
      await tester.scrollUntilVisible(find.text('😅 Relatable Life'), 100,
          scrollable: find.descendant(
              of: find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.horizontal).first,
              matching: find.byType(Scrollable)));
      await tester.ensureVisible(find.text('😅 Relatable Life'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('😅 Relatable Life'));
      await tester.pumpAndSettle();
      expect(find.text('Salary Day'), findsOneWidget);
      expect(find.text('Confused'), findsNothing);
    });

    testWidgets('favourite a template, then see it under Favorites', (tester) async {
      await pumpMemes(tester);
      expect(find.text('No favorite templates yet'), findsNothing);
      await tester.tap(find.byTooltip('Add to favorites').first);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remove from favorites'), findsOneWidget);
      await tester.tap(find.text('❤️ Favorites'));
      await tester.pumpAndSettle();
      expect(find.byType(MemeCard), findsOneWidget);
    });

    testWidgets('Favorites and Recent show friendly empty states', (tester) async {
      await pumpMemes(tester);
      await tester.tap(find.text('❤️ Favorites'));
      await tester.pumpAndSettle();
      expect(find.text('No favorite templates yet'), findsOneWidget);
      await tester.tap(find.text('🕘 Recent'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing used recently'), findsOneWidget);
    });

    testWidgets('opening a template launches the editor, records it as recent and offers suggestions', (tester) async {
      await pumpMemes(tester);
      await tester.tap(find.text('Confused'));
      await tester.pumpAndSettle();
      expect(find.text('Edit poster'), findsOneWidget);
      expect(find.text('Enna nadakkuthu inga?'), findsWidgets);
      // select the top caption on the poster, then a suggestion chip replaces its text
      final onPoster = find.descendant(of: find.byType(PosterView), matching: find.text('Exam hall la question paper paathadhum'));
      await tester.tap(onPoster.first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Enna nadakkuthu inga?'));
      await tester.pumpAndSettle();
      List<String> captions() => tester
          .widgetList<PosterText>(find.descendant(of: find.byType(PosterView), matching: find.byType(PosterText)))
          .map((w) => w.element.text)
          .toList();
      expect(captions(), isNot(contains('Exam hall la question paper paathadhum')));
      expect(captions().where((c) => c == 'Enna nadakkuthu inga?').length, 2);
      // go back: the template now appears under Recent
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Recently used'), findsOneWidget);
    });

    testWidgets('long-press shows licence and reference details', (tester) async {
      await pumpMemes(tester);
      await tester.longPress(find.text('Confused'));
      await tester.pumpAndSettle();
      expect(find.text('TM001'), findsWidgets);
      expect(find.textContaining('Original illustration'), findsOneWidget);
      expect(find.text('Use this template'), findsOneWidget);
    });

    testWidgets('home and posters tab link to the section', (tester) async {
      usePhoneSize(tester);
      await tester.pumpWidget(await buildTestApp());
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Tamil Memes'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Tamil Memes'));
      await tester.pumpAndSettle();
      expect(find.byType(MemesScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Posters')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tamil Memes'));
      await tester.pumpAndSettle();
      expect(find.byType(MemesScreen), findsOneWidget);
    });

    testWidgets('unknown template id shows an error instead of crashing', (tester) async {
      usePhoneSize(tester);
      await tester.pumpWidget(await buildTestApp(location: '/meme/NOPE'));
      await tester.pumpAndSettle();
      expect(find.text('That template is not available any more.'), findsOneWidget);
    });

    testWidgets('add-template sheet validates before saving', (tester) async {
      await pumpMemes(tester);
      await tester.tap(find.text('Add template'));
      await tester.pumpAndSettle();
      expect(find.text('Add your own template'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(InkWell, 'Add template').last);
      await tester.tap(find.widgetWithText(InkWell, 'Add template').last);
      await tester.pumpAndSettle();
      expect(find.text('Choose an image first'), findsOneWidget);
      expect(find.text('Please enter a name'), findsOneWidget);
    });
  });

  group('editor for memes', () {
    Future<void> openMeme(WidgetTester tester, {String id = 'TM001'}) async {
      usePhoneSize(tester);
      await tester.pumpWidget(await buildTestApp(location: '/meme/$id'));
      await tester.pumpAndSettle();
    }

    testWidgets('alignment, outline and font controls change the selected caption', (tester) async {
      await openMeme(tester);
      await tester.tap(find.descendant(of: find.byType(PosterView), matching: find.text('Enna nadakkuthu inga?')).first);
      await tester.pumpAndSettle();
      final panel = find.descendant(
        of: find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.vertical),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(find.byTooltip('Align left'), 80, scrollable: panel.first);
      expect(find.byTooltip('Align left'), findsOneWidget);
      expect(find.byTooltip('Align centre'), findsOneWidget);
      expect(find.byTooltip('Align right'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Align left'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Align left'));
      await tester.pumpAndSettle();
      final onPoster = find.descendant(of: find.byType(PosterView), matching: find.byType(PosterText));
      final aligned = tester.widgetList<PosterText>(onPoster).where((w) => w.element.align == 0);
      expect(aligned, isNotEmpty);
    });

    testWidgets('format change re-flows the meme and exports at the right size', (tester) async {
      await openMeme(tester);
      await tester.tap(find.text('Format'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Story\n9:16'));
      await tester.pumpAndSettle();
      final posterRect = tester.getRect(find.byType(PosterView));
      expect(posterRect.height / posterRect.width, closeTo(16 / 9, 0.02));
      expect(find.textContaining('1080 x 1920'), findsOneWidget);
    });

    testWidgets('every template renders and exports in all three formats', (tester) async {
      usePhoneSize(tester);
      for (final t in catalog.templates) {
        for (final layout in PosterLayout.values) {
          final key = GlobalKey();
          await tester.pumpWidget(MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  child: RepaintBoundary(key: key, child: PosterView(doc: MemeDocBuilder.build(t, layout: layout))),
                ),
              ),
            ),
          ));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump();
          final png = await tester.runAsync(() => PosterExporter.capturePng(key, targetWidth: layout.exportSize.width));
          final img = await tester.runAsync(() async => (await (await ui.instantiateImageCodec(png!)).getNextFrame()).image);
          expect(img!.width, 1080, reason: '${t.id} ${layout.name}');
          expect(img.height, closeTo(layout.exportSize.height, 1), reason: '${t.id} ${layout.name}');
          expect(tester.takeException(), isNull, reason: '${t.id} ${layout.name}');
        }
      }
    });
  });
}
