import 'package:flutter/material.dart';

import '../../core/utils/random_picker.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'games_common.dart';

enum GeneratorKind { challenge, punishment }

/// Endless generator of challenges or punishments, optionally assigned to a
/// random player.
class GeneratorGame extends StatefulWidget {
  const GeneratorGame({super.key, required this.ctx, required this.kind});
  final GameContext ctx;
  final GeneratorKind kind;
  @override
  State<GeneratorGame> createState() => _GeneratorGameState();
}

class _GeneratorGameState extends State<GeneratorGame> {
  late final Deck<String> _deck = Deck(
    widget.kind == GeneratorKind.challenge
        ? widget.ctx.content.challenges
        : widget.ctx.content.punishments,
  );
  late final Deck<String>? _players =
      widget.ctx.players.isEmpty ? null : Deck(widget.ctx.players);
  String? _text;
  String? _who;
  int _count = 0;

  void _generate() {
    widget.ctx.tap();
    setState(() {
      _text = _deck.draw();
      _who = _players?.draw();
      _count++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isChallenge = widget.kind == GeneratorKind.challenge;
    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        if (_text == null)
          PromptCard(
            text: isChallenge ? 'Ready for a challenge?' : 'Who needs a punishment?',
            emoji: isChallenge ? '⚡' : '😈',
            colors: isChallenge
                ? const [Color(0xFFFB8C00), Color(0xFFBF360C)]
                : const [Color(0xFF212121), Color(0xFFB71C1C)],
          )
        else ...[
          if (_who != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Center(child: Chip(avatar: PlayerAvatar(name: _who!, radius: 12), label: Text('For $_who'))),
            ),
          PromptCard(
            text: _text!,
            label: isChallenge ? 'Challenge #$_count' : 'Punishment #$_count',
            emoji: isChallenge ? '⚡' : '😈',
            colors: isChallenge
                ? const [Color(0xFFFB8C00), Color(0xFFBF360C)]
                : const [Color(0xFF212121), Color(0xFFB71C1C)],
          ),
        ],
        const SizedBox(height: Spacing.lg),
        GradientButton(
          label: _text == null ? 'Generate' : 'Another one',
          icon: Icons.casino,
          onPressed: _generate,
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => widget.ctx.finish(GameResult(
            headline: 'Done after $_count ${isChallenge ? 'challenges' : 'punishments'}',
            detail: 'Be a good sport!',
          )),
          child: const Text('I am done'),
        ),
      ],
    );
  }
}
