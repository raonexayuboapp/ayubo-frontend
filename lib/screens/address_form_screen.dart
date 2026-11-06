import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/countries.dart';
import '../widgets/app_header.dart';
import '../widgets/loading_button.dart';

class AddressFormScreen extends StatefulWidget {
  final Map<String, dynamic>? address; // null = add, otherwise edit
  final String defaultRecipient;
  final String initialType; // 'shipping' or 'billing' for a new address

  const AddressFormScreen({
    super.key,
    this.address,
    this.defaultRecipient = '',
    this.initialType = 'shipping',
  });

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _form = GlobalKey<FormState>();
  final _postalKey = GlobalKey<FormFieldState<String>>();

  late final _recipient = TextEditingController(
    text: (widget.address?['recipient'] as String?) ??
        widget.defaultRecipient,
  );
  late final _company = TextEditingController(
    text: (widget.address?['company'] as String?) ?? '',
  );
  late final _street = TextEditingController(
    text: (widget.address?['street'] as String?) ?? '',
  );
  late final _line2 = TextEditingController(
    text: (widget.address?['address_line2'] as String?) ?? '',
  );
  late final _postal = TextEditingController(
    text: (widget.address?['postal_code'] as String?) ?? '',
  );
  late final _city = TextEditingController(
    text: (widget.address?['city'] as String?) ?? '',
  );
  late final _region = TextEditingController(
    text: (widget.address?['region'] as String?) ?? '',
  );

  late String _type =
      (widget.address?['address_type'] as String?) ?? widget.initialType;
  late final String _originalType = _type;
  late String _country =
      (widget.address?['country_code'] as String?) ?? 'DE';
  late bool _default = widget.address?['is_default'] == true;
  late final bool _wasDefault = _default;

  bool _saving = false;
  String? _error;
  Map<String, String> _serverErrors = {};

  bool get _editing => widget.address != null;

  @override
  void dispose() {
    for (final c in [
      _recipient,
      _company,
      _street,
      _line2,
      _postal,
      _city,
      _region,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _vRequired(String? v, int max, String label) {
    final s = (v ?? '').trim();
    return s.isEmpty || s.length > max
        ? '$label must be 1 to $max characters.'
        : null;
  }

  String? _vOptional(String? v, int max) =>
      (v ?? '').trim().length > max ? 'Maximum $max characters.' : null;

  String? _vPostal(String? v) {
    final s = normalizePostal(v);
    final country = countryByCode(_country);
    final ok =
        s.length <= 20 && (country?.postal ?? genericPostal).hasMatch(s);

    if (ok) return null;
    return country?.example == null
        ? 'Enter a valid postal code.'
        : 'Enter a valid postal code, for example ${country!.example}.';
  }

  bool _isFieldKey(String k) => const {
        'address_type',
        'recipient',
        'company',
        'street',
        'address_line2',
        'postal_code',
        'city',
        'region',
        'country_code',
        'is_default',
      }.contains(k);

  Future<void> _save() async {
    setState(() {
      _error = null;
      _serverErrors = {};
    });

    if (!_form.currentState!.validate()) return;

    setState(() => _saving = true);

    String? orNull(String s) => s.trim().isEmpty ? null : s.trim();

    final body = <String, dynamic>{
      'address_type': _type,
      'recipient': _recipient.text.trim(),
      'company': orNull(_company.text),
      'street': _street.text.trim(),
      'address_line2': orNull(_line2.text),
      'postal_code': normalizePostal(_postal.text),
      'city': _city.text.trim(),
      'region': orNull(_region.text),
      'country_code': _country,
      if (_default) 'is_default': true,
    };

    try {
      if (_editing) {
        await ApiService.instance.updateAddress(
          widget.address!['id'] as int,
          body,
        );
      } else {
        await ApiService.instance.createAddress(body);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;

      final errs = e.fieldErrors;
      final general = errs.entries
          .where((x) => !_isFieldKey(x.key))
          .map((x) => x.value)
          .join('\n');

      setState(() {
        _serverErrors = errs;
        _error = errs.isEmpty ? e.message : (general.isEmpty ? null : general);
        _saving = false;
      });
    }
  }

  Widget _text(
    String serverKey,
    String label,
    TextEditingController c,
    String? Function(String?) validator, {
    TextInputType? type,
    Key? fieldKey,
    TextCapitalization capitalization = TextCapitalization.words,
    IconData? icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: fieldKey,
        controller: c,
        keyboardType: type,
        textCapitalization: capitalization,
        textInputAction: TextInputAction.next,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: validator,
        forceErrorText: _serverErrors[serverKey],
        style: TextStyle(color: scheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null
              ? Icon(
                  icon,
                  color: AppTheme.primaryGreen,
                  size: 20,
                )
              : null,
          filled: true,
          fillColor: isDark
              ? AppTheme.bgDark.withValues(alpha: 0.5)
              : AppTheme.bgLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: scheme.outline.withValues(alpha: 0.15),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AppTheme.primaryGreen,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeChanged = _type != _originalType;

    final countryItems = [
      for (final c in countries)
        DropdownMenuItem<String>(
          value: c.code,
          child: Text('${c.name} (${c.code})'),
        ),
      if (countryByCode(_country) == null)
        DropdownMenuItem<String>(
          value: _country,
          child: Text(_country),
        ),
    ];

    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    return Scaffold(
      appBar: AppHeader(
        title: _editing
            ? (isDe ? 'Adresse bearbeiten' : 'Edit Address')
            : (isDe ? 'Neue Adresse' : 'Add Address'),
        subtitle: isDe ? 'Liefer- & Kontaktdaten' : 'Delivery & contact details',
        showBackButton: true,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'shipping',
                  label: Text('Shipping'),
                  icon: Icon(Icons.local_shipping_outlined),
                ),
                ButtonSegment(
                  value: 'billing',
                  label: Text('Billing'),
                  icon: Icon(Icons.receipt_long_outlined),
                ),
              ],
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppTheme.brandGold.withValues(alpha: 0.25);
                  }
                  return isDark ? AppTheme.surfaceDark : Colors.white;
                }),
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppTheme.brandGoldDark;
                  }
                  return scheme.onSurface;
                }),
                side: WidgetStateProperty.all(
                  BorderSide(
                    color: AppTheme.brandGold.withValues(alpha: 0.4),
                  ),
                ),
              ),
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                if (_editing) {
                  _default = _type == _originalType ? _wasDefault : false;
                }
              }),
            ),
            if (_serverErrors['address_type'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _serverErrors['address_type']!,
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
              ),

            const SizedBox(height: 24),

            _text(
              'recipient',
              'Recipient Name',
              _recipient,
              (v) => _vRequired(v, 190, 'Recipient'),
              icon: Icons.person_outline_rounded,
            ),
            _text(
              'company',
              'Company (Optional)',
              _company,
              (v) => _vOptional(v, 190),
              icon: Icons.business_outlined,
            ),
            _text(
              'street',
              'Street and House Number',
              _street,
              (v) => _vRequired(v, 190, 'Street'),
              icon: Icons.home_outlined,
            ),
            _text(
              'address_line2',
              'Address Line 2 (Optional)',
              _line2,
              (v) => _vOptional(v, 190),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _text(
                    'postal_code',
                    'Postal Code',
                    _postal,
                    _vPostal,
                    fieldKey: _postalKey,
                    capitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _text(
                    'city',
                    'City',
                    _city,
                    (v) => _vRequired(v, 100, 'City'),
                  ),
                ),
              ],
            ),
            _text(
              'region',
              'Region / State (Optional)',
              _region,
              (v) => _vOptional(v, 100),
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<String>(
                value: _country,
                isExpanded: true,
                style: TextStyle(color: scheme.onSurface, fontSize: 14),
                dropdownColor: isDark ? AppTheme.surfaceDark : Colors.white,
                decoration: InputDecoration(
                  labelText: 'Country',
                  prefixIcon: const Icon(
                    Icons.public_rounded,
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: isDark
                      ? AppTheme.bgDark.withValues(alpha: 0.5)
                      : AppTheme.bgLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: scheme.outline.withValues(alpha: 0.15),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryGreen,
                      width: 1.5,
                    ),
                  ),
                  errorText: _serverErrors['country_code'],
                ),
                items: countryItems,
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _country = v);
                  _postalKey.currentState?.validate();
                },
              ),
            ),

            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                ),
              ),
              child: SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                activeColor: AppTheme.brandGold,
                activeTrackColor: AppTheme.primaryGreen,
                title: Text(
                  'Use as default ${_type == 'shipping' ? 'shipping' : 'billing'} address',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: _wasDefault && !typeChanged
                    ? Text(
                        'To change default, mark another address as default.',
                        style: TextStyle(
                          color: scheme.onSurface.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      )
                    : null,
                value: _default,
                onChanged: _wasDefault && !typeChanged
                    ? null
                    : (v) => setState(() => _default = v),
              ),
            ),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: scheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 18, color: scheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: scheme.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),

            LoadingButton(
              label: 'Save Address',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}