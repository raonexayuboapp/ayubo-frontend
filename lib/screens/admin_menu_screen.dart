import 'package:flutter/material.dart';

import '../widgets/app_header.dart';
import 'admin_categories_screen.dart';
import 'admin_membership_plans_screen.dart';
import 'admin_products_screen.dart';
import 'admin_shipping_screen.dart';
import 'admin_tax_rates_screen.dart';
import 'admin_users_screen.dart';
import 'admin_vouchers_screen.dart';

class AdminMenuScreen extends StatelessWidget {
  final int currentUserId;
  const AdminMenuScreen({super.key, required this.currentUserId});

  Widget _entry(BuildContext context, IconData icon, String title, Widget screen) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.secondary;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: goldColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: goldColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: 20,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
      ),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const AppHeader(
        title: 'Admin Console',
        subtitle: 'Store Operations & Catalog',
        showBackButton: true,
        showAdmin: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _entry(context, Icons.people_outline, 'Users', AdminUsersScreen(currentUserId: currentUserId)),
          Divider(height: 1, indent: 60, endIndent: 20, color: theme.dividerColor.withValues(alpha: 0.2)),
          _entry(context, Icons.inventory_2_outlined, 'Products', const AdminProductsScreen()),
          Divider(height: 1, indent: 60, endIndent: 20, color: theme.dividerColor.withValues(alpha: 0.2)),
          _entry(context, Icons.category_outlined, 'Categories', const AdminCategoriesScreen()),
          Divider(height: 1, indent: 60, endIndent: 20, color: theme.dividerColor.withValues(alpha: 0.2)),
          _entry(context, Icons.percent, 'Tax rates', const AdminTaxRatesScreen()),
          Divider(height: 1, indent: 60, endIndent: 20, color: theme.dividerColor.withValues(alpha: 0.2)),
          _entry(context, Icons.card_membership_outlined, 'Membership plans', const AdminMembershipPlansScreen()),
          Divider(height: 1, indent: 60, endIndent: 20, color: theme.dividerColor.withValues(alpha: 0.2)),
          _entry(context, Icons.local_shipping_outlined, 'Shipping', const AdminShippingScreen()),
          Divider(height: 1, indent: 60, endIndent: 20, color: theme.dividerColor.withValues(alpha: 0.2)),
          _entry(context, Icons.card_giftcard_outlined, 'Vouchers', const AdminVouchersScreen()),
        ],
      ),
    );
  }
}