import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/money.dart';
import '../widgets/image_manager.dart';
import '../widgets/loading_button.dart';
import 'admin_stock_screen.dart';

/// One editable variant. Existing variants keep their id, so saving updates them instead of adding copies.
class _VariantRow {
  final int? id;
  final TextEditingController sku;
  final TextEditingController price;
  final TextEditingController pack;
  final TextEditingController unit;
  final TextEditingController ean;
  bool active;
  Map<String, dynamic>? stock; // on_hand, reserved, available (saved variants only)

  _VariantRow({
    this.id,
    String sku = '',
    String price = '',
    String pack = '',
    String unit = '',
    String ean = '',
    this.active = true,
    this.stock,
  })  : sku = TextEditingController(text: sku),
        price = TextEditingController(text: price),
        pack = TextEditingController(text: pack),
        unit = TextEditingController(text: unit),
        ean = TextEditingController(text: ean);

  factory _VariantRow.fromJson(Map<String, dynamic> v) {
    final cents = v['price_cents'] as int;
    final packQty = v['pack_quantity'] as num?;
    return _VariantRow(
      id: v['id'] as int,
      sku: v['sku'] as String,
      price: '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}',
      pack: packQty == null ? '' : formatQuantity(packQty),
      unit: (v['unit'] as String?) ?? '',
      ean: (v['ean'] as String?) ?? '',
      active: v['active'] == true,
      stock: v['on_hand'] == null
          ? null
          : {'on_hand': v['on_hand'], 'reserved': v['reserved'], 'available': v['available_quantity']},
    );
  }

  void dispose() {
    sku.dispose();
    price.dispose();
    pack.dispose();
    unit.dispose();
    ean.dispose();
  }
}

class AdminProductFormScreen extends StatefulWidget {
  final int? productId; // null = create, otherwise edit
  const AdminProductFormScreen({super.key, this.productId});

  @override
  State<AdminProductFormScreen> createState() => _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends State<AdminProductFormScreen> {
  // ASSUMPTION: confirm these words with the supervisor (the schema stores them as free text).
  static const _types = ['physical', 'gift_voucher', 'course', 'service'];
  static const _statuses = ['draft', 'published', 'archived'];

  final _form = GlobalKey<FormState>();
  final _slug = TextEditingController();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _ingredients = TextEditingController();
  final _allergens = TextEditingController();

  String _type = 'physical';
  String _status = 'draft';
  int? _taxRateId;
  int? _originalTaxRateId; // what the product has stored (edit mode)
  final Set<int> _categoryIds = {};
  final List<_VariantRow> _variants = [];
  List<Map<String, dynamic>> _taxRates = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _images = [];
  List<int> _originalImageIds = [];

  // Not editable here, but kept so saving does not erase them (a translation is replaced as a whole).
  String? _seoTitle;
  String? _seoDescription;

  bool _loadingData = true;
  String? _loadError;
  bool _saving = false;
  String? _error;
  Map<String, String> _serverErrors = {};

  bool get _editing => widget.productId != null;

  List<int> get _imageIds => [for (final i in _images) i['id'] as int];

  /// Images are only sent when the admin changed them, so a stale form cannot overwrite another admin's change.
  bool get _imagesChanged {
    if (!_editing) return _images.isNotEmpty;
    final now = _imageIds;
    if (now.length != _originalImageIds.length) return true;
    for (var i = 0; i < now.length; i++) {
      if (now[i] != _originalImageIds[i]) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    for (final c in [_slug, _name, _desc, _ingredients, _allergens]) {
      c.dispose();
    }
    for (final v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final api = ApiService.instance;
      final results = await Future.wait<Object>([
        api.adminTaxRates(),
        api.adminCategories(),
        if (_editing) api.adminGetProduct(widget.productId!),
      ]);
      if (!mounted) return;

      final taxRates = [...(results[0] as List<Map<String, dynamic>>)];
      final categories = results[1] as List<Map<String, dynamic>>;

      if (_editing) {
        final p = results[2] as Map<String, dynamic>;
        // PHP encodes an empty translations object as [] (a list), so check the type first.
        final tr = p['translations'];
        final de = tr is Map<String, dynamic> ? tr['de'] as Map<String, dynamic>? : null;

        _slug.text = p['slug'] as String;
        _type = p['product_type'] as String;
        _status = p['status'] as String;
        _taxRateId = p['tax_rate_id'] as int;
        _originalTaxRateId = _taxRateId;
        _name.text = (de?['name'] as String?) ?? '';
        _desc.text = (de?['description'] as String?) ?? '';
        _ingredients.text = (de?['ingredients'] as String?) ?? '';
        _allergens.text = (de?['allergens'] as String?) ?? '';
        _seoTitle = de?['seo_title'] as String?;
        _seoDescription = de?['seo_description'] as String?;
        _categoryIds.addAll((p['category_ids'] as List<dynamic>).cast<int>());
        _images = [for (final i in (p['images'] as List<dynamic>)) Map<String, dynamic>.from(i as Map)];
        _originalImageIds = _imageIds;
        _variants.addAll((p['variants'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(_VariantRow.fromJson));

        // The product's own rate may have ended. Keep it in the list so the dropdown stays valid;
        // it is only sent to the server if the admin picks a different one.
        if (!taxRates.any((t) => t['id'] == _taxRateId)) {
          taxRates.add({
            'id': _taxRateId,
            'code': p['tax_rate_code'],
            'rate_percent': p['tax_rate_percent'],
            'ended': true,
          });
        }
      } else {
        if (taxRates.isNotEmpty) _taxRateId = taxRates.first['id'] as int;
        _variants.add(_VariantRow());
      }

      setState(() {
        _taxRates = taxRates;
        _categories = categories;
        _loadingData = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loadingData = false;
      });
    }
  }

  // ---------- validation (the server checks everything again) ----------

  String? _vSlug(String? v) {
    final s = (v ?? '').trim();
    return s.length <= 190 && RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(s)
        ? null
        : 'Lowercase letters and numbers separated by single hyphens.';
  }

  String? _vName(String? v) {
    final s = (v ?? '').trim();
    return s.isEmpty || s.length > 190 ? 'Name must be 1 to 190 characters.' : null;
  }

  String? _vMax(String? v, int max) =>
      (v ?? '').trim().length > max ? 'Maximum $max characters.' : null;

  String? _vSku(String? v) => RegExp(r'^[A-Za-z0-9][A-Za-z0-9._/-]{0,99}$').hasMatch((v ?? '').trim())
      ? null
      : 'Letters, numbers and . _ / - (maximum 100).';

  String? _vPrice(String? v) =>
      parseEuroToCents(v ?? '') == null ? 'Enter an amount like 6.99.' : null;

  String? _vPack(String? v) {
    final s = (v ?? '').trim().replaceAll(',', '.');
    if (s.isEmpty) return null;
    final ok = RegExp(r'^\d{1,9}(\.\d{1,3})?$').hasMatch(s) && double.parse(s) >= 0.001;
    return ok ? null : 'A number from 0.001 with at most 3 decimals.';
  }

  String? _vEan(String? v) {
    final s = (v ?? '').trim();
    return s.isEmpty || RegExp(r'^[0-9]{8,14}$').hasMatch(s) ? null : '8 to 14 digits.';
  }

  // ---------- variants and stock ----------

  void _addVariant() => setState(() => _variants.add(_VariantRow()));

  /// Only rows that were never saved can be removed. A saved variant is retired with its Active switch,
  /// because orders may already reference it.
  void _removeVariant(int i) {
    final row = _variants[i];
    setState(() => _variants.removeAt(i));
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  Future<void> _openStock(_VariantRow v) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminStockScreen(variantId: v.id!, title: v.sku.text)),
    );
    // Show the new numbers without touching anything the admin has typed in this form.
    try {
      final data = await ApiService.instance.adminVariantStock(v.id!);
      if (mounted) setState(() => v.stock = data['totals'] as Map<String, dynamic>);
    } on ApiException {
      // the old numbers stay
    }
  }

  String _stockText(Map<String, dynamic> s) =>
      '${formatQuantity(s['on_hand'] as num)} on hand · ${formatQuantity(s['reserved'] as num)} reserved · '
          '${formatQuantity(s['available'] as num)} available';

  // ---------- save ----------

  bool _isFieldKey(String k) =>
      const {'slug', 'product_type', 'status', 'tax_rate_id'}.contains(k) ||
          k.startsWith('translations.de.') ||
          RegExp(r'^variants\.\d+\.').hasMatch(k);

  Future<void> _save() async {
    setState(() {
      _error = null;
      _serverErrors = {};
    });
    if (!_form.currentState!.validate()) return;
    if (_status == 'published' && !_variants.any((v) => v.active)) {
      setState(() => _error = 'A published product needs at least one active variant.');
      return;
    }

    setState(() => _saving = true);

    String? orNull(String s) => s.trim().isEmpty ? null : s.trim();

    final body = <String, dynamic>{
      'slug': _slug.text.trim(),
      'product_type': _type,
      'status': _status,
      // An unchanged rate is not sent: a product whose rate has ended can still be edited.
      if (!_editing || _taxRateId != _originalTaxRateId) 'tax_rate_id': _taxRateId,
      'translations': {
        'de': {
          'name': _name.text.trim(),
          'description': orNull(_desc.text),
          'ingredients': orNull(_ingredients.text),
          'allergens': orNull(_allergens.text),
          'seo_title': _seoTitle,
          'seo_description': _seoDescription,
        },
      },
      'category_ids': _categoryIds.toList(),
      'variants': [
        for (final v in _variants)
          {
            if (v.id != null) 'id': v.id,
            'sku': v.sku.text.trim(),
            'price_cents': parseEuroToCents(v.price.text)!, // safe: validate() accepted it
            'pack_quantity': v.pack.text.trim().isEmpty ? null : v.pack.text.trim().replaceAll(',', '.'),
            'unit': orNull(v.unit.text),
            'ean': orNull(v.ean.text),
            'active': v.active,
          },
      ],
      if (_imagesChanged) 'media_ids': _imageIds,
    };

    try {
      if (_editing) {
        await ApiService.instance.adminUpdateProduct(widget.productId!, body);
      } else {
        await ApiService.instance.adminCreateProduct(body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      final errs = e.fieldErrors;
      final general = errs.entries.where((x) => !_isFieldKey(x.key)).map((x) => x.value).join('\n');
      setState(() {
        _serverErrors = errs;
        _error = errs.isEmpty ? e.message : (general.isEmpty ? null : general);
        _saving = false;
      });
    }
  }

  // ---------- UI ----------

  Widget _text(
      String serverKey,
      String label,
      TextEditingController c,
      String? Function(String?) validator, {
        int maxLines = 1,
        TextInputType? type,
        String? helper,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        keyboardType: type,
        textInputAction: maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: validator,
        forceErrorText: _serverErrors[serverKey],
        decoration: InputDecoration(labelText: label, helperText: helper),
      ),
    );
  }

  Widget _variantCard(int i) {
    final v = _variants[i];
    const money = TextInputType.numberWithOptions(decimal: true);
    String? server(String f) => _serverErrors['variants.$i.$f'];

    return Card(
      key: ObjectKey(v),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: v.sku,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: _vSku,
                forceErrorText: server('sku'),
                decoration: const InputDecoration(labelText: 'SKU'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: v.price,
                keyboardType: money,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: _vPrice,
                forceErrorText: server('price_cents'),
                decoration: const InputDecoration(labelText: 'Price (€)', helperText: 'incl. VAT'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextFormField(
                controller: v.pack,
                keyboardType: money,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: _vPack,
                forceErrorText: server('pack_quantity'),
                decoration: const InputDecoration(labelText: 'Pack size'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: v.unit,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (x) => _vMax(x, 20),
                forceErrorText: server('unit'),
                decoration: const InputDecoration(labelText: 'Unit (g, ml...)'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          TextFormField(
            controller: v.ean,
            keyboardType: TextInputType.number,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: _vEan,
            forceErrorText: server('ean'),
            decoration: const InputDecoration(labelText: 'EAN (optional)'),
          ),
          if (v.id != null && _type == 'physical' && v.stock != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Stock: ${_stockText(v.stock!)}', style: Theme.of(context).textTheme.bodySmall),
                  TextButton.icon(
                    onPressed: () => _openStock(v),
                    icon: const Icon(Icons.warehouse_outlined),
                    label: const Text('Manage stock'),
                  ),
                ]),
              ),
            ),
          Row(children: [
            Expanded(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: v.active,
                onChanged: (x) => setState(() => v.active = x),
              ),
            ),
            if (v.id == null)
              IconButton(
                tooltip: 'Remove variant',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _removeVariant(i),
              ),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loadingData) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_loadError!),
            TextButton(
              onPressed: () {
                setState(() {
                  _loadingData = true;
                  _loadError = null;
                });
                _init();
              },
              child: const Text('Retry'),
            ),
          ]),
        ),
      );
    }

    final endedRateSelected = _taxRates.any((t) => t['id'] == _taxRateId && t['ended'] == true);

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit product' : 'New product')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _text('slug', 'Slug (URL name)', _slug, _vSlug, helper: 'e.g. ceylon-zimt'),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<String>(
                value: _type,
                decoration: InputDecoration(labelText: 'Type', errorText: _serverErrors['product_type']),
                items: [for (final t in _types) DropdownMenuItem(value: t, child: Text(t.replaceAll('_', ' ')))],
                onChanged: (v) => setState(() => _type = v!),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<String>(
                value: _status,
                decoration: InputDecoration(
                  labelText: 'Status',
                  helperText: 'Only "published" products are visible to customers. '
                      'Publishing needs a text and an active variant.',
                  helperMaxLines: 3,
                  errorText: _serverErrors['status'],
                ),
                items: [for (final s in _statuses) DropdownMenuItem(value: s, child: Text(s))],
                onChanged: (v) => setState(() => _status = v!),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<int>(
                value: _taxRateId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Tax rate',
                  helperText: endedRateSelected
                      ? 'This rate has ended. It still works for this product, but a current rate should replace it.'
                      : null,
                  helperMaxLines: 3,
                  errorText: _serverErrors['tax_rate_id'],
                ),
                validator: (v) => v == null ? 'Choose a tax rate.' : null,
                items: [
                  for (final t in _taxRates)
                    DropdownMenuItem(
                      value: t['id'] as int,
                      child: Text('${t['code']} (${t['rate_percent']}%)${t['ended'] == true ? ' · ended' : ''}'),
                    ),
                ],
                onChanged: (v) => setState(() => _taxRateId = v),
              ),
            ),
            const Divider(height: 32),
            Text('text', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _text('translations.de.name', 'Name', _name, _vName),
            _text('translations.de.description', 'Description (optional)', _desc, (v) => _vMax(v, 20000),
                maxLines: 4),
            _text('translations.de.ingredients', 'Ingredients (optional)', _ingredients, (v) => _vMax(v, 5000),
                maxLines: 3),
            _text('translations.de.allergens', 'Allergens (optional)', _allergens, (v) => _vMax(v, 5000),
                maxLines: 2),
            const Divider(height: 32),
            Text('Images', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'The first image is the main image. Removing an image only takes it off this product.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ImageManager(images: _images, onChanged: (list) => setState(() => _images = list)),
            if (_categories.isNotEmpty) ...[
              const Divider(height: 32),
              Text('Categories', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final c in _categories)
                  FilterChip(
                    label: Text('${c['name']}${c['active'] == true ? '' : ' (hidden)'}'),
                    selected: _categoryIds.contains(c['id']),
                    onSelected: (on) => setState(() {
                      final id = c['id'] as int;
                      on ? _categoryIds.add(id) : _categoryIds.remove(id);
                    }),
                  ),
              ]),
            ],
            const Divider(height: 32),
            Text('Variants', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('A variant is a pack size with its own SKU and price. Retire one with its Active switch.',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            for (var i = 0; i < _variants.length; i++) _variantCard(i),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addVariant,
                icon: const Icon(Icons.add),
                label: const Text('Add variant'),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 16),
            LoadingButton(label: _editing ? 'Save changes' : 'Create product', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}