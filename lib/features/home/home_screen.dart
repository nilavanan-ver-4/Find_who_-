import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/poster_models.dart';
import '../../models/records.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/poster_widgets.dart';
import '../games/game_registry.dart';
import '../games/game_widgets.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider);
    final settings = ref.watch(settingsProvider);
    final favs = ref.watch(favoritesProvider).value ?? <String>{};
    final history = ref.watch(historyProvider).value ?? const <HistoryEntry>[];
    final saved = ref.watch(savedPostersProvider).value ?? const [];

    final trending = content.templates.where((t) => t.trending).toList();
    final recentTemplates = recentUnique(history, HistoryKind.template, limit: 8)
        .map((h) => content.templateById(h.refId))
        .whereType<PosterTemplate>()
        .toList();
    final favPosters =
        content.templates.where((t) => favs.contains(FavoritesNotifier.posterKey(t.id))).take(10).toList();
    final popular = Games.list.where((g) => g.popular).toList();
    final recentGames = recentUnique(history, HistoryKind.game, limit: 6)
        .map((h) => Games.byId(h.refId))
        .whereType<GameInfo>()
        .toList();

    void randomFun() {
      final r = ref.read(randomProvider);
      switch (r.nextInt(3)) {
        case 0:
          context.push('/create?template=${r.pick(content.templates).id}');
        case 1:
          context.push('/game/${r.pick(Games.list).id}');
        default:
          context.push('/game/${r.pick([Games.truthDare, Games.randomChallenge, Games.punishment, Games.spinWheel]).id}');
      }
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  Spacing.md, MediaQuery.paddingOf(context).top + Spacing.md, Spacing.md, Spacing.lg),
              decoration: const BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings.userName.isEmpty ? 'Hey there! 👋' : 'Hey ${settings.userName}! 👋',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text('Ready to make your friends laugh?',
                      style: TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: Spacing.md),
                  Row(
                    children: [
                      _QuickAction(Icons.add_photo_alternate, 'Create\nPoster', () => context.push('/create')),
                      _QuickAction(Icons.sports_esports, 'Play with\nFriends', () => context.go('/games')),
                      _QuickAction(Icons.casino, 'Random\nFun', randomFun),
                      _QuickAction(Icons.share, 'Share\nthe app', () async {
                        try {
                          await ref.read(shareServiceProvider).shareText(
                              'Make funny posters and play friend games with Find Who! 😂');
                        } catch (_) {
                          if (context.mounted) showSnack(context, 'Sharing is not available right now.');
                        }
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _section(context, 'Trending posters', 'See all', () => context.go('/posters'))),
          SliverToBoxAdapter(child: _posterRow(context, trending)),
          SliverToBoxAdapter(child: _section(context, 'Popular games', 'All games', () => context.go('/games'))),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                itemCount: popular.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => GameCard(game: popular[i]),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SectionHeader(title: 'Recently used templates')),
          SliverToBoxAdapter(
            child: recentTemplates.isEmpty
                ? const _HintCard('Posters you create will show up here.')
                : _posterRow(context, recentTemplates),
          ),
          const SliverToBoxAdapter(child: SectionHeader(title: 'Favorite posters')),
          SliverToBoxAdapter(
            child: favPosters.isEmpty
                ? const _HintCard('Tap the ❤ on a poster to save it here.')
                : _posterRow(context, favPosters),
          ),
          if (saved.isNotEmpty) ...[
            SliverToBoxAdapter(child: _section(context, 'Your recent designs', 'View all', () => context.push('/saved'))),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                  itemCount: saved.take(8).length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => AspectRatio(
                    aspectRatio: 0.8,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: GestureDetector(
                        onTap: () => context.push('/saved'),
                        child: Image.file(
                          File(saved[i].imagePath),
                          fit: BoxFit.cover,
                          cacheWidth: 300,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Colors.black12,
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SectionHeader(title: 'Recently played')),
          SliverToBoxAdapter(
            child: recentGames.isEmpty
                ? const _HintCard('Games you play will show up here.')
                : SizedBox(
                    height: 110,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                      itemCount: recentGames.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (_, i) => GameCard(game: recentGames[i], width: 140),
                    ),
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: Spacing.xl)),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, String action, VoidCallback onAction) =>
      SectionHeader(title: title, action: action, onAction: onAction);

  Widget _posterRow(BuildContext context, List<PosterTemplate> items) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => PosterCard(
          template: items[i],
          width: 160,
          onTap: () => context.push('/create?template=${items[i].id}'),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: label.replaceAll('\n', ' '),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(18)),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 6),
                Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        child: Card(child: Padding(padding: const EdgeInsets.all(Spacing.md), child: Text(text))),
      );
}
