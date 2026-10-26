import 'dart:math';

import 'package:find_who/core/utils/game_logic.dart';
import 'package:find_who/core/utils/random_picker.dart';
import 'package:find_who/core/utils/scoreboard.dart';
import 'package:find_who/core/utils/validators.dart';
import 'package:find_who/models/content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Scoreboard', () {
    test('ranks by score, ties keep joining order', () {
      final b = Scoreboard(['Ann', 'Bo', 'Cy'])
        ..add('Cy', 3)
        ..add('Ann', 1)
        ..add('Bo', 1);
      expect(b.ranking().map((e) => e.key), ['Cy', 'Ann', 'Bo']);
      expect(b.winners(), ['Cy']);
      expect(b.losers(), ['Ann', 'Bo']);
    });

    test('shared top score is a tie, no scores means no winners', () {
      final b = Scoreboard(['A', 'B'])..add('A')..add('B');
      expect(b.winners(), ['A', 'B']);
      expect(b.losers(), isEmpty);
      expect(Scoreboard(['A', 'B']).winners(), isEmpty);
    });

    test('ignores unknown players', () {
      final b = Scoreboard(['A'])..add('Z', 5);
      expect(b.total, 0);
    });
  });

  group('VoteTally', () {
    test('finds leaders including ties', () {
      final t = VoteTally()..vote('A')..vote('B')..vote('A');
      expect(t.leaders(), ['A']);
      t.vote('B');
      expect(t.leaders().toSet(), {'A', 'B'});
      expect(t.totalVotes, 4);
    });

    test('empty tally has no leaders', () => expect(VoteTally().leaders(), isEmpty));
  });

  group('Quiz scoring', () {
    const titles = [
      ScoreTitle(0, 'Needs More Friendship Training', 'x'),
      ScoreTitle(40, 'Certified Partner in Crime', 'x'),
      ScoreTitle(70, 'Best Friend Expert', 'x'),
      ScoreTitle(90, 'Friendship Legend', 'x'),
    ];
    test('percent', () {
      expect(QuizScoring.percent(7, 10), 70);
      expect(QuizScoring.percent(0, 0), 0);
    });
    test('title thresholds', () {
      expect(QuizScoring.titleFor(0, titles).title, 'Needs More Friendship Training');
      expect(QuizScoring.titleFor(39, titles).title, 'Needs More Friendship Training');
      expect(QuizScoring.titleFor(40, titles).title, 'Certified Partner in Crime');
      expect(QuizScoring.titleFor(89, titles).title, 'Best Friend Expert');
      expect(QuizScoring.titleFor(100, titles).title, 'Friendship Legend');
    });
  });

  test('matchScore counts equal answers and tolerates length mismatch', () {
    expect(matchScore([0, 1, 2], [0, 2, 2]), 2);
    expect(matchScore([0, 1], [0, 1, 3]), 2);
    expect(matchScore([], []), 0);
  });

  group('GuessFriend', () {
    test('hints are derived from the name', () {
      expect(GuessFriend.hint('Mary Ann', 0), contains('7 letters'));
      expect(GuessFriend.hint('mary', 1), contains('"M"'));
      expect(GuessFriend.hint('mary', 2), contains('"Y"'));
    });
    test('earlier guesses are worth more', () {
      expect(GuessFriend.points(1), 3);
      expect(GuessFriend.points(2), 2);
      expect(GuessFriend.points(3), 1);
    });
  });

  group('RandomPicker & Deck', () {
    test('pick is deterministic with a seed and stays in range', () {
      final a = RandomPicker(Random(1));
      final b = RandomPicker(Random(1));
      final items = List.generate(20, (i) => i);
      expect([for (var i = 0; i < 10; i++) a.pick(items)], [for (var i = 0; i < 10; i++) b.pick(items)]);
    });

    test('pick on empty list throws', () {
      expect(() => RandomPicker().pick(<int>[]), throwsArgumentError);
    });

    test('pickMany returns distinct items and clamps count', () {
      final r = RandomPicker(Random(3));
      final out = r.pickMany([1, 2, 3, 4], 3);
      expect(out.toSet().length, 3);
      expect(r.pickMany([1, 2], 5).length, 2);
    });

    test('pickExcluding avoids the previous value', () {
      final r = RandomPicker(Random(5));
      for (var i = 0; i < 50; i++) {
        expect(r.pickExcluding([1, 2, 3], 2), isNot(2));
      }
    });

    test('Deck draws every item once per cycle and never repeats across the boundary', () {
      final deck = Deck([1, 2, 3, 4, 5], Random(9));
      var prev = -1;
      for (var cycle = 0; cycle < 4; cycle++) {
        final seen = <int>{};
        for (var i = 0; i < 5; i++) {
          final v = deck.draw();
          expect(seen.add(v), isTrue, reason: 'duplicate within a cycle');
          expect(v, isNot(prev));
          prev = v;
        }
      }
    });

    test('empty deck throws', () => expect(() => Deck<int>([]).draw(), throwsStateError));
  });

  group('Validators', () {
    test('name', () {
      expect(Validators.name(''), isNotNull);
      expect(Validators.name('   '), isNotNull);
      expect(Validators.name('A' * 25), isNotNull);
      expect(Validators.name('Bad<name>'), isNotNull);
      expect(Validators.name('Riya'), isNull);
      expect(Validators.name('riya', existing: ['Riya']), isNotNull);
    });
    test('optional name', () {
      expect(Validators.optionalName(''), isNull);
      expect(Validators.optionalName('X' * 30), isNotNull);
    });
    test('caption', () {
      expect(Validators.caption(''), isNotNull);
      expect(Validators.caption('x' * 121), isNotNull);
      expect(Validators.caption('LOL'), isNull);
    });
    test('wheel options', () {
      expect(Validators.wheelOptions(['a']), isNotNull);
      expect(Validators.wheelOptions(['a', 'A']), isNotNull);
      expect(Validators.wheelOptions(['a', 'b']), isNull);
      expect(Validators.wheelOptions(List.generate(25, (i) => 'o$i')), isNotNull);
    });
    test('player count', () {
      expect(Validators.playerCount(1, min: 2), isNotNull);
      expect(Validators.playerCount(2, min: 2), isNull);
      expect(Validators.playerCount(13, min: 1), isNotNull);
      expect(Validators.playerCount(0, min: 0), isNull);
    });
  });
}
