import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/custom_loader.dart';

import 'checkout_screen.dart';

class ShopMenuScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final Map<String, dynamic> shopData;
  final String? heroTag;

  const ShopMenuScreen({
    super.key,
    required this.shopId,
    required this.shopName,
    this.shopData = const {},
    this.heroTag,
  });

  @override
  State<ShopMenuScreen> createState() => _ShopMenuScreenState();
}

class _ShopMenuScreenState extends State<ShopMenuScreen>
    with TickerProviderStateMixin {
  final Map<String, Map<String, dynamic>> _cart = {};

  late Stream<QuerySnapshot> _foodItemsStream;

  Map<String, dynamic> _resolvedShopData = {};

  bool _isFavorite = false;
  bool _isTogglingFavorite = false;

  String _dietFilter = 'All';

  final Color primaryGreen = const Color(0xFF00bf63);

  late AnimationController _listAnimationController;
  late AnimationController _cartBarAnimationController;
  late AnimationController _headerFadeController;

  @override
  void initState() {
    super.initState();

    _listAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _cartBarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    _headerFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _foodItemsStream = FirebaseFirestore.instance
        .collection('food_items')
        .where('shopId', isEqualTo: widget.shopId)
        .where('isSoldOut', isEqualTo: false)
        .snapshots();

    if (widget.shopData.isNotEmpty) {
      _resolvedShopData = widget.shopData;
    } else {
      _fetchShopData();
    }

    _loadFavoriteStatus();
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    _cartBarAnimationController.dispose();
    _headerFadeController.dispose();
    super.dispose();
  }

  Future<void> _fetchShopData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _resolvedShopData = doc.data() as Map<String, dynamic>;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadFavoriteStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists && mounted) {
        final favorites = List<String>.from(doc.data()?['favoriteShops'] ?? []);
        setState(() => _isFavorite = favorites.contains(widget.shopId));
      }
    } catch (_) {}
  }

  Future<void> _toggleFavorite() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _isTogglingFavorite) return;

    setState(() => _isTogglingFavorite = true);

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      if (_isFavorite) {
        await userRef.update({
          'favoriteShops': FieldValue.arrayRemove([widget.shopId]),
        });
      } else {
        await userRef.update({
          'favoriteShops': FieldValue.arrayUnion([widget.shopId]),
        });
      }
      if (mounted) setState(() => _isFavorite = !_isFavorite);
    } catch (_) {}

    if (mounted) setState(() => _isTogglingFavorite = false);
  }

  void _updateCart(DocumentSnapshot doc, int change) {
    final item = doc.data() as Map<String, dynamic>;
    final id = doc.id;
    final int stock = item['quantity'] ?? 0;

    setState(() {
      if (_cart.containsKey(id)) {
        int newQty = (_cart[id]!['cartQuantity'] as int) + change;

        if (newQty > stock && change > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Only $stock items left in stock for ${item['name']}!',
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
          return;
        }

        _cart[id]!['cartQuantity'] = newQty;
        if (_cart[id]!['cartQuantity'] <= 0) {
          _cart.remove(id);
        }
      } else if (change > 0) {
        if (1 > stock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Out of stock for ${item['name']}!'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
          return;
        }

        _cart[id] = {
          'itemId': id,
          'name': item['name'],
          'price': (item['discountedPrice'] as num).toDouble(),
          'cartQuantity': 1,
        };
      }
    });

    // Animate cart bar in/out
    if (_cart.isNotEmpty) {
      _cartBarAnimationController.forward();
    } else {
      _cartBarAnimationController.reverse();
    }
  }

  Future<void> _handleCheckout(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CustomLoader()),
    );

    try {
      List<String> itemsOutStock = [];
      for (var cartItem in _cart.values) {
        final doc = await FirebaseFirestore.instance
            .collection('food_items')
            .doc(cartItem['itemId'])
            .get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          final int stock = data['quantity'] ?? 0;
          if (cartItem['cartQuantity'] > stock) {
            itemsOutStock.add("${cartItem['name']} (Only $stock left)");
          }
        } else {
          itemsOutStock.add("${cartItem['name']} (Item no longer available)");
        }
      }

      if (mounted) Navigator.pop(context);

      if (itemsOutStock.isNotEmpty) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              title: const Text(
                "Not Enough Stock",
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              content: Text(
                "The following items do not have enough stock:\n\n${itemsOutStock.join('\n')}",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "OK",
                    style: TextStyle(color: Color(0xFF00bf63)),
                  ),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CheckoutScreen(
              shopId: widget.shopId,
              shopName: widget.shopName,
              cartItems: _cart.values.toList(),
              totalAmount: _getTotalPrice(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error validating stock: $e')));
      }
    }
  }

  int _getTotalItems() {
    return _cart.values.fold(
      0,
      (sum, item) => sum + (item['cartQuantity'] as int),
    );
  }

  double _getTotalPrice() {
    return _cart.values.fold(
      0.0,
      (sum, item) =>
          sum + ((item['price'] as double) * (item['cartQuantity'] as int)),
    );
  }

  bool _isItemExpired(String? dateStr, String? timeStr) {
    if (dateStr == null ||
        timeStr == null ||
        dateStr.isEmpty ||
        timeStr.isEmpty) {
      return false;
    }
    try {
      DateTime date = DateFormat('yyyy-MM-dd').parse(dateStr);
      DateTime time;
      try {
        time = DateFormat('h:mm a').parse(timeStr);
      } catch (e) {
        try {
          time = DateFormat('H:mm').parse(timeStr);
        } catch (e) {
          time = DateFormat('HH:mm').parse(timeStr);
        }
      }
      DateTime itemExpiry = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      return DateTime.now().isAfter(itemExpiry);
    } catch (e) {
      return false;
    }
  }

  // ── Glassmorphic Button ────────────────────────────────────────────────────

  Widget _buildGlassButton({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            splashColor: Colors.white.withOpacity(0.1),
            child: Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.25),
                  width: 1,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  // ── Restaurant Header ──────────────────────────────────────────────────────

  Widget _buildRestaurantHeader(BuildContext context) {
    final data = _resolvedShopData;
    final images = data['images'] as List<dynamic>?;
    final String category = data['category'] ?? 'Restaurant';
    final String address =
        data['location']?['address'] ?? 'Address not available';
    final String rating = (data['rating'] ?? '4.0').toString();
    final String mapUrl = data['mapUrl'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Hero Image Stack ─────────────────────────────────────────────
        Stack(
          children: [
            Hero(
              tag: widget.heroTag ?? 'shop_image_${widget.shopId}',
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(36),
                ),
                child: SizedBox(
                  height: 350,
                  width: double.infinity,
                  child: (images != null && images.isNotEmpty)
                      ? _ShopImageSlideshow(images: images.cast<String>())
                      : Container(
                          color: Colors.grey[100],
                          child: Icon(
                            Icons.restaurant,
                            size: 80,
                            color: Colors.grey[300],
                          ),
                        ),
                ),
              ),
            ),

            // Multi-stop gradient for depth
            Positioned.fill(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(36),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.55),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.85),
                      ],
                      stops: const [0.0, 0.3, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // Top Bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: FadeTransition(
                opacity: _headerFadeController,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildGlassButton(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    _buildGlassButton(
                      onTap: _isTogglingFavorite ? () {} : _toggleFavorite,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, anim) => ScaleTransition(
                          scale: CurvedAnimation(
                            parent: anim,
                            curve: Curves.easeOutBack,
                          ),
                          child: child,
                        ),
                        child: Icon(
                          _isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          key: ValueKey(_isFavorite),
                          color: _isFavorite
                              ? const Color(0xFFFF4D6D)
                              : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Info Overlay
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: FadeTransition(
                opacity: _headerFadeController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: primaryGreen.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: primaryGreen.withOpacity(0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        category.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            widget.shopName,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.1,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _RatingBadge(
                          rating: rating,
                          primaryGreen: primaryGreen,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // ── Address Card ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: _AddressCard(
            address: address,
            mapUrl: mapUrl,
            primaryGreen: primaryGreen,
          ),
        ),

        // ── Menu Section Title ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
          child: _SectionTitle(label: 'MENU', primaryGreen: primaryGreen),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  // ── Diet Filter ────────────────────────────────────────────────────────────

  Widget _buildDietFilter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: ['All', 'Veg', 'Non-Veg'].map((type) {
            final isSelected = _dietFilter == type;
            Color typeColor = primaryGreen;
            IconData typeIcon = Icons.restaurant_rounded;
            if (type == 'Veg') {
              typeColor = const Color(0xFF2E7D32);
              typeIcon = Icons.eco_rounded;
            }
            if (type == 'Non-Veg') {
              typeColor = const Color(0xFFD32F2F);
              typeIcon = Icons.set_meal_rounded;
            }

            return GestureDetector(
              onTap: () => setState(() => _dietFilter = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? typeColor : Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected
                        ? typeColor
                        : Colors.grey.withOpacity(0.15),
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: typeColor.withOpacity(0.3),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (type != 'All') ...[
                      AnimatedOpacity(
                        opacity: 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          typeIcon,
                          size: 14,
                          color: isSelected ? Colors.white : typeColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      type,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[700],
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Food Item Card ─────────────────────────────────────────────────────────

  Widget _buildFoodItemCard(DocumentSnapshot doc, int index) {
    final item = doc.data() as Map<String, dynamic>;
    final int currentQty = _cart[doc.id]?['cartQuantity'] ?? 0;
    final bool isVeg = (item['dietType'] ?? 'Veg') == 'Veg';
    final bool isSupermarket = _resolvedShopData['category'] == 'Supermarket';

    // Staggered entrance animation
    final Animation<double> animation = CurvedAnimation(
      parent: _listAnimationController,
      curve: Interval(
        (index * 0.07).clamp(0.0, 0.75),
        ((index * 0.07) + 0.45).clamp(0.1, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );

    // Discount calculation
    final bool hasDiscount =
        item['originalPrice'] != null &&
        item['originalPrice'] != item['discountedPrice'];
    final int discountPercent = hasDiscount
        ? (((item['originalPrice'] - item['discountedPrice']) /
                      item['originalPrice']) *
                  100)
              .round()
        : 0;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.055),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.025),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Left: Details ────────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Diet indicator
                        if (!isSupermarket) ...[
                          _DietIndicator(isVeg: isVeg),
                          const SizedBox(height: 9),
                        ],

                        // Item name
                        Text(
                          item['name'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111111),
                            height: 1.25,
                            letterSpacing: -0.2,
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Price row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '₹${item['discountedPrice']}',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: primaryGreen,
                                height: 1,
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (hasDiscount) ...[
                              const SizedBox(width: 8),
                              Text(
                                '₹${item['originalPrice']}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[400],
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE8E8),
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: Text(
                                  '$discountPercent% OFF',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFD32F2F),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 11),

                        // Expiry badge
                        _ExpiryBadge(
                          expiryDate: item['expiryDate'],
                          expiryTime: item['expiryTime'],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 14),

                  // ── Right: Image + Controls ──────────────────────────
                  SizedBox(
                    width: 108,
                    child: Column(
                      children: [
                        // Item image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            children: [
                              (item['imageUrl'] != null &&
                                      item['imageUrl'] != "")
                                  ? Image.network(
                                      item['imageUrl'],
                                      width: 108,
                                      height: 92,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _PlaceholderImage(
                                            size: 108,
                                            height: 92,
                                          ),
                                    )
                                  : _PlaceholderImage(size: 108, height: 92),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Add / Qty Controls
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 320),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOutBack,
                                  ),
                                  child: child,
                                ),
                              ),
                          child: currentQty == 0
                              ? _AddButton(
                                  key: const ValueKey('add'),
                                  primaryGreen: primaryGreen,
                                  onTap: () => _updateCart(doc, 1),
                                )
                              : _QtyControls(
                                  key: const ValueKey('controls'),
                                  qty: currentQty,
                                  primaryGreen: primaryGreen,
                                  onDecrement: () => _updateCart(doc, -1),
                                  onIncrement: () => _updateCart(doc, 1),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Reviews Section ────────────────────────────────────────────────────────

  Widget _buildReviewsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('shopId', isEqualTo: widget.shopId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00bf63),
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        Widget sectionHeader = Padding(
          padding: const EdgeInsets.fromLTRB(20, 36, 20, 18),
          child: _SectionTitle(
            label: 'RATINGS & REVIEWS',
            primaryGreen: primaryGreen,
          ),
        );

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionHeader,
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.rate_review_outlined,
                          color: Colors.grey[400],
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        "No reviews yet. Be the first!",
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final tA = dataA['createdAt'] as Timestamp?;
          final tB = dataB['createdAt'] as Timestamp?;
          if (tA == null && tB == null) return 0;
          if (tA == null) return 1;
          if (tB == null) return -1;
          return tB.compareTo(tA);
        });

        int totalReviews = docs.length;
        double averageRating = 0.0;
        List<int> distribution = [0, 0, 0, 0, 0];

        for (var doc in docs) {
          final review = doc.data() as Map<String, dynamic>;
          final int rating = (review['rating'] ?? 0).toInt();
          averageRating += rating;
          if (rating >= 1 && rating <= 5) distribution[rating - 1]++;
        }

        if (totalReviews > 0) averageRating /= totalReviews;

        final reviewDocsWithComments = docs.where((doc) {
          final reviewData = doc.data() as Map<String, dynamic>;
          final String comment = reviewData['comment'] ?? "";
          return comment.trim().isNotEmpty;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionHeader,

            // ── Rating Summary Card ──────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.055),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Score circle
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              primaryGreen.withOpacity(0.15),
                              primaryGreen.withOpacity(0.05),
                            ],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: primaryGreen.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            averageRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: primaryGreen,
                              height: 1,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (index) {
                          return Icon(
                            index < averageRating.round()
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: primaryGreen,
                            size: 13,
                          );
                        }),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "$totalReviews review${totalReviews == 1 ? '' : 's'}",
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 24),

                  // Distribution bars
                  Expanded(
                    child: Column(
                      children: List.generate(5, (index) {
                        int starLevel = 5 - index;
                        int count = distribution[starLevel - 1];
                        double percent = totalReviews > 0
                            ? count / totalReviews
                            : 0.0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.5),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 12,
                                child: Text(
                                  starLevel.toString(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.star_rounded,
                                size: 11,
                                color: Colors.amber[400],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: percent),
                                    duration: Duration(
                                      milliseconds: 600 + (index * 100),
                                    ),
                                    curve: Curves.easeOutCubic,
                                    builder: (_, value, __) =>
                                        LinearProgressIndicator(
                                          value: value,
                                          backgroundColor: Colors.grey[100],
                                          minHeight: 8,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                primaryGreen,
                                              ),
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 22,
                                child: Text(
                                  count.toString(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[400],
                                  ),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),

            // ── Review Cards ─────────────────────────────────────────────
            if (reviewDocsWithComments.isNotEmpty) ...[
              const SizedBox(height: 14),
              ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reviewDocsWithComments.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final review =
                      reviewDocsWithComments[index].data()
                          as Map<String, dynamic>;
                  final int rating = (review['rating'] ?? 0).toInt();
                  final String comment = review['comment'] ?? "";
                  final Timestamp? createdAt =
                      review['createdAt'] as Timestamp?;

                  String dateStr = "";
                  if (createdAt != null) {
                    final date = createdAt.toDate();
                    dateStr = "${date.day}/${date.month}/${date.year}";
                  }

                  final Color ratingColor = rating >= 4
                      ? primaryGreen
                      : (rating >= 3 ? Colors.amber[700]! : Colors.redAccent);

                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.grey.shade100, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.035),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ratingColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        color: ratingColor,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        rating.toString(),
                                        style: TextStyle(
                                          color: ratingColor,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 13,
                                      color: primaryGreen,
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      "Verified Buyer",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (dateStr.isNotEmpty)
                              Text(
                                dateStr,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        if (comment.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            comment,
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: Color(0xFF444444),
                              height: 1.6,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: _foodItemsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CustomLoader());
              }

              final allDocs = snapshot.data!.docs;
              final docs = allDocs.where((doc) {
                final item = doc.data() as Map<String, dynamic>;
                final int quantity = item['quantity'] ?? 0;

                bool matchesDiet = true;
                if (_resolvedShopData['category'] != 'Supermarket' &&
                    _dietFilter != 'All') {
                  final itemDiet = item['dietType'] ?? 'Veg';
                  matchesDiet = itemDiet == _dietFilter;
                }

                return !_isItemExpired(
                      item['expiryDate'],
                      item['expiryTime'],
                    ) &&
                    quantity > 0 &&
                    matchesDiet;
              }).toList();

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildRestaurantHeader(context)),

                  if (_resolvedShopData['category'] != 'Supermarket')
                    SliverToBoxAdapter(child: _buildDietFilter()),

                  if (docs.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.no_food_rounded,
                                size: 44,
                                color: Color(0xFFCCCCCC),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "No items available right now",
                              style: TextStyle(
                                color: Color(0xFF888888),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Check back soon!",
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildFoodItemCard(docs[index], index),
                          childCount: docs.length,
                        ),
                      ),
                    ),

                  SliverToBoxAdapter(child: _buildReviewsSection()),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 130)),
                ],
              );
            },
          ),

          // ── Floating Cart Bar ──────────────────────────────────────────
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: AnimatedBuilder(
              animation: _cartBarAnimationController,
              builder: (context, child) {
                final value = CurvedAnimation(
                  parent: _cartBarAnimationController,
                  curve: Curves.easeOutBack,
                ).value;
                return Transform.scale(
                  scale: value.clamp(0.0, 1.0),
                  alignment: Alignment.bottomCenter,
                  child: Opacity(
                    opacity: _cartBarAnimationController.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: _cart.isNotEmpty
                  ? _CartBar(
                      totalItems: _getTotalItems(),
                      totalPrice: _getTotalPrice(),
                      primaryGreen: primaryGreen,
                      onCheckout: () => _handleCheckout(context),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── Extracted Reusable Widgets ────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String label;
  final Color primaryGreen;

  const _SectionTitle({required this.label, required this.primaryGreen});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: primaryGreen,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: Colors.grey[600],
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final String rating;
  final Color primaryGreen;

  const _RatingBadge({required this.rating, required this.primaryGreen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: primaryGreen,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.45),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 5),
          Text(
            rating,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final String address;
  final String mapUrl;
  final Color primaryGreen;

  const _AddressCard({
    required this.address,
    required this.mapUrl,
    required this.primaryGreen,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: mapUrl.isNotEmpty
          ? () async {
              final Uri url = Uri.parse(mapUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.045),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.09),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.location_on_rounded,
                size: 22,
                color: primaryGreen,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LOCATION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[400],
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    address,
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 13.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (mapUrl.isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.directions_rounded,
                  size: 17,
                  color: primaryGreen,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DietIndicator extends StatelessWidget {
  final bool isVeg;

  const _DietIndicator({required this.isVeg});

  @override
  Widget build(BuildContext context) {
    final Color color = isVeg
        ? const Color(0xFF2E7D32)
        : const Color(0xFFD32F2F);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 15,
          height: 15,
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.8),
            borderRadius: BorderRadius.circular(3.5),
          ),
          child: Center(
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          isVeg ? 'Veg' : 'Non-Veg',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

class _ExpiryBadge extends StatelessWidget {
  final dynamic expiryDate;
  final dynamic expiryTime;

  const _ExpiryBadge({required this.expiryDate, required this.expiryTime});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.12), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded, size: 11, color: Colors.red.shade600),
          const SizedBox(width: 4),
          Text(
            "Exp: $expiryDate · $expiryTime",
            style: TextStyle(
              color: Colors.red.shade600,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  final double size;
  final double height;

  const _PlaceholderImage({required this.size, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(Icons.fastfood_rounded, color: Colors.grey[350], size: 30),
    );
  }
}

class _CartBar extends StatelessWidget {
  final int totalItems;
  final double totalPrice;
  final Color primaryGreen;
  final VoidCallback onCheckout;

  const _CartBar({
    required this.totalItems,
    required this.totalPrice,
    required this.primaryGreen,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.95),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Text(
                          '$totalItems',
                          key: ValueKey(totalItems),
                          style: TextStyle(
                            color: primaryGreen,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "ITEM${totalItems > 1 ? 'S' : ''} ADDED",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white54,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (child, anim) =>
                            FadeTransition(opacity: anim, child: child),
                        child: Text(
                          '₹${totalPrice % 1 == 0 ? totalPrice.toInt() : totalPrice.toStringAsFixed(2)}',
                          key: ValueKey(totalPrice),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: onCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 13,
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Checkout",
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Add Button ────────────────────────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  final Color primaryGreen;
  final VoidCallback onTap;

  const _AddButton({
    super.key,
    required this.primaryGreen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: primaryGreen, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: primaryGreen.withOpacity(0.14),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: primaryGreen, size: 16),
            const SizedBox(width: 4),
            Text(
              "ADD",
              style: TextStyle(
                color: primaryGreen,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Qty Controls ──────────────────────────────────────────────────────────────

class _QtyControls extends StatelessWidget {
  final int qty;
  final Color primaryGreen;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _QtyControls({
    super.key,
    required this.qty,
    required this.primaryGreen,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: primaryGreen,
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GestureDetector(
            onTap: onDecrement,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.remove_rounded, color: Colors.white, size: 17),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
              child: child,
            ),
            child: Text(
              "$qty",
              key: ValueKey(qty),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
          ),
          GestureDetector(
            onTap: onIncrement,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.add_rounded, color: Colors.white, size: 17),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Image Slideshow ───────────────────────────────────────────────────────────

class _ShopImageSlideshow extends StatefulWidget {
  final List<String> images;
  const _ShopImageSlideshow({required this.images});

  @override
  State<_ShopImageSlideshow> createState() => _ShopImageSlideshowState();
}

class _ShopImageSlideshowState extends State<_ShopImageSlideshow> {
  late PageController _pageController;
  int _currentPage = 0;
  bool _isAutoScrolling = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    if (widget.images.length <= 1) return;
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted || !_isAutoScrolling) return;
      int nextPage = _currentPage + 1;
      if (nextPage >= widget.images.length) {
        nextPage = 0;
        _pageController.jumpToPage(0);
      } else {
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.fastOutSlowIn,
        );
      }
      _startAutoScroll();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _isAutoScrolling = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return Container(
        color: Colors.grey[100],
        child: Icon(Icons.restaurant, size: 60, color: Colors.grey[300]),
      );
    }

    if (widget.images.length == 1) {
      return Image.network(widget.images.first, fit: BoxFit.cover);
    }

    return Listener(
      onPointerDown: (_) => _isAutoScrolling = false,
      onPointerUp: (_) {
        _isAutoScrolling = true;
        _startAutoScroll();
      },
      child: Stack(
        alignment: Alignment.bottomCenter,
        fit: StackFit.expand,
        children: [
          Image.network(widget.images.first, fit: BoxFit.cover),
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              if (index == 0) return const SizedBox.shrink();
              return Image.network(widget.images[index], fit: BoxFit.cover);
            },
          ),
          // Dots indicator
          Positioned(
            bottom: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.images.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3.5),
                  width: _currentPage == index ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? const Color(0xFF00bf63)
                        : Colors.white.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
