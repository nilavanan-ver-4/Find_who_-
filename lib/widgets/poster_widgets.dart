import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../models/poster_doc.dart';
import '../models/poster_models.dart';
import '../theme/app_theme.dart';
import 'poster_view.dart';

/// A poster template rendered as a card with a favourite toggle.
class PosterCard extends ConsumerWidget {
  const PosterCard({
    super.key,
    required this.template,
    required this.onTap,
    this.width,
    this.showFavorite = true,
  });

  final PosterTemplate template;
  final VoidCallback onTap;
  final double? width;
  final bool showFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = PosterDoc.fromTemplate(
      template,
      inputs: const PosterInputs(nameA: 'Alex', nameB: 'Sam'),
    );
    final key = FavoritesNotifier.posterKey(template.id);
    final fav = isFav(ref, key);
    return Semantics(
      button: true,
      label: 'Poster: ${template.title}',
      child: SizedBox(
        width: width,
        child: GestureDetector(
          onTap: onTap,
          child: RepaintBoundary(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  PosterView(doc: doc, photoCacheWidth: 300),
                  if (showFavorite)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: IconButton(
                        tooltip: fav ? 'Remove from favorites' : 'Add to favorites',
                        onPressed: () {
                          ref.read(feedbackProvider).tap();
                          ref.read(favoritesProvider.notifier).toggle(key);
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black38,
                          minimumSize: const Size(40, 40),
                        ),
                        icon: Icon(
                          fav ? Icons.favorite : Icons.favorite_border,
                          color: fav ? AppColors.pink : Colors.white,
                          size: 20,
                        ),
                      ),
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

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.emoji,
  });
  final String label;
  final String? emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => onTap(),
        label: Text(emoji == null ? label : '$emoji $label'),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        showCheckmark: false,
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}
