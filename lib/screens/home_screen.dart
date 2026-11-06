import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/cart_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/home/compact_product_card.dart';
import '../widgets/home/home_categories_section.dart';
import '../widgets/home/home_header.dart';
import '../widgets/home/home_membership_card.dart';
import '../widgets/home/home_promo_banner.dart';
import '../widgets/home/home_search_bar.dart';
import '../widgets/home/home_trust_footer.dart';
import '../widgets/settings_modal.dart';
import 'products_screen.dart';

typedef ProductData = Map<String, dynamic>;
typedef CategoryData = Map<String, dynamic>;

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? user;

  const HomeScreen({
    super.key,
    this.user,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _user;

  List<CategoryData> _categories = [];
  List<ProductData> _popularProducts = [];
  List<ProductData> _newArrivals = [];
  Map<String, dynamic>? _membership;

  bool _loading = true;
  String? _error;

  bool get _isGuest => _user == null;

  @override
  void initState() {
    super.initState();
    _user = widget.user;

    if (!_isGuest) {
      CartState.instance.refresh();
    }

    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final futures = <Future<dynamic>>[
        ApiService.instance.listCategories(),
        ApiService.instance.listProducts(page: 1, sort: 'newest'),
      ];

      // If user is authenticated, fetch their membership status as well
      if (!_isGuest) {
        futures.add(
          ApiService.instance.membershipPlans().catchError(
                (_) => <String, dynamic>{'plans': <dynamic>[], 'membership': null},
              ),
        );
      }

      final results = await Future.wait(futures);

      if (!mounted) return;

      final categoryTree = results[0] as List<dynamic>;
      final productData = results[1] as Map<String, dynamic>;
      final allProducts = (productData['products'] as List<dynamic>).cast<ProductData>();

      // Divide products cleanly so "Popular Products" and "New Arrivals" show distinct selections
      final popular = allProducts.take(6).toList();
      final arrivals = allProducts.skip(popular.length >= 4 ? 4 : 0).take(6).toList();

      Map<String, dynamic>? memberData;
      if (results.length > 2 && results[2] is Map<String, dynamic>) {
        memberData = (results[2] as Map<String, dynamic>)['membership'] as Map<String, dynamic>?;
      }

      setState(() {
        _categories = categoryTree.cast<CategoryData>();
        _popularProducts = popular;
        _newArrivals = arrivals.isNotEmpty ? arrivals : popular;
        _membership = memberData;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.statusCode == 401 ? 'Unable to load store data.' : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to connect to the store. Please pull down to retry.';
      });
    }
  }

  Future<void> _refreshUser() async {
    try {
      if (!await ApiService.instance.hasToken()) {
        if (mounted && _user != null) {
          setState(() {
            _user = null;
            _membership = null;
          });
        }
        return;
      }

      final fresh = await ApiService.instance.me();

      if (mounted) {
        setState(() {
          _user = fresh;
        });
        CartState.instance.refresh();
        _loadHomeData();
      }
    } catch (_) {}
  }

  void _openCatalogue() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductsScreen(user: _user ?? const {}),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
              color: AppTheme.textPrimary(context),
            ),
          ),
          GestureDetector(
            onTap: onAction,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: AppTheme.primaryGreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularProductsCarousel() {
    if (_popularProducts.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 252,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _popularProducts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final product = _popularProducts[index];
          return CompactProductCard(
            product: product,
            user: _user,
            width: 168,
          );
        },
      ),
    );
  }

  Widget _buildNewArrivalsGrid(BoxConstraints constraints) {
    if (_newArrivals.isEmpty) return const SizedBox.shrink();

    final width = constraints.maxWidth;
    final crossAxisCount = width > 800 ? 4 : (width > 550 ? 3 : 2);
    final cardAspectRatio = width > 600 ? 0.72 : 0.70;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _newArrivals.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 14,
          mainAxisSpacing: 16,
          childAspectRatio: cardAspectRatio,
        ),
        itemBuilder: (context, index) {
          return CompactProductCard(
            product: _newArrivals[index],
            user: _user,
          );
        },
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    final isDark = AppTheme.isDark(context);
    final shimmerColor = isDark ? const Color(0xFF1B2A20) : const Color(0xFFE8ECE8);

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header placeholder
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(shape: BoxShape.circle, color: shimmerColor),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 120, height: 16, decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 6),
                  Container(width: 180, height: 12, decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(6))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search bar placeholder
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),

          // Membership placeholder
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const SizedBox(height: 20),

          // Categories placeholder
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              4,
              (_) => Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: shimmerColor),
                  ),
                  const SizedBox(height: 8),
                  Container(width: 48, height: 10, decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(4))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Products row placeholder
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(color: shimmerColor, borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String message) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryGreen.withValues(alpha: 0.12),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 32,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary(context),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadHomeData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(l10n?.retry ?? 'Retry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: _loading && _popularProducts.isEmpty
          ? SafeArea(child: _buildLoadingSkeleton())
          : _error != null && _popularProducts.isEmpty
              ? SafeArea(child: _buildErrorView(_error!))
              : RefreshIndicator(
                  onRefresh: _loadHomeData,
                  color: AppTheme.brandGold,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 960),
                          child: CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              // Section A: Compact Header
                              SliverToBoxAdapter(
                                child: HomeHeader(
                                  user: _user,
                                  onProfileClosed: _refreshUser,
                                  onOpenSettings: () => showAppSettingsModal(context),
                                ),
                              ),

                              // Section B: Prominent & Compact Search
                              SliverToBoxAdapter(
                                child: HomeSearchBar(user: _user),
                              ),

                              // Section C: Compact Ayubo Family Membership
                              SliverToBoxAdapter(
                                child: HomeMembershipCard(
                                  user: _user,
                                  membership: _membership,
                                ),
                              ),

                              // Section D: Horizontal Product Categories
                              SliverToBoxAdapter(
                                child: HomeCategoriesSection(
                                  user: _user,
                                  categories: _categories,
                                ),
                              ),

                              // Section E: Popular Products Header & Horizontal Carousel
                              SliverToBoxAdapter(
                                child: _buildSectionHeader(
                                  title: l10n?.popularProducts ?? 'Popular Products',
                                  actionLabel: l10n?.viewAll ?? 'View All',
                                  onAction: _openCatalogue,
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: _buildPopularProductsCarousel(),
                              ),

                              // Section F: Contextual Promotional Card (Gift Vouchers)
                              SliverToBoxAdapter(
                                child: HomePromoBanner(user: _user),
                              ),

                              // Section G: Additional Product Discovery (New Arrivals Grid)
                              SliverToBoxAdapter(
                                child: _buildSectionHeader(
                                  title: l10n?.newArrivals ?? 'New Arrivals',
                                  actionLabel: l10n?.viewAll ?? 'View All',
                                  onAction: _openCatalogue,
                                ),
                              ),
                              SliverToBoxAdapter(
                                child: _buildNewArrivalsGrid(constraints),
                              ),

                              // Section H: Trust Badges & Minimal Brand Footer
                              const SliverToBoxAdapter(
                                child: HomeTrustFooter(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      bottomNavigationBar: AppBottomBar(
        currentIndex: 0,
        user: _user ?? const {},
      ),
    );
  }
}
