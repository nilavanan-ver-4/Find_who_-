import 'dart:ui';

import 'poster_models.dart';

class TruthDareItem {
  const TruthDareItem(this.type, this.level, this.category, this.text);
  final String type; // truth | dare
  final String level; // easy | medium | spicy
  final String category;
  final String text;
}

class WouldYouRatherItem {
  const WouldYouRatherItem(this.a, this.b);
  final String a;
  final String b;
}

class MostLikelyDeck {
  const MostLikelyDeck(this.id, this.title, this.emoji, this.items);
  final String id;
  final String title;
  final String emoji;
  final List<String> items;
}

class QuizItem {
  const QuizItem(this.question, this.options, this.answer);
  final String question;
  final List<String> options;
  final int answer;
}

class OptionQuestion {
  const OptionQuestion(this.question, this.options);
  final String question;
  final List<String> options;
}

class EmojiPuzzle {
  const EmojiPuzzle(this.emoji, this.options, this.correct);
  final String emoji;
  final List<String> options;
  final int correct;
}

class AwardItem {
  const AwardItem(this.title, this.emoji, this.blurb);
  final String title;
  final String emoji;
  final String blurb;
}

class ScoreTitle {
  const ScoreTitle(this.min, this.title, this.emoji);
  final int min;
  final String title;
  final String emoji;
}

class FontOption {
  const FontOption(this.id, this.label);
  final String id;
  final String label;
}

/// Everything that is data-driven and can be extended by editing JSON only.
class AppContent {
  const AppContent({
    required this.categories,
    required this.templates,
    required this.stickers,
    required this.gradients,
    required this.palette,
    required this.fonts,
    required this.truthDare,
    required this.wouldYouRather,
    required this.mostLikely,
    required this.neverHaveIEver,
    required this.friendshipQuiz,
    required this.whoKnowsWhom,
    required this.guessEmoji,
    required this.completeSentence,
    required this.challenges,
    required this.punishments,
    required this.activities,
    required this.awards,
    required this.quizTitles,
  });

  final List<PosterCategory> categories;
  final List<PosterTemplate> templates;
  final List<String> stickers;
  final List<List<Color>> gradients;
  final List<Color> palette;
  final List<FontOption> fonts;
  final List<TruthDareItem> truthDare;
  final List<WouldYouRatherItem> wouldYouRather;
  final List<MostLikelyDeck> mostLikely;
  final List<String> neverHaveIEver;
  final List<QuizItem> friendshipQuiz;
  final List<OptionQuestion> whoKnowsWhom;
  final List<EmojiPuzzle> guessEmoji;
  final List<String> completeSentence;
  final List<String> challenges;
  final List<String> punishments;
  final List<String> activities;
  final List<AwardItem> awards;
  final List<ScoreTitle> quizTitles;

  PosterTemplate? templateById(String id) {
    for (final t in templates) {
      if (t.id == id) return t;
    }
    return null;
  }

  PosterCategory? categoryById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  MostLikelyDeck deck(String id) =>
      mostLikely.firstWhere((d) => d.id == id, orElse: () => mostLikely.first);

  static List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
      ((v as List?) ?? const [])
          .map((e) => f(e as Map<String, dynamic>))
          .toList();

  static List<String> _strings(dynamic v) =>
      ((v as List?) ?? const []).map((e) => e as String).toList();

  factory AppContent.fromJson(Map<String, Map<String, dynamic>> f) {
    final posters = f['posters']!;
    final editor = f['editor_assets']!;
    final td = f['truth_dare']!;
    final chal = f['challenges']!;
    return AppContent(
      categories: _list(posters['categories'], PosterCategory.fromJson),
      templates: _list(posters['templates'], PosterTemplate.fromJson),
      stickers: _strings(editor['stickers']),
      gradients: ((editor['gradients'] as List?) ?? const [])
          .map((g) => (g as List).map((c) => colorFromHex(c as String)).toList())
          .toList(),
      palette: _strings(editor['colors']).map(colorFromHex).toList(),
      fonts: _list(editor['fonts'],
          (j) => FontOption(j['id'] as String, j['label'] as String)),
      truthDare: _list(
          td['items'],
          (j) => TruthDareItem(j['type'] as String, j['level'] as String,
              j['category'] as String, j['text'] as String)),
      wouldYouRather: _list(f['would_you_rather']!['items'],
          (j) => WouldYouRatherItem(j['a'] as String, j['b'] as String)),
      mostLikely: _list(
          f['most_likely']!['decks'],
          (j) => MostLikelyDeck(j['id'] as String, j['title'] as String,
              j['emoji'] as String, _strings(j['items']))),
      neverHaveIEver: _strings(f['never_have_i_ever']!['items']),
      friendshipQuiz: _list(
          f['friendship_quiz']!['items'],
          (j) => QuizItem(j['q'] as String, _strings(j['options']),
              j['answer'] as int)),
      whoKnowsWhom: _list(f['who_knows_whom']!['items'],
          (j) => OptionQuestion(j['q'] as String, _strings(j['options']))),
      guessEmoji: _list(
          f['guess_emoji']!['items'],
          (j) => EmojiPuzzle(j['emoji'] as String, _strings(j['options']),
              j['correct'] as int)),
      completeSentence: _strings(f['complete_sentence']!['items']),
      challenges: _strings(chal['challenges']),
      punishments: _strings(chal['punishments']),
      activities: _strings(chal['activities']),
      awards: _list(
          f['awards']!['items'],
          (j) => AwardItem(j['title'] as String, j['emoji'] as String,
              j['blurb'] as String)),
      quizTitles: _list(
          f['friendship_titles']!['quiz_titles'],
          (j) => ScoreTitle(j['min'] as int, j['title'] as String,
              j['emoji'] as String)),
    );
  }

  static const fileNames = [
    'posters',
    'editor_assets',
    'truth_dare',
    'would_you_rather',
    'most_likely',
    'never_have_i_ever',
    'friendship_quiz',
    'who_knows_whom',
    'guess_emoji',
    'complete_sentence',
    'challenges',
    'awards',
    'friendship_titles',
  ];
}
