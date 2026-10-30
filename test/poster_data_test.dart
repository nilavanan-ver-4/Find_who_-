import 'package:find_who/models/poster_doc.dart';
import 'package:find_who/models/poster_models.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  final content = loadTestContent();

  group('bundled content', () {
    test('has all 19 requested categories plus Tamil Memes, each with several templates', () {
      expect(content.topCategories.length, 20);
      for (final c in content.categories.where((c) => c.parent == null && c.id != 'tamil_memes')) {
        final n = content.templates.where((t) => t.category == c.id).length;
        expect(n, greaterThanOrEqualTo(4), reason: c.name);
      }
    });

    test('Tamil Memes has an actor sub-category per actor, each with templates', () {
      final actors = content.childrenOf('tamil_memes');
      expect(actors.length, greaterThanOrEqualTo(12));
      final names = actors.map((c) => c.name).toSet();
      for (final n in ['Vadivelu', 'Goundamani', 'Santhanam', 'Yogi Babu', 'Vivek', 'Soori', 'Rajinikanth',
        'Kamal Haasan', 'Vijay', 'Ajith Kumar', 'Suriya', 'Dhanush', 'Vijay Sethupathi']) {
        expect(names, contains(n));
      }
      for (final a in actors) {
        final n = content.templates.where((t) => t.category == a.id).length;
        expect(n, greaterThanOrEqualTo(5), reason: a.name);
        expect(content.inCategory(a.id, 'tamil_memes'), isTrue);
      }
      expect(content.templates.where((t) => content.inCategory(t.category, 'tamil_memes')).length, 70);
      expect(content.inCategory('birthday', 'tamil_memes'), isFalse);
    });

    test('template ids are unique and categories exist', () {
      final ids = content.templates.map((t) => t.id).toSet();
      expect(ids.length, content.templates.length);
      for (final t in content.templates) {
        expect(content.categoryById(t.category), isNotNull, reason: t.id);
        expect(t.colors.length, greaterThanOrEqualTo(2));
      }
    });

    test('game content is present', () {
      expect(content.truthDare.where((i) => i.type == 'truth'), isNotEmpty);
      expect(content.truthDare.where((i) => i.type == 'dare'), isNotEmpty);
      for (final level in ['easy', 'medium', 'spicy']) {
        expect(content.truthDare.where((i) => i.level == level && i.type == 'truth'), isNotEmpty, reason: level);
        expect(content.truthDare.where((i) => i.level == level && i.type == 'dare'), isNotEmpty, reason: level);
      }
      expect(content.mostLikely.length, 5);
      expect(content.friendshipQuiz.every((q) => q.answer < q.options.length), isTrue);
      expect(content.guessEmoji.every((q) => q.correct < q.options.length), isTrue);
      expect(content.awards.length, greaterThanOrEqualTo(8));
      expect(content.quizTitles.map((t) => t.title), contains('Friendship Legend'));
    });
  });

  group('PosterTemplate', () {
    test('search matches title, caption and category', () {
      final t = content.templates.firstWhere((t) => t.id == 'awards_2');
      expect(t.matches('late'), isTrue);
      expect(t.matches('AWARDS'), isTrue);
      expect(t.matches('zzzzzz'), isFalse);
      expect(t.matches('  '), isTrue);
    });

    test('placeholders are replaced', () {
      expect(fillPlaceholders('{a} & {b}', a: 'Ann', b: 'Bo'), 'Ann & Bo');
    });
  });

  group('PosterInputs', () {
    test('nickname wins, fallbacks apply', () {
      expect(const PosterInputs(nameA: 'Ann', nicknameA: 'Annie').displayA, 'Annie');
      expect(const PosterInputs(nameA: ' Ann ').displayA, 'Ann');
      expect(const PosterInputs().displayA, 'Your Friend');
      expect(const PosterInputs().displayB, 'Bestie');
    });
  });

  group('PosterDoc', () {
    final template = content.templateById('bff_vs_bff_1')!;

    test('fromTemplate fills names into elements', () {
      final doc = PosterDoc.fromTemplate(template, inputs: const PosterInputs(nameA: 'Ann', nameB: 'Bo'));
      expect(doc.elements.firstWhere((e) => e.id == 'title').text, 'Ann VS Bo');
      expect(doc.elements.any((e) => e.text.contains('{')), isFalse);
      expect(doc.templateId, template.id);
    });

    test('JSON round trip preserves everything, including photo settings', () {
      var doc = PosterDoc.fromTemplate(template,
              inputs: const PosterInputs(nameA: 'Ann'), layout: PosterLayout.story, photoPath: '/p.jpg')
          .copyWith(border: PosterBorder.dashed, borderColor: const Color(0xFF123456));
      final photo = doc.elements.firstWhere((e) => e.isPhoto).copyWith(
            rotation: 0.5, shape: PhotoShape.circle, aspect: 0.8, brightness: 0.2, saturation: 1.5, flipped: true);
      doc = doc.updateElement(photo);
      final back = PosterDoc.fromJson(doc.toJson());
      expect(back.toJson(), doc.toJson());
      expect(back.layout, PosterLayout.story);
      final p = back.elements.firstWhere((e) => e.isPhoto);
      expect(p.text, '/p.jpg');
      expect(p.shape, PhotoShape.circle);
      expect(p.flipped, isTrue);
      expect(p.rotation, 0.5);
    });

    test('a photo from a template sits behind the text', () {
      final doc = PosterDoc.fromTemplate(template, photoPath: '/p.jpg');
      expect(doc.elements.first.isPhoto, isTrue);
    });

    test('posters saved with the old photoPath field still show their photo', () {
      final doc = PosterDoc.fromJson({'layout': 'square', 'photoPath': '/old.jpg', 'elements': []});
      expect(doc.elements.single.isPhoto, isTrue);
      expect(doc.elements.single.text, '/old.jpg');
    });

    test('element positions are clamped to the poster', () {
      const e = PosterElement(id: 'x', kind: ElementKind.text, text: 'hi');
      final moved = e.copyWith(dx: 1.7, dy: -0.4);
      expect(moved.dx, 1.0);
      expect(moved.dy, 0.0);
    });

    test('export sizes match the requested formats', () {
      expect(PosterLayout.square.exportSize, const Size(1080, 1080));
      expect(PosterLayout.portrait.exportSize, const Size(1080, 1350));
      expect(PosterLayout.story.exportSize, const Size(1080, 1920));
      for (final l in PosterLayout.values) {
        expect(l.exportSize.width / l.exportSize.height, closeTo(l.aspect, 0.001));
      }
    });

    test('fromJson tolerates missing / unknown fields', () {
      final doc = PosterDoc.fromJson({'layout': 'nope', 'elements': []});
      expect(doc.layout, PosterLayout.portrait);
      expect(doc.elements, isEmpty);
    });
  });
}
