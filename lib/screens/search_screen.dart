import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/custom_loader.dart';
import '../widgets/shop_card.dart';
import 'shop_menu_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = "";
  GeoPoint? _userLocation;

  final Color primaryGreen = const Color(0xFF00bf63);

  late TabController _tabController;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fetchUserLocation();
  }

  Future<void> _fetchUserLocation() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final location = data['location'] as Map<String, dynamic>?;
          if (location != null && location['geopoint'] != null) {
            if (mounted) {
              setState(() => _userLocation = location['geopoint'] as GeoPoint);
            }
            return;
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final double? lat = prefs.getDouble('cached_geopoint_lat');
      final double? lon = prefs.getDouble('cached_geopoint_lon');
      if (lat != null && lon != null) {
        if (mounted) setState(() => _userLocation = GeoPoint(lat, lon));
      }
    } catch (e) {
      debugPrint('Error fetching user location: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    _animController.dispose();
    super.dispose();
  }

  bool _matchesSearch(String text, String query) {
    if (query.isEmpty) return true;
    final t = text.toLowerCase();
    final q = query.toLowerCase();
    return t.startsWith(q) || t.contains(' $q');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: Column(
        children: [
          _buildSearchHeader(context),
          _buildTabBar(),
          Expanded(
            child: _searchQuery.isEmpty
                ? _buildInitialState()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildShopSearchResults(),
                      _buildFoodSearchResults(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── Search Header ──────────────────────────────────────────────────────────

  Widget _buildSearchHeader(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          right: 16,
          bottom: 14,
        ),
        child: Row(
          children: [
            // Back button
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6F8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: Color(0xFF111111),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Search field
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6F8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _focusNode.hasFocus
                        ? primaryGreen.withOpacity(0.4)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        autofocus: true,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111111),
                          letterSpacing: -0.1,
                        ),
                        decoration: InputDecoration(
                          hintText: "Restaurants, food...",
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w500,
                            fontSize: 14.5,
                          ),
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (value) {
                          setState(() => _searchQuery = value.trim());
                        },
                      ),
                    ),
                    // Clear button
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: _searchQuery.isNotEmpty
                          ? GestureDetector(
                              key: const ValueKey('clear'),
                              onTap: () {
                                _searchController.clear();
                                setState(() => _searchQuery = "");
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded,
                                      size: 13, color: Colors.white),
                                ),
                              ),
                            )
                          : const SizedBox(key: ValueKey('empty'), width: 10),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab Bar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: primaryGreen,
            unselectedLabelColor: Colors.grey[400],
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              letterSpacing: 0.2,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
            indicatorColor: primaryGreen,
            indicatorWeight: 2.5,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: "Restaurants"),
              Tab(text: "Food Items"),
            ],
          ),
          // Subtle bottom shadow separator
          Container(
            height: 1,
            color: Colors.grey.shade100,
          ),
        ],
      ),
    );
  }

  // ── Initial / Empty State ──────────────────────────────────────────────────

  Widget _buildInitialState() {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.search_rounded,
                    size: 34,
                    color: primaryGreen.withOpacity(0.7),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "What are you craving today?",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF333333),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Search for restaurants or food items nearby",
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shop Results ───────────────────────────────────────────────────────────

  Widget _buildShopSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .where('verificationStatus', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CustomLoader());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoResults("No matching restaurants found.");
        }

        final queryLower = _searchQuery.toLowerCase();
        final results = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final shopName = (data['shopName'] ?? '').toString();
          final category = (data['category'] ?? '').toString();
          return _matchesSearch(shopName, queryLower) ||
              _matchesSearch(category, queryLower);
        }).toList();

        if (results.isEmpty) {
          return _buildNoResults("No matching restaurants found.");
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: false,
          itemCount: results.length,
          itemBuilder: (context, index) {
            final doc = results[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildAnimatedItem(
              index: index,
              child: ShopCard(
                shopId: doc.id,
                data: data,
                userLocation: _userLocation,
                isCompact: true,
                defaultIcon: Icons.restaurant,
                defaultCategory: "Restaurant",
              ),
            );
          },
        );
      },
    );
  }

  // ── Food Results ───────────────────────────────────────────────────────────

  Widget _buildFoodSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('food_items')
          .where('isSoldOut', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CustomLoader());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoResults("No matching food found.");
        }

        final queryLower = _searchQuery.toLowerCase();
        final results = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final itemName = (data['name'] ?? '').toString();
          return _matchesSearch(itemName, queryLower);
        }).toList();

        if (results.isEmpty) {
          return _buildNoResults("No matching food found.");
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: false,
          itemCount: results.length,
          itemBuilder: (context, index) {
            final doc = results[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildAnimatedItem(
              index: index,
              child: _buildFoodItemCard(context, data),
            );
          },
        );
      },
    );
  }

  // ── Staggered list item animation ─────────────────────────────────────────

  Widget _buildAnimatedItem({required int index, required Widget child}) {
    final double start = (index * 0.06).clamp(0.0, 0.7);
    final double end = (start + 0.4).clamp(0.1, 1.0);
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _animController,
        curve: Interval(start, end, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        )),
        child: child,
      ),
    );
  }

  String _formatItemName(String name) {
    if (name.trim().isEmpty) return name;
    return name.trim().split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return word;
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }

  // ── Food Item Card ─────────────────────────────────────────────────────────

  Widget _buildFoodItemCard(BuildContext context, Map<String, dynamic> data) {
    final String shopId = data['shopId'] ?? '';
    final String shopName = data['shopName'] ?? 'Unknown Shop';
    final String imageUrl = data['imageUrl'] ?? '';
    final bool hasDiscount = data['originalPrice'] != null &&
        data['originalPrice'] != data['discountedPrice'];
    final int discountPercent = hasDiscount
        ? (((data['originalPrice'] - data['discountedPrice']) /
                    data['originalPrice']) *
                100)
            .round()
        : 0;

    return GestureDetector(
      onTap: () {
        if (shopId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ShopMenuScreen(shopId: shopId, shopName: shopName),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.025),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Image
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            height: 86,
                            width: 86,
                            fit: BoxFit.cover,
                            cacheWidth: 172,
                            cacheHeight: 172,
                            gaplessPlayback: true,
                            errorBuilder: (_, __, ___) =>
                                _buildFoodPlaceholder(data['name']),
                          )
                        : _buildFoodPlaceholder(data['name']),
                  ),
                  if (hasDiscount)
                    Positioned(
                      top: 5,
                      left: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD32F2F),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          '$discountPercent%',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatItemName(data['name'] ?? 'Unknown Item'),
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111111),
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 5),

                    // Shop name row
                    Row(
                      children: [
                        Icon(Icons.storefront_rounded,
                            size: 12, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            shopName,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Price row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '₹${data['discountedPrice']}',
                          style: TextStyle(
                            color: primaryGreen,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: -0.5,
                            height: 1,
                          ),
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(width: 8),
                          Text(
                            '₹${data['originalPrice']}',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12.5,
                              decoration: TextDecoration.lineThrough,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: primaryGreen.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: primaryGreen.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_forward_ios_rounded,
                                  size: 10, color: primaryGreen),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFoodPlaceholder(String? itemName) {
    String firstLetter = '';
    if (itemName != null && itemName.trim().isNotEmpty) {
      firstLetter = itemName.trim().substring(0, 1).toUpperCase();
    }

    return Container(
      height: 86,
      width: 86,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: firstLetter.isNotEmpty
          ? Center(
              child: Text(
                firstLetter,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : Icon(Icons.fastfood_rounded, color: Colors.grey[350], size: 30),
    );
  }

  // ── No Results ─────────────────────────────────────────────────────────────

  Widget _buildNoResults(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.search_off_rounded,
                    size: 30, color: Colors.grey[350]),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            message,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF555555),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Try a different keyword",
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}