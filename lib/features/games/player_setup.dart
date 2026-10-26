import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/utils/validators.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'game_registry.dart';
import 'games_common.dart';

/// Lets the user choose who plays: saved friends and/or typed names.
class PlayerSetup extends ConsumerStatefulWidget {
  const PlayerSetup({
    super.key,
    required this.game,
    required this.onStart,
    this.initial = const [],
  });
  final GameInfo game;
  final List<String> initial;
  final void Function(List<String> players) onStart;

  @override
  ConsumerState<PlayerSetup> createState() => _PlayerSetupState();
}

class _PlayerSetupState extends ConsumerState<PlayerSetup> {
  late final List<String> _players = [...widget.initial];
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _startError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String name) {
    final err = Validators.name(name, existing: _players);
    if (err != null) {
      showSnack(context, err);
      return;
    }
    if (_players.length >= Validators.maxPlayers) {
      showSnack(context, 'Maximum ${Validators.maxPlayers} players');
      return;
    }
    ref.read(feedbackProvider).tap();
    setState(() {
      _players.add(name.trim());
      _startError = null;
    });
  }

  void _submitTyped() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _add(_controller.text);
    _controller.clear();
  }

  void _start() {
    final err = Validators.playerCount(_players.length, min: widget.game.minPlayers);
    if (err != null) {
      setState(() => _startError = err);
      return;
    }
    widget.onStart(List.of(_players));
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider).value ?? const [];
    final g = widget.game;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        PromptCard(text: g.description, emoji: g.emoji, colors: g.colors),
        const SizedBox(height: Spacing.md),
        Wrap(
          spacing: 8,
          children: [for (final m in g.modes) Chip(label: Text(m.label))],
        ),
        const SizedBox(height: Spacing.md),
        Text(
          g.playersOptional
              ? "Who's playing? (optional)"
              : g.minPlayers <= 1
                  ? "Who's playing? (1 to ${Validators.maxPlayers})"
                  : "Who's playing? (${g.minPlayers} to ${Validators.maxPlayers})",
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: Spacing.sm),
        Form(
          key: _formKey,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _controller,
                  maxLength: Validators.maxNameLength,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(hintText: 'Type a name', counterText: ''),
                  validator: (v) => Validators.name(v, existing: _players),
                  onFieldSubmitted: (_) => _submitTyped(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _submitTyped,
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          ),
        ),
        if (friends.isNotEmpty) ...[
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              Expanded(child: Text('From your friends', style: theme.textTheme.titleSmall)),
              TextButton(
                onPressed: () {
                  for (final f in friends) {
                    if (_players.length < Validators.maxPlayers &&
                        Validators.name(f.displayName, existing: _players) == null) {
                      _players.add(f.displayName);
                    }
                  }
                  setState(() => _startError = null);
                },
                child: const Text('Add all'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final f in friends)
                ActionChip(
                  avatar: PlayerAvatar(name: f.displayName, radius: 12),
                  label: Text(f.displayName),
                  onPressed: _players.contains(f.displayName) ? null : () => _add(f.displayName),
                ),
            ],
          ),
        ],
        const SizedBox(height: Spacing.md),
        Row(
          children: [
            Expanded(
              child: Text('Players (${_players.length})', style: theme.textTheme.titleMedium),
            ),
            if (_players.length > 1)
              TextButton.icon(
                onPressed: () => setState(() {
                  final shuffled = ref.read(randomProvider).shuffled(_players);
                  _players
                    ..clear()
                    ..addAll(shuffled);
                }),
                icon: const Icon(Icons.shuffle),
                label: const Text('Shuffle order'),
              ),
          ],
        ),
        if (_players.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            child: Text(
              g.playersOptional ? 'No players added. You can still play!' : 'Add players to begin.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        for (var i = 0; i < _players.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              leading: PlayerAvatar(name: _players[i]),
              title: Text(_players[i], style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: IconButton(
                tooltip: 'Remove ${_players[i]}',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _players.removeAt(i)),
              ),
            ),
          ),
        if (_startError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_startError!, style: TextStyle(color: theme.colorScheme.error)),
          ),
        const SizedBox(height: Spacing.md),
        GradientButton(label: 'Start game', icon: Icons.play_arrow, onPressed: _start),
        const SizedBox(height: Spacing.lg),
      ],
    );
  }
}
