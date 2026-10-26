import 'package:flutter/material.dart';

import '../../core/utils/game_logic.dart';
import '../../core/utils/scoreboard.dart';
import '../../models/content.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'games_common.dart';

// ---------------------------------------------------------------------------
// Friendship Quiz (each player answers the same questions, gets a title)
// ---------------------------------------------------------------------------
class FriendshipQuizGame extends StatefulWidget {
  const FriendshipQuizGame({super.key, required this.ctx});
  final GameContext ctx;
  @override
  State<FriendshipQuizGame> createState() => _FriendshipQuizGameState();
}

class _FriendshipQuizGameState extends State<FriendshipQuizGame> {
  late final List<QuizItem> _questions = widget.ctx.random.shuffled(widget.ctx.content.friendshipQuiz);
  late final List<String> _players = widget.ctx.players.isEmpty ? ['You'] : widget.ctx.players;
  late final Scoreboard _board = Scoreboard(_players);
  int _player = 0;
  int _q = 0;
  int? _picked;
  bool _gate = true;

  void _answer(int i) {
    if (_picked != null) return;
    widget.ctx.tap();
    setState(() {
      _picked = i;
      if (i == _questions[_q].answer) _board.add(_players[_player]);
    });
  }

  void _next() {
    if (_q + 1 < _questions.length) {
      setState(() {
        _q++;
        _picked = null;
      });
    } else if (_player + 1 < _players.length) {
      setState(() {
        _player++;
        _q = 0;
        _picked = null;
        _gate = true;
      });
    } else {
      final titles = widget.ctx.content.quizTitles;
      final extras = <String, String>{};
      for (final p in _players) {
        final pct = QuizScoring.percent(_board.scoreOf(p), _questions.length);
        final t = QuizScoring.titleFor(pct, titles);
        extras[p] = '${t.emoji} ${t.title} ($pct%)';
      }
      final best = _board.ranking().first;
      final pct = QuizScoring.percent(best.value, _questions.length);
      final t = QuizScoring.titleFor(pct, titles);
      widget.ctx.finish(GameResult(
        board: _board,
        headline: '${t.emoji} ${t.title}',
        detail: _players.length == 1
            ? 'You scored ${best.value}/${_questions.length}'
            : '${best.key} leads with ${best.value}/${_questions.length}',
        extras: extras,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final multi = _players.length > 1;
    if (multi && _gate) {
      return PassPhoneGate(player: _players[_player], onReady: () => setState(() => _gate = false));
    }
    final q = _questions[_q];
    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        LinearProgressIndicator(value: (_q + 1) / _questions.length, borderRadius: BorderRadius.circular(8)),
        const SizedBox(height: Spacing.sm),
        if (multi) TurnBanner(player: _players[_player], trailing: '${_q + 1}/${_questions.length}')
        else Text('Question ${_q + 1} of ${_questions.length}'),
        const SizedBox(height: Spacing.md),
        PromptCard(text: q.question, emoji: '🧠', colors: const [Color(0xFF3949AB), Color(0xFF1A237E)]),
        const SizedBox(height: Spacing.md),
        for (var i = 0; i < q.options.length; i++)
          OptionButton(
            label: q.options[i],
            onTap: _picked == null ? () => _answer(i) : null,
            state: _picked == null
                ? OptionState.idle
                : i == q.answer
                    ? OptionState.correct
                    : i == _picked
                        ? OptionState.wrong
                        : OptionState.idle,
          ),
        if (_picked != null) ...[
          const SizedBox(height: 8),
          GradientButton(
            label: _q + 1 < _questions.length
                ? 'Next question'
                : (_player + 1 < _players.length ? 'Next player' : 'See results'),
            onPressed: _next,
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Guess the Emoji
// ---------------------------------------------------------------------------
class GuessEmojiGame extends StatefulWidget {
  const GuessEmojiGame({super.key, required this.ctx});
  final GameContext ctx;
  @override
  State<GuessEmojiGame> createState() => _GuessEmojiGameState();
}

class _GuessEmojiGameState extends State<GuessEmojiGame> {
  static const rounds = 10;
  late final List<EmojiPuzzle> _puzzles = widget.ctx.random.pickMany(widget.ctx.content.guessEmoji, rounds);
  late final List<String> _players = widget.ctx.players.isEmpty ? ['You'] : widget.ctx.players;
  late final Scoreboard _board = Scoreboard(_players);
  int _i = 0;
  int? _picked;

  String get _turn => _players[_i % _players.length];

  void _answer(int idx) {
    if (_picked != null) return;
    widget.ctx.tap();
    setState(() {
      _picked = idx;
      if (idx == _puzzles[_i].correct) _board.add(_turn);
    });
  }

  void _next() {
    if (_i + 1 >= _puzzles.length) {
      widget.ctx.finish(GameResult(
        board: _board,
        headline: _players.length == 1
            ? 'You solved ${_board.scoreOf(_players.first)} of ${_puzzles.length}'
            : ResultLines.summary(_board),
        detail: 'Emoji decoder complete!',
      ));
      return;
    }
    setState(() {
      _i++;
      _picked = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _puzzles[_i];
    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        LinearProgressIndicator(value: (_i + 1) / _puzzles.length, borderRadius: BorderRadius.circular(8)),
        const SizedBox(height: Spacing.sm),
        TurnBanner(player: _turn, trailing: '${_i + 1}/${_puzzles.length}'),
        const SizedBox(height: Spacing.md),
        PromptCard(text: p.emoji, label: 'What is it?', colors: const [Color(0xFFFDD835), Color(0xFFF57F17)]),
        const SizedBox(height: Spacing.md),
        for (var k = 0; k < p.options.length; k++)
          OptionButton(
            label: p.options[k],
            onTap: _picked == null ? () => _answer(k) : null,
            state: _picked == null
                ? OptionState.idle
                : k == p.correct
                    ? OptionState.correct
                    : k == _picked
                        ? OptionState.wrong
                        : OptionState.idle,
          ),
        if (_picked != null)
          GradientButton(label: _i + 1 >= _puzzles.length ? 'See results' : 'Next', onPressed: _next),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Who Knows Whom Best
// ---------------------------------------------------------------------------
class WhoKnowsWhomGame extends StatefulWidget {
  const WhoKnowsWhomGame({super.key, required this.ctx});
  final GameContext ctx;
  @override
  State<WhoKnowsWhomGame> createState() => _WhoKnowsWhomGameState();
}

enum _Phase { subjectGate, subjectAnswering, guesserGate, guessing, roundResult }

class _WhoKnowsWhomGameState extends State<WhoKnowsWhomGame> {
  static const questionsPerRound = 5;
  late final Scoreboard _board = Scoreboard(widget.ctx.players);
  List<String> get _players => widget.ctx.players;

  int _round = 0;
  _Phase _phase = _Phase.subjectGate;
  late List<OptionQuestion> _qs = _draw();
  List<int> _truth = [];
  List<int> _guess = [];
  int _guesser = 0; // index into guessers
  final Map<String, int> _roundScores = {};

  String get _subject => _players[_round % _players.length];
  List<String> get _guessers => _players.where((p) => p != _subject).toList();

  List<OptionQuestion> _draw() =>
      widget.ctx.random.pickMany(widget.ctx.content.whoKnowsWhom, questionsPerRound);

  void _pick(int option) {
    widget.ctx.tap();
    setState(() {
      if (_phase == _Phase.subjectAnswering) {
        _truth.add(option);
        if (_truth.length == _qs.length) {
          _guesser = 0;
          _phase = _Phase.guesserGate;
        }
      } else {
        _guess.add(option);
        if (_guess.length == _qs.length) {
          final g = _guessers[_guesser];
          final pts = matchScore(_truth, _guess);
          _board.add(g, pts);
          _roundScores[g] = pts;
          _guess = [];
          if (_guesser + 1 < _guessers.length) {
            _guesser++;
            _phase = _Phase.guesserGate;
          } else {
            _phase = _Phase.roundResult;
          }
        }
      }
    });
  }

  void _nextRound() => setState(() {
        _round++;
        _qs = _draw();
        _truth = [];
        _guess = [];
        _roundScores.clear();
        _phase = _Phase.subjectGate;
      });

  void _finish() {
    widget.ctx.finish(GameResult(
      board: _board,
      headline: ResultLines.summary(_board),
      detail: 'Points = answers guessed correctly about each friend.',
    ));
  }

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _Phase.subjectGate:
        return PassPhoneGate(
          player: _subject,
          message: 'Round ${_round + 1}: this round is about',
          buttonLabel: "I'm $_subject, answer my questions",
          onReady: () => setState(() => _phase = _Phase.subjectAnswering),
        );
      case _Phase.guesserGate:
        return PassPhoneGate(
          player: _guessers[_guesser],
          message: 'Guess what $_subject answered. Pass to',
          onReady: () => setState(() => _phase = _Phase.guessing),
        );
      case _Phase.roundResult:
        return ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            Text('How well did they know $_subject?', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Spacing.md),
            for (final e in _roundScores.entries)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: PlayerAvatar(name: e.key),
                  title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w800)),
                  trailing: Text('${e.value}/${_qs.length}', style: Theme.of(context).textTheme.titleLarge),
                ),
              ),
            const SizedBox(height: Spacing.md),
            ScoreboardView(board: _board),
            const SizedBox(height: Spacing.md),
            GradientButton(label: 'Next round', onPressed: _nextRound),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _finish, child: const Text('Finish game')),
          ],
        );
      case _Phase.subjectAnswering:
      case _Phase.guessing:
        final answering = _phase == _Phase.subjectAnswering;
        final idx = answering ? _truth.length : _guess.length;
        final q = _qs[idx];
        return ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            LinearProgressIndicator(value: (idx + 1) / _qs.length, borderRadius: BorderRadius.circular(8)),
            const SizedBox(height: Spacing.sm),
            Text(answering
                ? '$_subject, answer honestly (${idx + 1}/${_qs.length})'
                : '${_guessers[_guesser]}, what did $_subject pick? (${idx + 1}/${_qs.length})'),
            const SizedBox(height: Spacing.md),
            PromptCard(
              text: q.question,
              emoji: answering ? '🙋' : '🔮',
              colors: const [Color(0xFF8E24AA), Color(0xFF4A148C)],
            ),
            const SizedBox(height: Spacing.md),
            for (var i = 0; i < q.options.length; i++)
              OptionButton(label: q.options[i], onTap: () => _pick(i)),
          ],
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Guess the Friend
// ---------------------------------------------------------------------------
class GuessFriendGame extends StatefulWidget {
  const GuessFriendGame({super.key, required this.ctx});
  final GameContext ctx;
  @override
  State<GuessFriendGame> createState() => _GuessFriendGameState();
}

enum _GfPhase { chooserGate, choosing, guessing, reveal }

class _GuessFriendGameState extends State<GuessFriendGame> {
  late final Scoreboard _board = Scoreboard(widget.ctx.players);
  List<String> get _players => widget.ctx.players;
  int _round = 0;
  _GfPhase _phase = _GfPhase.chooserGate;
  String? _secret;
  int _wrongs = 0;
  final Set<String> _eliminated = {};
  String? _winner;

  String get _chooser => _players[_round % _players.length];
  List<String> get _candidates => _players.where((p) => p != _chooser).toList();
  List<String> get _guessers => _players.where((p) => p != _chooser && p != _secret).toList();
  String get _currentGuesser => _guessers[_wrongs % _guessers.length];
  int get _hintsShown => (_wrongs ~/ _guessers.length + 1).clamp(1, GuessFriend.maxHints);
  bool get _outOfHints => _wrongs >= _guessers.length * GuessFriend.maxHints;

  void _choose(String name) {
    widget.ctx.tap();
    setState(() {
      _secret = name;
      _wrongs = 0;
      _eliminated.clear();
      _winner = null;
      _phase = _GfPhase.guessing;
    });
  }

  void _guess(String name) {
    widget.ctx.tap();
    setState(() {
      if (name == _secret) {
        _winner = _currentGuesser;
        _board.add(_winner!, GuessFriend.points(_hintsShown));
        _phase = _GfPhase.reveal;
      } else {
        _eliminated.add(name);
        _wrongs++;
        if (_outOfHints) _phase = _GfPhase.reveal;
      }
    });
  }

  void _next() {
    setState(() {
      _round++;
      _secret = null;
      _phase = _GfPhase.chooserGate;
    });
  }

  void _finish() => widget.ctx.finish(GameResult(
        board: _board,
        headline: ResultLines.summary(_board),
        detail: 'Earlier correct guesses earn more points.',
      ));

  @override
  Widget build(BuildContext context) {
    switch (_phase) {
      case _GfPhase.chooserGate:
        return PassPhoneGate(
          player: _chooser,
          message: 'Round ${_round + 1}: you pick a secret friend. Pass to',
          onReady: () => setState(() => _phase = _GfPhase.choosing),
        );
      case _GfPhase.choosing:
        return ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            Text('$_chooser, secretly pick a friend. Others look away!',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Spacing.md),
            for (final c in _candidates) OptionButton(label: c, onTap: () => _choose(c)),
          ],
        );
      case _GfPhase.guessing:
        return ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            TurnBanner(player: _currentGuesser, trailing: '+${GuessFriend.points(_hintsShown)} pts'),
            const SizedBox(height: Spacing.md),
            for (var i = 0; i < _hintsShown; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PromptCard(
                  text: GuessFriend.hint(_secret!, i),
                  label: 'Hint ${i + 1}',
                  emoji: '🕵️',
                  colors: const [Color(0xFF455A64), Color(0xFF263238)],
                ),
              ),
            const SizedBox(height: Spacing.sm),
            Text('Who is it, $_currentGuesser?', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final c in _candidates)
              OptionButton(
                label: c,
                state: _eliminated.contains(c) ? OptionState.wrong : OptionState.idle,
                onTap: _eliminated.contains(c) ? null : () => _guess(c),
              ),
          ],
        );
      case _GfPhase.reveal:
        return ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            PromptCard(
              text: _secret!,
              label: 'The secret friend was',
              emoji: _winner == null ? '🤷' : '🎯',
              colors: const [Color(0xFF26A69A), Color(0xFF004D40)],
            ),
            const SizedBox(height: Spacing.md),
            Center(
              child: Text(
                _winner == null ? 'Nobody guessed it!' : '$_winner got it! +${GuessFriend.points(_hintsShown)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: Spacing.md),
            ScoreboardView(board: _board),
            const SizedBox(height: Spacing.md),
            GradientButton(label: 'Next round', onPressed: _next),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _finish, child: const Text('Finish game')),
          ],
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Complete the Sentence
// ---------------------------------------------------------------------------
class CompleteSentenceGame extends StatefulWidget {
  const CompleteSentenceGame({super.key, required this.ctx});
  final GameContext ctx;
  @override
  State<CompleteSentenceGame> createState() => _CompleteSentenceGameState();
}

enum _CsPhase { gate, writing, vote, reveal }

class _CompleteSentenceGameState extends State<CompleteSentenceGame> {
  static const rounds = 3;
  late final List<String> _prompts = widget.ctx.random.pickMany(widget.ctx.content.completeSentence, rounds);
  late final Scoreboard _board = Scoreboard(widget.ctx.players);
  List<String> get _players => widget.ctx.players;
  final _text = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _round = 0;
  int _writer = 0;
  _CsPhase _phase = _CsPhase.gate;
  final Map<String, String> _answers = {};
  List<String> _order = [];
  String? _winner;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.ctx.tap();
    setState(() {
      _answers[_players[_writer]] = _text.text.trim();
      _text.clear();
      if (_writer + 1 < _players.length) {
        _writer++;
        _phase = _CsPhase.gate;
      } else {
        _order = widget.ctx.random.shuffled(_answers.keys);
        _phase = _CsPhase.vote;
      }
    });
  }

  void _choose(String author) {
    widget.ctx.tap();
    setState(() {
      _winner = author;
      _board.add(author);
      _phase = _CsPhase.reveal;
    });
  }

  void _next() {
    if (_round + 1 >= _prompts.length) {
      widget.ctx.finish(GameResult(
        board: _board,
        headline: ResultLines.summary(_board),
        detail: 'Funniest sentences win.',
      ));
      return;
    }
    setState(() {
      _round++;
      _writer = 0;
      _answers.clear();
      _winner = null;
      _phase = _CsPhase.gate;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prompt = _prompts[_round];
    switch (_phase) {
      case _CsPhase.gate:
        return PassPhoneGate(
          player: _players[_writer],
          message: 'Round ${_round + 1}: write your answer. Pass to',
          onReady: () => setState(() => _phase = _CsPhase.writing),
        );
      case _CsPhase.writing:
        return ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            PromptCard(text: prompt, emoji: '✍️', colors: const [Color(0xFF26A69A), Color(0xFF004D40)]),
            const SizedBox(height: Spacing.md),
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _text,
                autofocus: true,
                maxLength: 80,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: '${_players[_writer]}, finish the sentence'),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Write something funny first' : null,
              ),
            ),
            const SizedBox(height: Spacing.md),
            GradientButton(label: 'Lock it in', onPressed: _submit),
          ],
        );
      case _CsPhase.vote:
        return ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            Text(prompt, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Read them aloud, then tap the funniest answer:'),
            const SizedBox(height: Spacing.md),
            for (final a in _order) OptionButton(label: _answers[a]!, onTap: () => _choose(a)),
          ],
        );
      case _CsPhase.reveal:
        return ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            PromptCard(text: _answers[_winner]!, label: 'Funniest answer by', emoji: '🏆'),
            const SizedBox(height: 8),
            Center(child: Text(_winner!, style: Theme.of(context).textTheme.headlineMedium)),
            const SizedBox(height: Spacing.md),
            Text('All answers', style: Theme.of(context).textTheme.titleMedium),
            for (final e in _answers.entries)
              Card(
                margin: const EdgeInsets.only(top: 6),
                child: ListTile(
                  leading: PlayerAvatar(name: e.key),
                  title: Text(e.value),
                  subtitle: Text(e.key),
                ),
              ),
            const SizedBox(height: Spacing.md),
            GradientButton(label: _round + 1 >= _prompts.length ? 'See results' : 'Next round', onPressed: _next),
          ],
        );
    }
  }
}
