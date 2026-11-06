import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'auth_prompt_dialog.dart';

/// A heart that adds or removes a product from the favourites.
///
/// The heart changes at once (optimistic) and goes back if the server refuses, for example when the
/// favourites limit is reached. [onChanged] lets the parent keep its own data in step.
class FavouriteButton extends StatefulWidget {
  final int productId;
  final bool isFavourite;
  final ValueChanged<bool>? onChanged;
  final bool overlay; // a round light background, for use on top of a picture

  const FavouriteButton({
    super.key,
    required this.productId,
    required this.isFavourite,
    this.onChanged,
    this.overlay = false,
  });

  @override
  State<FavouriteButton> createState() => _FavouriteButtonState();
}

class _FavouriteButtonState extends State<FavouriteButton> {
  late bool _on = widget.isFavourite;
  bool _busy = false;

  @override
  void didUpdateWidget(FavouriteButton old) {
    super.didUpdateWidget(old);
    if (old.isFavourite != widget.isFavourite) _on = widget.isFavourite;
  }

  Future<void> _toggle() async {
    if (_busy) return;

    // Intercept guest action and prompt for authentication
    if (!await ApiService.instance.hasToken()) {
      if (!mounted) return;
      final user = await showAuthPrompt(
        context,
        title: 'Save to Favourites',
        message: 'Log in or create an account to save your favourite organic products and access them anywhere.',
      );
      if (user == null || !mounted) return;
    }

    final target = !_on;
    setState(() {
      _on = target;
      _busy = true;
    });
    widget.onChanged?.call(target);

    try {
      if (target) {
        await ApiService.instance.addFavourite(widget.productId);
      } else {
        await ApiService.instance.removeFavourite(widget.productId);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _on = !target);
      widget.onChanged?.call(!target);
      // Suppress raw 401 errors from reaching the user
      if (e.statusCode != 401) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final button = IconButton(
      tooltip: _on ? 'Remove from favourites' : 'Add to favourites',
      visualDensity: VisualDensity.compact,
      icon: Icon(
        _on ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        size: 20,
        color: _on
            ? Colors.redAccent
            : (widget.overlay
                ? theme.colorScheme.onSurface.withValues(alpha: 0.7)
                : theme.colorScheme.onSurface.withValues(alpha: 0.5)),
      ),
      onPressed: _busy ? null : _toggle,
    );

    if (!widget.overlay) return button;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(
          color: _on
              ? Colors.redAccent.withValues(alpha: 0.3)
              : theme.dividerColor.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: button,
    );
  }
}
