import '../../models/content.dart';
import 'scoreboard.dart';

/// Counts votes and works out who won a round.
class VoteTally {
  final Map<String, int> _counts = {};

  void vote(String option) => _counts[option] = (_counts[option] ?? 0) + 1;

  int countFor(String option) => _counts[option] ?? 0;
  int get totalVotes => _counts.values.fold(0, (a, b) => a + b);
  Map<String, int> get counts => Map.unmodifiable(_counts);

  /// All options sharing the highest vote count.
  List<String> leaders() {
    if (_counts.isEmpty) return const [];
    final top = _counts.values.reduce((a, b) => a > b ? a : b);
    return _counts.entries.where((e) => e.value == top).map((e) => e.key).toList();
  }
}

/// Friendship quiz: percentage and playful title.
class QuizScoring {
  static int percent(int correct, int total) =>
      total <= 0 ? 0 : ((correct * 100) / total).round();

  static ScoreTitle titleFor(int percent, List<ScoreTitle> titles) {
    final sorted = [...titles]..sort((a, b) => a.min.compareTo(b.min));
    var result = sorted.first;
    for (final t in sorted) {
      if (percent >= t.min) result = t;
    }
    return result;
  }
}

/// "Who Knows Whom Best": points for every answer that matches the subject's.
int matchScore(List<int> subjectAnswers, List<int> guesses) {
  var score = 0;
  final n = subjectAnswers.length < guesses.length
      ? subjectAnswers.length
      : guesses.length;
  for (var i = 0; i < n; i++) {
    if (subjectAnswers[i] == guesses[i]) score++;
  }
  return score;
}

/// "Guess the Friend": progressively more revealing hints derived from a name.
class GuessFriend {
  static const maxHints = 3;

  static String hint(String name, int level) {
    final n = name.trim();
    final letters = n.replaceAll(RegExp(r'\s'), '').length;
    switch (level) {
      case 0:
        return 'Their name has $letters letters.';
      case 1:
        return 'It starts with "${String.fromCharCode(n.runes.first).toUpperCase()}".';
      default:
        return 'It ends with "${String.fromCharCode(n.runes.last).toUpperCase()}".';
    }
  }

  /// 3 points for a correct guess on the first hint, then 2, then 1.
  static int points(int hintsShown) => (maxHints + 1 - hintsShown).clamp(1, maxHints);
}

/// Fun, deterministic result lines for the end of a game.
class ResultLines {
  static const winnerTitles = [
    'Friendship Champion',
    'Absolute Legend',
    'Big Brain Energy',
    'Main Character',
  ];
  static const loserTitles = [
    'Needs More Friendship Training',
    'Professional Snack Taster',
    'Participation Trophy Holder',
    'Tomorrow Is Another Day',
  ];

  static String winner(int seed) => winnerTitles[seed.abs() % winnerTitles.length];
  static String loser(int seed) => loserTitles[seed.abs() % loserTitles.length];

  static String summary(Scoreboard board) {
    final w = board.winners();
    if (w.isEmpty) return 'Nobody scored. Everyone wins (and loses)!';
    return w.length == 1 ? '${w.first} wins!' : "It's a tie: ${w.join(', ')}!";
  }
}
