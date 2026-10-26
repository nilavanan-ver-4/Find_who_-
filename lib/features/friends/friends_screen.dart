import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/utils/validators.dart';
import '../../models/friend.dart';
import '../../models/poster_doc.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/photo_picker.dart';

class FriendAvatar extends StatelessWidget {
  const FriendAvatar({super.key, required this.friend, this.radius = 24});
  final Friend friend;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final path = friend.photoPath;
    final hue = (friend.displayName.codeUnits.fold<int>(0, (a, b) => a + b) * 37) % 360;
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: HSLColor.fromAHSL(1, hue.toDouble(), 0.6, 0.5).toColor(),
      child: Text(friend.initials,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: radius * 0.8)),
    );
    if (path == null) return fallback;
    return ClipOval(
      child: Image.file(
        File(path),
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        cacheWidth: (radius * 4).round(),
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showFriendEditor(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Add friend'),
      ),
      body: friends.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          message: 'We could not load your friends.',
          onRetry: () => ref.invalidate(friendsProvider),
        ),
        data: (list) => list.isEmpty
            ? EmptyState(
                emoji: '👯',
                title: 'No friends added yet',
                message: 'Save your friends once and reuse them for posters, awards and games. Everything stays on this phone.',
                actionLabel: 'Add your first friend',
                onAction: () => showFriendEditor(context),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(Spacing.md, 0, Spacing.md, 96),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final f = list[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      leading: FriendAvatar(friend: f),
                      title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                        [if (f.nickname.isNotEmpty) '"${f.nickname}"', if (f.notes.isNotEmpty) f.notes].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.more_vert),
                      onTap: () => _actions(context, ref, f),
                    ),
                  );
                },
              ),
      ),
    );
  }

  void _actions(BuildContext context, WidgetRef ref, Friend f) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: FriendAvatar(friend: f),
              title: Text(f.displayName, style: Theme.of(context).textTheme.titleMedium),
              subtitle: f.notes.isEmpty ? null : Text(f.notes),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Make a poster'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/create?name=${Uri.encodeQueryComponent(f.name)}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title: const Text('Give an award'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/awards?name=${Uri.encodeQueryComponent(f.displayName)}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                showFriendEditor(context, friend: f);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove'),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await confirm(context,
                    title: 'Remove ${f.displayName}?', message: 'Their saved details and photo will be deleted from this phone.');
                if (ok) await ref.read(friendsProvider.notifier).remove(f);
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showFriendEditor(BuildContext context, {Friend? friend}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FriendEditor(friend: friend),
  );
}

class _FriendEditor extends ConsumerStatefulWidget {
  const _FriendEditor({this.friend});
  final Friend? friend;
  @override
  ConsumerState<_FriendEditor> createState() => _FriendEditorState();
}

class _FriendEditorState extends ConsumerState<_FriendEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.friend?.name);
  late final _nick = TextEditingController(text: widget.friend?.nickname);
  late final _notes = TextEditingController(text: widget.friend?.notes);
  late String? _photo = widget.friend?.photoPath;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _nick.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final f = (widget.friend ?? Friend(id: PosterDoc.newId(), name: '')).copyWith(
      name: _name.text.trim(),
      nickname: _nick.text.trim(),
      notes: _notes.text.trim(),
      photoPath: _photo,
    );
    final oldPhoto = widget.friend?.photoPath;
    await ref.read(friendsProvider.notifier).save(f);
    if (oldPhoto != null && oldPhoto != _photo) await ref.read(fileStoreProvider).delete(oldPhoto);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final existing = (ref.read(friendsProvider).value ?? const <Friend>[])
        .where((f) => f.id != widget.friend?.id)
        .map((f) => f.name);
    final preview = Friend(id: 'x', name: _name.text.isEmpty ? '?' : _name.text, photoPath: _photo);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.friend == null ? 'Add a friend' : 'Edit friend',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: Spacing.md),
              GestureDetector(
                onTap: () async {
                  final p = await pickPhoto(context, ref);
                  if (p != null) setState(() => _photo = p);
                },
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    FriendAvatar(friend: preview, radius: 44),
                    const CircleAvatar(radius: 14, child: Icon(Icons.camera_alt, size: 16)),
                  ],
                ),
              ),
              if (_photo != null)
                TextButton(onPressed: () => setState(() => _photo = null), child: const Text('Remove photo')),
              const SizedBox(height: Spacing.sm),
              TextFormField(
                controller: _name,
                maxLength: Validators.maxNameLength,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name', counterText: ''),
                validator: (v) => Validators.name(v, existing: existing),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nick,
                maxLength: Validators.maxNameLength,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nickname (optional)', counterText: ''),
                validator: Validators.optionalName,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notes,
                maxLength: Validators.maxNotesLength,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Friendship notes (optional)',
                  hintText: 'Inside jokes, how you met...',
                ),
                validator: Validators.notes,
              ),
              const SizedBox(height: 8),
              Text('Saved only on this phone.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: Spacing.md),
              GradientButton(label: _saving ? 'Saving...' : 'Save', onPressed: _saving ? null : _save),
              const SizedBox(height: Spacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
