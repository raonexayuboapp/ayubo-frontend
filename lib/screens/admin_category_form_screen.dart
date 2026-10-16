import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/category_tree.dart';
import '../widgets/loading_button.dart';

class AdminCategoryFormScreen extends StatefulWidget {
  final int? categoryId; // null = create, otherwise edit
  const AdminCategoryFormScreen({super.key, this.categoryId});

  @override
  State<AdminCategoryFormScreen> createState() => _AdminCategoryFormScreenState();
}

class _AdminCategoryFormScreenState extends State<AdminCategoryFormScreen> {
  final _form = GlobalKey<FormState>();
  final _slug = TextEditingController();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _sort = TextEditingController(text: '0');

  int? _parentId;
  bool _active = true;
  List<Map<String, dynamic>> _all = [];
  Set<int> _blocked = {}; // the category itself and everything below it can not be its parent

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
    for (final c in [_slug, _name, _desc, _sort]) {
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

      final all = results[0] as List<Map<String, dynamic>>;

      if (_editing) {
        final c = results[1] as Map<String, dynamic>;
        // An empty translations object can arrive as a list, so check the type first.
        final tr = c['translations'];
        final de = tr is Map<String, dynamic> ? tr['de'] as Map<String, dynamic>? : null;

        _slug.text = c['slug'] as String;
        _name.text = (de?['name'] as String?) ?? '';
        _desc.text = (de?['description'] as String?) ?? '';
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

  // ---------- validation (the server checks everything again) ----------

  String? _vSlug(String? v) => RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch((v ?? '').trim()) &&
      (v ?? '').trim().length <= 190
      ? null
      : 'Lowercase letters and numbers separated by single hyphens.';

  String? _vName(String? v) {
    final s = (v ?? '').trim();
    return s.isEmpty || s.length > 190 ? 'Name must be 1 to 190 characters.' : null;
  }

  String? _vDesc(String? v) => (v ?? '').trim().length > 2000 ? 'Maximum 2000 characters.' : null;

  String? _vSort(String? v) {
    final n = int.tryParse((v ?? '').trim());
    return n == null || n < 0 || n > 10000 ? 'Enter a whole number from 0 to 10000.' : null;
  }

  // ---------- save ----------

  bool _isFieldKey(String k) =>
      const {'slug', 'parent_id', 'sort_order', 'active'}.contains(k) || k.startsWith('translations.de.');

  Future<void> _save() async {
    setState(() {
      _error = null;
      _serverErrors = {};
    });
    if (!_form.currentState!.validate()) return;

    setState(() => _saving = true);

    final description = _desc.text.trim();
    final body = <String, dynamic>{
      'slug': _slug.text.trim(),
      'parent_id': _parentId,
      'sort_order': int.parse(_sort.text.trim()), // safe: validate() accepted it
      'active': _active,
      'translations': {
        'de': {'name': _name.text.trim(), 'description': description.isEmpty ? null : description},
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

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit category' : 'New category')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _text('slug', 'Slug (URL name)', _slug, _vSlug, helper: 'e.g. gewuerze'),
            _text('translations.de.name', 'Name (German)', _name, _vName),
            _text('translations.de.description', 'Description (optional)', _desc, _vDesc, maxLines: 3),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<int?>(
                value: _parentId,
                decoration: InputDecoration(labelText: 'Parent category', errorText: _serverErrors['parent_id']),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('None (top level)')),
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
            _text('sort_order', 'Sort order', _sort, _vSort,
                type: TextInputType.number, helper: 'Lower numbers are shown first.'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Visible to customers'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 16),
            LoadingButton(label: _editing ? 'Save changes' : 'Create category', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}