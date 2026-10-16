import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import 'product_image.dart';

/// The picture strip of a product form. The parent owns the list and passes it in; this widget picks a file,
/// uploads it, and reports the new list through [onChanged]. The first image is the main image.
/// Removing an image only DETACHES it from the product: the file stays on the server.
class ImageManager extends StatefulWidget {
  static const maxImages = 20; // the server accepts at most 20 per product
  static const maxBytes = 5 * 1024 * 1024; // and 5 MB per file

  final List<Map<String, dynamic>> images; // each: id, url, alt_text
  final ValueChanged<List<Map<String, dynamic>>> onChanged;

  const ImageManager({super.key, required this.images, required this.onChanged});

  @override
  State<ImageManager> createState() => _ImageManagerState();
}

class _ImageManagerState extends State<ImageManager> {
  final _picker = ImagePicker();
  bool _busy = false;

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _add() async {
    if (_busy) return;

    // On phones the picker shrinks the photo before it is uploaded, so it stays under the 5 MB limit.
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 85);
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    if (bytes.length > ImageManager.maxBytes) {
      _snack('This image is larger than 5 MB. Choose a smaller one.');
      return;
    }

    final alt = await showDialog<String>(context: context, builder: (_) => const _AltTextDialog());
    if (alt == null || !mounted) return; // cancelled

    setState(() => _busy = true);
    try {
      // The server decides what the file really is from its CONTENT, whatever its name says.
      final media = await ApiService.instance.adminUploadImage(
        bytes: bytes,
        filename: picked.name,
        altText: alt.trim(),
      );
      if (!mounted) return;
      widget.onChanged([...widget.images, media]);
    } on ApiException catch (e) {
      if (mounted) _snack(e.fieldErrors['file'] ?? e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _makeMain(int i) {
    final list = [...widget.images];
    list.insert(0, list.removeAt(i));
    widget.onChanged(list);
  }

  void _remove(int i) {
    final list = [...widget.images]..removeAt(i);
    widget.onChanged(list);
  }

  Widget _tile(int i) {
    final img = widget.images[i];
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      key: ValueKey(img['id']),
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(
        width: 108,
        child: Stack(children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ProductImage(url: img['url'] as String?),
            ),
          ),
          if (i == 0)
            Positioned(
              left: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(4)),
                child: Text('Main', style: TextStyle(fontSize: 11, color: scheme.onPrimary)),
              ),
            ),
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: Colors.white70,
              shape: const CircleBorder(),
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 18,
                tooltip: 'Image options',
                onSelected: (v) => v == 'main' ? _makeMain(i) : _remove(i),
                itemBuilder: (_) => [
                  if (i > 0) const PopupMenuItem(value: 'main', child: Text('Make main image')),
                  const PopupMenuItem(value: 'remove', child: Text('Remove from product')),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _addTile() {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 108,
      child: InkWell(
        onTap: _busy ? null : _add,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outline),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: _busy
              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : const Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_photo_alternate_outlined),
            SizedBox(height: 4),
            Text('Add image', style: TextStyle(fontSize: 12)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < widget.images.length; i++) _tile(i),
          if (widget.images.length < ImageManager.maxImages) _addTile(),
        ],
      ),
    );
  }
}

class _AltTextDialog extends StatefulWidget {
  const _AltTextDialog();

  @override
  State<_AltTextDialog> createState() => _AltTextDialogState();
}

class _AltTextDialogState extends State<_AltTextDialog> {
  final _alt = TextEditingController();

  @override
  void dispose() {
    _alt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Describe the image'),
      content: TextField(
        controller: _alt,
        autofocus: true,
        maxLength: 255,
        decoration: const InputDecoration(
          labelText: 'Alt text (optional)',
          helperText: 'Read aloud by screen readers and shown if the image cannot load.',
          helperMaxLines: 2,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _alt.text), child: const Text('Upload')),
      ],
    );
  }
}
