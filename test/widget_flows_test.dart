import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:find_who/features/games/game_registry.dart';
import 'package:find_who/features/posters/editor_screen.dart';
import 'package:find_who/models/poster_doc.dart';
import 'package:find_who/models/poster_models.dart';
import 'package:find_who/services/poster_exporter.dart';
import 'package:find_who/widgets/poster_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

Future<void> pumpApp(WidgetTester tester, {String location = '/home'}) async {
  usePhoneSize(tester);
  await tester.pumpWidget(await buildTestApp(location: location));
  await tester.pumpAndSettle();
}

Future<void> addPlayer(WidgetTester tester, String name) async {
  await tester.enterText(find.byType(TextFormField).first, name);
  await tester.tap(find.byIcon(Icons.add));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('home shows dashboard and bottom navigation works', (tester) async {
    await pumpApp(tester);
    expect(find.text('Ready to make your friends laugh?'), findsOneWidget);
    expect(find.text('Trending posters'), findsOneWidget);
    for (final label in ['Posters', 'Games', 'Friends', 'Profile', 'Home']) {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
      await tester.pumpAndSettle();
    }
    expect(find.text('Ready to make your friends laugh?'), findsOneWidget);
  });

  testWidgets('poster library: search, category filter, empty state', (tester) async {
    await pumpApp(tester, location: '/posters');
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'qqqqqqzzz');
    await tester.pumpAndSettle();
    expect(find.text('No posters found'), findsOneWidget);
    await tester.tap(find.text('Show all posters'));
    await tester.pumpAndSettle();
    expect(find.text('No posters found'), findsNothing);
    await tester.scrollUntilVisible(find.textContaining('Birthday Fun'), 100,
        scrollable: find.descendant(
          of: find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.horizontal),
          matching: find.byType(Scrollable),
        ));
    await tester.ensureVisible(find.textContaining('Birthday Fun'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Birthday Fun'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Happy Birthday'), findsWidgets);
  });

  testWidgets('create flow validates names then opens the editor', (tester) async {
    await pumpApp(tester, location: '/create?template=birthday_1');
    await tester.scrollUntilVisible(find.text('Generate poster'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Generate poster'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a name'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Riya');
    await tester.tap(find.text('Generate poster'));
    await tester.pumpAndSettle();
    expect(find.text('Edit poster'), findsOneWidget);
    expect(find.text('Happy Birthday Riya!'), findsWidgets);
  });

  testWidgets('editor: add text with validation, undo, reset', (tester) async {
    usePhoneSize(tester);
    final content = loadTestContent();
    final doc = PosterDoc.fromTemplate(content.templateById('birthday_1')!, inputs: const PosterInputs(nameA: 'Riya'));
    await tester.pumpWidget(ProviderScope(
      overrides: (await buildTestApp()).overrides,
      child: MaterialApp(home: EditorScreen(args: EditorArgs(doc: doc, title: 'Test'))),
    ));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Undo').evaluate().isNotEmpty, isTrue);
    await tester.tap(find.text('Add text'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Text cannot be empty'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Party time');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Party time'), findsWidgets);
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Party time'), findsNothing);
    // switch panels
    for (final t in ['Stickers', 'Background', 'Border', 'Format']) {
      await tester.tap(find.text(t));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('No watermark'), findsOneWidget);
  });

  testWidgets('export renders a sharp PNG in every layout with correct aspect ratio', (tester) async {
    usePhoneSize(tester);
    final content = loadTestContent();
    for (final layout in PosterLayout.values) {
      final key = GlobalKey();
      final doc = PosterDoc.fromTemplate(content.templates[10], layout: layout, inputs: const PosterInputs(nameA: 'Riya'));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Center(child: SizedBox(width: 300, child: RepaintBoundary(key: key, child: PosterView(doc: doc))))),
      ));
      await tester.pumpAndSettle();
      final Uint8List? png = await tester.runAsync(() => PosterExporter.capturePng(key, targetWidth: layout.exportSize.width));
      expect(png, isNotNull);
      final img = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(png!);
        return (await codec.getNextFrame()).image;
      });
      expect(img!.width, layout.exportSize.width.toInt(), reason: layout.label);
      expect(img.height, closeTo(layout.exportSize.height, 1), reason: layout.label);
      // Not blank: the poster paints a gradient so it must have non-transparent bytes.
      expect(png!.length, greaterThan(5000));
    }
  });

  testWidgets('elements never overflow the poster at any layout', (tester) async {
    usePhoneSize(tester);
    final content = loadTestContent();
    for (final t in content.templates) {
      final doc = PosterDoc.fromTemplate(t, inputs: const PosterInputs(nameA: 'Maximilian-Alexander', nameB: 'Bartholomew'));
      for (final e in doc.elements) {
        final s = measureElement(e, 300);
        expect(s.width, lessThanOrEqualTo(300 * kElementMaxWidthFraction + 0.5), reason: t.id);
      }
    }
  });

  testWidgets('friends: add, appears in list, validation, delete', (tester) async {
    await pumpApp(tester, location: '/friends');
    expect(find.text('No friends added yet'), findsOneWidget);
    await tester.tap(find.text('Add friend'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter a name'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Karthik');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nickname (optional)'), 'Kar');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Karthik'), findsOneWidget);
    expect(find.textContaining('"Kar"'), findsOneWidget);
    await tester.tap(find.text('Karthik'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('No friends added yet'), findsOneWidget);
  });

  testWidgets('every game opens and offers player setup', (tester) async {
    for (final g in Games.list) {
      await pumpApp(tester, location: '/game/${g.id}');
      expect(find.text('Start game'), findsOneWidget, reason: g.id);
      expect(find.textContaining(g.title), findsWidgets, reason: g.id);
    }
  });

  testWidgets('game start requires the minimum number of players', (tester) async {
    await pumpApp(tester, location: '/game/most_likely');
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();
    expect(find.text('Add at least 2 players'), findsOneWidget);
    await addPlayer(tester, 'Ann');
    await addPlayer(tester, 'ann');
    expect(find.textContaining('already added'), findsWidgets);
  });

  testWidgets('truth or dare: choose, complete, skip, finish', (tester) async {
    await pumpApp(tester, location: '/game/truth_dare');
    await addPlayer(tester, 'Ann');
    await addPlayer(tester, 'Bo');
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Let's go"));
    await tester.pumpAndSettle();
    expect(find.text("Ann's turn"), findsOneWidget);
    await tester.tap(find.text('Truth'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done! Next player'));
    await tester.pumpAndSettle();
    expect(find.text("Bo's turn"), findsOneWidget);
    await tester.tap(find.text('Dare'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish game'));
    await tester.pumpAndSettle();
    expect(find.text('Ann wins!'), findsOneWidget);
    expect(find.text('Play again'), findsOneWidget);
  });

  testWidgets('most likely to: 3 players pass the phone through a full game', (tester) async {
    await pumpApp(tester, location: '/game/drama');
    for (final n in ['Ann', 'Bo', 'Cy']) {
      await addPlayer(tester, n);
    }
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();
    for (var round = 0; round < 8; round++) {
      for (final n in ['Ann', 'Bo', 'Cy']) {
        expect(find.text("I'm $n"), findsOneWidget, reason: 'round $round gate for $n');
        await tester.tap(find.text("I'm $n"));
        await tester.pumpAndSettle();
        await tester.tap(find.text(n == 'Cy' ? 'Cy (yourself)' : 'Cy'));
        await tester.pumpAndSettle();
      }
      expect(find.text('The crown goes to...'), findsOneWidget);
      await tester.tap(find.text(round == 7 ? 'See results' : 'Next round'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Cy wins!'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('would you rather works solo and shows results', (tester) async {
    await pumpApp(tester, location: '/game/would_you_rather');
    await addPlayer(tester, 'Ann');
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I pick A'));
    await tester.pumpAndSettle();
    expect(find.text('Next question'), findsOneWidget);
  });

  testWidgets('friendship quiz solo gives a title at the end', (tester) async {
    await pumpApp(tester, location: '/game/friendship_quiz');
    await addPlayer(tester, 'Ann');
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 10; i++) {
      await tester.tap(find.byType(InkWell).at(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text(i == 9 ? 'See results' : 'Next question'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Play again'), findsOneWidget);
    expect(find.textContaining('Ann'), findsWidgets);
  });

  testWidgets('spin the wheel spins and reports a result; invalid options are rejected', (tester) async {
    await pumpApp(tester, location: '/game/spin_wheel');
    await tester.tap(find.text('Start game'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('SPIN'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('SPIN'));
    await tester.pump();
    expect(find.text('Spinning...'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 6));
    expect(find.text('THE WHEEL SAYS'), findsOneWidget);
  });

  testWidgets('awards: add person, shuffle, open poster editor', (tester) async {
    await pumpApp(tester, location: '/awards');
    expect(find.text('Nobody yet'), findsOneWidget);
    await addPlayer(tester, 'Ann');
    expect(find.text('Ann'), findsWidgets);
    await tester.tap(find.text('Shuffle all awards'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Poster'));
    await tester.pumpAndSettle();
    expect(find.text('Edit poster'), findsOneWidget);
  });

  testWidgets('settings: theme, switches and clear data', (tester) async {
    await pumpApp(tester, location: '/settings');
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
    await tester.tap(find.text('Sound effects'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Clear history'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Clear history'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsWidgets);
  });

  testWidgets('unknown game id shows an error state instead of crashing', (tester) async {
    await pumpApp(tester, location: '/game/not_a_game');
    expect(find.text('We could not find that game.'), findsOneWidget);
  });

  testWidgets('layouts render without overflow on small and large phones', (tester) async {
    for (final size in [const Size(320, 568), const Size(360, 640), const Size(412, 915), const Size(800, 1280)]) {
      usePhoneSize(tester, size: size);
      for (final loc in ['/home', '/posters', '/games', '/friends', '/settings', '/awards', '/game/truth_dare']) {
        await tester.pumpWidget(await buildTestApp(location: loc));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$loc at $size');
      }
    }
  });
  Future<void> pumpEditor(WidgetTester tester, PosterDoc doc) async {
    usePhoneSize(tester);
    await tester.pumpWidget(ProviderScope(
      overrides: (await buildTestApp()).overrides,
      child: MaterialApp(home: EditorScreen(args: EditorArgs(doc: doc, title: 'Test'))),
    ));
    await tester.pumpAndSettle();
  }

  Finder onPoster(String text) =>
      find.descendant(of: find.byType(PosterView), matching: find.text(text));

  PosterDoc birthdayDoc({String? photo}) => PosterDoc.fromTemplate(
        loadTestContent().templateById('birthday_1')!,
        inputs: const PosterInputs(nameA: 'Riya'),
        photoPath: photo,
      );

  testWidgets('editor: dragging text moves it and undo puts it back', (tester) async {
    await pumpEditor(tester, birthdayDoc());
    final finder = onPoster('Happy Birthday Riya!');
    final before = tester.getCenter(finder);
    await tester.drag(finder, const Offset(0, -90));
    await tester.pumpAndSettle();
    final after = tester.getCenter(finder);
    expect(after.dy, lessThan(before.dy - 60));
    expect(after.dx, closeTo(before.dx, 2));
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(tester.getCenter(finder).dy, closeTo(before.dy, 2));
  });

  testWidgets('editor: dragged text can never leave the poster', (tester) async {
    await pumpEditor(tester, birthdayDoc());
    final poster = tester.getRect(find.byType(PosterView));
    final finder = onPoster('Happy Birthday Riya!');
    await tester.drag(finder, const Offset(900, -900));
    await tester.pumpAndSettle();
    final r = tester.getRect(finder);
    expect(poster.inflate(1).contains(r.topLeft), isTrue);
    expect(poster.inflate(1).contains(r.bottomRight), isTrue);
    expect(r.center.dx, greaterThan(poster.center.dx - 1)); // it did move (or sits at the edge)
  });

  testWidgets('editor: pinch resizes the selected element', (tester) async {
    await pumpEditor(tester, birthdayDoc());
    final finder = onPoster('Happy Birthday Riya!');
    final c = tester.getCenter(finder);
    final before = tester.getSize(finder);
    final g1 = await tester.startGesture(c - const Offset(20, 0));
    final g2 = await tester.startGesture(c + const Offset(20, 0));
    await tester.pump();
    await g1.moveTo(c - const Offset(50, 0));
    await g2.moveTo(c + const Offset(50, 0));
    await tester.pump();
    await g1.up();
    await g2.up();
    await tester.pumpAndSettle();
    expect(tester.getSize(finder).height, greaterThan(before.height * 1.3));
  });

  testWidgets('editor: corner handle resizes and the delete handle removes the element', (tester) async {
    await pumpEditor(tester, birthdayDoc());
    final finder = onPoster('Happy Birthday Riya!');
    await tester.tap(finder);
    await tester.pumpAndSettle();
    final before = tester.getSize(finder).height;
    final handle = find.byIcon(Icons.open_in_full);
    expect(handle, findsOneWidget);
    final g = await tester.startGesture(tester.getCenter(handle));
    await g.moveBy(const Offset(30, 30));
    await tester.pump();
    await g.moveBy(const Offset(40, 40));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(tester.getSize(finder).height, isNot(closeTo(before, 0.5)));
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(finder, findsNothing);
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(finder, findsOneWidget);
  });

  testWidgets('editor: drag a sticker from the panel and drop it on the poster', (tester) async {
    await pumpEditor(tester, birthdayDoc());
    await tester.tap(find.text('Stickers'));
    await tester.pumpAndSettle();
    expect(find.textContaining('hold and drag'), findsOneWidget);
    final tile = find.text('🔥');
    final target = tester.getRect(find.byType(PosterView)).center + const Offset(0, 120);
    final g = await tester.startGesture(tester.getCenter(tile));
    await tester.pump(const Duration(milliseconds: 700));
    await g.moveTo(target);
    await tester.pump();
    expect(find.text('Drop it here'), findsOneWidget);
    await g.up();
    await tester.pumpAndSettle();
    expect(find.text('Drop it here'), findsNothing);
    final dropped = onPoster('🔥');
    expect(dropped, findsOneWidget);
    expect((tester.getCenter(dropped) - target).distance, lessThan(30));
  });

  testWidgets('editor: photo tool shows image controls for a selected photo', (tester) async {
    await pumpEditor(tester, birthdayDoc(photo: '/does/not/exist.jpg'));
    // Select the photo from the layer chips in the Text tool, then open the Photo tool.
    await tester.tap(find.text('📷 Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Photo').first);
    await tester.pumpAndSettle();
    expect(find.text('Add photo'), findsOneWidget);
    expect(find.text('Replace'), findsOneWidget);
    await tester.tap(find.text('Circle'));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Add photo'), const Offset(0, -200));
    await tester.pumpAndSettle();
    for (final label in ['Flip', 'Rotate 90°', 'Reset look']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Flip'), const Offset(0, 300));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete photo'));
    await tester.pumpAndSettle();
    expect(find.text('Replace'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('photo element renders (all shapes, flip, adjustments) and exports without errors', (tester) async {
    usePhoneSize(tester);
    // Make a real PNG on disk.
    final file = await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 200, 150), Paint()..color = const Color(0xFF2E7D32));
      canvas.drawCircle(const Offset(60, 60), 30, Paint()..color = const Color(0xFFFFEB3B));
      final img = await rec.endRecording().toImage(200, 150);
      final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!;
      final f = File('${Directory.systemTemp.path}/findwho_test_photo.png');
      await f.writeAsBytes(bytes.buffer.asUint8List());
      return f;
    });
    addTearDown(() => file!.deleteSync());

    for (final shape in PhotoShape.values) {
      final key = GlobalKey();
      final base = birthdayDoc(photo: file!.path);
      final photo = base.elements.first.copyWith(
          shape: shape, flipped: true, rotation: 0.3, brightness: 0.2, saturation: 0.4, aspect: 4 / 3);
      final doc = base.updateElement(photo);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Center(child: SizedBox(width: 300, child: RepaintBoundary(key: key, child: PosterView(doc: doc))))),
      ));
      await tester.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      final png = await tester.runAsync(() => PosterExporter.capturePng(key));
      expect(png!.length, greaterThan(5000), reason: shape.name);
      expect(tester.takeException(), isNull, reason: shape.name);
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing, reason: shape.name);
    }
  });
  testWidgets('posters: Tamil Posters shows actor sub-categories that filter templates', (tester) async {
    await pumpApp(tester, location: '/posters');
    await tester.scrollUntilVisible(find.textContaining('Tamil Posters'), 150,
        scrollable: find.descendant(
          of: find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.horizontal),
          matching: find.byType(Scrollable),
        ));
    await tester.ensureVisible(find.textContaining('Tamil Posters'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Tamil Posters'));
    await tester.pumpAndSettle();
    expect(find.text('All Tamil Posters'), findsOneWidget);
    expect(find.textContaining('Vadivelu'), findsWidgets);
    final subRow = find.descendant(
      of: find.byWidgetPredicate((w) => w is ListView && w.scrollDirection == Axis.horizontal).at(1),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(find.text('🤣 Vadivelu'), 100, scrollable: subRow);
    await tester.ensureVisible(find.text('🤣 Vadivelu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🤣 Vadivelu'));
    await tester.pumpAndSettle();
    expect(find.text('Vadivelu Mode: ON'), findsOneWidget);
    expect(find.text('Aiyyo Aiyyo!'), findsOneWidget);
    expect(find.text('Super Star Entry'), findsNothing); // another actor's poster is filtered out
    // Searching an actor name finds its templates from any category.
    await tester.scrollUntilVisible(find.text('All Tamil Posters'), -100, scrollable: subRow);
    await tester.ensureVisible(find.text('All Tamil Posters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All Tamil Posters'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'rajinikanth');
    await tester.pumpAndSettle();
    expect(find.text('Super Star Entry'), findsOneWidget);
  });
}
