import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/cart_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/compact_product_card.dart';
import '../widgets/home/home_bestsellers_section.dart';
import '../widgets/home/home_categories_section.dart';
import '../widgets/home/home_family_promo_section.dart';
import '../widgets/home/home_header.dart';
import '../widgets/home/home_membership_card.dart';
import '../widgets/home/home_promo_banner.dart';
import '../widgets/home/home_search_bar.dart';
import '../widgets/home/home_shop_experience_section.dart';
import '../widgets/home/home_trust_footer.dart';
import '../widgets/settings_modal.dart';
import 'family_screen.dart';
import 'products_screen.dart';

typedef ProductData = Map<String, dynamic>;
typedef CategoryData = Map<String, dynamic>;

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? user;

  const HomeScreen({super.key, this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _user;

  List<CategoryData> _categories = [];
  List<ProductData> _bestSellers = [];
  List<ProductData> _newArrivals = [];
  List<ProductData> _collectionProducts = [];
  Map<String, dynamic>? _membership;

  bool _loading = true;
  String? _error;
  int _loadRequestId = 0;

  bool get _isGuest => _user == null || _user!.isEmpty || _user!['id'] == null;

  @override
  void initState() {
    super.initState();
    _user = widget.user;

    if (!_isGuest) {
      CartState.instance.refresh();
    }

    _loadHomeData();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.user != oldWidget.user) {
      _user = widget.user;

      if (!_isGuest) {
        CartState.instance.refresh();
      } else {
        CartState.instance.clear();
      }

      _loadHomeData();
    }
  }

  void _handleSessionExpired() {
    CartState.instance.clear();

    if (mounted) {
      setState(() {
        _user = null;
        _membership = null;
      });
    } else {
      _user = null;
      _membership = null;
    }
  }

  Future<void> _loadHomeData() async {
    final currentRequestId = ++_loadRequestId;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final futures = <Future<dynamic>>[
        ApiService.instance.listCategories(),
        ApiService.instance.getBestSellers(),
        ApiService.instance.listProducts(page: 1, sort: 'newest'),
        ApiService.instance.listProducts(page: 1, sort: 'name'),
      ];

      // Fetch membership status for authenticated customers.
      if (!_isGuest) {
        futures.add(
          ApiService.instance.membershipPlans().catchError((err) {
            if (err is ApiException && err.statusCode == 401) {
              _handleSessionExpired();
            }

            return <String, dynamic>{'plans': <dynamic>[], 'membership': null};
          }),
        );
      }

      final results = await Future.wait(futures);

      if (!mounted || currentRequestId != _loadRequestId) return;

      final categoryTree = results[0] as List<dynamic>;
      final bestSellerData = results[1] as List<dynamic>;
      final newestData = results[2] as Map<String, dynamic>;
      final nameData = results[3] as Map<String, dynamic>;

      // Best Sellers: backend-ranked products based on paid units sold.
      final bestSellers = bestSellerData
          .whereType<ProductData>()
          .take(6)
          .toList();

      final newestList = (newestData['products'] as List<dynamic>? ?? const [])
          .whereType<ProductData>()
          .toList();

      final nameList = (nameData['products'] as List<dynamic>? ?? const [])
          .whereType<ProductData>()
          .toList();

      // New Arrivals are independent of Best Sellers.
      // A product can appear in both sections.
      final newArrivals = newestList.take(6).toList();

      // Keep the additional collection grid free of products
      // already displayed in Best Sellers or New Arrivals.
      final bestSellerIds = bestSellers.map((p) => p['id']).toSet();
      final arrivalIds = newArrivals.map((p) => p['id']).toSet();

      final collection = nameList
          .where(
            (p) =>
                !bestSellerIds.contains(p['id']) &&
                !arrivalIds.contains(p['id']),
          )
          .take(8)
          .toList();

      Map<String, dynamic>? memberData;

      if (results.length > 4 && results[4] is Map<String, dynamic>) {
        memberData =
            (results[4] as Map<String, dynamic>)['membership']
                as Map<String, dynamic>?;
      }

      setState(() {
        _categories = categoryTree.whereType<CategoryData>().toList();
        _bestSellers = bestSellers;
        _newArrivals = newArrivals;
        _collectionProducts = collection;
        _membership = memberData;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted || currentRequestId != _loadRequestId) return;

      if (e.statusCode == 401) {
        _handleSessionExpired();
      }

      final msg = e.statusCode == 401
          ? 'Session expired. Browsing as guest.'
          : e.message;

      setState(() {
        _loading = false;
        _error = msg;
      });

      if (_bestSellers.isNotEmpty || _newArrivals.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      if (!mounted || currentRequestId != _loadRequestId) return;

      const msg = 'Unable to connect to the store. Please pull down to retry.';

      setState(() {
        _loading = false;
        _error = msg;
      });

      if (_bestSellers.isNotEmpty || _newArrivals.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _refreshUser() async {
    try {
      if (!await ApiService.instance.hasToken()) {
        if (!_isGuest) {
          _handleSessionExpired();
          _loadHomeData();
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
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        _handleSessionExpired();
        _loadHomeData();
      }
    } catch (_) {}
  }

  void _openCatalogue([String sort = 'newest']) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProductsScreen(user: _user ?? const {}, initialSort: sort),
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
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
                color: AppTheme.textPrimary(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
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

  Widget _buildNewArrivalsCarousel() {
    if (_newArrivals.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 268,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _newArrivals.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final product = _newArrivals[index];

          return CompactProductCard(product: product, user: _user, width: 168);
        },
      ),
    );
  }

  Widget _buildCollectionGrid(BoxConstraints constraints) {
    if (_collectionProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    final width = constraints.maxWidth;
    final crossAxisCount = width > 800 ? 4 : (width > 550 ? 3 : 2);
    final cardAspectRatio = width > 800 ? 0.68 : (width > 550 ? 0.66 : 0.64);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _collectionProducts.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 14,
          mainAxisSpacing: 16,
          childAspectRatio: cardAspectRatio,
        ),
        itemBuilder: (context, index) {
          return CompactProductCard(
            product: _collectionProducts[index],
            user: _user,
          );
        },
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    final isDark = AppTheme.isDark(context);
    final shimmerColor = isDark
        ? const Color(0xFF1B2A20)
        : const Color(0xFFE8ECE8);

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: shimmerColor,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 16,
                    decoration: BoxDecoration(
                      color: shimmerColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 180,
                    height: 12,
                    decoration: BoxDecoration(
                      color: shimmerColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              4,
              (_) => Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: shimmerColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 48,
                    height: 10,
                    decoration: BoxDecoration(
                      color: shimmerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          onRefresh: _loadHomeData,
          color: AppTheme.brandGold,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 40,
                  ),
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
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body:
          _loading &&
              _bestSellers.isEmpty &&
              _newArrivals.isEmpty &&
              _collectionProducts.isEmpty
          ? SafeArea(child: _buildLoadingSkeleton())
          : _error != null &&
                _bestSellers.isEmpty &&
                _newArrivals.isEmpty &&
                _collectionProducts.isEmpty
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
                          // Header
                          SliverToBoxAdapter(
                            child: HomeHeader(
                              user: _user,
                              onProfileClosed: _refreshUser,
                              onOpenSettings: () =>
                                  showAppSettingsModal(context),
                            ),
                          ),

                          // Search
                          SliverToBoxAdapter(child: HomeSearchBar(user: _user)),

                          // 1. Active paid membership section
                          if (!_isGuest && _membership != null)
                            SliverToBoxAdapter(
                              child: HomeMembershipCard(
                                user: _user,
                                membership: _membership,
                              ),
                            ),

                          // 2. Categories
                          SliverToBoxAdapter(
                            child: HomeCategoriesSection(
                              user: _user,
                              categories: _categories,
                            ),
                          ),

                          // 3. Best Sellers
                          SliverToBoxAdapter(
                            child: HomeBestSellersSection(
                              products: _bestSellers,
                              user: _user,
                              loading: _loading && _bestSellers.isEmpty,
                              error: _error != null && _bestSellers.isEmpty
                                  ? _error
                                  : null,
                              onRetry: _loadHomeData,
                              onViewAll: () => _openCatalogue('name'),
                            ),
                          ),

                          // 4. Physical Shop
                          SliverToBoxAdapter(
                            child: HomeShopExperienceSection(
                              user: _user,
                              onExploreProducts: () => _openCatalogue('newest'),
                            ),
                          ),

                          // 5. New Arrivals
                          if (_newArrivals.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: _buildSectionHeader(
                                title: l10n?.newArrivals ?? 'New Arrivals',
                                actionLabel: l10n?.viewAll ?? 'View All',
                                onAction: () => _openCatalogue('newest'),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: _buildNewArrivalsCarousel(),
                            ),
                          ],

                          // 6. Ayubo Family Membership Promotion
                          SliverToBoxAdapter(
                            child: HomeFamilyPromoSection(
                              user: _user,
                              membership: _membership,
                              onExplore: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FamilyScreen(
                                      user: _user ?? const {},
                                      initialSection: 0,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          // 7. Gift Voucher section
                          SliverToBoxAdapter(
                            child: HomePromoBanner(user: _user),
                          ),

                          // Additional Product Discovery Grid
                          if (_collectionProducts.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: _buildSectionHeader(
                                title:
                                    l10n?.exploreCollection ??
                                    'Explore Our Collection',
                                actionLabel: l10n?.viewAll ?? 'View All',
                                onAction: () => _openCatalogue('name'),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: _buildCollectionGrid(constraints),
                            ),
                          ],

                          // Trust Badges & Brand Footer
                          const SliverToBoxAdapter(child: HomeTrustFooter()),
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
