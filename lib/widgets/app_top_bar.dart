import 'package:flutter/material.dart';

import '../screens/admin_menu_screen.dart';
import '../screens/products_screen.dart';
import '../screens/profile_screen.dart';

class AppTopBar extends StatefulWidget implements PreferredSizeWidget {
final Map<String, dynamic> user;
final VoidCallback? onProfileClosed;

/// Updates the existing catalogue when searching from ProductsScreen.
final ValueChanged<String>? onSearchSubmitted;

/// Initial query when opening ProductsScreen from another page.
final String initialSearch;

const AppTopBar({
super.key,
required this.user,
this.onProfileClosed,
this.onSearchSubmitted,
this.initialSearch = '',
});

@override
Size get preferredSize => const Size.fromHeight(kToolbarHeight);

@override
State<AppTopBar> createState() => _AppTopBarState();
}

class _AppTopBarState extends State<AppTopBar> {
late final TextEditingController _searchController;

@override
void initState() {
super.initState();

_searchController = TextEditingController(
text: widget.initialSearch,
);

_searchController.addListener(_handleSearchChanged);
}

@override
void didUpdateWidget(covariant AppTopBar oldWidget) {
super.didUpdateWidget(oldWidget);

if (oldWidget.initialSearch != widget.initialSearch &&
_searchController.text != widget.initialSearch) {
_searchController.text = widget.initialSearch;
}
}

void _handleSearchChanged() {
if (mounted) {
setState(() {});
}
}

@override
void dispose() {
_searchController.removeListener(_handleSearchChanged);
_searchController.dispose();
super.dispose();
}

Future<void> _openProfile() async {
await Navigator.push(
context,
MaterialPageRoute(
builder: (_) => ProfileScreen(user: widget.user),
),
);

if (mounted) {
widget.onProfileClosed?.call();
}
}

void _submitSearch(String value) {
final query = value.trim();

// Update the current catalogue instead of opening another
// ProductsScreen when the search originates there.
if (widget.onSearchSubmitted != null) {
widget.onSearchSubmitted!(query);
return;
}

// Open the catalogue with the submitted query from other pages.
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => ProductsScreen(
user: widget.user,
initialSearch: query,
),
),
);
}

void _clearSearch() {
_searchController.clear();

// If already on ProductsScreen, immediately reset the catalogue.
widget.onSearchSubmitted?.call('');
}

@override
Widget build(BuildContext context) {
final scheme = Theme.of(context).colorScheme;

return AppBar(
automaticallyImplyLeading: false,
titleSpacing: 12,
title: Container(
height: 40,
padding: const EdgeInsets.symmetric(horizontal: 10),
decoration: BoxDecoration(
color: scheme.surfaceContainerHighest,
borderRadius: BorderRadius.circular(24),
),
child: Row(
children: [
Icon(
Icons.search,
size: 20,
color: scheme.onSurfaceVariant,
),
const SizedBox(width: 8),
Expanded(
child: TextField(
controller: _searchController,
textInputAction: TextInputAction.search,
onSubmitted: _submitSearch,
style: TextStyle(
color: scheme.onSurface,
fontSize: 14,
),
decoration: InputDecoration(
hintText: 'Search products',
hintStyle: TextStyle(
color: scheme.onSurfaceVariant,
fontSize: 14,
),
border: InputBorder.none,
isDense: true,
contentPadding: EdgeInsets.zero,
),
),
),
if (_searchController.text.isNotEmpty)
IconButton(
tooltip: 'Clear search',
visualDensity: VisualDensity.compact,
padding: EdgeInsets.zero,
constraints: const BoxConstraints(
minWidth: 30,
minHeight: 30,
),
icon: Icon(
Icons.close,
size: 18,
color: scheme.onSurfaceVariant,
),
onPressed: _clearSearch,
),
],
),
),
actions: [
if (widget.user['role'] == 'admin')
IconButton(
icon: const Icon(
Icons.admin_panel_settings_outlined,
),
tooltip: 'Admin',
onPressed: () {
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => AdminMenuScreen(
currentUserId: widget.user['id'] as int,
),
),
);
},
),
IconButton(
icon: const Icon(Icons.person_outline),
tooltip: 'My profile',
onPressed: _openProfile,
),
],
);
}
}