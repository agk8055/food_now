import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/custom_loader.dart';
import 'checkout_screen.dart';

class ShopMenuScreen extends StatefulWidget {
  final String shopId;
  final String shopName;
  final Map<String, dynamic> shopData;

  const ShopMenuScreen({
    super.key,
    required this.shopId,
    required this.shopName,
    this.shopData = const {},
  });

  @override
  State<ShopMenuScreen> createState() => _ShopMenuScreenState();
}

class _ShopMenuScreenState extends State<ShopMenuScreen> {
  // Cart maps Item ID to a Map of item details including selected quantity
  final Map<String, Map<String, dynamic>> _cart = {};

  // Stream for food items
  late Stream<QuerySnapshot> _foodItemsStream;

  // Resolved shop data (may be fetched from Firestore if not passed in)
  Map<String, dynamic> _resolvedShopData = {};

  // Favorites state
  bool _isFavorite = false;
  bool _isTogglingFavorite = false;

  @override
  void initState() {
    super.initState();
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

    setState(() {
      if (_cart.containsKey(id)) {
        _cart[id]!['cartQuantity'] += change;
        if (_cart[id]!['cartQuantity'] <= 0) {
          _cart.remove(id);
        }
      } else if (change > 0) {
        _cart[id] = {
          'itemId': id,
          'name': item['name'],
          'price': (item['discountedPrice'] as num).toDouble(),
          'cartQuantity': 1,
        };
      }
    });
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

  // ── Restaurant header ────────────────────────────────────────────────────────
  Widget _buildRestaurantHeader(BuildContext context) {
    final data = _resolvedShopData;
    final images = data['images'] as List<dynamic>?;
    final String? bannerUrl = (images != null && images.isNotEmpty)
        ? images.first as String
        : null;

    final String category = data['category'] ?? 'Restaurant';
    final String address =
        data['location']?['address'] ?? 'Address not available';
    final String rating = (data['rating'] ?? '4.0').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            // Image
            bannerUrl != null
                ? Image.network(
                    bannerUrl,
                    height: 320,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 320,
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.restaurant,
                      size: 60,
                      color: Colors.grey,
                    ),
                  ),

            // Light green gradient + dark bottom gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(
                        0xFF00bf63,
                      ).withOpacity(0.4), // Light green top
                      Colors.transparent,
                      Colors.black.withOpacity(
                        0.85,
                      ), // Dark bottom for white text
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),

            // Top Buttons: Back & Favorite
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 4),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.black),
                    ),
                  ),
                  // Favorite Button
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                    child: IconButton(
                      tooltip: _isFavorite
                          ? 'Remove from favourites'
                          : 'Add to favourites',
                      onPressed: _isTogglingFavorite ? null : _toggleFavorite,
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                          key: ValueKey(_isFavorite),
                          color: _isFavorite ? Colors.redAccent : Colors.grey,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Shop Details overlaid on bottom left
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          widget.shopName,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black45,
                                offset: Offset(0, 1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Rating badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00bf63),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Category
                  Row(
                    children: [
                      // Category chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        // ── Address below the image ──────────────────────────────────────────
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, size: 18, color: Color(0xFF00bf63)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  address,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Section label ─────────────────────────────────────────────────────
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: const Text(
            'MENU',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _foodItemsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CustomLoader());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: _buildRestaurantHeader(context),
                        ),
                        const SliverFillRemaining(
                          child: Center(
                            child: Text("No items available right now."),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: CustomScrollView(
                    slivers: [
                      // Restaurant header as a sticky/scrollable top block
                      SliverToBoxAdapter(
                        child: _buildRestaurantHeader(context),
                      ),

                      // Food items list
                      SliverPadding(
                        padding: const EdgeInsets.only(bottom: 80),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final doc = docs[index];
                            final item = doc.data() as Map<String, dynamic>;
                            final int currentQty =
                                _cart[doc.id]?['cartQuantity'] ?? 0;

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey.shade100,
                                  ),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Item details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "₹${item['discountedPrice']}",
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          "Expires: ${item['expiryDate']} at ${item['expiryTime']}",
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Item image + ADD button
                                  SizedBox(
                                    width: 110,
                                    height: 120,
                                    child: Stack(
                                      alignment: Alignment.topCenter,
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child:
                                              (item['imageUrl'] != null &&
                                                  item['imageUrl'] != "")
                                              ? Image.network(
                                                  item['imageUrl'],
                                                  width: 110,
                                                  height: 105,
                                                  fit: BoxFit.cover,
                                                )
                                              : Container(
                                                  width: 110,
                                                  height: 105,
                                                  color: Colors.grey[100],
                                                  child: const Icon(
                                                    Icons.fastfood,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          child: Container(
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.grey.shade300,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.05),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: currentQty == 0
                                                ? InkWell(
                                                    onTap: () =>
                                                        _updateCart(doc, 1),
                                                    child: Container(
                                                      width: 90,
                                                      alignment:
                                                          Alignment.center,
                                                      child: const Text(
                                                        "ADD",
                                                        style: TextStyle(
                                                          color: Color(
                                                            0xFF00bf63,
                                                          ),
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 15,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.remove,
                                                          color: Colors.black54,
                                                          size: 18,
                                                        ),
                                                        onPressed: () =>
                                                            _updateCart(
                                                              doc,
                                                              -1,
                                                            ),
                                                        constraints:
                                                            const BoxConstraints(
                                                              minWidth: 32,
                                                              minHeight: 32,
                                                            ),
                                                        padding:
                                                            EdgeInsets.zero,
                                                      ),
                                                      Text(
                                                        "$currentQty",
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.add,
                                                          color: Color(
                                                            0xFF00bf63,
                                                          ),
                                                          size: 18,
                                                        ),
                                                        onPressed: () =>
                                                            _updateCart(doc, 1),
                                                        constraints:
                                                            const BoxConstraints(
                                                              minWidth: 32,
                                                              minHeight: 32,
                                                            ),
                                                        padding:
                                                            EdgeInsets.zero,
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }, childCount: docs.length),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ── Cart bar ─────────────────────────────────────────────────────────
          if (_cart.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${_getTotalItems()} ITEM${_getTotalItems() > 1 ? 'S' : ''}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "₹${_getTotalPrice()}",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () {
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
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00bf63),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Next ➔",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
