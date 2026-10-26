import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/utils/validators.dart';
import '../../models/content.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../games/games_common.dart';
import '../posters/editor_screen.dart';
import 'award_poster.dart';

class AwardsScreen extends ConsumerStatefulWidget {
  const AwardsScreen({super.key, this.initialName});
  final String? initialName;
  @override
  ConsumerState<AwardsScreen> createState() => _AwardsScreenState();
}

class _AwardsScreenState extends ConsumerState<AwardsScreen> {
  final _input = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final List<String> _names = [];
  final Map<String, AwardItem> _assigned = {};

  @override
  void initState() {
    super.initState();
    final n = widget.initialName;
    if (n != null && Validators.name(n) == null) {
      _names.add(n.trim());
      _assign(n.trim());
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _assign(String name) {
    final awards = ref.read(contentProvider).awards;
    final used = _assigned.values.toSet();
    final fresh = awards.where((a) => !used.contains(a)).toList();
    _assigned[name] = ref.read(randomProvider).pick(fresh.isEmpty ? awards : fresh);
  }

  void _addName(String raw) {
    final err = Validators.name(raw, existing: _names);
    if (err != null) {
      showSnack(context, err);
      return;
    }
    if (_names.length >= Validators.maxPlayers) {
      showSnack(context, 'Maximum ${Validators.maxPlayers} people');
      return;
    }
    setState(() {
      _names.add(raw.trim());
      _assign(raw.trim());
    });
  }

  void _shuffleAll() {
    final awards = ref.read(randomProvider).shuffled(ref.read(contentProvider).awards);
    setState(() {
      for (var i = 0; i < _names.length; i++) {
        _assigned[_names[i]] = awards[i % awards.length];
      }
    });
    ref.read(feedbackProvider).success();
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider).value ?? const [];
    final awards = ref.watch(contentProvider).awards;
    return Scaffold(
      appBar: AppBar(title: const Text('Friendship Awards')),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.md),
        children: [
          const Text('Add the people who deserve an award, then shuffle or choose awards yourself.'),
          const SizedBox(height: Spacing.md),
          Form(
            key: _formKey,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _input,
                    maxLength: Validators.maxNameLength,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(hintText: 'Type a name', counterText: ''),
                    validator: (v) => Validators.name(v, existing: _names),
                    onFieldSubmitted: (_) {
                      if (_formKey.currentState!.validate()) {
                        _addName(_input.text);
                        _input.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _addName(_input.text);
                        _input.clear();
                      }
                    },
                    child: const Icon(Icons.add),
                  ),
                ),
              ],
            ),
          ),
          if (friends.isNotEmpty)
            Wrap(
              spacing: 8,
              children: [
                for (final f in friends)
                  ActionChip(
                    avatar: PlayerAvatar(name: f.displayName, radius: 12),
                    label: Text(f.displayName),
                    onPressed: _names.contains(f.displayName) ? null : () => _addName(f.displayName),
                  ),
              ],
            ),
          const SizedBox(height: Spacing.md),
          if (_names.isEmpty)
            const EmptyState(emoji: '🏆', title: 'Nobody yet', message: 'Add a name above to start handing out awards.')
          else ...[
            GradientButton(label: 'Shuffle all awards', icon: Icons.shuffle, onPressed: _shuffleAll),
            const SizedBox(height: Spacing.md),
            for (final n in List.of(_names))
              _AwardCard(
                name: n,
                award: _assigned[n]!,
                awards: awards,
                onChange: (a) => setState(() => _assigned[n] = a),
                onRemove: () => setState(() {
                  _names.remove(n);
                  _assigned.remove(n);
                }),
              ),
          ],
        ],
      ),
    );
  }
}

class _AwardCard extends StatelessWidget {
  const _AwardCard({
    required this.name,
    required this.award,
    required this.awards,
    required this.onChange,
    required this.onRemove,
  });
  final String name;
  final AwardItem award;
  final List<AwardItem> awards;
  final void Function(AwardItem) onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PlayerAvatar(name: name),
                const SizedBox(width: 10),
                Expanded(child: Text(name, style: Theme.of(context).textTheme.titleMedium)),
                IconButton(tooltip: 'Remove $name', onPressed: onRemove, icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(award.emoji, style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(award.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                      Text(award.blurb),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showModalBottomSheet<AwardItem>(
                        context: context,
                        showDragHandle: true,
                        isScrollControlled: true,
                        builder: (ctx) => DraggableScrollableSheet(
                          expand: false,
                          initialChildSize: 0.7,
                          builder: (_, sc) => ListView(
                            controller: sc,
                            children: [
                              for (final a in awards)
                                ListTile(
                                  leading: Text(a.emoji, style: const TextStyle(fontSize: 28)),
                                  title: Text(a.title),
                                  subtitle: Text(a.blurb),
                                  selected: a == award,
                                  onTap: () => Navigator.pop(ctx, a),
                                ),
                            ],
                          ),
                        ),
                      );
                      if (picked != null) onChange(picked);
                    },
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Change'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => context.push(
                      '/editor',
                      extra: EditorArgs(doc: buildAwardPoster(award, name), title: '${award.title} – $name'),
                    ),
                    icon: const Icon(Icons.image),
                    label: const Text('Poster'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
