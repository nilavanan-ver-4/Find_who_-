import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/meme_template.dart';
import '../../models/records.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/meme_widgets.dart';
import '../../widgets/poster_widgets.dart';
import 'add_meme_sheet.dart';

/// Tamil Memes: searchable grid of blank templates with category filters,
/// favourites and recently used templates.
class MemesScreen extends ConsumerStatefulWidget {
  const MemesScreen({super.key});
  @override
  ConsumerState<MemesScreen> createState() => _MemesScreenState();
}

class _MemesScreenState extends ConsumerState<MemesScreen> {
  static const filterAll = 'all';
  static const filterFavorites = 'favorites';
  static const filterRecent = 'recent';
  static const filterMine = 'mine';

  final _search = TextEditingController();
  String _filter = filterAll;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<MemeTemplate> _visible(MemeCatalog catalog, Set<String> favs, List<HistoryEntry> history) {
    Iterable<MemeTemplate> r = catalog.templates;
    switch (_filter) {
      case filterAll:
        break;
      case filterFavorites:
        r = r.where((t) => favs.contains(memeKey(t.id)));
      case filterRecent:
        final order = recentUnique(history, HistoryKind.meme, limit: 30).map((h) => h.refId).toList();
        r = order.map(catalog.byId).whereType<MemeTemplate>();
      case filterMine:
        r = r.where((t) => t.isUser);
      default:
        r = r.where((t) => t.category == _filter);
    }
    return r
        .where((t) => t.matches(_search.text, categoryName: catalog.categoryById(t.category)?.name ?? ''))
        .toList();
  }

  void _open(MemeTemplate t) {
    ref.read(feedbackProvider).tap();
    context.push('/meme/${Uri.encodeComponent(t.id)}');
  }

  void _info(MemeTemplate t, MemeCatalog catalog) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _MemeInfoSheet(
        template: t,
        categoryName: catalog.categoryById(t.category)?.name ?? t.category,
        onUse: () {
          Navigator.pop(ctx);
          _open(t);
        },
        onDelete: !t.isUser
            ? null
            : () async {
                final ok = await confirm(ctx,
                    title: 'Delete "${t.title}"?', message: 'This removes your template from this phone.');
                if (!ok) return;
                await ref.read(userMemesProvider.notifier).remove(t);
                if (ctx.mounted) Navigator.pop(ctx);
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(allMemesProvider);
    final favs = ref.watch(favoritesProvider).value ?? <String>{};
    final history = ref.watch(historyProvider).value ?? const <HistoryEntry>[];
    final items = _visible(catalog, favs, history);
    final showRecents = _filter == filterAll && _search.text.trim().isEmpty;
    final recents = recentUnique(history, HistoryKind.meme, limit: 10)
        .map((h) => catalog.byId(h.refId))
        .whereType<MemeTemplate>()
        .toList();
    final hasMine = catalog.templates.any((t) => t.isUser);
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddMemeSheet(context),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Add template'),
      ),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, Spacing.md, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: () => context.pop(),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, Spacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tamil Memes',
                        style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                    const SizedBox(height: 2),
                    Text('${catalog.templates.length} blank templates · Tamil & Tanglish captions',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, Spacing.sm),
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search actor, caption, category, ID',
                    prefixIcon: const Icon(Icons.search_rounded),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.cancel_rounded),
                            onPressed: () => setState(_search.clear),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                  children: [
                    CategoryChip(label: 'All', emoji: '✨', selected: _filter == filterAll, onTap: () => setState(() => _filter = filterAll)),
                    CategoryChip(label: 'Favorites', emoji: '❤️', selected: _filter == filterFavorites, onTap: () => setState(() => _filter = filterFavorites)),
                    CategoryChip(label: 'Recent', emoji: '🕘', selected: _filter == filterRecent, onTap: () => setState(() => _filter = filterRecent)),
                    if (hasMine)
                      CategoryChip(label: 'Mine', emoji: '🖼️', selected: _filter == filterMine, onTap: () => setState(() => _filter = filterMine)),
                    for (final c in catalog.categories)
                      CategoryChip(label: c.name, emoji: c.emoji, selected: _filter == c.id, onTap: () => setState(() => _filter = c.id)),
                  ],
                ),
              ),
            ),
            if (showRecents && recents.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SectionHeader(title: 'Recently used')),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                    itemCount: recents.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => AspectRatio(
                      aspectRatio: 1,
                      child: MemeCard(template: recents[i], onTap: () => _open(recents[i]), onLongPress: () => _info(recents[i], catalog)),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SectionHeader(title: 'All templates')),
            ],
            if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  emoji: _filter == filterFavorites ? '💔' : _filter == filterRecent ? '🕘' : '🔍',
                  title: switch (_filter) {
                    filterFavorites => 'No favorite templates yet',
                    filterRecent => 'Nothing used recently',
                    _ => 'No templates found',
                  },
                  message: switch (_filter) {
                    filterFavorites => 'Tap the heart on a template to keep it here.',
                    filterRecent => 'Templates you open will show up here.',
                    _ => 'Try a different search or category.',
                  },
                  actionLabel: 'Show all templates',
                  onAction: () => setState(() {
                    _filter = filterAll;
                    _search.clear();
                  }),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, 110),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) => MemeCard(
                    template: items[i],
                    onTap: () => _open(items[i]),
                    onLongPress: () => _info(items[i], catalog),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MemeInfoSheet extends StatelessWidget {
  const _MemeInfoSheet({required this.template, required this.categoryName, required this.onUse, this.onDelete});
  final MemeTemplate template;
  final String categoryName;
  final VoidCallback onUse;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final t = template;
    final text = Theme.of(context).textTheme;
    Widget row(String k, String v) => v.trim().isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 110, child: Text(k, style: text.labelLarge)),
                Expanded(child: Text(v)),
              ],
            ),
          );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240, maxHeight: 240),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(aspectRatio: t.aspect, child: MemeThumb(template: t, cacheWidth: 700)),
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
            Text(t.title, style: text.titleLarge),
            const SizedBox(height: 8),
            row('ID', t.id),
            row('Comedian / actor', t.actor),
            row('Source', t.source),
            row('Category', categoryName),
            row('Suggested', t.captions.isEmpty ? '' : t.captions.first),
            row('Image licence', t.license),
            row('Reference', t.referenceNote),
            const SizedBox(height: Spacing.md),
            GradientButton(label: 'Use this template', icon: Icons.edit, onPressed: onUse),
            if (onDelete != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                  onPressed: onDelete, icon: const Icon(Icons.delete_outline), label: const Text('Delete my template')),
            ],
          ],
        ),
      ),
    );
  }
}
