import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/category_tree.dart';
import '../widgets/loading_button.dart';

typedef CategoryData = Map<String, dynamic>;

class AdminCategoryFormScreen extends StatefulWidget {
  final int? categoryId; // null = create, otherwise edit

  const AdminCategoryFormScreen({super.key, this.categoryId});

  @override
  State<AdminCategoryFormScreen> createState() =>
      _AdminCategoryFormScreenState();
}

class _AdminCategoryFormScreenState extends State<AdminCategoryFormScreen> {
  final _form = GlobalKey<FormState>();

  final _slug = TextEditingController();

  // English translation
  final _nameEn = TextEditingController();
  final _descEn = TextEditingController();

  // German translation
  final _nameDe = TextEditingController();
  final _descDe = TextEditingController();

  final _sort = TextEditingController(text: '0');

  int? _parentId;
  bool _active = true;

  List<CategoryData> _all = [];
  Set<int> _blocked = {};

  bool _loadingData = true;
  String? _loadError;

  bool _saving = false;
  String? _error;

  Map<String, String> _serverErrors = {};

  bool get _editing => widget.categoryId != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    for (final c in [_slug, _nameEn, _descEn, _nameDe, _descDe, _sort]) {
      c.dispose();
    }

    super.dispose();
  }

  Future<void> _init() async {
    try {
      final api = ApiService.instance;

      final results = await Future.wait<Object>([
        api.adminCategories(),
        if (_editing) api.adminGetCategory(widget.categoryId!),
      ]);

      if (!mounted) return;

      final all = (results[0] as List<dynamic>).cast<CategoryData>();

      if (_editing) {
        final c = results[1] as CategoryData;

        final rawTranslations = c['translations'];

        final translations = rawTranslations is Map
            ? rawTranslations
            : <String, dynamic>{};

        final en = translations['en'] is Map
            ? Map<String, dynamic>.from(translations['en'] as Map)
            : <String, dynamic>{};

        final de = translations['de'] is Map
            ? Map<String, dynamic>.from(translations['de'] as Map)
            : <String, dynamic>{};

        _slug.text = c['slug'] as String;

        _nameEn.text = (en['name'] as String?) ?? '';
        _descEn.text = (en['description'] as String?) ?? '';

        _nameDe.text = (de['name'] as String?) ?? '';
        _descDe.text = (de['description'] as String?) ?? '';

        _sort.text = '${c['sort_order']}';

        _parentId = c['parent_id'] as int?;
        _active = c['active'] == true;

        _blocked = categoryAndDescendants(all, widget.categoryId!);
      }

      setState(() {
        _all = all;
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

  // ---------- validation ----------

  String? _vSlug(String? v) {
    final s = (v ?? '').trim();

    return RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(s) && s.length <= 190
        ? null
        : 'Lowercase letters and numbers separated by single hyphens.';
  }

  String? _vNameEn(String? v) {
    final s = (v ?? '').trim();

    return s.isEmpty || s.length > 190
        ? 'English name must be 1 to 190 characters.'
        : null;
  }

  String? _vNameDe(String? v) {
    final s = (v ?? '').trim();

    return s.length > 190
        ? 'German name must not exceed 190 characters.'
        : null;
  }

  String? _vDesc(String? v) {
    return (v ?? '').trim().length > 2000 ? 'Maximum 2000 characters.' : null;
  }

  String? _vSort(String? v) {
    final n = int.tryParse((v ?? '').trim());

    return n == null || n < 0 || n > 10000
        ? 'Enter a whole number from 0 to 10000.'
        : null;
  }

  // ---------- server error handling ----------

  bool _isFieldKey(String k) {
    return const {'slug', 'parent_id', 'sort_order', 'active'}.contains(k) ||
        k.startsWith('translations.en.') ||
        k.startsWith('translations.de.');
  }

  // ---------- save ----------

  Future<void> _save() async {
    setState(() {
      _error = null;
      _serverErrors = {};
    });

    if (!_form.currentState!.validate()) return;

    setState(() => _saving = true);

    final descriptionEn = _descEn.text.trim();
    final descriptionDe = _descDe.text.trim();

    final body = <String, dynamic>{
      'slug': _slug.text.trim(),
      'parent_id': _parentId,
      'sort_order': int.parse(_sort.text.trim()),
      'active': _active,
      'translations': {
        'en': {
          'name': _nameEn.text.trim(),
          'description': descriptionEn.isEmpty ? null : descriptionEn,
        },
        'de': {
          'name': _nameDe.text.trim(),
          'description': descriptionDe.isEmpty ? null : descriptionDe,
        },
      },
    };

    try {
      if (_editing) {
        await ApiService.instance.adminUpdateCategory(widget.categoryId!, body);
      } else {
        await ApiService.instance.adminCreateCategory(body);
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

  // ---------- UI helpers ----------

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
        textInputAction: maxLines == 1
            ? TextInputAction.next
            : TextInputAction.newline,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: validator,
        forceErrorText: _serverErrors[serverKey],
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, {String? subtitle, IconData? icon}) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: theme.colorScheme.secondary, size: 21),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _translationSection({
    required String title,
    required String subtitle,
    required String languageCode,
    required TextEditingController nameController,
    required TextEditingController descriptionController,
    required String? Function(String?) nameValidator,
    required bool requiredLanguage,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: requiredLanguage
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  requiredLanguage ? 'Required' : 'Optional',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          _text(
            'translations.$languageCode.name',
            'Name',
            nameController,
            nameValidator,
            helper: requiredLanguage
                ? 'Required. Maximum 190 characters.'
                : 'Maximum 190 characters.',
          ),
          _text(
            'translations.$languageCode.description',
            'Description',
            descriptionController,
            _vDesc,
            maxLines: 3,
            helper: 'Optional. Maximum 2000 characters.',
          ),
        ],
      ),
    );
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;

    if (_loadingData) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_editing ? 'Edit category' : 'New category'),
        ),
        body: Center(child: CircularProgressIndicator(color: goldColor)),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_editing ? 'Edit category' : 'New category'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _loadingData = true;
                      _loadError = null;
                    });
                    _init();
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: goldColor),
                    foregroundColor: goldColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit category' : 'New category')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Basic information
            _sectionTitle(
              'Basic information',
              subtitle: 'Category identifier and organisation.',
              icon: Icons.category_outlined,
            ),

            _text(
              'slug',
              'Slug (URL name)',
              _slug,
              _vSlug,
              helper: 'e.g. organic-skincare',
            ),

            // English translation
            _translationSection(
              title: 'English',
              subtitle: 'Default language',
              languageCode: 'en',
              nameController: _nameEn,
              descriptionController: _descEn,
              nameValidator: _vNameEn,
              requiredLanguage: true,
            ),

            // German translation
            _translationSection(
              title: 'German',
              subtitle: 'German translation',
              languageCode: 'de',
              nameController: _nameDe,
              descriptionController: _descDe,
              nameValidator: _vNameDe,
              requiredLanguage: false,
            ),

            // Category hierarchy
            _sectionTitle(
              'Category organisation',
              subtitle: 'Set the parent and display order.',
              icon: Icons.account_tree_outlined,
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<int?>(
                initialValue: _parentId,
                decoration: InputDecoration(
                  labelText: 'Parent category',
                  errorText: _serverErrors['parent_id'],
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('None (top level)'),
                  ),
                  for (final (c, depth) in flattenCategories(_all))
                    if (!_blocked.contains(c['id']))
                      DropdownMenuItem<int?>(
                        value: c['id'] as int,
                        child: Text('${'– ' * depth}${c['name']}'),
                      ),
                ],
                onChanged: (v) => setState(() => _parentId = v),
              ),
            ),

            _text(
              'sort_order',
              'Sort order',
              _sort,
              _vSort,
              type: TextInputType.number,
              helper: 'Lower numbers are shown first.',
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: goldColor,
              activeTrackColor: goldColor,
              title: Text(
                'Visible to customers',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),

            const SizedBox(height: 24),

            LoadingButton(
              label: _editing ? 'Save changes' : 'Create category',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
