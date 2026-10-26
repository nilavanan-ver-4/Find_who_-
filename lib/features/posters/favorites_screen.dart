import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/poster_widgets.dart';
import '../games/game_registry.dart';
import '../games/game_widgets.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider);
    final favs = ref.watch(favoritesProvider).value ?? <String>{};
    final posters = content.templates
        .where((t) => favs.contains(FavoritesNotifier.posterKey(t.id)))
        .toList();
    final games = Games.list.where((g) => favs.contains(FavoritesNotifier.gameKey(g.id))).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: posters.isEmpty && games.isEmpty
          ? const EmptyState(
              emoji: '💔',
              title: 'Nothing here yet',
              message: 'Tap the heart on any poster or game to keep it close.',
            )
          : ListView(
              padding: const EdgeInsets.all(Spacing.md),
              children: [
                if (posters.isNotEmpty) ...[
                  Text('Posters', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 4 / 5,
                    ),
                    itemCount: posters.length,
                    itemBuilder: (_, i) => PosterCard(
                      template: posters[i],
                      onTap: () => context.push('/create?template=${posters[i].id}'),
                    ),
                  ),
                ],
                if (games.isNotEmpty) ...[
                  const SizedBox(height: Spacing.lg),
                  Text('Games', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  for (final g in games)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GameListTile(game: g),
                    ),
                ],
              ],
            ),
    );
  }
}
