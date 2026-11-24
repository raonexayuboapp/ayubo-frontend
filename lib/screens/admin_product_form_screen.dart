import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../utils/localized_content.dart';
import '../utils/money.dart';
import '../widgets/image_manager.dart';
import '../widgets/loading_button.dart';
import 'admin_stock_screen.dart';

typedef ProductFormData = Map<String, dynamic>;

/// One editable variant. Existing variants keep their id, so saving updates
/// them instead of adding duplicates.
class _VariantRow {
  final int? id;
  final TextEditingController sku;
  final TextEditingController price;
  final TextEditingController pack;
  final TextEditingController unit;
  final TextEditingController ean;

  bool active;
  ProductFormData? stock;

  _VariantRow({
    this.id,
    String sku = '',
    String price = '',
    String pack = '',
    String unit = '',
    String ean = '',
    this.active = true,
    this.stock,
  }) : sku = TextEditingController(text: sku),
       price = TextEditingController(text: price),
       pack = TextEditingController(text: pack),
       unit = TextEditingController(text: unit),
       ean = TextEditingController(text: ean);

  factory _VariantRow.fromJson(ProductFormData v) {
    final cents = (v['price_cents'] as num).toInt();
    final packQty = v['pack_quantity'] as num?;

    return _VariantRow(
      id: (v['id'] as num).toInt(),
      sku: (v['sku'] as String?) ?? '',
      price: '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}',
      pack: packQty == null ? '' : formatQuantity(packQty),
      unit: (v['unit'] as String?) ?? '',
      ean: (v['ean'] as String?) ?? '',
      active: v['active'] == true,
      stock: v['on_hand'] == null
          ? null
          : {
              'on_hand': v['on_hand'],
              'reserved': v['reserved'],
              'available': v['available_quantity'],
            },
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
  final int? productId;

  const AdminProductFormScreen({super.key, this.productId});

  @override
  State<AdminProductFormScreen> createState() => _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends State<AdminProductFormScreen> {
  static const _types = ['physical', 'gift_voucher', 'course', 'service'];

  static const _statuses = ['draft', 'published', 'archived'];

  final _form = GlobalKey<FormState>();

  final _slug = TextEditingController();

  // German translation.
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _ingredients = TextEditingController();
  final _allergens = TextEditingController();

  // English translation.
  final _nameEn = TextEditingController();
  final _descEn = TextEditingController();
  final _ingredientsEn = TextEditingController();
  final _allergensEn = TextEditingController();

  // Product discount UI and preview state.
  final _discountValue = TextEditingController();
  bool _discountEnabled = false;
  String _discountType = 'percentage';

  // Retained for displaying the existing-discount removal notice.
  // Existing discount loading/saving requires the backend contract.
  Map<String, String>? _originalDiscount;

  String _type = 'physical';
  String _status = 'draft';

  int? _taxRateId;
  int? _originalTaxRateId;

  final Set<int> _categoryIds = {};
  final List<_VariantRow> _variants = [];

  List<ProductFormData> _taxRates = [];
  List<ProductFormData> _categories = [];
  List<ProductFormData> _images = [];

  List<int> _originalImageIds = [];

  // SEO translations.
  String? _seoTitle;
  String? _seoDescription;
  String? _seoTitleEn;
  String? _seoDescriptionEn;

  bool _hadEnglishTranslation = false;

  bool _loadingData = true;
  String? _loadError;

  bool _saving = false;
  String? _error;

  Map<String, String> _serverErrors = {};

  bool get _editing => widget.productId != null;

  List<int> get _imageIds => [
    for (final image in _images) (image['id'] as num).toInt(),
  ];

  bool get _imagesChanged {
    if (!_editing) return _images.isNotEmpty;

    final now = _imageIds;

    if (now.length != _originalImageIds.length) return true;

    for (var i = 0; i < now.length; i++) {
      if (now[i] != _originalImageIds[i]) return true;
    }

    return false;
  }

  bool get _hasEnglishContent =>
      _nameEn.text.trim().isNotEmpty ||
      _descEn.text.trim().isNotEmpty ||
      _ingredientsEn.text.trim().isNotEmpty ||
      _allergensEn.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    for (final controller in [
      _slug,
      _name,
      _desc,
      _ingredients,
      _allergens,
      _nameEn,
      _descEn,
      _ingredientsEn,
      _allergensEn,
      _discountValue,
    ]) {
      controller.dispose();
    }

    for (final variant in _variants) {
      variant.dispose();
    }

    super.dispose();
  }

  Future<void> _init() async {
    try {
      final api = ApiService.instance;

      final results = await Future.wait<Object>([
        api.adminTaxRates(),
        api.adminCategories(lang: currentAppLocale),
        if (_editing) api.adminGetProduct(widget.productId!),
      ]);

      if (!mounted) return;

      final taxRates = (results[0] as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      final categories = (results[1] as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      if (_editing) {
        final p = Map<String, dynamic>.from(results[2] as Map);

        // Read translations safely, regardless of the runtime map type.
        final rawTranslations = p['translations'];

        final translations = rawTranslations is Map
            ? Map<String, dynamic>.from(rawTranslations)
            : <String, dynamic>{};

        final deRaw = translations['de'];
        final enRaw = translations['en'];

        final de = deRaw is Map
            ? Map<String, dynamic>.from(deRaw)
            : <String, dynamic>{};

        final en = enRaw is Map
            ? Map<String, dynamic>.from(enRaw)
            : <String, dynamic>{};

        _hadEnglishTranslation = en.isNotEmpty;

        _slug.text = (p['slug'] as String?) ?? '';

        _type = (p['product_type'] as String?) ?? 'physical';

        _status = (p['status'] as String?) ?? 'draft';

        _taxRateId = (p['tax_rate_id'] as num?)?.toInt();
        _originalTaxRateId = _taxRateId;

        // German translation.
        _name.text = (de['name'] as String?) ?? '';
        _desc.text = (de['description'] as String?) ?? '';
        _ingredients.text = (de['ingredients'] as String?) ?? '';
        _allergens.text = (de['allergens'] as String?) ?? '';

        _seoTitle = de['seo_title'] as String?;
        _seoDescription = de['seo_description'] as String?;

        // English translation.
        _nameEn.text = (en['name'] as String?) ?? '';
        _descEn.text = (en['description'] as String?) ?? '';
        _ingredientsEn.text = (en['ingredients'] as String?) ?? '';
        _allergensEn.text = (en['allergens'] as String?) ?? '';

        _seoTitleEn = en['seo_title'] as String?;
        _seoDescriptionEn = en['seo_description'] as String?;

        final rawCategoryIds = p['category_ids'] as List? ?? [];

        _categoryIds.addAll(rawCategoryIds.map((id) => (id as num).toInt()));

        final rawImages = p['images'] as List? ?? [];

        _images = [
          for (final image in rawImages)
            Map<String, dynamic>.from(image as Map),
        ];

        _originalImageIds = _imageIds;

        final rawVariants = p['variants'] as List? ?? [];

        _variants.addAll(
          rawVariants.map(
            (variant) =>
                _VariantRow.fromJson(Map<String, dynamic>.from(variant as Map)),
          ),
        );

        if (_taxRateId != null && !taxRates.any((t) => t['id'] == _taxRateId)) {
          taxRates.add({
            'id': _taxRateId,
            'code': p['tax_rate_code'],
            'rate_percent': p['tax_rate_percent'],
            'ended': true,
          });
        }
      } else {
        if (taxRates.isNotEmpty) {
          _taxRateId = (taxRates.first['id'] as num).toInt();
        }

        _variants.add(_VariantRow());
      }

      if (!mounted) return;

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
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadError = 'Unable to load product data: $e';
        _loadingData = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  String? _vSlug(String? value) {
    final s = (value ?? '').trim();

    return s.length <= 190 && RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(s)
        ? null
        : 'Lowercase letters and numbers separated by single hyphens.';
  }

  String? _vName(String? value) {
    final s = (value ?? '').trim();

    return s.isEmpty || s.length > 190
        ? 'Name must be 1 to 190 characters.'
        : null;
  }

  String? _vEnglishName(String? value) {
    final s = (value ?? '').trim();

    if (s.isEmpty && !_hasEnglishContent && !_hadEnglishTranslation) {
      return null;
    }

    return s.isEmpty || s.length > 190
        ? 'Enter an English name between 1 and 190 characters.'
        : null;
  }

  String? _vMax(String? value, int max) {
    return (value ?? '').trim().length > max
        ? 'Maximum $max characters.'
        : null;
  }

  String? _vSku(String? value) {
    return RegExp(
          r'^[A-Za-z0-9][A-Za-z0-9._/-]{0,99}$',
        ).hasMatch((value ?? '').trim())
        ? null
        : 'Letters, numbers and . _ / - (maximum 100).';
  }

  String? _vPrice(String? value) {
    return parseEuroToCents(value ?? '') == null
        ? 'Enter an amount like 6.99.'
        : null;
  }

  String? _vPack(String? value) {
    final s = (value ?? '').trim().replaceAll(',', '.');

    if (s.isEmpty) return null;

    final valid =
        RegExp(r'^\d{1,9}(\.\d{1,3})?$').hasMatch(s) &&
        double.parse(s) >= 0.001;

    return valid ? null : 'A number from 0.001 with at most 3 decimals.';
  }

  String? _vEan(String? value) {
    final s = (value ?? '').trim();

    return s.isEmpty || RegExp(r'^[0-9]{8,14}$').hasMatch(s)
        ? null
        : '8 to 14 digits.';
  }

  // ---------------------------------------------------------------------------
  // Discount calculations and preview
  // ---------------------------------------------------------------------------

  /// Normalises a discount value without relying on floating-point arithmetic.
  /// Example: 15.5 becomes 15.50.
  String? _normaliseDiscountValue(String raw) {
    final value = raw.trim().replaceAll(',', '.');

    if (!RegExp(r'^\d{1,10}(?:\.\d{1,2})?$').hasMatch(value)) {
      return null;
    }

    final parts = value.split('.');
    final whole = int.tryParse(parts[0]);

    if (whole == null) return null;

    final decimals = parts.length == 1 ? '00' : parts[1].padRight(2, '0');

    return '$whole.$decimals';
  }

  int? _discountValueHundredths(String raw) {
    final normalised = _normaliseDiscountValue(raw);

    if (normalised == null) return null;

    final parts = normalised.split('.');
    final whole = int.parse(parts[0]);
    final decimals = int.parse(parts[1]);

    return whole * 100 + decimals;
  }

  String? _vDiscountValue(String? raw) {
    if (!_discountEnabled) return null;

    final value = _discountValueHundredths(raw ?? '');

    if (value == null) {
      return 'Enter a valid amount with up to 2 decimal places.';
    }

    if (value <= 0) {
      return 'The discount must be greater than zero.';
    }

    if (_discountType == 'percentage' && value > 10000) {
      return 'Percentage discount cannot exceed 100%.';
    }

    if (_discountType == 'fixed' && value > 100000000) {
      return 'Fixed discount cannot exceed €1,000,000.00.';
    }

    return null;
  }

  int _discountForVariant(int originalCents) {
    if (!_discountEnabled || originalCents <= 0) return 0;

    final value = _discountValueHundredths(_discountValue.text);

    if (value == null || value <= 0) return 0;

    int discountCents;

    if (_discountType == 'percentage') {
      discountCents = (originalCents * value + 5000) ~/ 10000;
    } else {
      discountCents = value;
    }

    return discountCents.clamp(0, originalCents);
  }

  String _formatMoney(int cents) {
    return '€${(cents / 100).toStringAsFixed(2)}';
  }

  Widget _discountPreview() {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (!_discountEnabled) {
      return const SizedBox.shrink();
    }

    final value = _discountValueHundredths(_discountValue.text);

    if (value == null || value <= 0) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'Enter a valid discount to see the estimated variant prices.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    if (_variants.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('Add a variant to preview its discounted price.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Text(
          l10n?.adminDiscountPreview ?? 'Estimated variant prices',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < _variants.length; i++)
          _variantPricePreview(_variants[i], i),
        const SizedBox(height: 6),
        Text(
          'These are estimates. The backend calculates the final prices.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }

  Widget _variantPricePreview(_VariantRow variant, int index) {
    final theme = Theme.of(context);
    final originalCents = parseEuroToCents(variant.price.text);

    final label = variant.sku.text.trim().isEmpty
        ? 'Variant #${index + 1}'
        : variant.sku.text.trim();

    if (originalCents == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              'Enter a valid price',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      );
    }

    final discountCents = _discountForVariant(originalCents);
    final discountedCents = originalCents - discountCents;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            _formatMoney(originalCents),
            style: theme.textTheme.bodySmall?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatMoney(discountedCents),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _discountSection() {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          context,
          l10n?.adminDiscount ?? 'Product Discount',
          subtitle:
              'The same discount rule applies to every variant. Original prices are preserved.',
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: goldColor,
          activeTrackColor: goldColor,
          title: Text(l10n?.adminDiscount ?? 'Enable product discount'),
          subtitle: const Text(
            'Customers will see the discounted price throughout the shop.',
          ),
          value: _discountEnabled,
          onChanged: (enabled) {
            setState(() {
              _discountEnabled = enabled;
              _serverErrors.remove('discount');
              _serverErrors.remove('discount.discount_type');
              _serverErrors.remove('discount.discount_value');
            });
          },
        ),
        if (_discountEnabled) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _discountType,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n?.adminDiscount ?? 'Discount Type',
              errorText: _serverErrors['discount.discount_type'],
            ),
            items: [
              DropdownMenuItem(
                value: 'percentage',
                child: Text(l10n?.adminDiscountPercentage ?? 'Percentage (%)'),
              ),
              DropdownMenuItem(
                value: 'fixed',
                child: Text(l10n?.adminDiscountFixed ?? 'Fixed amount (€)'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                _discountType = value;
                _serverErrors.remove('discount.discount_type');
                _serverErrors.remove('discount.discount_value');
              });
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _discountValue,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: _vDiscountValue,
            forceErrorText: _serverErrors['discount.discount_value'],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText:
                  l10n?.adminDiscountValue ??
                  (_discountType == 'percentage'
                      ? 'Discount Percentage (%)'
                      : 'Discount Amount (€)'),
              hintText: _discountType == 'percentage' ? '15.00' : '5.00',
              helperText: _discountType == 'percentage'
                  ? 'Enter a value between 0.01% and 100%.'
                  : 'Deducted from each variant unit price.',
              errorText: _serverErrors['discount'],
            ),
          ),
          _discountPreview(),
        ],
        if (!_discountEnabled && _originalDiscount != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'The existing discount will be removed when you save.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Variants and stock
  // ---------------------------------------------------------------------------

  void _addVariant() {
    setState(() {
      _variants.add(_VariantRow());
    });
  }

  void _removeVariant(int index) {
    final row = _variants[index];

    setState(() {
      _variants.removeAt(index);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      row.dispose();
    });
  }

  Future<void> _openStock(_VariantRow variant) async {
    if (variant.id == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AdminStockScreen(variantId: variant.id!, title: variant.sku.text),
      ),
    );

    try {
      final data = await ApiService.instance.adminVariantStock(variant.id!);

      if (mounted) {
        setState(() {
          variant.stock = Map<String, dynamic>.from(data['totals'] as Map);
        });
      }
    } on ApiException {
      // Keep the previous stock numbers if the request fails.
    }
  }

  String _stockText(ProductFormData stock, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onHand = l10n?.adminStockOnHand ?? 'on hand';
    final reserved = l10n?.adminStockReserved ?? 'reserved';
    final available = l10n?.adminStockAvailable ?? 'available';
    return '${formatQuantity(stock['on_hand'] as num)} $onHand · '
        '${formatQuantity(stock['reserved'] as num)} $reserved · '
        '${formatQuantity(stock['available'] as num)} $available';
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  bool _isFieldKey(String key) {
    return const {
          'slug',
          'product_type',
          'status',
          'tax_rate_id',
        }.contains(key) ||
        key.startsWith('translations.de.') ||
        key.startsWith('translations.en.') ||
        RegExp(r'^variants\.\d+\.').hasMatch(key);
  }

  Future<void> _save() async {
    setState(() {
      _error = null;
      _serverErrors = {};
    });

    if (!_form.currentState!.validate()) return;

    if (_status == 'published' && !_variants.any((variant) => variant.active)) {
      setState(() {
        _error = 'A published product needs at least one active variant.';
      });
      return;
    }

    if (_status == 'published' && _name.text.trim().isEmpty) {
      setState(() {
        _error = 'A published product needs a German translation.';
      });
      return;
    }

    setState(() {
      _saving = true;
    });

    String? orNull(String value) {
      return value.trim().isEmpty ? null : value.trim();
    }

    final translations = <String, dynamic>{
      'de': {
        'name': _name.text.trim(),
        'description': orNull(_desc.text),
        'ingredients': orNull(_ingredients.text),
        'allergens': orNull(_allergens.text),
        'seo_title': _seoTitle,
        'seo_description': _seoDescription,
      },
    };

    // English is optional. Send it only when an English name is provided.
    if (_nameEn.text.trim().isNotEmpty) {
      translations['en'] = {
        'name': _nameEn.text.trim(),
        'description': orNull(_descEn.text),
        'ingredients': orNull(_ingredientsEn.text),
        'allergens': orNull(_allergensEn.text),
        'seo_title': _seoTitleEn,
        'seo_description': _seoDescriptionEn,
      };
    }

    final body = <String, dynamic>{
      'slug': _slug.text.trim(),
      'product_type': _type,
      'status': _status,
      if (!_editing || _taxRateId != _originalTaxRateId)
        'tax_rate_id': _taxRateId,
      'translations': translations,
      'category_ids': _categoryIds.toList(),
      'variants': [
        for (final variant in _variants)
          {
            if (variant.id != null) 'id': variant.id,
            'sku': variant.sku.text.trim(),
            'price_cents': parseEuroToCents(variant.price.text)!,
            'pack_quantity': variant.pack.text.trim().isEmpty
                ? null
                : variant.pack.text.trim().replaceAll(',', '.'),
            'unit': orNull(variant.unit.text),
            'ean': orNull(variant.ean.text),
            'active': variant.active,
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

      final errors = e.fieldErrors;

      final general = errors.entries
          .where((entry) => !_isFieldKey(entry.key))
          .map((entry) => entry.value)
          .join('\n');

      setState(() {
        _serverErrors = errors;
        _error = errors.isEmpty
            ? e.message
            : (general.isEmpty ? null : general);
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to save product: $e';
        _saving = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // UI helper components
  // ---------------------------------------------------------------------------

  Widget _sectionHeader(
    BuildContext context,
    String title, {
    String? subtitle,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _text(
    String serverKey,
    String label,
    TextEditingController controller,
    String? Function(String?) validator, {
    int maxLines = 1,
    TextInputType? type,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: type,
        textInputAction: maxLines == 1
            ? TextInputAction.next
            : TextInputAction.newline,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: validator,
        forceErrorText: _serverErrors[serverKey],
        decoration: InputDecoration(labelText: label, helperText: helper),
      ),
    );
  }

  Widget _variantCard(int index) {
    final variant = _variants[index];
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final l10n = AppLocalizations.of(context);

    const money = TextInputType.numberWithOptions(decimal: true);

    String? server(String field) {
      return _serverErrors['variants.$index.$field'];
    }

    return Container(
      key: ObjectKey(variant),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Variant #${index + 1}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const Spacer(),
              if (variant.id == null)
                IconButton(
                  tooltip: 'Remove variant',
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: theme.colorScheme.error.withValues(alpha: 0.8),
                  ),
                  onPressed: () => _removeVariant(index),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: variant.sku,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _vSku,
                  forceErrorText: server('sku'),
                  decoration: InputDecoration(
                    labelText: l10n?.adminSku ?? 'SKU',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: variant.price,
                  keyboardType: money,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _vPrice,
                  forceErrorText: server('price_cents'),
                  onChanged: (_) {
                    if (_discountEnabled) setState(() {});
                  },
                  decoration: InputDecoration(
                    labelText: l10n?.adminPriceGross ?? 'Price (€)',
                    helperText: l10n?.taxIncluded ?? 'incl. VAT',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: variant.pack,
                  keyboardType: money,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: _vPack,
                  forceErrorText: server('pack_quantity'),
                  decoration: InputDecoration(
                    labelText: l10n?.adminPackQuantity ?? 'Pack size',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: variant.unit,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) => _vMax(value, 20),
                  forceErrorText: server('unit'),
                  decoration: InputDecoration(
                    labelText: l10n?.adminUnit ?? 'Unit (g, ml...)',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: variant.ean,
            keyboardType: TextInputType.number,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: _vEan,
            forceErrorText: server('ean'),
            decoration: InputDecoration(
              labelText:
                  '${l10n?.adminEan ?? 'EAN'} (${l10n?.adminEnglishTranslation != null ? 'optional' : 'optional'})',
            ),
          ),
          if (variant.id != null &&
              _type == 'physical' &&
              variant.stock != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _stockText(variant.stock!, context),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openStock(variant),
                    icon: Icon(
                      Icons.warehouse_outlined,
                      size: 16,
                      color: goldColor,
                    ),
                    label: Text(
                      l10n?.adminStock ?? 'Stock',
                      style: TextStyle(
                        color: goldColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: goldColor,
            activeTrackColor: goldColor,
            title: Text(
              l10n?.adminActive ?? 'Active variant',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            value: variant.active,
            onChanged: (value) {
              setState(() {
                variant.active = value;
              });
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;
    final l10n = AppLocalizations.of(context);

    if (_loadingData) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            _editing
                ? (l10n?.adminEditProduct ?? 'Edit product')
                : (l10n?.adminNewProduct ?? 'New product'),
          ),
        ),
        body: Center(
          child: CircularProgressIndicator(color: goldColor, strokeWidth: 2),
        ),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            _editing
                ? (l10n?.adminEditProduct ?? 'Edit product')
                : (l10n?.adminNewProduct ?? 'New product'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 40,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _loadingData = true;
                      _loadError = null;
                    });
                    _init();
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(l10n?.adminRetry ?? 'Retry'),
                  style: TextButton.styleFrom(foregroundColor: goldColor),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final endedRateSelected = _taxRates.any(
      (rate) => rate['id'] == _taxRateId && rate['ended'] == true,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _editing
              ? (l10n?.adminEditProduct ?? 'Edit product')
              : (l10n?.adminNewProduct ?? 'New product'),
        ),
        elevation: 0,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Basic settings.
            _sectionHeader(context, l10n?.adminBasicInfo ?? 'Basic Settings'),

            _text(
              'slug',
              l10n?.adminSlug ?? 'Slug (URL name)',
              _slug,
              _vSlug,
              helper: 'e.g. ceylon-zimt',
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: InputDecoration(
                  labelText: l10n?.adminProductType ?? 'Product Type',
                  errorText: _serverErrors['product_type'],
                ),
                items: [
                  for (final type in _types)
                    DropdownMenuItem(
                      value: type,
                      child: Text(type.replaceAll('_', ' ')),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _type = value);
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: InputDecoration(
                  labelText: l10n?.adminProductStatus ?? 'Status',
                  helperText:
                      'Publishing requires a German translation and at least one active variant.',
                  helperMaxLines: 2,
                  errorText: _serverErrors['status'],
                ),
                items: [
                  for (final status in _statuses)
                    DropdownMenuItem(
                      value: status,
                      child: Text(
                        localizedProductStatus(status, context: context),
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _status = value);
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<int>(
                initialValue: _taxRateId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n?.adminTaxRate ?? 'Tax Rate',
                  helperText: endedRateSelected
                      ? 'This rate has ended. Select a current rate if updating.'
                      : null,
                  helperMaxLines: 2,
                  errorText: _serverErrors['tax_rate_id'],
                ),
                validator: (value) =>
                    value == null ? 'Choose a tax rate.' : null,
                items: [
                  for (final rate in _taxRates)
                    DropdownMenuItem(
                      value: (rate['id'] as num).toInt(),
                      child: Text(
                        '${rate['code']} (${rate['rate_percent']}%)'
                        '${rate['ended'] == true ? ' · ended' : ''}',
                      ),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _taxRateId = value);
                },
              ),
            ),

            // German translation.
            _sectionHeader(
              context,
              l10n?.adminGermanTranslation ?? 'Product Details — German',
              subtitle: 'German is currently required for publishing products.',
            ),

            _text(
              'translations.de.name',
              '${l10n?.adminProductName ?? 'Product Name'} (German)',
              _name,
              _vName,
            ),

            _text(
              'translations.de.description',
              '${l10n?.adminProductDescription ?? 'Description'} (German)',
              _desc,
              (value) => _vMax(value, 20000),
              maxLines: 4,
            ),

            _text(
              'translations.de.ingredients',
              '${l10n?.adminIngredients ?? 'Ingredients'} (German)',
              _ingredients,
              (value) => _vMax(value, 5000),
              maxLines: 3,
            ),

            _text(
              'translations.de.allergens',
              '${l10n?.adminAllergens ?? 'Allergens'} (German)',
              _allergens,
              (value) => _vMax(value, 5000),
              maxLines: 2,
            ),

            const Divider(height: 32),

            // English translation.
            _sectionHeader(
              context,
              l10n?.adminEnglishTranslation ?? 'Product Details — English',
              subtitle:
                  'Optional. Add an English name to make this product available in English.',
            ),

            _text(
              'translations.en.name',
              '${l10n?.adminProductName ?? 'Product Name'} (English)',
              _nameEn,
              _vEnglishName,
              helper: 'Required if you enter any other English details.',
            ),

            _text(
              'translations.en.description',
              '${l10n?.adminProductDescription ?? 'Description'} (English)',
              _descEn,
              (value) => _vMax(value, 20000),
              maxLines: 4,
            ),

            _text(
              'translations.en.ingredients',
              '${l10n?.adminIngredients ?? 'Ingredients'} (English)',
              _ingredientsEn,
              (value) => _vMax(value, 5000),
              maxLines: 3,
            ),

            _text(
              'translations.en.allergens',
              '${l10n?.adminAllergens ?? 'Allergens'} (English)',
              _allergensEn,
              (value) => _vMax(value, 5000),
              maxLines: 2,
            ),

            const Divider(height: 32),

            // Images.
            _sectionHeader(
              context,
              l10n?.adminImages ?? 'Images',
              subtitle:
                  'The first image will be set as the primary catalog cover.',
            ),

            ImageManager(
              images: _images,
              onChanged: (list) {
                setState(() {
                  _images = list;
                });
              },
            ),

            // Categories.
            if (_categories.isNotEmpty) ...[
              _sectionHeader(context, l10n?.adminCategories ?? 'Categories'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in _categories)
                    FilterChip(
                      label: Text(
                        '${localizedCategoryName(category, context: context)}'
                        '${category['active'] == true ? '' : ' (hidden)'}',
                      ),
                      selected: _categoryIds.contains(
                        (category['id'] as num).toInt(),
                      ),
                      showCheckmark: false,
                      side: BorderSide(
                        color:
                            _categoryIds.contains(
                              (category['id'] as num).toInt(),
                            )
                            ? goldColor
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.15,
                              ),
                      ),
                      selectedColor: goldColor.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        color:
                            _categoryIds.contains(
                              (category['id'] as num).toInt(),
                            )
                            ? goldColor
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                        fontWeight:
                            _categoryIds.contains(
                              (category['id'] as num).toInt(),
                            )
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        final id = (category['id'] as num).toInt();

                        setState(() {
                          if (selected) {
                            _categoryIds.add(id);
                          } else {
                            _categoryIds.remove(id);
                          }
                        });
                      },
                    ),
                ],
              ),
            ],

            // Variants.
            _sectionHeader(
              context,
              l10n?.adminVariants ?? 'Variants',
              subtitle: 'Configure pack sizes, SKUs, and pricing.',
            ),

            for (var i = 0; i < _variants.length; i++) _variantCard(i),

            OutlinedButton.icon(
              onPressed: _addVariant,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n?.adminAddVariant ?? 'Add Variant'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: goldColor),
                foregroundColor: goldColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),

            // Discount controls and preview.
            _discountSection(),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 13,
                  ),
                ),
              ),

            const SizedBox(height: 24),

            LoadingButton(
              label: _editing
                  ? (l10n?.saveChanges ?? 'Save Changes')
                  : (l10n?.adminSaveProduct ?? 'Create Product'),
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
