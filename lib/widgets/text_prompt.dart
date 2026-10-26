import 'package:flutter/material.dart';

/// Single-field dialog that owns (and disposes) its controller at the right
/// time. Returns the entered text, or null when cancelled.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? hint,
  String confirmLabel = 'Save',
  String initial = '',
  int maxLength = 120,
  int maxLines = 1,
  TextCapitalization capitalization = TextCapitalization.sentences,
  required String? Function(String?) validator,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPromptDialog(
      title: title,
      hint: hint,
      confirmLabel: confirmLabel,
      initial: initial,
      maxLength: maxLength,
      maxLines: maxLines,
      capitalization: capitalization,
      validator: validator,
    ),
  );
}

class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.initial,
    required this.maxLength,
    required this.maxLines,
    required this.capitalization,
    required this.validator,
  });
  final String title;
  final String? hint;
  final String confirmLabel;
  final String initial;
  final int maxLength;
  final int maxLines;
  final TextCapitalization capitalization;
  final String? Function(String?) validator;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          maxLength: widget.maxLength,
          maxLines: widget.maxLines,
          textCapitalization: widget.capitalization,
          decoration: InputDecoration(hintText: widget.hint, counterText: ''),
          validator: widget.validator,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(80, 44)),
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
