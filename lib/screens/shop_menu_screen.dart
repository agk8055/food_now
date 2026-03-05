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
              child: CircularProgressIndicator(color: Color(0xFF00bf63)),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                color: Colors.grey[50],
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: const Text(
                  'RATINGS & REVIEWS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    "No reviews yet.",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
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
        List<int> distribution = [0, 0, 0, 0, 0]; // 1 to 5 stars

        for (var doc in docs) {
          final review = doc.data() as Map<String, dynamic>;
          final num ratingNum = review['rating'] ?? 0;
          final int rating = ratingNum.toInt();

          averageRating += rating;
          if (rating >= 1 && rating <= 5) {
            distribution[rating - 1]++;
          }
        }

        if (totalReviews > 0) {
          averageRating /= totalReviews;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              color: Colors.grey[50],
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: const Text(
                'RATINGS & REVIEWS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            // Rating Distribution Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left side: Average Rating
                  Column(
                    children: [
                      Text(
                        averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (index) {
                          return Icon(
                            index < averageRating.round()
                                ? Icons.star
                                : Icons.star_border,
                            color: const Color(0xFF00bf63),
                            size: 14,
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$totalReviews review${totalReviews == 1 ? '' : 's'}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 32),
                  // Right side: Distribution Bars
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(5, (index) {
                        int starLevel = 5 - index; // 5 -> 1
                        int count = distribution[starLevel - 1];
                        double percent = totalReviews > 0
                            ? count / totalReviews
                            : 0.0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            children: [
                              Text(
                                starLevel.toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: percent,
                                    backgroundColor: Colors.grey[200],
                                    minHeight: 6,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Color(0xFF00bf63),
                                        ),
                                  ),
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
            const Divider(height: 1, color: Colors.black12),

            ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: Colors.black12),
              itemBuilder: (context, index) {
                final review = docs[index].data() as Map<String, dynamic>;
                final num ratingNum = review['rating'] ?? 0;
                final int rating = ratingNum.toInt();
                final String comment = review['comment'] ?? "";
                final Timestamp? createdAt = review['createdAt'] as Timestamp?;

                String dateStr = "";
                if (createdAt != null) {
                  final date = createdAt.toDate();
                  dateStr = "${date.day}/${date.month}/${date.year}";
                }

                return Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
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
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: rating >= 4
                                      ? const Color(0xFF00bf63)
                                      : (rating >= 3
                                            ? Colors.amber
                                            : Colors.red),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      rating.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    const Icon(
                                      Icons.star,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "Verified Buyer",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          if (dateStr.isNotEmpty)
                            Text(
                              dateStr,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                      if (comment.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          comment,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
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

    final String category = data['category'] ?? 'Restaurant';
    final String address =
        data['location']?['address'] ?? 'Address not available';
    final String rating = (data['rating'] ?? '4.0').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            // Image Slideshow
            if (images != null && images.isNotEmpty)
              SizedBox(
                height: 320,
                width: double.infinity,
                child: _ShopImageSlideshow(images: images.cast<String>()),
              )
            else
              Container(
                height: 320,
                color: Colors.grey[200],
                child: const Icon(
                  Icons.restaurant,
                  size: 60,
                  color: Colors.grey,
                ),
              ),

            // Black gradient + dark bottom gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.6), // Black top
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
                        padding: const EdgeInsets.only(bottom: 0),
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

                      // Reviews Section
                      SliverToBoxAdapter(child: _buildReviewsSection()),

                      // Bottom padding for cart
                      const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
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
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
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
        color: Colors.grey[200],
        child: const Icon(Icons.restaurant, size: 60, color: Colors.grey),
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
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
            },
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              return Image.network(widget.images[index], fit: BoxFit.cover);
            },
          ),

          // Dots indicator
          if (widget.images.length > 1)
            Positioned(
              bottom: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? const Color(0xFF00bf63)
                          : Colors.white.withOpacity(0.5),
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
