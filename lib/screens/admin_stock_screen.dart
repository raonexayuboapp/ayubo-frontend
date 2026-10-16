import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';
import '../utils/request_key.dart';
import 'admin_stock_history_screen.dart';

/// Stock of ONE variant, per location, with the three admin operations.
class AdminStockScreen extends StatefulWidget {
  final int variantId;
  final String title; // the SKU, shown while the screen loads
  const AdminStockScreen({super.key, required this.variantId, required this.title});

  @override
  State<AdminStockScreen> createState() => _AdminStockScreenState();
}

class _AdminStockScreenState extends State<AdminStockScreen> {
  Map<String, dynamic>? _data;
  List<Map<String, dynamic>> _locations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ApiService.instance;
      final results = await Future.wait<Object>([
        api.adminVariantStock(widget.variantId),
        api.adminStockLocations(),
      ]);
      if (!mounted) return;
      setState(() {
        _data = results[0] as Map<String, dynamic>;
        _locations = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (_data == null) {
        setState(() => _error = e.message);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _operate(String kind) async {
    final balances = (_data!['balances'] as List<dynamic>).cast<Map<String, dynamic>>();

    final message = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _StockDialog(
        kind: kind,
        variantId: widget.variantId,
        locations: _locations,
        balances: balances,
      ),
    );
    if (message == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    _load();
  }

  Future<void> _addLocation() async {
    final created = await showDialog<bool>(context: context, builder: (_) => const _NewLocationDialog());
    if (created == true) _load();
  }

  Widget _totalsCard(Map<String, dynamic> totals) {
    Widget cell(String label, num value, {bool bold = false}) => Expanded(
      child: Column(children: [
        Text(formatQuantity(value),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: bold ? FontWeight.bold : null)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(children: [
          cell('On hand', totals['on_hand'] as num),
          cell('Reserved', totals['reserved'] as num),
          cell('Available', totals['available'] as num, bold: true),
        ]),
      ),
    );
  }

  Widget _balanceTile(Map<String, dynamic> b) {
    return ListTile(
      key: ValueKey(b['location_id']),
      contentPadding: EdgeInsets.zero,
      title: Text('${b['code']} · ${b['name']}'),
      subtitle: Text('On hand ${formatQuantity(b['on_hand'] as num)} · Reserved ${formatQuantity(b['reserved'] as num)}'),
      trailing: Text(formatQuantity(b['available'] as num),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Widget _body() {
    if (_loading && _data == null) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      );
    }

    final data = _data!;
    final variant = data['variant'] as Map<String, dynamic>;
    final balances = (data['balances'] as List<dynamic>).cast<Map<String, dynamic>>();
    final totals = data['totals'] as Map<String, dynamic>;
    final tracks = variant['product_type'] == 'physical';
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text((variant['product_name'] as String?) ?? variant['sku'] as String, style: theme.textTheme.titleLarge),
          Text('SKU ${variant['sku']}'),
          const SizedBox(height: 16),
          if (!tracks)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('This product type (service, voucher or course) does not track stock.'),
              ),
            )
          else ...[
            _totalsCard(totals),
            const SizedBox(height: 16),
            if (_locations.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('No stock location exists yet. Add one (for example MAIN) before you record stock.'),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _addLocation,
                      icon: const Icon(Icons.add_business_outlined),
                      label: const Text('Add location'),
                    ),
                  ]),
                ),
              )
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(
                  onPressed: () => _operate('receive'),
                  icon: const Icon(Icons.add),
                  label: const Text('Receive'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _operate('adjust'),
                  icon: const Icon(Icons.tune),
                  label: const Text('Adjust'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _operate('count'),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Count'),
                ),
              ]),
            const SizedBox(height: 16),
            for (final b in balances) _balanceTile(b),
            const SizedBox(height: 8),
            Text(
              'Reserved stock is held for orders that are not paid yet. It is not available to other customers '
                  'and cannot be removed here.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final variant = _data?['variant'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: Text(variant == null ? widget.title : '${variant['sku']} · Stock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminStockHistoryScreen(variantId: widget.variantId, title: widget.title),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_business_outlined),
            tooltip: 'Add location',
            onPressed: _data == null ? null : _addLocation,
          ),
        ],
      ),
      body: _body(),
    );
  }
}

/// Receive, adjust or count. It owns its controller and its request key.
class _StockDialog extends StatefulWidget {
  final String kind; // receive | adjust | count
  final int variantId;
  final List<Map<String, dynamic>> locations; // never empty: the screen only offers the buttons when one exists
  final List<Map<String, dynamic>> balances;

  const _StockDialog({
    required this.kind,
    required this.variantId,
    required this.locations,
    required this.balances,
  });

  @override
  State<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<_StockDialog> {
  final _form = GlobalKey<FormState>();
  final _qty = TextEditingController();
  late int _locationId = widget.locations.first['id'] as int;
  bool _saving = false;
  String? _error;
  Map<String, String> _serverErrors = {};

  // One key per distinct request. The same request sent again (after a dropped connection) reuses its key,
  // a request with other values gets a new one.
  String? _key;
  String? _signature;

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  String get _title => switch (widget.kind) {
    'receive' => 'Receive stock',
    'adjust' => 'Adjust stock',
    _ => 'Count stock',
  };

  String get _label => switch (widget.kind) {
    'receive' => 'Quantity received',
    'adjust' => 'Change (+ or -)',
    _ => 'Counted on the shelf',
  };

  String get _helper => switch (widget.kind) {
    'receive' => 'Goods that arrived at this location.',
    'adjust' => 'Use a minus sign to remove, for example -2 for damaged goods.',
    _ => 'The system works out the difference to what is recorded.',
  };

  String get _field => switch (widget.kind) {
    'receive' => 'quantity',
    'adjust' => 'delta',
    _ => 'on_hand',
  };

  String _normalized(String? v) => (v ?? '').trim().replaceAll(',', '.').replaceFirst(RegExp(r'^\+'), '');

  num _recorded() {
    final match = widget.balances.where((b) => b['location_id'] == _locationId);
    return match.isEmpty ? 0 : match.first['on_hand'] as num;
  }

  String? _validate(String? v) {
    final s = _normalized(v);
    final negativeAllowed = widget.kind == 'adjust';

    if (!RegExp(negativeAllowed ? r'^-?\d{1,7}(\.\d{1,3})?$' : r'^\d{1,7}(\.\d{1,3})?$').hasMatch(s)) {
      return negativeAllowed
          ? 'Enter a number such as 5 or -2 (up to 3 decimals).'
          : 'Enter a number such as 5 or 2.5 (up to 3 decimals).';
    }

    final n = double.parse(s);
    if (widget.kind == 'receive' && n <= 0) return 'A receipt must be more than zero.';
    if (widget.kind == 'adjust' && n == 0) return 'An adjustment cannot be zero.';

    return null;
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _serverErrors = {};
    });
    if (!_form.currentState!.validate()) return;

    final qty = _normalized(_qty.text);
    final signature = '${widget.kind}|$_locationId|$qty';
    if (signature != _signature) {
      _signature = signature;
      _key = newRequestKey();
    }

    setState(() => _saving = true);

    try {
      // The quantity is sent as TEXT, so no floating-point rounding can change it on the way.
      final result = await ApiService.instance.adminStockOperation(widget.variantId, widget.kind, {
        'location_id': _locationId,
        _field: qty,
        'request_key': _key,
      });
      if (!mounted) return;

      Navigator.pop(
        context,
        result['already_applied'] == true
            ? 'This was already recorded.'
            : result['changed'] == false
            ? 'No change: the count already matched.'
            : 'Stock updated.',
      );
    } on ApiException catch (e) {
      if (!mounted) return;

      final errs = e.fieldErrors;
      final qtyError = errs['quantity'] ?? errs['delta'] ?? errs['on_hand'];
      setState(() {
        _serverErrors = {
          if (qtyError != null) 'qty': qtyError,
          if (errs['location_id'] != null) 'location': errs['location_id']!,
        };
        _error = errs.isEmpty ? e.message : (errs['variant'] ?? errs['request_key']);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_title),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(
              value: _locationId,
              isExpanded: true,
              decoration: InputDecoration(labelText: 'Location', errorText: _serverErrors['location']),
              items: [
                for (final l in widget.locations)
                  DropdownMenuItem(value: l['id'] as int, child: Text('${l['code']} · ${l['name']}')),
              ],
              onChanged: _saving ? null : (v) => setState(() => _locationId = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _qty,
              enabled: !_saving,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: _validate,
              forceErrorText: _serverErrors['qty'],
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(labelText: _label, helperText: _helper, helperMaxLines: 2),
            ),
            if (widget.kind == 'count')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Currently recorded here: ${formatQuantity(_recorded())}',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _NewLocationDialog extends StatefulWidget {
  const _NewLocationDialog();

  @override
  State<_NewLocationDialog> createState() => _NewLocationDialogState();
}

class _NewLocationDialogState extends State<_NewLocationDialog> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  bool _saving = false;
  String? _error;
  Map<String, String> _serverErrors = {};

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _serverErrors = {};
    });
    if (!_form.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      await ApiService.instance.adminCreateStockLocation(_code.text.trim().toUpperCase(), _name.text.trim());
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _serverErrors = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? e.message : null;
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New stock location'),
      content: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) => RegExp(r'^[A-Z][A-Z0-9_-]{1,39}$').hasMatch((v ?? '').trim().toUpperCase())
                ? null
                : '2 to 40 characters: letters, numbers, - and _',
            forceErrorText: _serverErrors['code'],
            decoration: const InputDecoration(labelText: 'Code', helperText: 'e.g. MAIN'),
          ),
          TextFormField(
            controller: _name,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (v) {
              final s = (v ?? '').trim();
              return s.isEmpty || s.length > 100 ? 'Name must be 1 to 100 characters.' : null;
            },
            forceErrorText: _serverErrors['name'],
            decoration: const InputDecoration(labelText: 'Name', helperText: 'e.g. Main warehouse'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create'),
        ),
      ],
    );
  }
}