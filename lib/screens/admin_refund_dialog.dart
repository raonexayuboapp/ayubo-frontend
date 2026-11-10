import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';
import '../utils/request_key.dart';

/// Refunds an order, in full or in part. It makes the request itself and stays open while it runs, so a failed
/// try can be repeated with the SAME request key: the server then knows it is the same refund, never a second one.
/// Pops with the server's answer ("refunded", "partially_refunded" or "already_applied"), or null on cancel.
class AdminRefundDialog extends StatefulWidget {
  final int orderId;
  final String orderStatus;
  final int refundableCents;
  final bool hasManualPayment;

  const AdminRefundDialog({
    super.key,
    required this.orderId,
    required this.orderStatus,
    required this.refundableCents,
    required this.hasManualPayment,
  });

  @override
  State<AdminRefundDialog> createState() => _AdminRefundDialogState();
}

class _AdminRefundDialogState extends State<AdminRefundDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  final _reference = TextEditingController();
  final String _key = newRequestKey(
    24,
  ); // one key for this dialog: a retry is recognised as the same refund

  bool _full = true;
  // Goods that were not shipped are back on the shelf by definition; shipped ones are only restocked on purpose.
  late bool _restock = !const {
    'shipped',
    'delivered',
  }.contains(widget.orderStatus);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    _reference.dispose();
    super.dispose();
  }

  String? _vAmount(String? v) {
    final cents = parseEuroToCents((v ?? '').trim());
    if (cents == null || cents < 1) return 'Enter an amount like 5 or 5.90.';
    if (cents >= widget.refundableCents) {
      return 'Must be less than ${formatCents(widget.refundableCents)}. Use a full refund to refund everything.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final body = <String, dynamic>{
      'request_key': _key,
      if (_full)
        'full': true
      else
        'amount_cents': parseEuroToCents(
          _amount.text.trim(),
        )!, // safe: validate() accepted it
      if (_reason.text.trim().isNotEmpty) 'reason': _reason.text.trim(),
      if (_full) 'restock': _restock,
      if (widget.hasManualPayment && _reference.text.trim().isNotEmpty)
        'reference': _reference.text.trim(),
    };

    try {
      final result = await ApiService.instance.adminRefund(
        widget.orderId,
        body,
      );
      if (!mounted) return;
      Navigator.pop(context, result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.fieldErrors.isNotEmpty
            ? e.fieldErrors.values.join('\n')
            : e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_busy, // do not leave while the refund is being sent
      child: AlertDialog(
        title: const Text('Refund'),
        content: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Can still be refunded: ${formatCents(widget.refundableCents)}',
                ),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Full refund')),
                    ButtonSegment(value: false, label: Text('Part of it')),
                  ],
                  selected: {_full},
                  onSelectionChanged: _busy
                      ? null
                      : (s) => setState(() => _full = s.first),
                ),
                const SizedBox(height: 12),
                if (_full) ...[
                  Text(
                    'Everything that is left is refunded and the order is cancelled. '
                    'Vouchers and credit bought with it are withdrawn (only if none was used). '
                    'Loyalty points are taken back. Credit paid with comes back as credit.',
                    style: theme.textTheme.bodySmall,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Put the goods back into stock'),
                    subtitle: Text(
                      const {
                            'shipped',
                            'delivered',
                          }.contains(widget.orderStatus)
                          ? 'This order was shipped. Switch on only when the goods are back.'
                          : 'The order was not shipped.',
                    ),
                    value: _restock,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _restock = v),
                  ),
                ] else
                  TextFormField(
                    controller: _amount,
                    enabled: !_busy,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _vAmount,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    decoration: const InputDecoration(
                      labelText: 'Amount (€)',
                      helperText: 'Money goes back first, credit last.',
                    ),
                  ),
                TextFormField(
                  controller: _reason,
                  enabled: !_busy,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                  ),
                ),
                if (widget.hasManualPayment)
                  TextFormField(
                    controller: _reference,
                    enabled: !_busy,
                    maxLength: 190,
                    decoration: const InputDecoration(
                      labelText: 'Bank reference (optional)',
                      helperText:
                          'Money paid by bank transfer or in the shop is returned by you, outside the app.',
                      helperMaxLines: 3,
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_error == null ? 'Refund' : 'Try again'),
          ),
        ],
      ),
    );
  }
}
