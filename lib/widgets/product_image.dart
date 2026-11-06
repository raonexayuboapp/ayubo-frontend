import 'package:flutter/material.dart';

/// A product picture, or a placeholder when there is no URL or the image fails to load.
class ProductImage extends StatelessWidget {
  final String? url;
  const ProductImage({super.key, this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;

    final placeholder = Container(
      width: double.infinity,
      height: double.infinity,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      alignment: Alignment.center,
      child: Icon(
        Icons.spa_outlined,
        size: 32,
        color: goldColor.withValues(alpha: 0.6),
      ),
    );

    if (url == null || url!.trim().isEmpty) return placeholder;

    return Image.network(
      url!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => placeholder,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          child: child,
        );
      },
      loadingBuilder: (_, child, progress) => progress == null ? child : placeholder,
    );
  }
}