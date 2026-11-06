import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';
import '../utils/request_key.dart';
import 'admin_stock_history_screen.dart';

typedef StockData = Map<String, dynamic>;

/// Stock of ONE variant, per location, with the three admin operations.
class AdminStockScreen extends StatefulWidget {
  final int variantId;
  final String title; // the SKU, shown while the screen loads
  const AdminStockScreen({super.key, required this.variantId, required this.title});

  @override
  State<AdminStockScreen> createState() => _AdminStockScreenState();
}

class _AdminStockScreenState extends State<AdminStockScreen> {
  StockData? _data;
  List<StockData> _locations = [];
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
        _data = results[0] as StockData;
        _locations = (results[1] as List<dynamic>).cast<StockData>();
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
    final balances = (_data!['balances'] as List<dynamic>).cast<StockData>();

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

  Widget _totalsCard(StockData totals) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;

    Widget cell(String label, num value, {bool isHighlight = false}) => Expanded(
          child: Column(
            children: [
              Text(
                formatQuantity(value),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
                  color: isHighlight ? goldColor : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          cell('On hand', totals['on_hand'] as num),
          cell('Reserved', totals['reserved'] as num),
          cell('Available', totals['available'] as num, isHighlight: true),
        ],
      ),
    );
  }

  Widget _balanceTile(StockData b) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;

    return ListTile(
      key: ValueKey(b['location_id']),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      title: Text(
        '${b['code']} · ${b['name']}',
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'On hand ${formatQuantity(b['on_hand'] as num)} · Reserved ${formatQuantity(b['reserved'] as num)}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      trailing: Text(
        formatQuantity(b['available'] as num),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: goldColor,
        ),
      ),
    );
  }

  Widget _body() {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;

    if (_loading && _data == null) {
      return Center(child: CircularProgressIndicator(color: goldColor, strokeWidth: 2));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: TextButton.styleFrom(foregroundColor: goldColor),
              ),
            ],
          ),
        ),
      );
    }

    final data = _data!;
    final variant = data['variant'] as StockData;
    final balances = (data['balances'] as List<dynamic>).cast<StockData>();
    final totals = data['totals'] as StockData;
    final tracks = variant['product_type'] == 'physical';

    return RefreshIndicator(
      onRefresh: _load,
      color: goldColor,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            (variant['product_name'] as String?) ?? variant['sku'] as String,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            'SKU ${variant['sku']}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          if (!tracks)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
              ),
              child: Text(
                'This product type (service, voucher or course) does not track stock.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            )
          else ...[
            _totalsCard(totals),
            const SizedBox(height: 16),
            if (_locations.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No stock location exists yet. Add one (for example MAIN) before you record stock.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _addLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: goldColor,
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add_business_outlined, size: 18),
                      label: const Text('Add location', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _operate('receive'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: goldColor,
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Receive', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _operate('adjust'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: goldColor),
                        foregroundColor: goldColor,
                      ),
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('Adjust'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _operate('count'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: goldColor),
                        foregroundColor: goldColor,
                      ),
                      icon: const Icon(Icons.fact_check_outlined, size: 18),
                      label: const Text('Count'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            for (final b in balances) _balanceTile(b),
            const SizedBox(height: 12),
            Text(
              'Reserved stock is held for orders that are not paid yet. It is not available to other customers '
              'and cannot be removed here.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final variant = _data?['variant'] as StockData?;

    return Scaffold(
      appBar: AppBar(
        title: Text(variant == null ? widget.title : '${variant['sku']} · Stock'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, size: 20),
            tooltip: 'History',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminStockHistoryScreen(variantId: widget.variantId, title: widget.title),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_business_outlined, size: 20),
            tooltip: 'Add location',
            onPressed: _data == null ? null : _addLocation,
          ),
        ],
      ),
      body: _body(),
    );
  }
}

// ---------------------------------------------------------------------------

class _StockDialog extends StatefulWidget {
  final String kind;
  final int variantId;
  final List<StockData> locations;
  final List<StockData> balances;

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
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        _title,
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    child: Text(
                      'Currently recorded here: ${formatQuantity(_recorded())}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: goldColor,
            elevation: 0,
          ),
          child: _saving
              ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: goldColor))
              : const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
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
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'New stock location',
        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            const SizedBox(height: 12),
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
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error, fontSize: 13)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: goldColor,
            elevation: 0,
          ),
          child: _saving
              ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: goldColor))
              : const Text('Create', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}