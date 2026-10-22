import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/countries.dart';
import '../utils/money.dart';

/// The shipping line of the cart footer. It asks the server for a quote whenever [cartKey] changes, which is
/// whenever the cart changes. It is an estimate: the customer picks a delivery method at checkout.
class ShippingEstimate extends StatefulWidget {
  final String cartKey;
  const ShippingEstimate({super.key, required this.cartKey});

  @override
  State<ShippingEstimate> createState() => _ShippingEstimateState();
}

class _ShippingEstimateState extends State<ShippingEstimate> {
  Map<String, dynamic>? _quote;
  int _request = 0; // an answer that belongs to an older cart is ignored

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ShippingEstimate old) {
    super.didUpdateWidget(old);
    if (old.cartKey != widget.cartKey) _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    try {
      final quote = await ApiService.instance.shippingQuote();
      if (!mounted || request != _request) return;
      setState(() => _quote = quote);
    } on ApiException {
      // A stale estimate would mislead, so show none until the next successful quote.
      if (mounted && request == _request) setState(() => _quote = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    if (quote == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final country = quote['country_code'] as String?;
    final to = country == null ? '' : countryName(country);
    final options = (quote['options'] as List<dynamic>).cast<Map<String, dynamic>>();

    String? line;
    String? hint;
    var problem = false;

    switch (quote['status'] as String) {
      case 'ok':
        final first = options.first; // the cheapest option comes first
        final price = first['price_cents'] as int;
        final free = first['free'] == true;
        line = free
            ? 'Free shipping to $to'
            : options.length == 1
            ? 'Shipping to $to: ${formatCents(price)}'
            : 'Shipping to $to from ${formatCents(price)}';

        final next = first['next_band'] as Map<String, dynamic>?;
        if (next != null) {
          final remaining = formatCents(next['remaining_cents'] as int);
          hint = next['price_cents'] == 0
              ? 'Spend $remaining more for free shipping.'
              : 'Spend $remaining more and shipping drops to ${formatCents(next['price_cents'] as int)}.';
        }
      case 'needs_address':
        line = 'Add a shipping address to see the delivery cost.';
      case 'country_not_served':
        line = 'We do not deliver to $to yet.';
        problem = true;
      case 'no_option':
        line = 'No delivery price is set for this order. Please contact support.';
        problem = true;
      default:
        return const SizedBox.shrink(); // empty cart, or nothing that has to be shipped
    }

    final color = problem ? theme.colorScheme.error : null;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(line, style: theme.textTheme.bodyMedium?.copyWith(color: color)),
        if (hint != null) Text(hint, style: theme.textTheme.bodySmall),
      ]),
    );
  }
}