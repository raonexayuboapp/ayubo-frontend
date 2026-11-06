import 'package:flutter/material.dart';

class PromptField {
  final String key;
  final String label;
  final String? helper;
  final bool required;
  final int maxLength;
  final int maxLines;
  final String initial;

  const PromptField({
    required this.key,
    required this.label,
    this.helper,
    this.required = false,
    this.maxLength = 200,
    this.maxLines = 1,
    this.initial = '',
  });
}

/// Asks for a few texts. Answers a map of key -> trimmed text (an empty string for an empty optional field),
/// or null when the person cancels.
Future<Map<String, String>?> showPrompt(
  BuildContext context, {
  required String title,
  required List<PromptField> fields,
  String? message,
  String confirmLabel = 'OK',
}) {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (_) => _PromptDialog(title: title, message: message, fields: fields, confirmLabel: confirmLabel),
  );
}

class _PromptDialog extends StatefulWidget {
  final String title;
  final String? message;
  final List<PromptField> fields;
  final String confirmLabel;
  const _PromptDialog({required this.title, required this.message, required this.fields, required this.confirmLabel});

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers = {
    for (final f in widget.fields) f.key: TextEditingController(text: f.initial),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, {for (final e in _controllers.entries) e.key: e.value.text.trim()});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.message != null) ...[Text(widget.message!), const SizedBox(height: 12)],
            for (final f in widget.fields)
              TextFormField(
                controller: _controllers[f.key],
                maxLength: f.maxLength,
                minLines: 1,
                maxLines: f.maxLines,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (v) => f.required && (v ?? '').trim().isEmpty ? 'Required.' : null,
                decoration: InputDecoration(labelText: f.label, helperText: f.helper, helperMaxLines: 2),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}