import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/utils/validators.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/text_prompt.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final favCount = ref.watch(favoritesProvider).value?.length ?? 0;
    final savedCount = ref.watch(savedPostersProvider).value?.length ?? 0;
    final friendCount = ref.watch(friendsProvider).value?.length ?? 0;
    final historyCount = ref.watch(historyProvider).value?.length ?? 0;
    final myMemes = ref.watch(userMemesProvider).value?.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Spacing.xl),
        children: [
          Card(
            margin: const EdgeInsets.all(Spacing.md),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(s.userName.isEmpty ? 'Set your name' : s.userName,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Used for the greeting on your home screen'),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editName(context, ref),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: Spacing.md),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.favorite_outline),
                  title: const Text('Favorites'),
                  subtitle: Text('$favCount saved'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/favorites'),
                ),
                ListTile(
                  leading: const Icon(Icons.collections_outlined),
                  title: const Text('My posters'),
                  subtitle: Text('$savedCount saved'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/saved'),
                ),
              ],
            ),
          ),
          const SectionHeader(title: 'Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('Auto')),
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Dark')),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => n.setTheme(v.first),
            ),
          ),
          const SectionHeader(title: 'Feedback'),
          SwitchListTile(
            title: const Text('Sound effects'),
            secondary: const Icon(Icons.volume_up_outlined),
            value: s.sound,
            onChanged: n.setSound,
          ),
          SwitchListTile(
            title: const Text('Haptic feedback'),
            secondary: const Icon(Icons.vibration),
            value: s.haptics,
            onChanged: n.setHaptics,
          ),
          const SectionHeader(title: 'Privacy'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Spacing.md),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(Spacing.md),
                child: Text(
                  '• No account or sign-in.\n'
                  '• Friends, photos and posters are stored only on this phone.\n'
                  '• No analytics, ads or tracking. The app works fully offline.\n'
                  '• Photos are only accessed when you pick one, and posters only leave your phone when you share or save them.',
                ),
              ),
            ),
          ),
          const SectionHeader(title: 'Your data'),
          _clearTile(context, ref, Icons.collections_outlined, 'Clear saved posters', '$savedCount posters',
              'Delete all saved posters from this phone? Images already in your gallery stay there.',
              () => ref.read(savedPostersProvider.notifier).clear()),
          _clearTile(context, ref, Icons.people_outline, 'Clear friends list', '$friendCount friends',
              'Remove all saved friends and their photos?', () => ref.read(friendsProvider.notifier).clear()),
          _clearTile(context, ref, Icons.favorite_outline, 'Clear favorites', '$favCount items',
              'Remove all favorite posters and games?', () => ref.read(favoritesProvider.notifier).clear()),
          _clearTile(context, ref, Icons.sentiment_very_satisfied_outlined, 'Clear my meme templates', '$myMemes templates',
              'Delete the meme templates you added yourself?', () => ref.read(userMemesProvider.notifier).clear()),
          _clearTile(context, ref, Icons.history, 'Clear history', '$historyCount entries',
              'Clear recently played and recently used history?', () => ref.read(historyProvider.notifier).clear()),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
            title: Text('Delete everything', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            subtitle: const Text('Friends, photos, posters, favorites, history and settings'),
            onTap: () async {
              final ok = await confirm(context,
                  title: 'Delete everything?',
                  message: 'All data stored by Find Who on this phone will be erased. This cannot be undone.',
                  confirmLabel: 'Delete all');
              if (!ok) return;
              await ref.read(savedPostersProvider.notifier).clear();
              await ref.read(friendsProvider.notifier).clear();
              await ref.read(userMemesProvider.notifier).clear();
              await ref.read(favoritesProvider.notifier).clear();
              await ref.read(historyProvider.notifier).clear();
              await ref.read(fileStoreProvider).clearPhotos();
              await ref.read(settingsProvider.notifier).reset();
              if (context.mounted) showSnack(context, 'Everything was deleted');
            },
          ),
          const SectionHeader(title: 'About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Find Who'),
            subtitle: Text('Version 1.0.0 · Funny posters and friend games'),
          ),
        ],
      ),
    );
  }

  Widget _clearTile(BuildContext context, WidgetRef ref, IconData icon, String title, String sub,
      String message, Future<void> Function() action) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(sub),
      onTap: () async {
        final ok = await confirm(context, title: title, message: message, confirmLabel: 'Clear');
        if (!ok) return;
        await action();
        if (context.mounted) showSnack(context, 'Done');
      },
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final name = await promptText(
      context,
      title: 'Your name',
      initial: ref.read(settingsProvider).userName,
      maxLength: Validators.maxNameLength,
      capitalization: TextCapitalization.words,
      validator: Validators.optionalName,
    );
    if (name != null) ref.read(settingsProvider.notifier).setUserName(name);
  }
}
