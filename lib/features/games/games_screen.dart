import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/records.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/poster_widgets.dart';
import 'game_registry.dart';
import 'game_widgets.dart';

class GamesScreen extends ConsumerStatefulWidget {
  const GamesScreen({super.key});
  @override
  ConsumerState<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends ConsumerState<GamesScreen> {
  PlayMode? _mode;
  bool _favOnly = false;

  @override
  Widget build(BuildContext context) {
    final favs = ref.watch(favoritesProvider).value ?? <String>{};
    final history = ref.watch(historyProvider).value ?? const <HistoryEntry>[];
    final recent = recentUnique(history, HistoryKind.game, limit: 6)
        .map((h) => Games.byId(h.refId))
        .whereType<GameInfo>()
        .toList();
    final games = Games.list
        .where((g) => _mode == null || g.modes.contains(_mode))
        .where((g) => !_favOnly || favs.contains(FavoritesNotifier.gameKey(g.id)))
        .toList();
    final past = history.where((h) => h.kind == HistoryKind.game && h.detail.isNotEmpty).take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Games'),
        actions: [
          IconButton(
            tooltip: 'Random game',
            icon: const Icon(Icons.casino_outlined),
            onPressed: () => context.push('/game/${ref.read(randomProvider).pick(Games.list).id}'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Spacing.xl),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
            child: Card(
              child: ListTile(
                leading: const Text('🏆', style: TextStyle(fontSize: 32)),
                title: const Text('Friendship Awards', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: const Text('Hand out funny awards and make award posters'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/awards'),
              ),
            ),
          ),
          if (recent.isNotEmpty) ...[
            const SectionHeader(title: 'Recently played'),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                itemCount: recent.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => GameCard(game: recent[i], width: 140),
              ),
            ),
          ],
          const SectionHeader(title: 'All games'),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
              children: [
                CategoryChip(label: 'All', selected: _mode == null && !_favOnly, onTap: () => setState(() {
                  _mode = null;
                  _favOnly = false;
                })),
                CategoryChip(label: 'Favorites', emoji: '❤️', selected: _favOnly, onTap: () => setState(() => _favOnly = !_favOnly)),
                for (final m in PlayMode.values)
                  CategoryChip(label: m.label, selected: _mode == m, onTap: () => setState(() => _mode = _mode == m ? null : m)),
              ],
            ),
          ),
          if (games.isEmpty)
            const Padding(
              padding: EdgeInsets.all(Spacing.lg),
              child: EmptyState(emoji: '🎮', title: 'No games here', message: 'Try another filter, or favorite a game with the heart.'),
            )
          else
            for (final g in games)
              Padding(
                padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, 10),
                child: GameListTile(game: g),
              ),
          if (past.isNotEmpty) ...[
            const SectionHeader(title: 'Game history'),
            for (final h in past)
              ListTile(
                leading: Text(Games.byId(h.refId)?.emoji ?? '🎮', style: const TextStyle(fontSize: 26)),
                title: Text(h.title),
                subtitle: Text(h.detail),
                trailing: Text(_ago(h.at), style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
        ],
      ),
    );
  }
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}
