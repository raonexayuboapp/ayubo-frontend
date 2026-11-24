import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../utils/money.dart';

/// The voucher amounts customers can buy. Staff type any amount; there is no VAT on vouchers.
class AdminVoucherAmountsScreen extends StatefulWidget {
  const AdminVoucherAmountsScreen({super.key});

  @override
  State<AdminVoucherAmountsScreen> createState() =>
      _AdminVoucherAmountsScreenState();
}

class _AdminVoucherAmountsScreenState extends State<AdminVoucherAmountsScreen> {
  List<Map<String, dynamic>> _amounts = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  String _msg(ApiException e) =>
      e.fieldErrors.isNotEmpty ? e.fieldErrors.values.join('\n') : e.message;

  Future<void> _load() async {
    setState(() {
      _loading = _amounts.isEmpty;
      _error = null;
    });

    try {
      final amounts = await ApiService.instance.adminVoucherAmounts();
      if (!mounted) return;

      setState(() {
        _amounts = amounts;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        if (_amounts.isEmpty) _error = e.message;
      });

      if (_amounts.isNotEmpty) _snack(e.message);
    }
  }

  Future<void> _add() async {
    final result = await showDialog<_NewVoucherAmountData>(
      context: context,
      builder: (_) => const _NewAmountDialog(),
    );

    if (result == null || !mounted) return;

    setState(() => _busy = true);

    try {
      await ApiService.instance.adminCreateVoucherAmount(
        result.cents,
        nameDe: result.nameDe,
        nameEn: result.nameEn,
      );

      if (mounted) {
        _snack('${formatCents(result.cents)} voucher added.');
      }
    } on ApiException catch (e) {
      if (mounted) _snack(_msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (mounted) await _load();
  }

  Future<void> _toggle(Map<String, dynamic> a, bool onSale) async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      await ApiService.instance.adminSetVoucherAmountOnSale(
        a['variant_id'] as int,
        onSale,
      );
    } on ApiException catch (e) {
      if (mounted) _snack(_msg(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }

    if (mounted) await _load();
  }

  Widget _body() {
    final l10n = AppLocalizations.of(context);
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            TextButton(
              onPressed: _load,
              child: Text(l10n?.adminRetry ?? 'Retry'),
            ),
          ],
        ),
      );
    }

    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            'These are the voucher amounts customers can buy on the Family page. The code is emailed, with no delivery '
            'and no VAT. Switching an amount off removes it from the shop. Vouchers already bought stay valid.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(),
            ),
          if (_amounts.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Center(
                child: Text(
                  l10n?.adminNone ??
                      'No voucher amounts yet. Add the first one.',
                ),
              ),
            ),
          for (final a in _amounts)
            Card(
              key: ValueKey(a['variant_id']),
              child: SwitchListTile(
                secondary: const Icon(Icons.card_giftcard_outlined),
                title: Text(
                  formatCents(a['price_cents'] as int),
                  style: theme.textTheme.titleMedium,
                ),
                subtitle: Text(
                  '${a['sold']} ${l10n?.adminSold ?? 'sold'} · ${a['on_sale'] == true ? (l10n?.adminOnSale ?? 'on sale') : (l10n?.adminInactive ?? 'not on sale')}',
                ),
                value: a['on_sale'] == true,
                onChanged: _busy ? null : (v) => _toggle(a, v),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.adminVoucherAmounts ?? 'Voucher amounts'),
      ),
      body: _body(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _add,
        icon: const Icon(Icons.add),
        label: Text(l10n?.adminNewAmount ?? 'New amount'),
      ),
    );
  }
}

class _NewVoucherAmountData {
  const _NewVoucherAmountData({
    required this.cents,
    required this.nameDe,
    required this.nameEn,
  });

  final int cents;
  final String nameDe;
  final String nameEn;
}

class _NewAmountDialog extends StatefulWidget {
  const _NewAmountDialog();

  @override
  State<_NewAmountDialog> createState() => _NewAmountDialogState();
}

class _NewAmountDialogState extends State<_NewAmountDialog> {
  final _form = GlobalKey<FormState>();

  final _amount = TextEditingController();
  final _nameEn = TextEditingController();
  final _nameDe = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _nameEn.dispose();
    _nameDe.dispose();
    super.dispose();
  }

  String? _validateAmount(String? v) {
    final cents = parseEuroToCents((v ?? '').trim());

    if (cents == null) return 'Enter an amount like 30 or 12.50.';

    return cents < 100 || cents > 1000000
        ? 'The amount must be from €1.00 to €10,000.00.'
        : null;
  }

  String? _validateName(String? value) {
    final name = (value ?? '').trim();

    if (name.isEmpty) return 'Please enter a product name.';
    if (name.length > 200) return 'Maximum 200 characters.';

    return null;
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;

    Navigator.pop(
      context,
      _NewVoucherAmountData(
        cents: parseEuroToCents(_amount.text.trim())!,
        nameDe: _nameDe.text.trim(),
        nameEn: _nameEn.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n?.adminNewAmount ?? 'New voucher amount'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: _validateAmount,
                decoration: InputDecoration(
                  labelText: '${l10n?.adminAmountValue ?? 'Amount'} (€)',
                  helperText:
                      'Customers pay this much and the voucher is worth this much. No VAT is charged.',
                  helperMaxLines: 3,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameEn,
                textCapitalization: TextCapitalization.sentences,
                validator: _validateName,
                decoration: InputDecoration(
                  labelText:
                      '${l10n?.adminProductName ?? 'Product name'} (${l10n?.adminEnglishTranslation ?? 'English'})',
                  hintText: 'Gift Voucher €30.00',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameDe,
                textCapitalization: TextCapitalization.sentences,
                validator: _validateName,
                decoration: InputDecoration(
                  labelText:
                      '${l10n?.adminProductName ?? 'Product name'} (${l10n?.adminGermanTranslation ?? 'German'})',
                  hintText: 'Geschenkgutschein 30,00 €',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n?.cancel ?? 'Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n?.adminCreate ?? 'Add'),
        ),
      ],
    );
  }
}
