import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/utils/validators.dart';
import '../../models/poster_doc.dart';
import '../../models/poster_models.dart';
import '../../models/content.dart';
import '../../models/records.dart';
import '../../services/poster_exporter.dart';
import '../../services/share_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/photo_picker.dart';
import '../../widgets/text_prompt.dart';
import '../../widgets/poster_view.dart';
import 'editor_controller.dart';

export 'editor_controller.dart' show EditorArgs;

enum _Tool { text, stickers, photo, background, border, format }

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, required this.args});
  final EditorArgs args;
  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late final EditorController _c = EditorController(widget.args.doc);
  final _boundaryKey = GlobalKey();
  final _posterKey = GlobalKey();
  final _textController = TextEditingController();
  _Tool _tool = _Tool.text;
  bool _busy = false;
  late final String _savedId = PosterDoc.newId();
  PosterDoc? _lastSavedDoc;
  String? _savedPath;

  @override
  void initState() {
    super.initState();
    _c.addListener(_syncTextField);
  }

  void _syncTextField() {
    final e = _c.selected;
    final text = e != null && e.kind == ElementKind.text ? e.text : '';
    if (_textController.text != text) {
      _textController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _textController.dispose();
    super.dispose();
  }

  // --- export -------------------------------------------------------------
  Future<Uint8List?> _render() async {
    try {
      _c.select(null);
      await WidgetsBinding.instance.endOfFrame;
      return await PosterExporter.capturePng(_boundaryKey, targetWidth: _c.doc.layout.exportSize.width);
    } on ExportException catch (e) {
      if (mounted) showSnack(context, e.message);
    } catch (_) {
      if (mounted) showSnack(context, 'Could not create the image. Please try again.');
    }
    return null;
  }

  Future<SavedPoster?> _ensureSaved(Uint8List png) async {
    try {
      final path = await ref.read(fileStoreProvider).savePoster(_savedId, png);
      final p = SavedPoster(
        id: _savedId,
        title: widget.args.title.replaceAll(RegExp(r'[{}]'), ''),
        imagePath: path,
        doc: _c.doc,
        createdAt: DateTime.now(),
      );
      await ref.read(savedPostersProvider.notifier).add(p);
      _lastSavedDoc = _c.doc;
      _savedPath = path;
      return p;
    } catch (_) {
      if (mounted) showSnack(context, 'Could not save the poster. Is your storage full?');
      return null;
    }
  }

  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(() async {
        final png = await _render();
        if (png == null) return;
        final saved = await _ensureSaved(png);
        if (saved != null && mounted) {
          ref.read(feedbackProvider).success();
          showSnack(context, 'Saved to My Posters');
        }
      });

  Future<void> _gallery() => _run(() async {
        final png = await _render();
        if (png == null) return;
        await _ensureSaved(png);
        final r = await ref.read(shareServiceProvider).saveToGallery(png, 'findwho_$_savedId');
        if (!mounted) return;
        showSnack(
          context,
          switch (r) {
            GalleryResult.saved => 'Saved to your gallery (Find Who album)',
            GalleryResult.denied => 'Gallery access denied. Allow it in system settings and try again.',
            GalleryResult.noSpace => 'Not enough storage space to save the image.',
            GalleryResult.failed => 'Could not save to the gallery. Please try again.',
          },
        );
      });

  Future<void> _share() => _run(() async {
        final png = await _render();
        if (png == null) return;
        final path = identical(_lastSavedDoc, _c.doc) && _savedPath != null
            ? _savedPath!
            : (await _ensureSaved(png))?.imagePath;
        if (path == null) return;
        try {
          await ref.read(shareServiceProvider).shareImage(path, text: 'Made with Find Who 😂');
        } catch (_) {
          if (mounted) showSnack(context, 'Sharing is not available right now.');
        }
      });

  // --- UI -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final content = ref.watch(contentProvider);
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final tid = _c.doc.templateId;
        final favKey = tid == null ? null : FavoritesNotifier.posterKey(tid);
        final fav = favKey != null && isFav(ref, favKey);
        return PopScope(
          canPop: !_c.isModified || _savedPathMatches,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final leave = await confirm(context,
                title: 'Discard changes?',
                message: 'You have unsaved edits to this poster.',
                confirmLabel: 'Discard');
            if (leave && context.mounted) Navigator.of(context).pop();
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Edit poster'),
              actions: [
                IconButton(
                  tooltip: 'Undo',
                  onPressed: _c.canUndo ? _c.undo : null,
                  icon: const Icon(Icons.undo),
                ),
                IconButton(
                  tooltip: 'Reset to original',
                  onPressed: _c.canUndo ? _c.reset : null,
                  icon: const Icon(Icons.restart_alt),
                ),
                if (favKey != null)
                  IconButton(
                    tooltip: fav ? 'Remove template from favorites' : 'Favorite this template',
                    onPressed: () => ref.read(favoritesProvider.notifier).toggle(favKey),
                    icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                        color: fav ? AppColors.pink : null),
                  ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  Expanded(child: _posterArea()),
                  _toolBar(),
                  SizedBox(
                    height: (_tool == _Tool.text || _tool == _Tool.photo) ? 236 : 190,
                    child: _panel(content),
                  ),
                  _actionBar(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool get _savedPathMatches => identical(_lastSavedDoc, _c.doc);

  Widget _posterArea() {
    return Padding(
      padding: const EdgeInsets.all(Spacing.sm),
      child: LayoutBuilder(
        builder: (context, box) {
          final aspect = _c.doc.layout.aspect;
          final w = min(box.maxWidth, box.maxHeight * aspect);
          final h = w / aspect;
          return Center(
            child: SizedBox(
              width: w,
              height: h,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 16, offset: Offset(0, 6))],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: DragTarget<String>(
                  onAcceptWithDetails: (d) {
                    final box = _posterKey.currentContext?.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    final local = box.globalToLocal(d.offset);
                    final err = _c.addStickerAt(
                      d.data,
                      (local.dx / w).clamp(0.05, 0.95),
                      (local.dy / h).clamp(0.05, 0.95),
                    );
                    if (err != null) showSnack(context, err);
                  },
                  builder: (context, candidates, _) => Stack(
                    key: _posterKey,
                    children: [
                      RepaintBoundary(
                        key: _boundaryKey,
                        child: PosterView(doc: _c.doc, photoCacheWidth: 1080),
                      ),
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () => _c.select(null),
                          child: _InteractionLayer(controller: _c, width: w, height: h),
                        ),
                      ),
                      if (candidates.isNotEmpty)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white, width: 3),
                                color: Colors.white24,
                              ),
                              child: const Center(
                                child: Text('Drop it here', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                              ),
                            ),
                          ),
                        ),
                      if (_busy)
                        const Positioned.fill(
                          child: ColoredBox(color: Color(0x88000000), child: LoadingState()),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _toolBar() {
    const labels = {
      _Tool.text: (Icons.text_fields, 'Text'),
      _Tool.stickers: (Icons.emoji_emotions_outlined, 'Stickers'),
      _Tool.photo: (Icons.photo_outlined, 'Photo'),
      _Tool.background: (Icons.palette_outlined, 'Background'),
      _Tool.border: (Icons.border_style, 'Border'),
      _Tool.format: (Icons.aspect_ratio, 'Format'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: Row(
        children: [
          for (final t in _Tool.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: _tool == t,
                label: labels[t]!.$2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() => _tool = t),
                  child: Container(
                    height: 52,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: _tool == t ? AppColors.purple.withValues(alpha: 0.16) : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(labels[t]!.$1, size: 20, color: _tool == t ? AppColors.purple : null),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(labels[t]!.$2,
                              maxLines: 1,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _tool == t ? AppColors.purple : null)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _panel(AppContent content) => switch (_tool) {
        _Tool.text => _textPanel(content),
        _Tool.stickers => _stickerPanel(content),
        _Tool.photo => _photoPanel(),
        _Tool.background => _backgroundPanel(content),
        _Tool.border => _borderPanel(content),
        _Tool.format => _formatPanel(),
      };

  Widget _swatches(List<Color> colors, Color? current, void Function(Color) onPick) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final col in colors)
          Semantics(
            button: true,
            label: 'Colour',
            child: GestureDetector(
              onTap: () => onPick(col),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: col,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: current == col ? AppColors.pink : Colors.black26,
                    width: current == col ? 3 : 1,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _textPanel(AppContent content) {
    final e = _c.selected;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Add text'),
                onPressed: _addTextDialog,
              ),
              for (final el in _c.doc.elements)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    selected: _c.selectedId == el.id,
                    showCheckmark: false,
                    label: Text(
                      el.isPhoto
                          ? '📷 Photo'
                          : el.text.length > 12
                              ? '${el.text.substring(0, 12)}…'
                              : el.text,
                    ),
                    onSelected: (_) => _c.select(el.id),
                  ),
                ),
            ],
          ),
        ),
        if (widget.args.suggestions.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Center(child: Text('💡', style: TextStyle(fontSize: 20))),
                ),
                for (final sug in widget.args.suggestions)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(sug.length > 30 ? '${sug.substring(0, 30)}…' : sug),
                      onPressed: () => _applySuggestion(sug),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        if (e == null)
          const Padding(
            padding: EdgeInsets.all(Spacing.md),
            child: Text('Tap anything on the poster to select it. Drag to move, pinch or use the corner handle to resize and rotate.'),
          )
        else ...[
          if (e.kind == ElementKind.text)
            TextField(
              controller: _textController,
              maxLength: 120,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                labelText: 'Caption',
                counterText: '',
                errorText: _textController.text.trim().isEmpty ? 'Text cannot be empty' : null,
              ),
              onChanged: (v) {
                if (v.trim().isNotEmpty) _c.editText(v);
                setState(() {});
              },
            ),
          Row(
            children: [
              const Icon(Icons.format_size),
              Expanded(
                child: Slider(
                  min: 14,
                  max: e.kind == ElementKind.sticker ? 140 : 72,
                  value: e.size.clamp(14, e.kind == ElementKind.sticker ? 140 : 72),
                  onChangeStart: (_) => _c.checkpoint(),
                  onChanged: (v) => _c.liveUpdateSelected((x) => x.copyWith(size: v)),
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: _c.deleteSelected,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          if (e.kind == ElementKind.text) ...[
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final f in content.fonts)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        selected: e.font == f.id,
                        showCheckmark: false,
                        label: Text(f.label, style: TextStyle(fontFamily: f.id)),
                        onSelected: (_) => _c.updateSelected((x) => x.copyWith(font: f.id)),
                      ),
                    ),
                  FilterChip(
                    selected: e.bold,
                    label: const Text('Bold'),
                    onSelected: (v) => _c.updateSelected((x) => x.copyWith(bold: v)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _swatches(content.palette, e.color, (col) => _c.updateSelected((x) => x.copyWith(color: col))),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.border_color_outlined),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: 10,
                    divisions: 20,
                    label: e.outline.toStringAsFixed(1),
                    value: e.outline.clamp(0, 10).toDouble(),
                    onChangeStart: (_) => _c.checkpoint(),
                    onChanged: (v) => _c.liveUpdateSelected((x) => x.copyWith(outline: v)),
                  ),
                ),
              ],
            ),
            if (e.outline > 0)
              _swatches(content.palette, e.outlineColor, (col) => _c.updateSelected((x) => x.copyWith(outlineColor: col))),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, icon: Icon(Icons.format_align_left), tooltip: 'Align left'),
                ButtonSegment(value: 1, icon: Icon(Icons.format_align_center), tooltip: 'Align centre'),
                ButtonSegment(value: 2, icon: Icon(Icons.format_align_right), tooltip: 'Align right'),
              ],
              selected: {e.align},
              onSelectionChanged: (v) => _c.updateSelected((x) => x.copyWith(align: v.first)),
            ),
            _rotationRow(e),
          ],
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  /// Replaces the selected text with a suggestion, or adds it as a new layer.
  void _applySuggestion(String text) {
    final e = _c.selected;
    if (e != null && e.kind == ElementKind.text) {
      _c.updateSelected((x) => x.copyWith(text: text));
      return;
    }
    final err = _c.addText(text);
    if (err != null) showSnack(context, err);
    final added = _c.selected;
    if (added != null && _c.doc.isMeme) {
      _c.updateSelected((x) => x.copyWith(font: 'MuktaMalar', outline: 4, outlineColor: Colors.black), checkpointFirst: false);
    }
  }

  Future<void> _addTextDialog() async {
    final text = await promptText(
      context,
      title: 'Add text',
      hint: 'Say something funny',
      confirmLabel: 'Add',
      maxLines: 2,
      validator: Validators.caption,
    );
    if (text == null) return;
    final err = _c.addText(text);
    if (err != null && mounted) showSnack(context, err);
  }

  Widget _stickerPanel(AppContent content) {
    final e = _c.selected;
    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text('Tap to add, or hold and drag onto the poster.'),
        ),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final s in content.stickers)
              LongPressDraggable<String>(
                data: s,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: Material(
                  color: Colors.transparent,
                  child: Text(s, style: const TextStyle(fontSize: 56)),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: SizedBox(width: 48, height: 48, child: Center(child: Text(s, style: const TextStyle(fontSize: 28)))),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    final err = _c.addSticker(s);
                    if (err != null) showSnack(context, err);
                  },
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(child: Text(s, style: const TextStyle(fontSize: 28))),
                  ),
                ),
              ),
          ],
        ),
        if (e != null && e.kind == ElementKind.sticker)
          Row(
            children: [
              const Icon(Icons.format_size),
              Expanded(
                child: Slider(
                  min: 20,
                  max: 160,
                  value: e.size.clamp(20, 160),
                  onChangeStart: (_) => _c.checkpoint(),
                  onChanged: (v) => _c.liveUpdateSelected((x) => x.copyWith(size: v)),
                ),
              ),
              IconButton(onPressed: _c.deleteSelected, tooltip: 'Delete', icon: const Icon(Icons.delete_outline)),
            ],
          ),
        if (e != null && e.kind == ElementKind.sticker) _rotationRow(e),
      ],
    );
  }

  Widget _rotationRow(PosterElement e) {
    final deg = (e.rotation * 180 / pi).clamp(-180.0, 180.0).toDouble();
    return Row(
      children: [
        const Icon(Icons.rotate_right),
        Expanded(
          child: Slider(
            min: -180,
            max: 180,
            value: deg,
            label: '${deg.round()}°',
            onChangeStart: (_) => _c.checkpoint(),
            onChanged: (v) => _c.liveUpdateSelected((x) => x.copyWith(rotation: v * pi / 180)),
          ),
        ),
        IconButton(
          tooltip: 'Straighten',
          onPressed: e.rotation == 0 ? null : () => _c.updateSelected((x) => x.copyWith(rotation: 0)),
          icon: const Icon(Icons.straighten),
        ),
      ],
    );
  }

  Widget _photoPanel() {
    final e = _c.selected;
    final photo = e != null && e.isPhoto ? e : null;
    Future<void> pick({required bool replace}) async {
      final path = await pickPhoto(context, ref);
      if (path == null || !mounted) return;
      if (replace) {
        _c.replacePhoto(path);
      } else {
        final err = _c.addPhoto(path);
        if (err != null) showSnack(context, err);
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => pick(replace: false),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add photo'),
              ),
            ),
            if (photo != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => pick(replace: true),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Replace'),
                ),
              ),
              IconButton(tooltip: 'Delete photo', onPressed: _c.deleteSelected, icon: const Icon(Icons.delete_outline)),
            ],
          ],
        ),
        if (photo == null)
          const Padding(
            padding: EdgeInsets.all(Spacing.md),
            child: Text('Add a photo, then tap it on the poster to move, resize, rotate, reshape and colour-adjust it.'),
          )
        else ...[
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final sh in PhotoShape.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      selected: photo.shape == sh,
                      showCheckmark: false,
                      label: Text(sh.name[0].toUpperCase() + sh.name.substring(1)),
                      onSelected: (_) => _c.updateSelected((x) => x.copyWith(shape: sh)),
                    ),
                  ),
                for (final a in const [(1.0, 'Square'), (4 / 5, 'Tall'), (4 / 3, 'Wide')])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      selected: (photo.aspect - a.$1).abs() < 0.01,
                      showCheckmark: false,
                      label: Text('Crop: ${a.$2}'),
                      onSelected: (_) => _c.updateSelected((x) => x.copyWith(aspect: a.$1)),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.zoom_out_map),
              Expanded(
                child: Slider(
                  min: 60,
                  max: 340,
                  value: photo.size.clamp(60, 340).toDouble(),
                  onChangeStart: (_) => _c.checkpoint(),
                  onChanged: (v) => _c.liveUpdateSelected((x) => x.copyWith(size: v)),
                ),
              ),
            ],
          ),
          _rotationRow(photo),
          Row(
            children: [
              const Icon(Icons.brightness_6_outlined),
              Expanded(
                child: Slider(
                  min: -0.4,
                  max: 0.4,
                  value: photo.brightness.clamp(-0.4, 0.4).toDouble(),
                  onChangeStart: (_) => _c.checkpoint(),
                  onChanged: (v) => _c.liveUpdateSelected((x) => x.copyWith(brightness: v)),
                ),
              ),
              const Icon(Icons.color_lens_outlined),
              Expanded(
                child: Slider(
                  min: 0,
                  max: 2,
                  value: photo.saturation.clamp(0, 2).toDouble(),
                  onChangeStart: (_) => _c.checkpoint(),
                  onChanged: (v) => _c.liveUpdateSelected((x) => x.copyWith(saturation: v)),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.flip, size: 18),
                label: const Text('Flip'),
                onPressed: () => _c.updateSelected((x) => x.copyWith(flipped: !x.flipped)),
              ),
              ActionChip(
                avatar: const Icon(Icons.rotate_90_degrees_cw, size: 18),
                label: const Text('Rotate 90°'),
                onPressed: () => _c.updateSelected((x) => x.copyWith(rotation: x.rotation + pi / 2)),
              ),
              ActionChip(
                avatar: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Reset look'),
                onPressed: () => _c.updateSelected(
                    (x) => x.copyWith(brightness: 0, saturation: 1, flipped: false, rotation: 0)),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _backgroundPanel(AppContent content) {
    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final g in content.gradients)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _c.setBackground(g),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: g),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _c.doc.colors.first == g.first && _c.doc.colors.last == g.last
                              ? AppColors.pink
                              : Colors.black26,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          children: [
            for (final p in PosterPattern.values)
              ChoiceChip(
                selected: _c.doc.pattern == p,
                showCheckmark: false,
                label: Text(p.name[0].toUpperCase() + p.name.substring(1)),
                onSelected: (_) => _c.setPattern(p),
              ),
          ],
        ),
      ],
    );
  }

  Widget _borderPanel(AppContent content) {
    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        Wrap(
          spacing: 6,
          children: [
            for (final b in PosterBorder.values)
              ChoiceChip(
                selected: _c.doc.border == b,
                showCheckmark: false,
                label: Text(b.name[0].toUpperCase() + b.name.substring(1)),
                onSelected: (_) => _c.setBorder(b),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _swatches(content.palette, _c.doc.borderColor, _c.setBorderColor),
      ],
    );
  }

  Widget _formatPanel() {
    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        SegmentedButton<PosterLayout>(
          segments: [
            for (final l in PosterLayout.values)
              ButtonSegment(
                value: l,
                label: Text('${l.label}\n${l.ratioLabel}', textAlign: TextAlign.center),
              ),
          ],
          selected: {_c.doc.layout},
          onSelectionChanged: (s) => _c.setLayout(s.first),
        ),
        const SizedBox(height: 8),
        Text(
          'Exports at ${_c.doc.layout.exportSize.width.toInt()} x ${_c.doc.layout.exportSize.height.toInt()} px. No watermark.',
        ),
      ],
    );
  }

  Widget _actionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.md, 4, Spacing.md, Spacing.sm),
      child: Row(
        children: [
          _ActionButton(icon: Icons.bookmark_add_outlined, label: 'Save', onTap: _busy ? null : _save),
          const SizedBox(width: 8),
          _ActionButton(icon: Icons.download, label: 'Gallery', onTap: _busy ? null : _gallery),
          const SizedBox(width: 12),
          Expanded(
            child: GradientButton(label: 'Share', icon: Icons.share, onPressed: _busy ? null : _share),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: SizedBox(
            width: 64,
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22),
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Transparent layer above the poster with one gesture box per element.
/// Lives outside the RepaintBoundary so selection outlines and handles never
/// get exported.
///
/// * drag with one finger to move (the element stays inside the poster)
/// * pinch with two fingers to resize and rotate
/// * drag the corner handle to resize and rotate with one finger
/// * tap the red button to delete
class _InteractionLayer extends StatefulWidget {
  const _InteractionLayer({required this.controller, required this.width, required this.height});
  final EditorController controller;
  final double width;
  final double height;

  @override
  State<_InteractionLayer> createState() => _InteractionLayerState();
}

class _InteractionLayerState extends State<_InteractionLayer> {
  static const _pad = 20.0; // extra grab area around each element

  double _startSize = 0;
  double _startRotation = 0;
  double _startDistance = 1;
  double _startAngle = 0;

  EditorController get c => widget.controller;
  Size get _poster => Size(widget.width, widget.height);

  (double, double) _limits(PosterElement e) => switch (e.kind) {
        ElementKind.photo => (60, 340),
        ElementKind.sticker => (20, 260),
        ElementKind.text => (12, 120),
      };

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      // The selected element goes last so its handles are never covered by
      // the (padded) grab area of a neighbouring element.
      children: [
        for (final e in c.doc.elements)
          if (e.id != c.selectedId) _box(e),
        for (final e in c.doc.elements)
          if (e.id == c.selectedId) _box(e),
      ],
    );
  }

  Widget _box(PosterElement e) {
    final size = measureElement(e, widget.width);
    final selected = c.selectedId == e.id;
    final center = elementCenter(e, _poster);
    final w = size.width + _pad * 2;
    final h = size.height + _pad * 2;
    return Positioned(
      left: center.dx - w / 2,
      top: center.dy - h / 2,
      width: w,
      height: h,
      child: Transform.rotate(
        angle: e.rotation,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => c.select(e.id),
                onScaleStart: (_) {
                  c.select(e.id);
                  c.checkpoint();
                  _startSize = e.size;
                  _startRotation = e.rotation;
                },
                onScaleUpdate: (d) => _onScale(e, d, size),
                child: Padding(
                  padding: const EdgeInsets.all(_pad),
                  child: DecoratedBox(
                    decoration: selected
                        ? BoxDecoration(border: Border.all(color: Colors.black54, width: 3))
                        : const BoxDecoration(),
                    position: DecorationPosition.background,
                    child: DecoratedBox(
                      decoration: selected
                          ? BoxDecoration(border: Border.all(color: Colors.white, width: 1.5))
                          : const BoxDecoration(),
                    ),
                  ),
                ),
              ),
            ),
            if (selected) ...[
              Positioned(right: 0, bottom: 0, child: _resizeHandle(e)),
              Positioned(left: 0, top: 0, child: _deleteHandle()),
            ],
          ],
        ),
      ),
    );
  }

  void _onScale(PosterElement e, ScaleUpdateDetails d, Size size) {
    final (minSize, maxSize) = _limits(e);
    final pinching = d.pointerCount > 1;
    final newSize = pinching ? (_startSize * d.scale).clamp(minSize, maxSize).toDouble() : e.size;
    final newRotation = pinching ? _startRotation + d.rotation : e.rotation;
    final grown = e.copyWith(size: newSize, rotation: newRotation);
    final grownSize = measureElement(grown, widget.width);
    final cur = elementCenter(e, _poster);
    final next = cur + d.focalPointDelta;
    c.liveUpdateSelected((x) => x.copyWith(size: newSize, rotation: newRotation));
    c.moveTo(
      e.id,
      next.dx / widget.width,
      next.dy / widget.height,
      halfW: grownSize.width / 2 / widget.width,
      halfH: grownSize.height / 2 / widget.height,
    );
  }

  Widget _resizeHandle(PosterElement e) {
    return Builder(
      builder: (_) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) {
          c.checkpoint();
          final v = _vectorFromCenter(e, d.globalPosition);
          _startSize = e.size;
          _startRotation = e.rotation;
          _startDistance = max(v.distance, 1);
          _startAngle = v.direction;
        },
        onPanUpdate: (d) {
          final v = _vectorFromCenter(e, d.globalPosition);
          final (minSize, maxSize) = _limits(e);
          c.liveUpdateSelected((x) => x.copyWith(
                size: (_startSize * v.distance / _startDistance).clamp(minSize, maxSize).toDouble(),
                rotation: _startRotation + (v.direction - _startAngle),
              ));
        },
        child: Semantics(
          label: 'Resize and rotate',
          child: Container(
            width: _pad * 1.6,
            height: _pad * 1.6,
            margin: const EdgeInsets.all(_pad * 0.2),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.purple, width: 2),
            ),
            child: const Icon(Icons.open_in_full, size: 14, color: AppColors.purple),
          ),
        ),
      ),
    );
  }

  Widget _deleteHandle() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: c.deleteSelected,
      child: Semantics(
        button: true,
        label: 'Delete element',
        child: Container(
          width: _pad * 1.6,
          height: _pad * 1.6,
          margin: const EdgeInsets.all(_pad * 0.2),
          decoration: const BoxDecoration(color: Color(0xFFE53935), shape: BoxShape.circle),
          child: const Icon(Icons.close, size: 16, color: Colors.white),
        ),
      ),
    );
  }

  /// Vector from the centre of an element to a pointer position (global).
  Offset _vectorFromCenter(PosterElement e, Offset global) {
    final layer = context.findRenderObject();
    if (layer is! RenderBox || !layer.hasSize) return const Offset(1, 0);
    return global - layer.localToGlobal(elementCenter(e, _poster));
  }
}
