import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/app_top_bar.dart';
import 'plan_detail_screen.dart';

/// The Family tab: displays available membership plans.
/// Details and "Add to cart" are handled by PlanDetailScreen.
class FamilyScreen extends StatefulWidget {
final Map<String, dynamic> user;

const FamilyScreen({
super.key,
required this.user,
});

@override
State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
List<Map<String, dynamic>> _plans = [];
bool _loading = true;
String? _error;

@override
void initState() {
super.initState();
_load();
}

Future<void> _load() async {
if (mounted) {
setState(() {
_loading = true;
_error = null;
});
}

try {
final plans = await ApiService.instance.listMembershipPlans();

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

int? _readId(dynamic value) {
if (value is int && value > 0) return value;
if (value is String) return int.tryParse(value);
return null;
}

String _readString(dynamic value, {String fallback = ''}) {
if (value is String) return value.trim();
return fallback;
}

bool _isActive(dynamic value) {
if (value == true || value == 1) return true;
if (value is String) {
return value == '1' ||
value.toLowerCase() == 'true';
}
return false;
}

List<Map<String, dynamic>> _readBenefits(dynamic value) {
if (value is! List) return [];

return value
    .whereType<Map>()
    .map((benefit) => Map<String, dynamic>.from(benefit))
    .toList();
}

Widget _planCard(Map<String, dynamic> plan) {
final theme = Theme.of(context);
final name = _readString(
plan['name'],
fallback: 'Membership plan',
);
final code = _readString(plan['code']);
final description = _readString(plan['description']);
final active = _isActive(plan['active']);
final benefits = _readBenefits(plan['benefits']);

return Card(
clipBehavior: Clip.antiAlias,
child: InkWell(
onTap: () {
Navigator.push(
context,
MaterialPageRoute<void>(
builder: (_) => PlanDetailScreen(plan: plan),
),
);
},
child: Padding(
padding: const EdgeInsets.all(16),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Expanded(
child: Text(
name,
style: theme.textTheme.titleLarge,
),
),
const SizedBox(width: 8),
Chip(
label: Text(active ? 'ACTIVE' : 'INACTIVE'),
visualDensity: VisualDensity.compact,
),
],
),
if (code.isNotEmpty) ...[
const SizedBox(height: 4),
Text(
code,
style: theme.textTheme.bodySmall,
),
],
if (description.isNotEmpty) ...[
const SizedBox(height: 8),
Text(description),
],
if (benefits.isNotEmpty) ...[
const SizedBox(height: 12),
Text(
'Benefits',
style: theme.textTheme.titleSmall,
),
const SizedBox(height: 4),
...benefits.take(3).map((benefit) {
final benefitDescription = _readString(
benefit['description'],
fallback: _readString(
benefit['benefit_code'],
fallback: 'Membership benefit',
),
);

return Padding(
padding: const EdgeInsets.only(bottom: 4),
child: Row(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Icon(
Icons.check_circle_outline,
size: 18,
color: theme.colorScheme.primary,
),
const SizedBox(width: 8),
Expanded(child: Text(benefitDescription)),
],
),
);
}),
if (benefits.length > 3)
Text(
'+ ${benefits.length - 3} more benefits',
style: theme.textTheme.bodySmall,
),
],
const SizedBox(height: 12),
Row(
mainAxisAlignment: MainAxisAlignment.end,
children: [
Text(
'View details',
style: TextStyle(
color: theme.colorScheme.primary,
),
),
Icon(
Icons.chevron_right,
color: theme.colorScheme.primary,
),
],
),
],
),
),
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
TextButton(
onPressed: _load,
child: const Text('Retry'),
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
Center(
child: Text(
'No membership plans available right now.',
),
),
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
separatorBuilder: (_, __) =>
const SizedBox(height: 12),
itemBuilder: (_, index) => _planCard(_plans[index]),
),
);
}

return Scaffold(
appBar: AppTopBar(user: widget.user),
body: body,
bottomNavigationBar: AppBottomBar(
currentIndex: 2,
user: widget.user,
),
);
}
}