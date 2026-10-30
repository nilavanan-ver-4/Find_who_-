import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/content.dart';
import '../../models/poster_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/poster_widgets.dart';
import '../../widgets/memes_banner.dart';

class PostersScreen extends ConsumerStatefulWidget {
  const PostersScreen({super.key, this.initialCategory});
  final String? initialCategory;
  @override
  ConsumerState<PostersScreen> createState() => _PostersScreenState();
}

class _PostersScreenState extends ConsumerState<PostersScreen> {
  final _search = TextEditingController();
  late String _filter = widget.initialCategory ?? 'all'; // all | trending | favorites | <category id>

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<PosterTemplate> _visible(AppContent content, Set<String> favs) {
    final all = content.templates;
    Iterable<PosterTemplate> r = all;
    switch (_filter) {
      case 'all':
        break;
      case 'trending':
        r = r.where((t) => t.trending);
      case 'favorites':
        r = r.where((t) => favs.contains(FavoritesNotifier.posterKey(t.id)));
      default:
        r = r.where((t) => content.inCategory(t.category, _filter));
    }
    final q = _search.text.trim().toLowerCase();
    return r.where((t) {
      if (t.matches(q)) return true;
      final c = content.categoryById(t.category);
      return c != null && c.name.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentProvider);
    final favs = ref.watch(favoritesProvider).value ?? <String>{};
    final items = _visible(content, favs);
    // Selected top-level category (or the parent of a selected sub-category).
    final selected = content.categoryById(_filter);
    final parentId = selected?.parent ?? selected?.id;
    final subs = parentId == null ? const <PosterCategory>[] : content.childrenOf(parentId);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Posters'),
        actions: [
          IconButton(
            tooltip: 'Random poster',
            icon: const Icon(Icons.casino_outlined),
            onPressed: () {
              final t = ref.read(randomProvider).pick(content.templates);
              context.push('/create?template=${t.id}');
            },
          ),
          IconButton(
            tooltip: 'My posters',
            icon: const Icon(Icons.collections_outlined),
            onPressed: () => context.push('/saved'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/create'),
        icon: const Icon(Icons.add),
        label: const Text('Create'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, Spacing.sm),
            child: MemesBanner(count: ref.watch(allMemesProvider).templates.length, compact: true),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, Spacing.sm),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search posters, captions, categories',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
              children: [
                CategoryChip(label: 'All', emoji: '✨', selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                CategoryChip(label: 'Trending', emoji: '🔥', selected: _filter == 'trending', onTap: () => setState(() => _filter = 'trending')),
                CategoryChip(label: 'Favorites', emoji: '❤️', selected: _filter == 'favorites', onTap: () => setState(() => _filter = 'favorites')),
                for (final c in content.topCategories)
                  CategoryChip(
                    label: c.name,
                    emoji: c.emoji,
                    selected: _filter == c.id || selected?.parent == c.id,
                    onTap: () => setState(() => _filter = c.id),
                  ),
              ],
            ),
          ),
          if (subs.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                children: [
                  CategoryChip(
                    label: 'All ${content.categoryById(parentId!)!.name}',
                    selected: _filter == parentId,
                    onTap: () => setState(() => _filter = parentId),
                  ),
                  for (final c in subs)
                    CategoryChip(
                      label: c.name,
                      emoji: c.emoji,
                      selected: _filter == c.id,
                      onTap: () => setState(() => _filter = c.id),
                    ),
                ],
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? EmptyState(
                    emoji: _filter == 'favorites' ? '💔' : '🔍',
                    title: _filter == 'favorites' && _search.text.isEmpty
                        ? 'No favorite posters yet'
                        : 'No posters found',
                    message: _filter == 'favorites'
                        ? 'Tap the heart on a poster to keep it here.'
                        : 'Try a different search or category.',
                    actionLabel: 'Show all posters',
                    onAction: () => setState(() {
                      _filter = 'all';
                      _search.clear();
                    }),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, 96),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 4 / 5,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) => PosterCard(
                      template: items[i],
                      onTap: () => context.push('/create?template=${items[i].id}'),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
