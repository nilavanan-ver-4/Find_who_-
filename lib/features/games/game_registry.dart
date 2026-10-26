import 'package:flutter/material.dart';

enum PlayMode {
  solo('Solo'),
  passPhone('Pass the phone'),
  group('Group');

  const PlayMode(this.label);
  final String label;
}

class GameInfo {
  const GameInfo({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    required this.colors,
    required this.minPlayers,
    required this.modes,
    this.popular = false,
  });

  final String id;
  final String title;
  final String emoji;
  final String description;
  final List<Color> colors;

  /// 0 means players are optional.
  final int minPlayers;
  final List<PlayMode> modes;
  final bool popular;

  bool get playersOptional => minPlayers == 0;
  bool get supportsSolo => minPlayers <= 1;
}

const _all = [PlayMode.solo, PlayMode.passPhone, PlayMode.group];
const _multi = [PlayMode.passPhone, PlayMode.group];

class Games {
  static const truthDare = GameInfo(
    id: 'truth_dare', title: 'Truth or Dare', emoji: '🎯',
    description: 'Pick a level, pick your poison. Skips allowed!',
    colors: [Color(0xFFFF4F8B), Color(0xFFC2185B)], minPlayers: 1, modes: _all, popular: true,
  );
  static const wouldYouRather = GameInfo(
    id: 'would_you_rather', title: 'Would You Rather', emoji: '🤔',
    description: 'Impossible choices. Everyone votes in secret.',
    colors: [Color(0xFF7C4DFF), Color(0xFF311B92)], minPlayers: 1, modes: _all, popular: true,
  );
  static const mostLikely = GameInfo(
    id: 'most_likely', title: 'Most Likely To', emoji: '🙋',
    description: 'Vote for the friend who fits best.',
    colors: [Color(0xFFFF9F1C), Color(0xFFE36414)], minPlayers: 2, modes: _multi, popular: true,
  );
  static const replyLate = GameInfo(
    id: 'reply_late', title: 'Reply Late Champion', emoji: '🐌',
    description: 'Who is most likely to reply late?',
    colors: [Color(0xFF26C6DA), Color(0xFF00695C)], minPlayers: 2, modes: _multi,
  );
  static const dramaQueen = GameInfo(
    id: 'drama', title: 'Drama King or Queen', emoji: '👑',
    description: 'Crown the most dramatic one.',
    colors: [Color(0xFFAB47BC), Color(0xFF4A148C)], minPlayers: 2, modes: _multi,
  );
  static const alwaysHungry = GameInfo(
    id: 'hungry', title: 'Always Hungry', emoji: '🍔',
    description: 'Who is always, always hungry?',
    colors: [Color(0xFFFFA726), Color(0xFFD84315)], minPlayers: 2, modes: _multi,
  );
  static const mostDramatic = GameInfo(
    id: 'dramatic', title: 'Most Dramatic Friend', emoji: '🎭',
    description: 'The Oscar goes to...',
    colors: [Color(0xFFEC407A), Color(0xFF6A1B9A)], minPlayers: 2, modes: _multi,
  );
  static const neverHaveIEver = GameInfo(
    id: 'never_have_i_ever', title: 'Never Have I Ever', emoji: '🙈',
    description: 'Tap if you have. No lying!',
    colors: [Color(0xFF42A5F5), Color(0xFF0D47A1)], minPlayers: 1, modes: _all, popular: true,
  );
  static const spinWheel = GameInfo(
    id: 'spin_wheel', title: 'Spin the Wheel', emoji: '🎡',
    description: 'Custom wheel for players, dares, plans.',
    colors: [Color(0xFF66BB6A), Color(0xFF1B5E20)], minPlayers: 0, modes: _all, popular: true,
  );
  static const randomChallenge = GameInfo(
    id: 'random_challenge', title: 'Random Challenge', emoji: '⚡',
    description: 'A silly challenge, on demand.',
    colors: [Color(0xFFFB8C00), Color(0xFFBF360C)], minPlayers: 0, modes: _all,
  );
  static const punishment = GameInfo(
    id: 'punishment', title: 'Funny Punishment', emoji: '😈',
    description: 'Lost a round? Face the consequences.',
    colors: [Color(0xFF212121), Color(0xFFB71C1C)], minPlayers: 0, modes: _all,
  );
  static const friendshipQuiz = GameInfo(
    id: 'friendship_quiz', title: 'Friendship Quiz', emoji: '🧠',
    description: 'How well do you know friendship? Get a title!',
    colors: [Color(0xFF3949AB), Color(0xFF1A237E)], minPlayers: 1, modes: _all, popular: true,
  );
  static const whoKnowsWhom = GameInfo(
    id: 'who_knows_whom', title: 'Who Knows Whom Best', emoji: '🔮',
    description: 'One answers, the rest guess.',
    colors: [Color(0xFF8E24AA), Color(0xFF4A148C)], minPlayers: 2, modes: _multi, popular: true,
  );
  static const guessFriend = GameInfo(
    id: 'guess_friend', title: 'Guess the Friend', emoji: '🕵️',
    description: 'Secret friend, three hints, one guess each.',
    colors: [Color(0xFF455A64), Color(0xFF263238)], minPlayers: 3, modes: _multi,
  );
  static const guessEmoji = GameInfo(
    id: 'guess_emoji', title: 'Guess the Emoji', emoji: '😜',
    description: 'Decode the emoji puzzles.',
    colors: [Color(0xFFFDD835), Color(0xFFF57F17)], minPlayers: 1, modes: _all,
  );
  static const completeSentence = GameInfo(
    id: 'complete_sentence', title: 'Complete the Sentence', emoji: '✍️',
    description: 'Finish the line. The funniest wins.',
    colors: [Color(0xFF26A69A), Color(0xFF004D40)], minPlayers: 2, modes: _multi,
  );

  static const list = [
    truthDare, wouldYouRather, mostLikely, neverHaveIEver, spinWheel,
    friendshipQuiz, whoKnowsWhom, guessFriend, guessEmoji, completeSentence,
    randomChallenge, punishment, replyLate, dramaQueen, alwaysHungry, mostDramatic,
  ];

  static GameInfo? byId(String id) {
    for (final g in list) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Ids of the "Most Likely To" family; they share one engine.
  static const mostLikelyIds = {'most_likely', 'reply_late', 'drama', 'hungry', 'dramatic'};
}
