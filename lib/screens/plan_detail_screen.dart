
import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

/// Full details of a membership plan, with the Add to cart button.
class PlanDetailScreen extends StatefulWidget {
  final Map<String, dynamic> plan;

  const PlanDetailScreen({
    super.key,
    required this.plan,
  });

  @override
  State<PlanDetailScreen> createState() => _PlanDetailScreenState();
}

class _PlanDetailScreenState extends State<PlanDetailScreen> {
  bool _adding = false;
  bool _added = false;

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String _readString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString();
  }

  bool _readActive(dynamic value) {
    return value == true || value == 1 || value == '1';
  }

  List<Map<String, dynamic>> _readBenefits(dynamic value) {
    if (value is! List) return [];

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String _formatConfiguration(dynamic value) {
    if (value == null) return '';

    dynamic decoded = value;

    if (value is String) {
      if (value.trim().isEmpty) return '';

      try {
        decoded = jsonDecode(value);
      } on FormatException {
        return value;
      }
    }

    if (decoded is! Map && decoded is! List) {
      return '';
    }

    // Convert configuration into a readable summary.
    if (decoded is Map) {
      final parts = <String>[];

      final discount = decoded['discount_percent'];
      if (discount is num) {
        parts.add('${discount.toStringAsFixed(0)}% discount');
      }

      final amount = decoded['amount_cents'];
      if (amount is num) {
        final currency = _readString(
          decoded['currency'],
          fallback: 'EUR',
        );
        parts.add(
          '$currency ${(amount / 100).toStringAsFixed(2)} credit',
        );
      }

      if (parts.isNotEmpty) return parts.join(' · ');
    }

    return '';
  }

  Future<void> _addToCart() async {
    if (_adding) return;

    final id = _readInt(widget.plan['id']);

    if (id == null || id < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This plan has an invalid ID. Please reload the plans.'),
        ),
      );
      return;
    }

    if (!_readActive(widget.plan['active'])) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This membership plan is currently unavailable.'),
        ),
      );
      return;
    }

    setState(() {
      _adding = true;
    });

    try {
      await ApiService.instance.addPlanToCart(id);

      if (!mounted) return;

      setState(() {
        _adding = false;
        _added = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"${_readString(widget.plan['name'], fallback: 'Membership plan')}" added to your cart.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _adding = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _adding = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to add this plan to your cart. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final theme = Theme.of(context);

    final name = _readString(
      plan['name'],
      fallback: 'Membership plan',
    );

    final code = _readString(plan['code']);
    final description = _readString(plan['description']);
    final active = _readActive(plan['active']);
    final benefits = _readBenefits(plan['benefits']);

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (code.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(code),
              ),
            ),

          const SizedBox(height: 8),

          Text(
            name,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          if (description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: theme.textTheme.bodyLarge,
            ),
          ],

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    active
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    color: active
                        ? Colors.green
                        : theme.colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      active
                          ? 'This membership plan is available.'
                          : 'This membership plan is currently inactive.',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Text(
            'Membership benefits',
            style: theme.textTheme.titleLarge,
          ),

          const SizedBox(height: 8),

          if (benefits.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No benefits have been configured for this plan.'),
            )
          else
            for (final benefit in benefits)
              _buildBenefit(benefit, theme),

          const SizedBox(height: 24),

          Text(
            'About this plan',
            style: theme.textTheme.titleMedium,
          ),

          const SizedBox(height: 8),

          const Text(
            'Review the benefits and terms associated with this membership '
                'before adding it to your cart. Any applicable discounts, credit, '
                'expiry rules, and redemption conditions must follow the terms '
                'implemented by Ayubo Organics.',
          ),

          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _adding || !active ? null : _addToCart,
            icon: _adding
                ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.add_shopping_cart),
            label: Text(
              _adding
                  ? 'Adding...'
                  : _added
                  ? 'Add another'
                  : 'Add to cart',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefit(
      Map<String, dynamic> benefit,
      ThemeData theme,
      ) {
    final code = _readString(benefit['benefit_code']);
    final description = _readString(
      benefit['description'],
      fallback: 'Membership benefit',
    );
    final configuration = _formatConfiguration(
      benefit['configuration_json'],
    );

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.check_circle_outline),
      title: Text(description),
      subtitle: [
        if (code.isNotEmpty) code,
        if (configuration.isNotEmpty) configuration,
      ].isEmpty
          ? null
          : Text(
        [
          if (code.isNotEmpty) code,
          if (configuration.isNotEmpty) configuration,
        ].join(' · '),
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}
