import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/address_text.dart';
import '../utils/dates.dart';
import '../utils/money.dart';
import '../utils/receipt_download.dart';
import '../widgets/order_status_chip.dart';
import '../widgets/product_image.dart';
import '../widgets/prompt_dialog.dart';
import 'admin_refund_dialog.dart';

class AdminOrderDetailScreen extends StatefulWidget {
  final int orderId;
  final String? number;

  const AdminOrderDetailScreen({super.key, required this.orderId, this.number});

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  // ---------- data ----------

  Map<String, dynamic> get _o => _data!['order'] as Map<String, dynamic>;

  Map<String, dynamic> get _a => _data!['admin'] as Map<String, dynamic>;

  List<Map<String, dynamic>> _list(Map<String, dynamic> m, String key) =>
      ((m[key] as List<dynamic>?) ?? const []).cast<Map<String, dynamic>>();

  String get _status => _o['status'] as String;
  String get _pay => _o['payment_status'] as String;

  bool get _awaitingPayment => _status == 'received' && _pay == 'unpaid';

  bool get _canShip =>
      _pay == 'paid' && (_status == 'processing' || _status == 'shipped');

  bool get _canRefund => _pay == 'paid' || _pay == 'partially_refunded';

  /// The one manual status change that makes sense from here, or null.
  /// The server allows exactly these.
  String? get _nextStatus {
    if (_pay != 'paid') return null;

    return switch (_status) {
      'on_hold' => 'processing',
      'processing' || 'shipped' => 'delivered',
      _ => null,
    };
  }

  /// Paid minus refunded, from what is on screen.
  /// The server checks the real figure.
  int get _refundable {
    var paid = 0;

    for (final p in _list(_a, 'payments')) {
      if (p['status'] == 'paid') {
        paid += (p['amount_cents'] as num).toInt();
      }
    }

    var refunded = 0;

    for (final r in _list(_o, 'refunds')) {
      refunded += (r['amount_cents'] as num).toInt();
    }

    return paid - refunded;
  }

  // ---------- loading and actions ----------

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _msg(ApiException e) =>
      e.fieldErrors.isNotEmpty ? e.fieldErrors.values.join('\n') : e.message;

  String? _n(String? s) => s == null || s.isEmpty ? null : s;

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = _data == null;
        _error = null;
      });
    }

    try {
      final data = await ApiService.instance.adminGetOrder(widget.orderId);

      if (!mounted) return;

      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        if (_data == null) _error = e.message;
      });

      if (_data != null) _snack(e.message);
    }
  }

  /// Runs an action, shows its message, and reloads the order either way:
  /// it may have changed even when it failed.
  Future<void> _act(Future<String?> Function() action) async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      final message = await action();

      if (message != null && mounted) {
        _snack(message);
      }
    } on ApiException catch (e) {
      if (mounted) _snack(_msg(e));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }

    if (mounted) {
      await _load(silent: true);
    }
  }

  Future<bool> _confirm(String title, String message, String confirm) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirm),
          ),
        ],
      ),
    );

    return ok == true;
  }

  Future<void> _markPaid() async {
    final r = await showPrompt(
      context,
      title: 'Record a payment',
      message:
          'Use this when the customer paid outside the app (bank transfer, in the shop). The whole order is marked as paid.',
      confirmLabel: 'Mark as paid',
      fields: const [
        PromptField(
          key: 'reference',
          label: 'Reference (optional)',
          helper: 'For example the bank transfer reference',
          maxLength: 190,
        ),
        PromptField(key: 'note', label: 'Note (optional)', maxLength: 255),
      ],
    );

    if (r == null) return;

    await _act(() async {
      await ApiService.instance.adminMarkPaid(
        widget.orderId,
        reference: _n(r['reference']),
        note: _n(r['note']),
      );

      return 'The order is marked as paid.';
    });
  }

  Future<void> _cancel() async {
    final r = await showPrompt(
      context,
      title: 'Cancel this order?',
      message:
          'The reserved stock is released and any membership credit used is given back.',
      confirmLabel: 'Cancel order',
      fields: const [PromptField(key: 'reason', label: 'Reason (optional)')],
    );

    if (r == null) return;

    await _act(() async {
      await ApiService.instance.adminCancelOrder(
        widget.orderId,
        reason: _n(r['reason']),
      );

      return 'The order is cancelled.';
    });
  }

  Future<void> _addNote() async {
    final r = await showPrompt(
      context,
      title: 'Add a note',
      message: 'Only staff see notes. Customers never do.',
      confirmLabel: 'Save note',
      fields: const [
        PromptField(
          key: 'note',
          label: 'Note',
          required: true,
          maxLength: 500,
          maxLines: 4,
        ),
      ],
    );

    if (r == null) return;

    await _act(() async {
      await ApiService.instance.adminAddOrderNote(widget.orderId, r['note']!);

      return 'Note saved.';
    });
  }

  Future<void> _changeStatus() async {
    final next = _nextStatus;
    if (next == null) return;

    final message = _status == 'on_hold'
        ? 'Release this order for processing? Fix what held it first (for example adjust the stock): releasing does not sell any stock.'
        : 'Mark this order as delivered?';

    final r = await showPrompt(
      context,
      title: '${orderStatusLabel(_status)} → ${orderStatusLabel(next)}',
      message: message,
      confirmLabel: 'Change status',
      fields: const [
        PromptField(key: 'note', label: 'Note (optional)', maxLength: 500),
      ],
    );

    if (r == null) return;

    await _act(() async {
      await ApiService.instance.adminSetOrderStatus(
        widget.orderId,
        next,
        _n(r['note']),
      );

      return 'Status changed.';
    });
  }

  Future<void> _addParcel() async {
    final r = await showPrompt(
      context,
      title: 'Add a parcel',
      message:
          'The customer gets an email. Add every parcel of the order before marking any of them delivered.',
      confirmLabel: 'Add parcel',
      fields: const [
        PromptField(
          key: 'carrier',
          label: 'Carrier',
          required: true,
          initial: 'DHL',
          maxLength: 60,
        ),
        PromptField(
          key: 'tracking',
          label: 'Tracking number (optional)',
          maxLength: 100,
        ),
      ],
    );

    if (r == null) return;

    await _act(() async {
      await ApiService.instance.adminAddParcel(
        widget.orderId,
        r['carrier']!,
        _n(r['tracking']),
      );

      return 'Parcel added. The customer has been emailed.';
    });
  }

  Future<void> _deliverParcel(Map<String, dynamic> s) async {
    if (!await _confirm(
      'Mark as delivered?',
      'The parcel with ${s['carrier']} has arrived.',
      'Delivered',
    )) {
      return;
    }

    await _act(() async {
      await ApiService.instance.adminUpdateParcel(s['id'] as int, {
        'status': 'delivered',
      });

      return 'Parcel marked delivered.';
    });
  }

  Future<void> _editParcel(Map<String, dynamic> s) async {
    final r = await showPrompt(
      context,
      title: 'Edit parcel',
      confirmLabel: 'Save',
      fields: [
        PromptField(
          key: 'carrier',
          label: 'Carrier',
          required: true,
          initial: (s['carrier'] as String?) ?? '',
          maxLength: 60,
        ),
        PromptField(
          key: 'tracking',
          label: 'Tracking number',
          initial: (s['tracking_number'] as String?) ?? '',
          maxLength: 100,
        ),
      ],
    );

    if (r == null) return;

    await _act(() async {
      await ApiService.instance.adminUpdateParcel(s['id'] as int, {
        'carrier': r['carrier'],
        'tracking_number': _n(r['tracking']),
      });

      return 'Parcel saved.';
    });
  }

  Future<void> _refund() async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdminRefundDialog(
        orderId: widget.orderId,
        orderStatus: _status,
        refundableCents: _refundable,
        hasManualPayment: _list(
          _a,
          'payments',
        ).any((p) => p['provider'] == 'manual' && p['status'] == 'paid'),
      ),
    );

    if (result != null && mounted) {
      _snack(switch (result) {
        'refunded' => 'Refunded in full. The order is cancelled.',
        'partially_refunded' => 'Partly refunded.',
        _ => 'This refund was already done.',
      });
    }

    if (mounted) {
      await _load(
        silent: true,
      ); // A refund that failed may still have changed the order.
    }
  }

  Future<void> _resendVouchers() async {
    if (!await _confirm(
      'Send the codes again?',
      'The customer gets the voucher email once more.',
      'Send',
    )) {
      return;
    }

    await _act(() async {
      await ApiService.instance.adminResendVouchers(widget.orderId);

      return 'The email is queued.';
    });
  }

  // ---------- pieces of the screen ----------

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    bool small = false,
  }) {
    final theme = Theme.of(context);

    final style = bold
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : (small ? theme.textTheme.bodySmall : null);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }

  String _provider(String p) => switch (p) {
    'membership_credit' => 'Membership credit',
    'gift_voucher' => 'Gift voucher',
    'manual' => 'Bank transfer / in the shop',
    'dev' => 'Test payment',
    _ => p.replaceAll('_', ' '),
  };

  Widget _attention() {
    // The newest note on the order says why it is on hold.
    final notes = _list(_a, 'history').where((h) => h['note'] != null).toList();

    final reason = notes.isEmpty ? null : notes.last['note'] as String;

    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This order is paid and needs a person.',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (reason != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(reason),
              ),
          ],
        ),
      ),
    );
  }

  Widget _customer() {
    final c = _a['customer'] as Map<String, dynamic>?;

    if (c == null) return const SizedBox.shrink();

    return Card(
      child: ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text('${c['name']}  ·  ${c['number']}'),
        subtitle: SelectableText(
          [
            c['email'] as String,
            if (c['phone'] != null) c['phone'] as String,
          ].join('\n'),
        ),
        isThreeLine: c['phone'] != null,
      ),
    );
  }

  Widget _actions() {
    final hasVouchers = _list(_a, 'vouchers').isNotEmpty && _pay == 'paid';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => downloadReceipt(
                  context,
                  widget.orderId,
                  _o['number'] as String,
                  admin: true,
                ),
          icon: const Icon(Icons.download_outlined),
          label: const Text('Receipt'),
        ),

        if (_awaitingPayment)
          FilledButton.icon(
            onPressed: _busy ? null : _markPaid,
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Mark as paid'),
          ),

        if (_canShip)
          FilledButton.icon(
            onPressed: _busy ? null : _addParcel,
            icon: const Icon(Icons.local_shipping_outlined),
            label: const Text('Add parcel'),
          ),

        if (_nextStatus != null)
          OutlinedButton.icon(
            onPressed: _busy ? null : _changeStatus,
            icon: const Icon(Icons.swap_horiz),
            label: Text('Mark ${orderStatusLabel(_nextStatus!).toLowerCase()}'),
          ),

        OutlinedButton.icon(
          onPressed: _busy ? null : _addNote,
          icon: const Icon(Icons.edit_note),
          label: const Text('Add note'),
        ),

        if (hasVouchers)
          OutlinedButton.icon(
            onPressed: _busy ? null : _resendVouchers,
            icon: const Icon(Icons.forward_to_inbox_outlined),
            label: const Text('Resend codes'),
          ),

        if (_canRefund)
          OutlinedButton.icon(
            onPressed: _busy || _refundable <= 0 ? null : _refund,
            icon: const Icon(Icons.undo),
            label: const Text('Refund'),
          ),

        if (_awaitingPayment)
          TextButton(
            onPressed: _busy ? null : _cancel,
            child: const Text('Cancel order'),
          ),
      ],
    );
  }

  List<Widget> _items() {
    final theme = Theme.of(context);

    return [
      for (final i in _list(_o, 'items'))
        ListTile(
          key: ValueKey(i['id']),
          contentPadding: EdgeInsets.zero,
          leading: SizedBox(
            width: 48,
            height: 48,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ProductImage(url: i['image_url'] as String?),
            ),
          ),
          title: Text(
            i['name'] as String,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            [
              'SKU ${i['sku']}',
              '${formatQuantity(i['quantity'] as num)} × ${formatCents(i['unit_price_cents'] as int)}',
              if ((i['discount_cents'] as int) > 0)
                'discount −${formatCents(i['discount_cents'] as int)}',
            ].join(' · '),
          ),
          trailing: Text(
            formatCents(i['line_total_cents'] as int),
            style: theme.textTheme.titleSmall,
          ),
        ),
    ];
  }

  Widget _totals() {
    final t = _o['totals'] as Map<String, dynamic>;
    final discount = t['discount_cents'] as int;
    final shipping = t['shipping_cents'] as int;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row('Items', formatCents(t['subtotal_cents'] as int)),
            if (discount > 0) _row('Discount', '−${formatCents(discount)}'),
            if ((_o['addresses'] as Map<String, dynamic>)['shipping'] != null)
              _row('Shipping', shipping == 0 ? 'Free' : formatCents(shipping)),
            const Divider(height: 20),
            _row('Total', formatCents(t['total_cents'] as int), bold: true),
            const SizedBox(height: 4),
            for (final x in _list(t, 'tax'))
              _row(
                'incl. ${formatPercent(x['rate_percent'] as num)}% VAT (net ${formatCents(x['net_cents'] as int)})',
                formatCents(x['tax_cents'] as int),
                small: true,
              ),
          ],
        ),
      ),
    );
  }

  Widget _addressCard(String title, Map<String, dynamic> address) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          SelectableText(addressLines(address).join('\n')),
        ],
      ),
    ),
  );

  List<Widget> _parcels() {
    final parcels = _list(_a, 'shipments');

    if (parcels.isEmpty) return const [];

    return [
      _heading('Parcels'),
      for (final s in parcels)
        Card(
          key: ValueKey('s${s['id']}'),
          child: ListTile(
            leading: const Icon(Icons.local_shipping_outlined),
            title: Text((s['carrier'] as String?) ?? 'Parcel'),
            subtitle: SelectableText(
              [
                if (s['tracking_number'] != null)
                  'Tracking ${s['tracking_number']}',
                orderStatusLabel(s['status'] as String),
                if (s['shipped_at'] != null)
                  'shipped ${formatDate(s['shipped_at'] as String?)}',
                if (s['delivered_at'] != null)
                  'delivered ${formatDate(s['delivered_at'] as String?)}',
              ].join(' · '),
            ),
            trailing: PopupMenuButton<String>(
              enabled: !_busy,
              onSelected: (v) =>
                  v == 'delivered' ? _deliverParcel(s) : _editParcel(s),
              itemBuilder: (_) => [
                if (s['status'] == 'shipped')
                  const PopupMenuItem(
                    value: 'delivered',
                    child: Text('Mark delivered'),
                  ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit tracking'),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  List<Widget> _payments() {
    final payments = _list(_a, 'payments');
    final refunds = _list(_o, 'refunds');

    return [
      if (payments.isNotEmpty) ...[
        _heading('Payments'),
        for (final p in payments)
          ListTile(
            key: ValueKey('p${p['id']}'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(_provider(p['provider'] as String)),
            subtitle: SelectableText(
              [
                paymentStatusLabel(p['status'] as String),
                if (p['paid_at'] != null)
                  formatDateTime(p['paid_at'] as String?),
                if (p['reference'] != null) 'ref ${p['reference']}',
              ].join(' · '),
            ),
            trailing: Text(formatCents(p['amount_cents'] as int)),
          ),
      ],
      if (refunds.isNotEmpty) ...[
        _heading('Refunds'),
        for (final r in refunds)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.undo_outlined),
            title: Text(_provider(r['provider'] as String)),
            subtitle: Text(formatDateTime(r['created_at'] as String?)),
            trailing: Text('−${formatCents(r['amount_cents'] as int)}'),
          ),
      ],
    ];
  }

  List<Widget> _vouchers() {
    final vouchers = _list(_a, 'vouchers');

    if (vouchers.isEmpty) return const [];

    return [
      _heading('Vouchers and credit bought with this order'),
      for (final v in vouchers)
        ListTile(
          key: ValueKey('v${v['id']}'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(Icons.card_giftcard_outlined),
          title: Text('•••• ${v['suffix']}'),
          subtitle: Text(
            '${v['status']} · value ${formatCents(v['original_cents'] as int)}',
          ),
          trailing: Text('balance ${formatCents(v['balance_cents'] as int)}'),
        ),
    ];
  }

  List<Widget> _history() {
    final theme = Theme.of(context);

    return [
      _heading('History'),
      for (final h in _list(_a, 'history').reversed)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(orderStatusLabel(h['status'] as String)),
                  ),
                  Text(
                    formatDateTime(h['created_at'] as String?),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 22),
                child: Text(
                  [
                    h['by'] as String,
                    if (h['note'] != null) h['note'] as String,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final theme = Theme.of(context);
    final addresses = _o['addresses'] as Map<String, dynamic>;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Text(_o['number'] as String, style: theme.textTheme.titleLarge),
          Text(
            'Placed ${formatDateTime(_o['created_at'] as String?)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              OrderStatusChip(status: _status),
              OrderStatusChip(status: _pay, payment: true),
            ],
          ),
          if (_status == 'on_hold')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _attention(),
            ),
          const SizedBox(height: 12),
          _customer(),
          const SizedBox(height: 12),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(),
            ),
          _actions(),
          _heading('Items'),
          ..._items(),
          _heading('Total'),
          _totals(),
          if (addresses.isNotEmpty) _heading('Addresses'),
          if (addresses['shipping'] != null)
            _addressCard(
              'Delivery address',
              addresses['shipping'] as Map<String, dynamic>,
            ),
          if (addresses['billing'] != null)
            _addressCard(
              'Billing address',
              addresses['billing'] as Map<String, dynamic>,
            ),
          ..._parcels(),
          ..._payments(),
          ..._vouchers(),
          ..._history(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.number ?? 'Order')),
      body: _body(),
    );
  }
}
