import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/meme_template.dart';
import '../../models/records.dart';
import '../../widgets/common.dart';
import '../posters/editor_screen.dart';

/// Opens the full-screen editor for a meme template and records it as
/// recently used.
class MemeEditorRoute extends ConsumerStatefulWidget {
  const MemeEditorRoute({super.key, required this.templateId});
  final String templateId;
  @override
  ConsumerState<MemeEditorRoute> createState() => _MemeEditorRouteState();
}

class _MemeEditorRouteState extends ConsumerState<MemeEditorRoute> {
  MemeTemplate? _template;
  EditorArgs? _args;

  @override
  void initState() {
    super.initState();
    final t = ref.read(allMemesProvider).byId(widget.templateId);
    _template = t;
    if (t != null) {
      _args = EditorArgs(
        doc: MemeDocBuilder.build(t),
        title: '${t.id} ${t.title}',
        suggestions: t.captions,
      );
      Future.microtask(() => ref.read(historyProvider.notifier).record(HistoryKind.meme, t.id, t.title));
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = _args;
    if (args == null || _template == null) {
      return Scaffold(
        appBar: AppBar(),
        body: ErrorState(message: 'That template is not available any more.', onRetry: () => context.go('/memes')),
      );
    }
    return EditorScreen(args: args);
  }
}
