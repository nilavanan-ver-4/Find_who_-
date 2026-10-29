import 'package:find_who/features/posters/editor_controller.dart';
import 'package:find_who/models/poster_doc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  final content = loadTestContent();
  PosterDoc base() => PosterDoc.fromTemplate(content.templates.first);

  test('add text, undo and reset', () {
    final c = EditorController(base());
    final before = c.doc.elements.length;
    expect(c.addText('Hello'), isNull);
    expect(c.doc.elements.length, before + 1);
    expect(c.canUndo, isTrue);
    c.undo();
    expect(c.doc.elements.length, before);
    c.addSticker('😂');
    c.setLayout(PosterLayout.story);
    c.reset();
    expect(c.doc.elements.length, before);
    expect(c.doc.layout, base().layout);
  });

  test('rejects empty text and caps element count', () {
    final c = EditorController(const PosterDoc());
    expect(c.addText('   '), isNotNull);
    for (var i = 0; i < EditorController.maxElements; i++) {
      expect(c.addSticker('😂'), isNull);
    }
    expect(c.addSticker('😂'), isNotNull);
  });

  test('moving an element stays inside the poster and is undoable', () {
    final c = EditorController(base());
    final id = c.doc.elements.first.id;
    c.checkpoint();
    c.moveBy(id, 5, -5);
    final e = c.doc.elementById(id)!;
    expect(e.dx, 1.0);
    expect(e.dy, 0.0);
    c.undo();
    expect(c.doc.elementById(id)!.dx, 0.5);
  });

  test('typing creates a single undo step per selection', () {
    final c = EditorController(base());
    c.select('title');
    c.editText('a');
    c.editText('ab');
    c.editText('abc');
    expect(c.doc.elementById('title')!.text, 'abc');
    c.undo();
    expect(c.doc.elementById('title')!.text, isNot('a'));
  });

  test('delete selected element clears selection', () {
    final c = EditorController(base());
    c.select('caption');
    c.deleteSelected();
    expect(c.doc.elementById('caption'), isNull);
    expect(c.selectedId, isNull);
    c.undo();
    expect(c.doc.elementById('caption'), isNotNull);
  });
  test('photos: add behind everything, replace, undo', () {
    final c = EditorController(base());
    expect(c.addPhoto('/a.jpg'), isNull);
    expect(c.doc.elements.first.isPhoto, isTrue);
    expect(c.selected!.isPhoto, isTrue);
    c.replacePhoto('/b.jpg');
    expect(c.selected!.text, '/b.jpg');
    c.undo();
    expect(c.selected!.text, '/a.jpg');
    c.undo();
    expect(c.doc.elements.any((e) => e.isPhoto), isFalse);
  });

  test('moveTo keeps the whole element inside the poster', () {
    final c = EditorController(base());
    final id = c.doc.elements.first.id;
    c.moveTo(id, -2, 5, halfW: 0.2, halfH: 0.1);
    expect(c.doc.elementById(id)!.dx, closeTo(0.2, 1e-9));
    expect(c.doc.elementById(id)!.dy, closeTo(0.9, 1e-9));
    c.moveTo(id, 0.9, 0.1, halfW: 0.7, halfH: 0.1); // wider than the poster -> centred
    expect(c.doc.elementById(id)!.dx, 0.5);
  });

  test('drag and drop adds a sticker exactly where it was dropped', () {
    final c = EditorController(base());
    expect(c.addStickerAt('😂', 0.3, 0.8), isNull);
    expect(c.selected!.dx, 0.3);
    expect(c.selected!.dy, 0.8);
    c.undo();
    expect(c.selected, isNull);
  });

  test('size and rotation edits are undoable', () {
    final c = EditorController(base());
    c.select('title');
    c.updateSelected((e) => e.copyWith(size: 60, rotation: 1));
    expect(c.selected!.rotation, 1);
    c.undo();
    expect(c.selected!.rotation, 0);
  });
}
