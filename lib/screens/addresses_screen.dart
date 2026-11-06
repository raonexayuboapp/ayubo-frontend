import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/countries.dart';
import '../widgets/app_header.dart';
import 'address_form_screen.dart';

typedef AddressData = Map<String, dynamic>;

class AddressesScreen extends StatefulWidget {
  final String defaultRecipient; // prefilled in the form for a new address
  const AddressesScreen({super.key, this.defaultRecipient = ''});

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  static const _maxAddresses = 10; // the server enforces the same limit
  static const _titles = {
    'shipping': 'Shipping Addresses',
    'billing': 'Billing Addresses',
  };

  List<AddressData> _items = [];
  bool _loading = true;
  String? _error;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ApiService.instance.listAddresses();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_items.isEmpty) _error = e.message;
      });
      if (_items.isNotEmpty) _snack(e.message);
    }
  }

  Future<void> _openForm([AddressData? address]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressFormScreen(
          address: address,
          defaultRecipient: widget.defaultRecipient,
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(AddressData a) async {
    final id = a['id'] as int;
    if (_busy.contains(id)) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: AppTheme.brandGoldDark),
            SizedBox(width: 8),
            Text('Delete Address?'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove the address for "${a['recipient']}" in ${a['city']}?',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy.add(id));
    try {
      await ApiService.instance.deleteAddress(id);
      await _load();
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  String _block(AddressData a) {
    String? text(String key) {
      final v = a[key] as String?;
      return v == null || v.trim().isEmpty ? null : v.trim();
    }

    return [
      a['recipient'] as String,
      text('company'),
      a['street'] as String,
      text('address_line2'),
      '${a['postal_code']} ${a['city']}',
      text('region'),
      countryName(a['country_code'] as String),
    ].whereType<String>().join('\n');
  }

  Widget _card(AddressData a) {
    final id = a['id'] as int;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: a['is_default'] == true
              ? AppTheme.brandGold
              : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
          width: a['is_default'] == true ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandGold.withValues(alpha: a['is_default'] == true ? 0.12 : 0.03),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ListTile(
        key: ValueKey(id),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        onTap: () => _openForm(a),
        title: a['is_default'] == true
            ? Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.brandGold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.brandGold, width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, size: 14, color: AppTheme.brandGoldDark),
                          SizedBox(width: 4),
                          Text(
                            'DEFAULT ADDRESS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.brandGoldDark,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            : null,
        subtitle: Text(
          _block(a),
          style: TextStyle(
            color: scheme.onSurface,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.edit_outlined,
                color: scheme.onSurface.withValues(alpha: 0.6),
                size: 20,
              ),
              tooltip: 'Edit',
              onPressed: () => _openForm(a),
            ),
            IconButton(
              icon: _busy.contains(id)
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.delete_outline_rounded,
                      color: scheme.error.withValues(alpha: 0.8),
                      size: 20,
                    ),
              tooltip: 'Delete',
              onPressed: _busy.contains(id) ? null : () => _delete(a),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final scheme = Theme.of(context).colorScheme;

    if (_loading && _items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brandGold),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: scheme.error),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: scheme.onSurface),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.brandGold,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            const SizedBox(height: 120),
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.brandGold.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.location_off_outlined,
                  size: 64,
                  color: AppTheme.brandGoldDark,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Saved Addresses',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a delivery address to complete your organic purchases faster.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.65),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final children = <Widget>[];
    for (final type in _titles.keys) {
      final group = _items.where((a) => a['address_type'] == type).toList();
      if (group.isEmpty) continue;

      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 10),
          child: Text(
            _titles[type]!,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGreen,
                ),
          ),
        ),
      );
      children.addAll(group.map((a) => _card(a)));
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.brandGold,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final full = _items.length >= _maxAddresses;
    final l10n = AppLocalizations.of(context);
    final isDe = l10n?.localeName.startsWith('de') ?? false;

    return Scaffold(
      appBar: AppHeader(
        title: isDe ? 'Gespeicherte Adressen' : 'Saved Addresses',
        subtitle: isDe ? 'Liefer- & Rechnungsadressen' : 'Shipping & billing addresses',
        showBackButton: true,
      ),
      body: _body(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: full ? Colors.grey : AppTheme.brandGold,
        foregroundColor: const Color(0xFF1B4332),
        elevation: 4,
        onPressed: full ? null : () => _openForm(),
        tooltip: full ? 'You can save up to $_maxAddresses addresses' : null,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text(
          'Add Address',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}