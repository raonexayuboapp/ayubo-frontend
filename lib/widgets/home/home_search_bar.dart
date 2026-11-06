import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../screens/products_screen.dart';
import '../../theme/app_theme.dart';

class HomeSearchBar extends StatefulWidget {
  final Map<String, dynamic>? user;

  const HomeSearchBar({
    super.key,
    required this.user,
  });

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  final TextEditingController _controller = TextEditingController();

  void _submitSearch(String query) {
    final clean = query.trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductsScreen(
          user: widget.user ?? const {},
          initialSearch: clean,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = AppTheme.isDark(context);
    final hint = l10n?.searchWellness ?? 'Search products, wellness...';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.borderColor(context),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(
              Icons.search_rounded,
              size: 22,
              color: isDark ? AppTheme.leafGreen : AppTheme.primaryGreen,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: _submitSearch,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary(context),
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                    color: AppTheme.textSecondary(context).withValues(alpha: 0.75),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() => _controller.clear());
                },
              ),
            InkWell(
              onTap: () => _submitSearch(_controller.text),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.brandGold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: AppTheme.brandGoldDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

