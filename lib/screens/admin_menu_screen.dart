import 'package:flutter/material.dart';

import 'admin_categories_screen.dart';
import 'admin_membership_plans_screen.dart';
import 'admin_products_screen.dart';
import 'admin_tax_rates_screen.dart';
import 'admin_users_screen.dart';
import 'admin_shipping_screen.dart';

class AdminMenuScreen extends StatelessWidget {
  final int currentUserId;
  const AdminMenuScreen({super.key, required this.currentUserId});

  Widget _entry(BuildContext context, IconData icon, String title, Widget screen) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: ListView(
        children: [
          _entry(context, Icons.people_outline, 'Users', AdminUsersScreen(currentUserId: currentUserId)),
          _entry(context, Icons.inventory_2_outlined, 'Products', const AdminProductsScreen()),
          _entry(context, Icons.category_outlined, 'Categories', const AdminCategoriesScreen()),
          _entry(context, Icons.percent, 'Tax rates', const AdminTaxRatesScreen()),
          _entry(context, Icons.card_membership_outlined, 'Membership plans', const AdminMembershipPlansScreen()),
          _entry(context, Icons.local_shipping_outlined, 'Shipping', const AdminShippingScreen()),
        ],
      ),
    );
  }
}