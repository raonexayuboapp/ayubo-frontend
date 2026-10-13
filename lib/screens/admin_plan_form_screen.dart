import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/loading_button.dart';

/// One editable membership benefit.
class _BenefitRow {
  final TextEditingController code;
  final TextEditingController description;
  final TextEditingController configuration;

  _BenefitRow({
    String code = '',
    String description = '',
    String configuration = '',
  })  : code = TextEditingController(text: code),
        description = TextEditingController(text: description),
        configuration = TextEditingController(text: configuration);

  factory _BenefitRow.fromJson(Map<String, dynamic> benefit) {
    final rawConfiguration = benefit['configuration_json'];

    String configurationText = '';

    if (rawConfiguration is Map || rawConfiguration is List) {
      configurationText = const JsonEncoder.withIndent('  ')
          .convert(rawConfiguration);
    } else if (rawConfiguration is String &&
        rawConfiguration.trim().isNotEmpty) {
      // Support APIs returning configuration_json as a JSON string.
      try {
        final decoded = jsonDecode(rawConfiguration);
        configurationText =
            const JsonEncoder.withIndent('  ').convert(decoded);
      } on FormatException {
        configurationText = rawConfiguration;
      }
    }

    return _BenefitRow(
      code: benefit['benefit_code'] as String? ?? '',
      description: benefit['description'] as String? ?? '',
      configuration: configurationText,
    );
  }

  void dispose() {
    code.dispose();
    description.dispose();
    configuration.dispose();
  }
}

class AdminPlanFormScreen extends StatefulWidget {
  /// Null creates a plan; a supplied plan edits an existing plan.
  final Map<String, dynamic>? plan;

  const AdminPlanFormScreen({
    super.key,
    this.plan,
  });

  @override
  State<AdminPlanFormScreen> createState() =>
      _AdminPlanFormScreenState();
}

class _AdminPlanFormScreenState extends State<AdminPlanFormScreen> {
  final _form = GlobalKey<FormState>();

  late final TextEditingController _code =
  TextEditingController(text: widget.plan?['code'] as String? ?? '');

  late final TextEditingController _name =
  TextEditingController(text: widget.plan?['name'] as String? ?? '');

  late final TextEditingController _description =
  TextEditingController(
    text: widget.plan?['description'] as String? ?? '',
  );

  late bool _active = _readActive(widget.plan?['active']);

  late final List<_BenefitRow> _benefits = [
    for (final benefit
    in (widget.plan?['benefits'] as List<dynamic>? ?? []))
      _BenefitRow.fromJson(
        Map<String, dynamic>.from(benefit as Map),
      ),
  ];

  bool _loading = false;
  String? _error;
  Map<String, String> _serverErrors = {};

  bool get _editing => widget.plan != null;

  static bool _readActive(dynamic value) {
    // The API may represent MySQL TINYINT values as 0/1,
    // or return a native boolean.
    if (value == false || value == 0 || value == '0') {
      return false;
    }

    return true;
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _description.dispose();

    for (final benefit in _benefits) {
      benefit.dispose();
    }

    super.dispose();
  }

  // ---------------- Validation ----------------

  String? _validateCode(String? value) {
    final code = (value ?? '').trim();

    return RegExp(r'^[a-z0-9][a-z0-9_-]{1,49}$')
        .hasMatch(code)
        ? null
        : 'Use 2–50 lowercase letters, numbers, hyphens or underscores.';
  }

  String? _validateName(String? value) {
    final name = (value ?? '').trim();

    return name.isEmpty || name.length > 100
        ? 'Name must be 1–100 characters.'
        : null;
  }

  String? _validateDescription(String? value) {
    final description = (value ?? '').trim();

    return description.length > 1000
        ? 'Maximum 1000 characters.'
        : null;
  }

  String? _validateBenefitCode(String? value) {
    final code = (value ?? '').trim();

    return RegExp(r'^[a-z0-9][a-z0-9_-]{0,99}$')
        .hasMatch(code)
        ? null
        : 'Use 1–100 lowercase letters, numbers, hyphens or underscores.';
  }

  String? _validateBenefitDescription(String? value) {
    final description = (value ?? '').trim();

    return description.isEmpty || description.length > 1000
        ? 'Description must be 1–1000 characters.'
        : null;
  }

  String? _validateConfiguration(String? value) {
    final text = (value ?? '').trim();

    if (text.isEmpty) return null;

    try {
      final decoded = jsonDecode(text);

      if (decoded is! Map && decoded is! List) {
        return 'Enter a JSON object, JSON array, or leave empty.';
      }

      return null;
    } on FormatException {
      return 'Enter valid JSON.';
    }
  }

  // ---------------- Benefits ----------------

  void _addBenefit() {
    if (_benefits.length >= 20) {
      setState(() {
        _error = 'A plan can have at most 20 benefits.';
      });
      return;
    }

    setState(() {
      _error = null;
      _benefits.add(_BenefitRow());
    });
  }

  void _removeBenefit(int index) {
    final benefit = _benefits[index];

    setState(() {
      _benefits.removeAt(index);
      _serverErrors = {};
    });

    // Dispose after Flutter has removed the corresponding fields.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      benefit.dispose();
    });
  }

  // ---------------- Save ----------------

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (!_form.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _serverErrors = {};
    });

    final benefits = <Map<String, dynamic>>[];

    for (final benefit in _benefits) {
      final rawConfiguration = benefit.configuration.text.trim();

      benefits.add({
        'benefit_code': benefit.code.text.trim(),
        'description': benefit.description.text.trim(),
        'configuration_json': rawConfiguration.isEmpty
            ? null
            : jsonDecode(rawConfiguration),
      });
    }

    final body = <String, dynamic>{
      if (!_editing) 'code': _code.text.trim(),
      'name': _name.text.trim(),
      'description': _description.text.trim().isEmpty
          ? null
          : _description.text.trim(),
      'active': _active,
      'benefits': benefits,
    };

    try {
      if (_editing) {
        final rawId = widget.plan!['id'];
        final id = rawId is int
            ? rawId
            : int.parse(rawId.toString());

        await ApiService.instance.adminUpdatePlan(id, body);
      } else {
        await ApiService.instance.adminCreatePlan(body);
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;

      final errors = Map<String, String>.from(e.fieldErrors);

      if (e.statusCode == 409) {
        errors['code'] = e.message;
      }

      final generalErrors = <String>[];

      for (final entry in errors.entries) {
        if (!entry.key.startsWith('benefits.') &&
            entry.key != 'code' &&
            entry.key != 'name' &&
            entry.key != 'description' &&
            entry.key != 'active') {
          generalErrors.add(entry.value);
        }
      }

      setState(() {
        _serverErrors = errors;
        _error = generalErrors.isNotEmpty
            ? generalErrors.join('\n')
            : (errors.isEmpty ? e.message : null);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to save the plan. Please try again.';
        _loading = false;
      });
    }
  }

  // ---------------- UI helpers ----------------

  Widget _textField({
    required String serverKey,
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool enabled = true,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: enabled && !_loading,
        validator: validator,
        maxLines: maxLines,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        forceErrorText: _serverErrors[serverKey],
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _benefitFields(int index) {
    final benefit = _benefits[index];

    return Card(
      key: ObjectKey(benefit),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Benefit ${index + 1}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove benefit',
                  onPressed: _loading
                      ? null
                      : () => _removeBenefit(index),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            _textField(
              serverKey: 'benefits.$index.benefit_code',
              label: 'Benefit code',
              controller: benefit.code,
              validator: _validateBenefitCode,
              helper: 'Example: special_offers',
            ),
            _textField(
              serverKey: 'benefits.$index.description',
              label: 'Benefit description',
              controller: benefit.description,
              validator: _validateBenefitDescription,
              maxLines: 2,
            ),
            _textField(
              serverKey: 'benefits.$index.configuration_json',
              label: 'Configuration JSON (optional)',
              controller: benefit.configuration,
              validator: _validateConfiguration,
              maxLines: 4,
              helper:
              'Example: {"discount_percent": 5}. Leave empty for no configuration.',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit membership plan' : 'New membership plan'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _textField(
              serverKey: 'code',
              label: 'Plan code',
              controller: _code,
              validator: _validateCode,
              enabled: !_editing,
              helper: _editing
                  ? 'The plan code cannot be changed.'
                  : 'Example: family-basic',
            ),
            _textField(
              serverKey: 'name',
              label: 'Plan name',
              controller: _name,
              validator: _validateName,
            ),
            _textField(
              serverKey: 'description',
              label: 'Description (optional)',
              controller: _description,
              validator: _validateDescription,
              maxLines: 3,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              subtitle: const Text(
                'Whether this plan is available for use.',
              ),
              value: _active,
              onChanged: _loading
                  ? null
                  : (value) {
                setState(() {
                  _active = value;
                  _serverErrors.remove('active');
                });
              },
            ),
            const Divider(height: 32),
            Text(
              'Membership benefits',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Each benefit has a code, description and optional JSON '
                  'configuration. The configuration is stored separately '
                  'from the benefit description.',
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < _benefits.length; i++)
              _benefitFields(i),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _loading ? null : _addBenefit,
                icon: const Icon(Icons.add),
                label: const Text('Add benefit'),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 24),
            LoadingButton(
              label: _editing ? 'Save changes' : 'Create plan',
              loading: _loading,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
