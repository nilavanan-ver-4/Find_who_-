import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/records.dart';
import '../../services/share_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'editor_screen.dart';

class SavedPostersScreen extends ConsumerWidget {
  const SavedPostersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedPostersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My posters')),
      body: saved.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: 'We could not load your posters.',
          onRetry: () => ref.invalidate(savedPostersProvider),
        ),
        data: (list) => list.isEmpty
            ? EmptyState(
                emoji: '🖼️',
                title: 'No saved posters yet',
                message: 'Posters you save or share show up here, ready to edit again.',
                actionLabel: 'Create a poster',
                onAction: () => context.push('/create'),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(Spacing.md),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) => SavedPosterTile(poster: list[i]),
              ),
      ),
    );
  }
}

class SavedPosterTile extends ConsumerWidget {
  const SavedPosterTile({super.key, required this.poster});
  final SavedPoster poster;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _SavedPosterSheet(poster: poster),
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(poster.imagePath),
              fit: BoxFit.cover,
              cacheWidth: 400,
              errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined, size: 40)),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                color: Colors.black54,
                child: Text(poster.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedPosterSheet extends ConsumerWidget {
  const _SavedPosterSheet({required this.poster});
  final SavedPoster poster;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = File(poster.imagePath);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, Spacing.md),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(file, cacheWidth: 900,
                      errorBuilder: (_, _, _) => const Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('This image file is missing.'),
                          )),
                ),
              ),
              const SizedBox(height: Spacing.md),
              Row(
                children: [
                  Expanded(
                    child: GradientButton(
                      label: 'Share',
                      icon: Icons.share,
                      onPressed: () async {
                        if (!await file.exists()) {
                          if (context.mounted) showSnack(context, 'The image file is missing.');
                          return;
                        }
                        try {
                          await ref.read(shareServiceProvider).shareImage(poster.imagePath, text: 'Made with Find Who 😂');
                        } catch (_) {
                          if (context.mounted) showSnack(context, 'Sharing is not available right now.');
                        }
                      },
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
                        try {
                          final bytes = await file.readAsBytes();
                          final r = await ref.read(shareServiceProvider).saveToGallery(bytes, 'findwho_${poster.id}');
                          if (context.mounted) {
                            showSnack(context, r == GalleryResult.saved
                                ? 'Saved to your gallery'
                                : r == GalleryResult.denied
                                    ? 'Gallery access denied. Allow it in system settings.'
                                    : 'Could not save to the gallery.');
                          }
                        } catch (_) {
                          if (context.mounted) showSnack(context, 'The image file is missing.');
                        }
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Gallery'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        context.push('/editor', extra: EditorArgs(doc: poster.doc, title: poster.title));
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final ok = await confirm(context,
                            title: 'Delete poster?', message: 'This removes it from this device.');
                        if (!ok) return;
                        await ref.read(savedPostersProvider.notifier).remove(poster);
                        if (context.mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
