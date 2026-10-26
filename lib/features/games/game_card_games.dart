import 'package:flutter/material.dart';

import '../../core/utils/game_logic.dart';
import '../../core/utils/random_picker.dart';
import '../../core/utils/scoreboard.dart';
import '../../models/content.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'games_common.dart';

// ---------------------------------------------------------------------------
// Truth or Dare
// ---------------------------------------------------------------------------
class TruthDareGame extends StatefulWidget {
  const TruthDareGame({super.key, required this.ctx});
  final GameContext ctx;
  @override
  State<TruthDareGame> createState() => _TruthDareGameState();
}

class _TruthDareGameState extends State<TruthDareGame> {
  String _level = 'easy';
  final Set<String> _cats = {};
  bool _started = false;
  late final Scoreboard _board = Scoreboard(widget.ctx.players);
  int _turn = 0;
  String? _type;
  TruthDareItem? _item;
  int _done = 0;
  final Map<String, Deck<TruthDareItem>> _decks = {};

  String get _player => widget.ctx.players.isEmpty ? 'You' : widget.ctx.players[_turn % widget.ctx.players.length];

  List<TruthDareItem> _pool(String type) => widget.ctx.content.truthDare
      .where((i) => i.type == type && i.level == _level && (_cats.isEmpty || _cats.contains(i.category)))
      .toList();

  void _choose(String type) {
    var pool = _pool(type);
    if (pool.isEmpty) {
      // Fall back to any level so the game never dead-ends.
      pool = widget.ctx.content.truthDare.where((i) => i.type == type).toList();
    }
    final deck = _decks.putIfAbsent('$type$_level${_cats.join()}', () => Deck(pool));
    widget.ctx.tap();
    setState(() {
      _type = type;
      _item = deck.draw();
    });
  }

  void _next({required bool completed}) {
    widget.ctx.tap();
    setState(() {
      if (completed) {
        _board.add(_player);
        _done++;
      }
      _turn++;
      _type = null;
      _item = null;
    });
  }

  void _finish() => widget.ctx.finish(GameResult(
        board: _board,
        headline: ResultLines.summary(_board),
        detail: '$_done challenges completed',
      ));

  @override
  Widget build(BuildContext context) {
    final cs = widget.ctx.content.truthDare;
    final categories = {for (final i in cs) i.category}.toList();
    if (!_started) {
      return ListView(
        padding: const EdgeInsets.all(Spacing.md),
        children: [
          Text('Difficulty', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'easy', label: Text('Easy 😇')),
              ButtonSegment(value: 'medium', label: Text('Medium 😏')),
              ButtonSegment(value: 'spicy', label: Text('Spicy 🌶️')),
            ],
            selected: {_level},
            onSelectionChanged: (s) => setState(() => _level = s.first),
          ),
          const SizedBox(height: Spacing.md),
          Text('Categories (none = all)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final c in categories)
                FilterChip(
                  label: Text(c[0].toUpperCase() + c.substring(1)),
                  selected: _cats.contains(c),
                  onSelected: (v) => setState(() => v ? _cats.add(c) : _cats.remove(c)),
                ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          const Text('All prompts are friendly and age-appropriate. You can skip any of them.'),
          const SizedBox(height: Spacing.lg),
          GradientButton(
            label: "Let's go",
            icon: Icons.play_arrow,
            onPressed: () => setState(() => _started = true),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        TurnBanner(player: _player, trailing: '$_done done'),
        const SizedBox(height: Spacing.md),
        if (_item == null) ...[
          const PromptCard(text: 'Truth or Dare?', emoji: '🎯'),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              Expanded(child: FilledButton(onPressed: () => _choose('truth'), child: const Text('Truth'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(onPressed: () => _choose('dare'), child: const Text('Dare'))),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _choose(widget.ctx.random.pick(['truth', 'dare'])),
            icon: const Icon(Icons.casino),
            label: const Text('Surprise me'),
          ),
        ] else ...[
          PromptCard(
            text: _item!.text,
            label: _type,
            emoji: _type == 'truth' ? '💬' : '⚡',
            colors: _type == 'truth'
                ? const [Color(0xFF3B82F6), Color(0xFF7C4DFF)]
                : const [Color(0xFFFF4F8B), Color(0xFFFF9F1C)],
          ),
          const SizedBox(height: Spacing.md),
          GradientButton(
            label: 'Done! Next player',
            icon: Icons.check,
            onPressed: () => _next(completed: true),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _next(completed: false),
            icon: const Icon(Icons.skip_next),
            label: const Text('Skip'),
          ),
        ],
        const SizedBox(height: Spacing.lg),
        TextButton(onPressed: _finish, child: const Text('Finish game')),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Would You Rather
// ---------------------------------------------------------------------------
class WouldYouRatherGame extends StatefulWidget {
  const WouldYouRatherGame({super.key, required this.ctx});
  final GameContext ctx;
  @override
  State<WouldYouRatherGame> createState() => _WouldYouRatherGameState();
}

class _WouldYouRatherGameState extends State<WouldYouRatherGame> {
  static const rounds = 8;
  late final List<WouldYouRatherItem> _questions =
      widget.ctx.random.pickMany(widget.ctx.content.wouldYouRather, rounds);
  late final Scoreboard _board = Scoreboard(widget.ctx.players);
  int _round = 0;
  int _voter = 0;
  bool _gate = true;
  final Map<String, bool> _votes = {}; // player -> picked A
  bool _revealed = false;

  List<String> get _players => widget.ctx.players;

  void _vote(bool a) {
    widget.ctx.tap();
    setState(() {
      _votes[_players[_voter]] = a;
      if (_voter + 1 < _players.length) {
        _voter++;
        _gate = true;
      } else {
        _revealed = true;
        final aCount = _votes.values.where((v) => v).length;
        final bCount = _votes.length - aCount;
        if (_players.length > 2 && aCount != bCount) {
          final minority = aCount < bCount;
          for (final e in _votes.entries) {
            if (e.value == minority) _board.add(e.key);
          }
        }
      }
    });
  }

  void _next() {
    if (_round + 1 >= _questions.length) {
      widget.ctx.finish(GameResult(
        board: _players.length > 1 ? _board : null,
        headline: _players.length > 1 ? 'Odd one out wins!' : 'All choices made!',
        detail: _players.length > 1
            ? 'You score when you pick the less popular answer.'
            : 'You answered ${_questions.length} tough questions.',
      ));
      return;
    }
    setState(() {
      _round++;
      _voter = 0;
      _gate = _players.length > 1;
      _votes.clear();
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_round];
    final multi = _players.length > 1;
    if (multi && _gate && !_revealed) {
      return PassPhoneGate(
        player: _players[_voter],
        onReady: () => setState(() => _gate = false),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        LinearProgressIndicator(value: (_round + 1) / _questions.length, borderRadius: BorderRadius.circular(8)),
        const SizedBox(height: Spacing.sm),
        Text('Question ${_round + 1} of ${_questions.length}'),
        const SizedBox(height: Spacing.md),
        if (!_revealed) ...[
          if (multi) TurnBanner(player: _players[_voter]),
          const SizedBox(height: Spacing.md),
          const Text('Would you rather...', textAlign: TextAlign.center),
          const SizedBox(height: Spacing.sm),
          PromptCard(text: q.a, label: 'Option A', colors: const [Color(0xFF3B82F6), Color(0xFF1E3A8A)]),
          const SizedBox(height: 8),
          const Center(child: Text('OR', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
          const SizedBox(height: 8),
          PromptCard(text: q.b, label: 'Option B', colors: const [Color(0xFFFF4F8B), Color(0xFF9D174D)]),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              Expanded(child: FilledButton(onPressed: () => _vote(true), child: const Text('I pick A'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(onPressed: () => _vote(false), child: const Text('I pick B'))),
            ],
          ),
        ] else ...[
          _ResultBar(label: q.a, names: [for (final e in _votes.entries) if (e.value) e.key], total: _votes.length, color: const Color(0xFF3B82F6)),
          const SizedBox(height: 12),
          _ResultBar(label: q.b, names: [for (final e in _votes.entries) if (!e.value) e.key], total: _votes.length, color: AppColors.pink),
          const SizedBox(height: Spacing.lg),
          GradientButton(
            label: _round + 1 >= _questions.length ? 'See results' : 'Next question',
            onPressed: _next,
          ),
        ],
      ],
    );
  }
}

class _ResultBar extends StatelessWidget {
  const _ResultBar({required this.label, required this.names, required this.total, required this.color});
  final String label;
  final List<String> names;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : names.length / total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: pct, minHeight: 12, color: color, borderRadius: BorderRadius.circular(8)),
            const SizedBox(height: 8),
            Text(names.isEmpty ? 'Nobody' : '${names.length}/$total: ${names.join(', ')}'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Most Likely To (and its themed decks)
// ---------------------------------------------------------------------------
class MostLikelyGame extends StatefulWidget {
  const MostLikelyGame({super.key, required this.ctx, required this.deckId});
  final GameContext ctx;
  final String deckId;
  @override
  State<MostLikelyGame> createState() => _MostLikelyGameState();
}

class _MostLikelyGameState extends State<MostLikelyGame> {
  static const rounds = 8;
  late final MostLikelyDeck _deck = widget.ctx.content.deck(widget.deckId);
  late final List<String> _questions = widget.ctx.random.pickMany(_deck.items, rounds);
  late final Scoreboard _board = Scoreboard(widget.ctx.players);
  int _round = 0;
  int _voter = 0;
  bool _gate = true;
  VoteTally _tally = VoteTally();
  bool _revealed = false;

  List<String> get _players => widget.ctx.players;

  void _vote(String who) {
    widget.ctx.tap();
    setState(() {
      _tally.vote(who);
      if (_voter + 1 < _players.length) {
        _voter++;
        _gate = true;
      } else {
        _revealed = true;
        for (final w in _tally.leaders()) {
          _board.add(w);
        }
      }
    });
  }

  void _next() {
    if (_round + 1 >= _questions.length) {
      widget.ctx.finish(GameResult(
        board: _board,
        headline: ResultLines.summary(_board),
        detail: '${_deck.title}: most crowns after ${_questions.length} rounds.',
      ));
      return;
    }
    setState(() {
      _round++;
      _voter = 0;
      _gate = true;
      _tally = VoteTally();
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_round];
    if (_gate && !_revealed) {
      return PassPhoneGate(player: _players[_voter], onReady: () => setState(() => _gate = false));
    }
    final voter = _players[_voter];
    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        LinearProgressIndicator(value: (_round + 1) / _questions.length, borderRadius: BorderRadius.circular(8)),
        const SizedBox(height: Spacing.sm),
        Text('Round ${_round + 1} of ${_questions.length}'),
        const SizedBox(height: Spacing.md),
        PromptCard(text: q, emoji: _deck.emoji, colors: const [Color(0xFFFF9F1C), Color(0xFFE36414)]),
        const SizedBox(height: Spacing.md),
        if (!_revealed) ...[
          Text('$voter, vote for someone:', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final p in _players)
            OptionButton(label: p == voter ? '$p (yourself)' : p, onTap: () => _vote(p)),
        ] else ...[
          Text('The crown goes to...', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final p in _players)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: PlayerAvatar(name: p),
                title: Text(p, style: const TextStyle(fontWeight: FontWeight.w800)),
                trailing: Text(
                  '${_tally.leaders().contains(p) ? '👑 ' : ''}${_tally.countFor(p)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          const SizedBox(height: Spacing.md),
          GradientButton(label: _round + 1 >= _questions.length ? 'See results' : 'Next round', onPressed: _next),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Never Have I Ever
// ---------------------------------------------------------------------------
class NeverHaveIEverGame extends StatefulWidget {
  const NeverHaveIEverGame({super.key, required this.ctx});
  final GameContext ctx;
  @override
  State<NeverHaveIEverGame> createState() => _NeverHaveIEverGameState();
}

class _NeverHaveIEverGameState extends State<NeverHaveIEverGame> {
  static const rounds = 10;
  late final List<String> _prompts = widget.ctx.random.pickMany(widget.ctx.content.neverHaveIEver, rounds);
  late final Scoreboard _board = Scoreboard(widget.ctx.players.isEmpty ? ['You'] : widget.ctx.players);
  int _round = 0;
  final Set<String> _have = {};

  void _next() {
    for (final p in _have) {
      _board.add(p);
    }
    if (_round + 1 >= _prompts.length) {
      widget.ctx.finish(GameResult(
        board: _board,
        headline: _board.winners().isEmpty ? 'Squeaky clean!' : '${_board.winners().join(' & ')} did it all!',
        detail: 'Points = things you have actually done. Wild, aren\'t you?',
      ));
      return;
    }
    widget.ctx.tap();
    setState(() {
      _round++;
      _have.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final players = _board.players;
    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        LinearProgressIndicator(value: (_round + 1) / _prompts.length, borderRadius: BorderRadius.circular(8)),
        const SizedBox(height: Spacing.sm),
        Text('Prompt ${_round + 1} of ${_prompts.length}'),
        const SizedBox(height: Spacing.md),
        PromptCard(text: _prompts[_round], emoji: '🙈', colors: const [Color(0xFF42A5F5), Color(0xFF0D47A1)]),
        const SizedBox(height: Spacing.md),
        Text('Tap everyone who HAS done it:', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final p in players)
              FilterChip(
                avatar: PlayerAvatar(name: p, radius: 12),
                label: Text('$p (${_board.scoreOf(p)})'),
                selected: _have.contains(p),
                onSelected: (v) {
                  widget.ctx.tap();
                  setState(() => v ? _have.add(p) : _have.remove(p));
                },
              ),
          ],
        ),
        const SizedBox(height: Spacing.lg),
        GradientButton(label: _round + 1 >= _prompts.length ? 'See results' : 'Next prompt', onPressed: _next),
      ],
    );
  }
}
