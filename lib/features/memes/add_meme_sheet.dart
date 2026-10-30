import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/utils/validators.dart';
import '../../models/meme_template.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/meme_widgets.dart';
import '../../widgets/photo_picker.dart';

Future<void> showAddMemeSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const AddMemeSheet(),
    );

/// Lets people add their own blank template (an image from the gallery)
/// without touching the app's source code.
class AddMemeSheet extends ConsumerStatefulWidget {
  const AddMemeSheet({super.key});
  @override
  ConsumerState<AddMemeSheet> createState() => _AddMemeSheetState();
}

class _AddMemeSheetState extends ConsumerState<AddMemeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _actor = TextEditingController();
  final _caption = TextEditingController();
  String? _path;
  double _aspect = 1;
  String _category = 'relatable';
  bool _rights = false;
  bool _saving = false;
  String? _imageError;

  @override
  void dispose() {
    _title.dispose();
    _actor.dispose();
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final path = await pickPhoto(context, ref);
    if (path == null || !mounted) return;
    try {
      final aspect = await imageAspectOf(path);
      if (!mounted) return;
      setState(() {
        _path = path;
        _aspect = aspect.clamp(0.3, 3.0).toDouble();
        _imageError = null;
      });
    } catch (_) {
      await ref.read(fileStoreProvider).delete(path);
      if (mounted) setState(() => _imageError = 'That file is not a readable image. Try another one.');
    }
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (_path == null) setState(() => _imageError = 'Choose an image first');
    if (!valid || _path == null) return;
    if (!_rights) {
      showSnack(context, 'Please confirm you have the right to use this image');
      return;
    }
    setState(() => _saving = true);
    final caption = _caption.text.trim();
    final t = MemeTemplate(
      id: 'UM${DateTime.now().microsecondsSinceEpoch}',
      title: _title.text.trim(),
      category: _category,
      imageRef: _path!,
      actor: _actor.text.trim(),
      source: 'My own template',
      aspect: _aspect,
      captions: [if (caption.isNotEmpty) caption],
      layers: [
        const MemeLayer(role: 'top', text: ''),
        MemeLayer(role: 'bottom', text: caption),
      ],
      license: 'Added by the user, who confirmed they have the right to use the image.',
      isUser: true,
      pack: 'mine',
    );
    await ref.read(userMemesProvider.notifier).add(t);
    if (mounted) {
      Navigator.pop(context);
      showSnack(context, 'Template added');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(memeCatalogProvider).categories;
    final preview = _path == null
        ? null
        : MemeTemplate(id: 'x', title: '', category: _category, imageRef: _path!, aspect: _aspect);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add your own template', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              const Text('Pick a blank image. It stays on this phone and works offline.'),
              const SizedBox(height: Spacing.md),
              GestureDetector(
                onTap: _pick,
                child: Container(
                  height: 170,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: preview == null
                      ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add_photo_alternate_outlined, size: 40), SizedBox(height: 6), Text('Choose image')]))
                      : Center(child: AspectRatio(aspectRatio: _aspect, child: MemeThumb(template: preview, cacheWidth: 700))),
                ),
              ),
              if (_imageError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_imageError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              const SizedBox(height: Spacing.md),
              TextFormField(
                controller: _title,
                maxLength: 40,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Template name', counterText: ''),
                validator: (v) => (v ?? '').trim().isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [for (final c in cats) DropdownMenuItem(value: c.id, child: Text('${c.emoji} ${c.name}'))],
                onChanged: (v) => setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _actor,
                maxLength: Validators.maxNameLength,
                decoration: const InputDecoration(labelText: 'Comedian / actor (optional)', counterText: ''),
                validator: Validators.optionalName,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _caption,
                maxLength: Validators.maxCaptionLength,
                decoration: const InputDecoration(labelText: 'Suggested caption (optional)', counterText: ''),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _rights,
                onChanged: (v) => setState(() => _rights = v ?? false),
                title: const Text('I own this image or have permission to use it.'),
              ),
              const SizedBox(height: 8),
              GradientButton(label: _saving ? 'Saving...' : 'Add template', onPressed: _saving ? null : _save),
              const SizedBox(height: Spacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
