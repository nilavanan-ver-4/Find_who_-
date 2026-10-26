import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/utils/validators.dart';
import '../../models/poster_doc.dart';
import '../../models/poster_models.dart';
import '../../models/records.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/photo_picker.dart';
import '../../widgets/poster_view.dart';
import '../../widgets/poster_widgets.dart';
import '../games/games_common.dart';
import 'editor_screen.dart';

/// Step between picking a template and editing: names, nicknames, layout, photo.
class PersonalizeScreen extends ConsumerStatefulWidget {
  const PersonalizeScreen({super.key, this.templateId, this.friendName});
  final String? templateId;
  final String? friendName;
  @override
  ConsumerState<PersonalizeScreen> createState() => _PersonalizeScreenState();
}

class _PersonalizeScreenState extends ConsumerState<PersonalizeScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _a = TextEditingController(text: widget.friendName ?? '');
  final _nick = TextEditingController();
  final _b = TextEditingController();
  PosterTemplate? _template;
  PosterLayout _layout = PosterLayout.portrait;
  String? _photo;

  @override
  void initState() {
    super.initState();
    final content = ref.read(contentProvider);
    _template = (widget.templateId == null ? null : content.templateById(widget.templateId!)) ??
        ref.read(randomProvider).pick(content.templates);
    for (final c in [_a, _nick, _b]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _a.dispose();
    _nick.dispose();
    _b.dispose();
    super.dispose();
  }

  PosterInputs get _inputs =>
      PosterInputs(nameA: _a.text, nicknameA: _nick.text, nameB: _b.text);

  PosterDoc get _doc => PosterDoc.fromTemplate(_template!,
      inputs: _inputs, layout: _layout, photoPath: _photo);

  Future<void> _addPhoto() async {
    final path = await pickPhoto(context, ref);
    if (path != null && mounted) setState(() => _photo = path);
  }

  void _generate() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref.read(feedbackProvider).success();
    ref.read(historyProvider.notifier).record(HistoryKind.template, _template!.id, _template!.title);
    context.pushReplacement('/editor', extra: EditorArgs(doc: _doc, title: _template!.title));
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentProvider);
    final friends = ref.watch(friendsProvider).value ?? const [];
    final t = _template!;
    return Scaffold(
      appBar: AppBar(title: const Text('Create poster')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Spacing.md),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: RepaintBoundary(child: PosterView(doc: _doc, photoCacheWidth: 600)),
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
            Text('Template: ${t.title.replaceAll('{a}', 'Friend').replaceAll('{b}', 'Bestie')}',
                style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: Spacing.sm),
            SizedBox(
              height: 138,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: content.templates.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final x = content.templates[i];
                  final selected = x.id == t.id;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: selected ? AppColors.pink : Colors.transparent, width: 3),
                    ),
                    child: SizedBox(
                      width: 96,
                      child: PosterCard(
                        template: x,
                        showFavorite: false,
                        onTap: () => setState(() => _template = x),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: Spacing.md),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _a,
                    maxLength: Validators.maxNameLength,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: "Friend's name", counterText: ''),
                    validator: Validators.name,
                  ),
                  if (friends.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final f in friends)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ActionChip(
                                  avatar: PlayerAvatar(name: f.displayName, radius: 11),
                                  label: Text(f.displayName),
                                  onPressed: () => setState(() {
                                    _a.text = f.name;
                                    _nick.text = f.nickname;
                                  }),
                                ),
                              ),
                          ],
                        ),
                      ),
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
                    controller: _b,
                    maxLength: Validators.maxNameLength,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: t.usesSecondName ? "Second friend's name" : "Second friend's name (optional)",
                      counterText: '',
                    ),
                    validator: Validators.optionalName,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.md),
            Text('Format', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<PosterLayout>(
              segments: [
                for (final l in PosterLayout.values)
                  ButtonSegment(value: l, label: Text('${l.label}\n${l.ratioLabel}', textAlign: TextAlign.center)),
              ],
              selected: {_layout},
              onSelectionChanged: (s) => setState(() => _layout = s.first),
            ),
            const SizedBox(height: Spacing.md),
            Row(
              children: [
                if (_photo != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(_photo!), width: 56, height: 56, fit: BoxFit.cover, cacheWidth: 160,
                          errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined)),
                    ),
                  ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addPhoto,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(_photo == null ? 'Add a photo (optional)' : 'Change photo'),
                  ),
                ),
                if (_photo != null)
                  IconButton(
                    tooltip: 'Remove photo',
                    onPressed: () => setState(() => _photo = null),
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            GradientButton(label: 'Generate poster', icon: Icons.auto_awesome, onPressed: _generate),
            const SizedBox(height: Spacing.lg),
          ],
        ),
      ),
    );
  }
}
