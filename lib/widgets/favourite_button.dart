import 'package:flutter/material.dart';

import '../services/api_service.dart';

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
    // The parent may know better (for example after coming back from the detail page).
    if (old.isFavourite != widget.isFavourite) _on = widget.isFavourite;
  }

  Future<void> _toggle() async {
    if (_busy) return; // ignore a second tap while the first one is still being sent

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
      setState(() => _on = !target); // the server refused: put the heart back
      widget.onChanged?.call(!target);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      tooltip: _on ? 'Remove from favourites' : 'Add to favourites',
      visualDensity: VisualDensity.compact,
      icon: Icon(
        _on ? Icons.favorite : Icons.favorite_border,
        color: _on ? Colors.red : (widget.overlay ? Colors.black54 : null),
      ),
      onPressed: _busy ? null : _toggle,
    );

    if (!widget.overlay) return button;

    return Material(color: Colors.white70, shape: const CircleBorder(), child: button);
  }
}