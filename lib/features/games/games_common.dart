import 'package:flutter/material.dart';

import '../../core/utils/game_logic.dart';
import '../../core/utils/random_picker.dart';
import '../../core/utils/scoreboard.dart';
import '../../models/content.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class GameResult {
  const GameResult({this.board, required this.headline, this.detail = '', this.extras = const {}});
  final Scoreboard? board;
  final String headline;
  final String detail;

  /// Optional per-player caption (for example a quiz title).
  final Map<String, String> extras;
}

/// Everything a game needs from the outside world.
class GameContext {
  const GameContext({
    required this.content,
    required this.players,
    required this.random,
    required this.tap,
    required this.finish,
  });
  final AppContent content;
  final List<String> players;
  final RandomPicker random;
  final VoidCallback tap;
  final void Function(GameResult result) finish;

  bool get solo => players.length <= 1;
}

/// "Pass the phone to X" interstitial that hides the previous player's choice.
class PassPhoneGate extends StatelessWidget {
  const PassPhoneGate({
    super.key,
    required this.player,
    required this.onReady,
    this.message = 'Pass the phone to',
    this.buttonLabel,
  });
  final String player;
  final String message;
  final String? buttonLabel;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📱', style: TextStyle(fontSize: 64)),
            const SizedBox(height: Spacing.md),
            Text(message, style: t.titleMedium),
            const SizedBox(height: Spacing.sm),
            Text(player,
                style: t.headlineMedium?.copyWith(color: AppColors.pink),
                textAlign: TextAlign.center),
            const SizedBox(height: Spacing.lg),
            GradientButton(label: buttonLabel ?? "I'm $player", onPressed: onReady),
          ],
        ),
      ),
    );
  }
}

class PromptCard extends StatelessWidget {
  const PromptCard({
    super.key,
    required this.text,
    this.label,
    this.emoji,
    this.colors = const [AppColors.pink, AppColors.purple],
  });
  final String text;
  final String? label;
  final String? emoji;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null)
            Text(label!.toUpperCase(),
                style: const TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          if (emoji != null) Text(emoji!, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: Spacing.sm),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.25),
          ),
        ],
      ),
    );
  }
}

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.name, this.radius = 20});
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hue = (name.codeUnits.fold<int>(0, (a, b) => a + b) * 37) % 360;
    return CircleAvatar(
      radius: radius,
      backgroundColor: HSLColor.fromAHSL(1, hue.toDouble(), 0.6, 0.5).toColor(),
      child: Text(
        name.isEmpty ? '?' : String.fromCharCode(name.runes.first).toUpperCase(),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: radius * 0.9),
      ),
    );
  }
}

class ScoreboardView extends StatelessWidget {
  const ScoreboardView({super.key, required this.board, this.extras = const {}});
  final Scoreboard board;
  final Map<String, String> extras;

  @override
  Widget build(BuildContext context) {
    final r = board.ranking();
    const medals = ['🥇', '🥈', '🥉'];
    final top = r.isEmpty ? 0 : r.first.value;
    return Column(
      children: [
        for (var i = 0; i < r.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: PlayerAvatar(name: r[i].key),
              title: Text(r[i].key, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: extras[r[i].key] == null ? null : Text(extras[r[i].key]!),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (i < 3 && top > 0 && r[i].value > 0) Text(medals[i], style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text('${r[i].value}',
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class ResultView extends StatelessWidget {
  const ResultView({
    super.key,
    required this.result,
    required this.onPlayAgain,
    required this.onDone,
  });
  final GameResult result;
  final VoidCallback onPlayAgain;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final board = result.board;
    final winners = board?.winners() ?? const [];
    final losers = board?.losers() ?? const [];
    final seed = (winners.isEmpty ? 0 : winners.first.hashCode);
    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        const SizedBox(height: Spacing.md),
        const Center(child: Text('🎉', style: TextStyle(fontSize: 64))),
        Center(
          child: Text(result.headline,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium),
        ),
        if (result.detail.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(result.detail, textAlign: TextAlign.center),
          ),
        if (winners.isNotEmpty && (board?.players.length ?? 0) > 1) ...[
          const SizedBox(height: Spacing.md),
          Center(
            child: Chip(
              avatar: const Text('🏆'),
              label: Text('${winners.join(' & ')}: ${ResultLines.winner(seed)}'),
            ),
          ),
        ],
        if (losers.isNotEmpty)
          Center(
            child: Chip(
              avatar: const Text('🐢'),
              label: Text('${losers.join(' & ')}: ${ResultLines.loser(seed + 1)}'),
            ),
          ),
        const SizedBox(height: Spacing.md),
        if (board != null) ScoreboardView(board: board, extras: result.extras),
        const SizedBox(height: Spacing.md),
        GradientButton(label: 'Play again', icon: Icons.replay, onPressed: onPlayAgain),
        const SizedBox(height: Spacing.sm),
        OutlinedButton(onPressed: onDone, child: const Text('Done')),
      ],
    );
  }
}

/// Small header chip showing whose turn it is.
class TurnBanner extends StatelessWidget {
  const TurnBanner({super.key, required this.player, this.trailing});
  final String player;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PlayerAvatar(name: player, radius: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text("$player's turn",
              style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
        ),
        if (trailing != null) Text(trailing!, style: Theme.of(context).textTheme.labelLarge),
      ],
    );
  }
}

class OptionButton extends StatelessWidget {
  const OptionButton({
    super.key,
    required this.label,
    required this.onTap,
    this.state = OptionState.idle,
  });
  final String label;
  final VoidCallback? onTap;
  final OptionState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg) = switch (state) {
      OptionState.correct => (const Color(0xFF2E7D32), Colors.white),
      OptionState.wrong => (const Color(0xFFC62828), Colors.white),
      OptionState.idle => (cs.surfaceContainerHighest, cs.onSurface),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            alignment: Alignment.centerLeft,
            child: Text(label,
                style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ),
      ),
    );
  }
}

enum OptionState { idle, correct, wrong }
