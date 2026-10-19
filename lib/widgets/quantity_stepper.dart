import 'package:flutter/material.dart';

/// − 2 +  with limits. Used on the product page and in the cart.
class QuantityStepper extends StatelessWidget {
  final int value;
  final int min;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        tooltip: 'Fewer',
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.remove_circle_outline),
        onPressed: enabled && value > min ? () => onChanged(value - 1) : null,
      ),
      SizedBox(
        width: 28,
        child: Text('$value', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
      ),
      IconButton(
        tooltip: 'More',
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.add_circle_outline),
        onPressed: enabled && value < max ? () => onChanged(value + 1) : null,
      ),
    ]);
  }
}