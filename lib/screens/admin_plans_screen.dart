import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'admin_plan_form_screen.dart';

class AdminPlansScreen extends StatefulWidget {
  const AdminPlansScreen({super.key});

  @override
  State<AdminPlansScreen> createState() => _AdminPlansScreenState();
}

class _AdminPlansScreenState extends State<AdminPlansScreen> {
  List<Map<String, dynamic>> _plans = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Safely converts API values to an integer.
  // Handles MySQL IDs returned as either int or numeric strings.
  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  // MySQL TINYINT values may be returned as 1/0 or "1"/"0".
  bool _readActive(dynamic value) {
    return value == true ||
        value == 1 ||
        value == '1';
  }

  String _readString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString();
  }

  List<Map<String, dynamic>> _readBenefits(dynamic value) {
    if (value is! List) return [];

    return value
        .whereType<Map>()
        .map((benefit) => Map<String, dynamic>.from(benefit))
        .toList();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final plans = await ApiService.instance.adminListPlans();

      if (!mounted) return;

      setState(() {
        _plans = plans;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to load membership plans. Please try again.';
        _loading = false;
      });
    }
  }

  Future<void> _openForm([Map<String, dynamic>? plan]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminPlanFormScreen(plan: plan),
      ),
    );

    if (!mounted) return;

    if (saved == true) {
      await _load();
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> plan) async {
    final id = _readInt(plan['id']);

    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot update this plan because its ID is missing or invalid.',
          ),
        ),
      );
      return;
    }

    final active = _readActive(plan['active']);
    final name = _readString(plan['name'], fallback: 'this plan');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(active ? 'Deactivate plan?' : 'Activate plan?'),
        content: Text(
          active
              ? '"$name" will no longer be available for new purchases.'
              : '"$name" will become available for use again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      // Use the new schema field: active, not is_active.
      await ApiService.instance.adminUpdatePlan(
        id,
        {'active': !active},
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            active ? 'Membership plan deactivated.' : 'Membership plan activated.',
          ),
        ),
      );

      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update the plan. Please try again.'),
        ),
      );
    }
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final id = _readInt(plan['id']);
    final name = _readString(plan['name'], fallback: 'Unnamed plan');
    final code = _readString(plan['code'], fallback: 'No code');
    final description = _readString(plan['description']);
    final active = _readActive(plan['active']);
    final benefits = _readBenefits(plan['benefits']);

    return Card(
      child: ListTile(
        onTap: () => _openForm(plan),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(active ? 'Active' : 'Inactive'),
              visualDensity: VisualDensity.compact,
              backgroundColor: active
                  ? Colors.green.withValues(alpha: 0.12)
                  : null,
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Code: $code'),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(description),
              ],
              const SizedBox(height: 8),
              Text(
                'Benefits (${benefits.length})',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (benefits.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('No benefits configured.'),
                )
              else
                ...benefits.map((benefit) {
                  final benefitDescription = _readString(
                    benefit['description'],
                    fallback: 'Unnamed benefit',
                  );

                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(child: Text(benefitDescription)),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Plan actions',
          onSelected: (action) {
            if (action == 'edit') {
              _openForm(plan);
            } else if (action == 'toggle') {
              _toggleActive(plan);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('Edit plan'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: ListTile(
                leading: Icon(
                  active ? Icons.toggle_off_outlined : Icons.toggle_on_outlined,
                ),
                title: Text(active ? 'Deactivate' : 'Activate'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.more_vert),
          ),
        ),
        isThreeLine: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;

    if (_loading) {
      body = const Center(
        child: CircularProgressIndicator(),
      );
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    } else if (_plans.isEmpty) {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(child: Icon(Icons.card_membership_outlined, size: 48)),
            SizedBox(height: 12),
            Center(child: Text('No membership plans yet.')),
            SizedBox(height: 8),
            Center(child: Text('Create a plan to get started.')),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: _plans.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, index) => _buildPlanCard(_plans[index]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Membership plans'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: body,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('New plan'),
      ),
    );
  }
}
