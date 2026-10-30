import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../models/meme_template.dart';
import '../theme/app_theme.dart';

/// Blank template image, decoded at thumbnail size so scrolling stays light.
class MemeThumb extends StatelessWidget {
  const MemeThumb({super.key, required this.template, this.cacheWidth = 420});
  final MemeTemplate template;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    Widget broken(BuildContext _, Object e, StackTrace? s) => const ColoredBox(
          color: Color(0x22000000),
          child: Center(child: Icon(Icons.broken_image_outlined)),
        );
    return template.isAsset
        ? Image.asset(template.assetPath,
            fit: BoxFit.cover, cacheWidth: cacheWidth, gaplessPlayback: true, errorBuilder: broken)
        : Image.file(File(template.imageRef),
            fit: BoxFit.cover, cacheWidth: cacheWidth, gaplessPlayback: true, errorBuilder: broken);
  }
}

/// iOS-style rounded card: image, soft bottom gradient, title, favourite heart.
class MemeCard extends ConsumerWidget {
  const MemeCard({super.key, required this.template, required this.onTap, this.onLongPress});
  final MemeTemplate template;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = memeKey(template.id);
    final fav = isFav(ref, key);
    return Semantics(
      button: true,
      label: 'Meme template ${template.title}',
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 14, offset: Offset(0, 6))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MemeThumb(template: template),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 92,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0xCC000000)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(template.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                        if (template.actor.isNotEmpty)
                          Text(template.actor,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: _Badge(template.isUser ? 'MINE' : template.id),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
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
                      icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                          size: 20, color: fav ? AppColors.pink : Colors.white),
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

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10)),
        child: Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
      );
}

/// Width / height of an image file (decoded once when a template is added).
Future<double> imageAspectOf(String path) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final aspect = frame.image.width / frame.image.height;
  frame.image.dispose();
  codec.dispose();
  return aspect;
}
