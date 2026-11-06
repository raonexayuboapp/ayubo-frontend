import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import 'product_image.dart';

typedef ProductImageData = Map<String, dynamic>;

/// The picture strip of a product form. The parent owns the list and passes it in; this widget picks a file,
/// uploads it, and reports the new list through [onChanged]. The first image is the main image.
/// Removing an image only DETACHES it from the product: the file stays on the server.
class ImageManager extends StatefulWidget {
  static const maxImages = 20; // the server accepts at most 20 per product
  static const maxBytes = 5 * 1024 * 1024; // and 5 MB per file

  final List<ProductImageData> images; // each: id, url, alt_text
  final ValueChanged<List<ProductImageData>> onChanged;

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

    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 85);
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    if (bytes.length > ImageManager.maxBytes) {
      _snack('This image is larger than 5 MB. Choose a smaller one.');
      return;
    }

    final alt = await showDialog<String>(context: context, builder: (_) => const _AltTextDialog());
    if (alt == null || !mounted) return;

    setState(() => _busy = true);
    try {
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
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final img = widget.images[i];

    return Padding(
      key: ValueKey(img['id']),
      padding: const EdgeInsets.only(right: 10),
      child: SizedBox(
        width: 108,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: i == 0 ? goldColor : theme.dividerColor.withValues(alpha: 0.15),
                    width: i == 0 ? 1.5 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ProductImage(url: img['url'] as String?),
                ),
              ),
            ),
            if (i == 0)
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: goldColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Main',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                ),
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  tooltip: 'Image options',
                  icon: Icon(
                    Icons.more_vert,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  onSelected: (v) => v == 'main' ? _makeMain(i) : _remove(i),
                  itemBuilder: (_) => [
                    if (i > 0) const PopupMenuItem(value: 'main', child: Text('Make main image')),
                    const PopupMenuItem(value: 'remove', child: Text('Remove from product')),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addTile() {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;

    return SizedBox(
      width: 108,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _busy ? null : _add,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.2),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: _busy
                ? CircularProgressIndicator(color: goldColor, strokeWidth: 2)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        color: goldColor,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add image',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
          ),
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
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Describe the image',
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _alt.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: goldColor,
            elevation: 0,
          ),
          child: const Text('Upload', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}