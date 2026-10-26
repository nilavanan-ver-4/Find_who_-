import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import 'game_registry.dart';

/// Compact square-ish card used in horizontal lists.
class GameCard extends ConsumerWidget {
  const GameCard({super.key, required this.game, this.width = 160});
  final GameInfo game;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: 'Game: ${game.title}',
      child: GestureDetector(
        onTap: () {
          ref.read(feedbackProvider).tap();
          context.push('/game/${game.id}');
        },
        child: Container(
          width: width,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: game.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(game.emoji, style: const TextStyle(fontSize: 38)),
              Text(
                game.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wide list tile with description and play modes.
class GameListTile extends ConsumerWidget {
  const GameListTile({super.key, required this.game});
  final GameInfo game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fav = isFav(ref, FavoritesNotifier.gameKey(game.id));
    return Semantics(
      button: true,
      label: 'Game: ${game.title}',
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: game.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(22),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              ref.read(feedbackProvider).tap();
              context.push('/game/${game.id}');
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Text(game.emoji, style: const TextStyle(fontSize: 40)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(game.title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                        const SizedBox(height: 2),
                        Text(game.description, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text(
                          game.modes.map((m) => m.label).join(' · ') +
                              (game.minPlayers > 1 ? ' · ${game.minPlayers}+ players' : ''),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: fav ? 'Remove from favorites' : 'Add to favorites',
                    onPressed: () => ref.read(favoritesProvider.notifier).toggle(FavoritesNotifier.gameKey(game.id)),
                    icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
