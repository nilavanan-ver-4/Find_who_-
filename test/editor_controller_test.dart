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
}
