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

class _ShopMenuScreenState extends State<ShopMenuScreen> {
  final Map<String, Map<String, dynamic>> _cart = {};

  late Stream<QuerySnapshot> _foodItemsStream;

  Map<String, dynamic> _resolvedShopData = {};

  bool _isFavorite = false;

  bool _isTogglingFavorite = false;

  String _dietFilter = 'All'; // 'All', 'Veg', 'Non-Veg'

  final Color primaryGreen = const Color(0xFF00bf63);

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
            SnackBar(content: Text('Out of stock for ${item['name']}!')),
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
              title: const Text("Not Enough Stock"),
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
        timeStr.isEmpty)
      return false;
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

  // ── Glassmorphic Button Helper ─────────────────────────────────────────────

  Widget _buildGlassButton({
    required Widget child,

    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),

      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),

        child: InkWell(
          onTap: onTap,

          child: Container(
            padding: const EdgeInsets.all(10),

            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),

              shape: BoxShape.circle,

              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),

            child: child,
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
        Stack(
          children: [
            // Image Slideshow with rounded bottom
            Hero(
              tag: widget.heroTag ?? 'shop_image_${widget.shopId}',
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),

                child: SizedBox(
                  height: 340,

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

            // Smooth Dark Gradient Overlay
            Positioned.fill(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),

                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,

                      end: Alignment.bottomCenter,

                      colors: [
                        Colors.black.withOpacity(0.5),

                        Colors.transparent,

                        Colors.black.withOpacity(0.9),
                      ],

                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // Top Bar (Back & Favorite)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,

              left: 16,

              right: 16,

              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  _buildGlassButton(
                    onTap: () => Navigator.pop(context),

                    child: const Icon(
                      Icons.arrow_back,

                      color: Colors.white,

                      size: 22,
                    ),
                  ),

                  _buildGlassButton(
                    onTap: _isTogglingFavorite ? () {} : _toggleFavorite,

                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),

                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),

                      child: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,

                        key: ValueKey(_isFavorite),

                        color: _isFavorite ? Colors.redAccent : Colors.white,

                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Info Overlay
            Positioned(
              bottom: 24,

              left: 20,

              right: 20,

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,

                          vertical: 6,
                        ),

                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),

                          borderRadius: BorderRadius.circular(20),

                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),

                        child: Text(
                          category.toUpperCase(),

                          style: const TextStyle(
                            color: Colors.white,

                            fontSize: 10,

                            letterSpacing: 1.2,

                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,

                    children: [
                      Expanded(
                        child: Text(
                          widget.shopName,

                          style: const TextStyle(
                            fontSize: 32,

                            fontWeight: FontWeight.w800,

                            color: Colors.white,

                            height: 1.1,
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,

                          vertical: 8,
                        ),

                        decoration: BoxDecoration(
                          color: primaryGreen,

                          borderRadius: BorderRadius.circular(16),

                          boxShadow: [
                            BoxShadow(
                              color: primaryGreen.withOpacity(0.4),

                              blurRadius: 12,

                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),

                        child: Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,

                              color: Colors.white,

                              size: 20,
                            ),

                            const SizedBox(width: 4),

                            Text(
                              rating,

                              style: const TextStyle(
                                color: Colors.white,

                                fontWeight: FontWeight.bold,

                                fontSize: 16,
                              ),
                            ),
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

        // Address Section
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),

          child: GestureDetector(
            onTap: mapUrl.isNotEmpty
                ? () async {
                    final Uri url = Uri.parse(mapUrl);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  }
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,

                children: [
                  Container(
                    padding: const EdgeInsets.all(8),

                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.1),

                      shape: BoxShape.circle,
                    ),

                    child: Icon(
                      Icons.location_on_rounded,

                      size: 20,

                      color: primaryGreen,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      address,

                      style: TextStyle(
                        color: Colors.grey[800],

                        fontSize: 14,

                        height: 1.5,

                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  if (mapUrl.isNotEmpty) ...[
                    const SizedBox(width: 8),

                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Section Title
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),

          child: Text(
            'MENU',

            style: TextStyle(
              fontSize: 14,

              fontWeight: FontWeight.w800,

              color: Colors.grey[400],

              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
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
              child: CircularProgressIndicator(color: Color(0xFF00bf63)),
            ),
          );
        }

        Widget sectionHeader = Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),

          child: Text(
            'RATINGS & REVIEWS',

            style: TextStyle(
              fontSize: 14,

              fontWeight: FontWeight.w800,

              color: Colors.grey[400],

              letterSpacing: 1.5,
            ),
          ),
        );

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              sectionHeader,

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),

                child: Text(
                  "No reviews yet.",

                  style: TextStyle(color: Colors.grey, fontSize: 16),
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

            // Rating Summary Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),

              padding: const EdgeInsets.all(24),

              decoration: BoxDecoration(
                color: Colors.white,

                borderRadius: BorderRadius.circular(24),

                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),

                    blurRadius: 20,

                    offset: const Offset(0, 4),
                  ),
                ],
              ),

              child: Row(
                children: [
                  Column(
                    children: [
                      Text(
                        averageRating.toStringAsFixed(1),

                        style: const TextStyle(
                          fontSize: 48,

                          fontWeight: FontWeight.w800,

                          color: Colors.black87,

                          height: 1,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Row(
                        mainAxisSize: MainAxisSize.min,

                        children: List.generate(5, (index) {
                          return Icon(
                            index < averageRating.round()
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,

                            color: primaryGreen,

                            size: 16,
                          );
                        }),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        "$totalReviews review${totalReviews == 1 ? '' : 's'}",

                        style: const TextStyle(
                          color: Colors.grey,

                          fontSize: 12,

                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 32),

                  Expanded(
                    child: Column(
                      children: List.generate(5, (index) {
                        int starLevel = 5 - index;

                        int count = distribution[starLevel - 1];

                        double percent = totalReviews > 0
                            ? count / totalReviews
                            : 0.0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),

                          child: Row(
                            children: [
                              Text(
                                starLevel.toString(),

                                style: const TextStyle(
                                  fontSize: 12,

                                  fontWeight: FontWeight.w700,

                                  color: Colors.black54,
                                ),
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),

                                  child: LinearProgressIndicator(
                                    value: percent,

                                    backgroundColor: Colors.grey[100],

                                    minHeight: 8,

                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      primaryGreen,
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

            if (reviewDocsWithComments.isNotEmpty) ...[
              const SizedBox(height: 16),

              // Review List
              ListView.separated(
                shrinkWrap: true,

                padding: const EdgeInsets.symmetric(horizontal: 20),

                physics: const NeverScrollableScrollPhysics(),

                itemCount: reviewDocsWithComments.length,

                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),

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

                  return Container(
                    padding: const EdgeInsets.all(20),

                    decoration: BoxDecoration(
                      color: Colors.white,

                      borderRadius: BorderRadius.circular(20),

                      border: Border.all(color: Colors.grey.shade100),

                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),

                          blurRadius: 10,

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

                                    vertical: 6,
                                  ),

                                  decoration: BoxDecoration(
                                    color: rating >= 4
                                        ? primaryGreen
                                        : (rating >= 3
                                              ? Colors.amber
                                              : Colors.redAccent),

                                    borderRadius: BorderRadius.circular(12),
                                  ),

                                  child: Row(
                                    children: [
                                      Text(
                                        rating.toString(),

                                        style: const TextStyle(
                                          color: Colors.white,

                                          fontWeight: FontWeight.bold,

                                          fontSize: 13,
                                        ),
                                      ),

                                      const SizedBox(width: 4),

                                      const Icon(
                                        Icons.star_rounded,

                                        color: Colors.white,

                                        size: 14,
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 12),

                                const Text(
                                  "Verified Buyer",

                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,

                                    fontSize: 14,

                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),

                            if (dateStr.isNotEmpty)
                              Text(
                                dateStr,

                                style: TextStyle(
                                  color: Colors.grey[500],

                                  fontSize: 12,

                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),

                        if (comment.isNotEmpty) ...[
                          const SizedBox(height: 16),

                          Text(
                            comment,

                            style: const TextStyle(
                              fontSize: 14,

                              color: Colors.black87,

                              height: 1.5,
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
      backgroundColor: const Color(
        0xFFF9FAFB,
      ), // Soft off-white premium background

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

              if (docs.isEmpty) {
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildRestaurantHeader(context)),

                    const SliverFillRemaining(
                      child: Center(
                        child: Text(
                          "No items available right now.",

                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildRestaurantHeader(context)),

                  if (_resolvedShopData['category'] != 'Supermarket')
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: ['All', 'Veg', 'Non-Veg'].map((type) {
                              final isSelected = _dietFilter == type;
                              Color typeColor = Colors.black87;
                              if (type == 'Veg') typeColor = Colors.green;
                              if (type == 'Non-Veg') typeColor = Colors.red;
                              if (type == 'All')
                                typeColor = const Color(0xFF00bf63);

                              return GestureDetector(
                                onTap: () {
                                  setState(() => _dietFilter = type);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? typeColor.withOpacity(0.15)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: isSelected
                                          ? typeColor
                                          : Colors.grey.withOpacity(0.2),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: typeColor.withOpacity(
                                                0.15,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (type != 'All') ...[
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? typeColor
                                                : Colors.transparent,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: typeColor,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Text(
                                        type,
                                        style: TextStyle(
                                          color: isSelected
                                              ? typeColor
                                              : Colors.grey[700],
                                          fontWeight: isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),

                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),

                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final doc = docs[index];

                        final item = doc.data() as Map<String, dynamic>;

                        final int currentQty =
                            _cart[doc.id]?['cartQuantity'] ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),

                          padding: const EdgeInsets.all(16),

                          decoration: BoxDecoration(
                            color: Colors.white,

                            borderRadius: BorderRadius.circular(24),

                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),

                                blurRadius: 15,

                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),

                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,

                            children: [
                              // Item details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_resolvedShopData['category'] !=
                                        'Supermarket')
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color:
                                                  (item['dietType'] ?? 'Veg') ==
                                                      'Veg'
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                          child: Center(
                                            child: Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                color:
                                                    (item['dietType'] ??
                                                            'Veg') ==
                                                        'Veg'
                                                    ? Colors.green
                                                    : Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    Text(
                                      item['name'],

                                      style: const TextStyle(
                                        fontSize: 17,

                                        fontWeight: FontWeight.w700,

                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 6),

                                    Text(
                                      "₹${item['discountedPrice']}",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black87,
                                      ),
                                    ),

                                    const SizedBox(height: 10),

                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),

                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),

                                      child: Text(
                                        "Exp: ${item['expiryDate']} | ${item['expiryTime']}",
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 16),

                              // Item image & Add button
                              SizedBox(
                                width: 110,

                                child: Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16),

                                      child:
                                          (item['imageUrl'] != null &&
                                              item['imageUrl'] != "")
                                          ? Image.network(
                                              item['imageUrl'],
                                              width: 110,
                                              height: 90,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              width: 110,

                                              height: 90,

                                              color: Colors.grey[100],

                                              child: const Icon(
                                                Icons.fastfood,

                                                color: Colors.grey,
                                              ),
                                            ),
                                    ),

                                    const SizedBox(height: 12),

                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),

                                      transitionBuilder:
                                          (
                                            Widget child,

                                            Animation<double> animation,
                                          ) {
                                            return FadeTransition(
                                              opacity: animation,

                                              child: ScaleTransition(
                                                scale: animation,

                                                child: child,
                                              ),
                                            );
                                          },

                                      child: currentQty == 0
                                          ? InkWell(
                                              key: const ValueKey('add'),
                                              onTap: () => _updateCart(doc, 1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Container(
                                                height: 36,
                                                width: double.infinity,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: primaryGreen,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: primaryGreen
                                                          .withOpacity(0.1),
                                                      blurRadius: 8,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: Text(
                                                  "ADD",
                                                  style: TextStyle(
                                                    color: primaryGreen,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Container(
                                              key: const ValueKey('controls'),
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: primaryGreen,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: primaryGreen
                                                        .withOpacity(0.3),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),

                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceEvenly,

                                                children: [
                                                  GestureDetector(
                                                    onTap: () =>
                                                        _updateCart(doc, -1),
                                                    child: const Padding(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                          ),

                                                      child: Icon(
                                                        Icons.remove,
                                                        color: Colors.white,

                                                        size: 18,
                                                      ),
                                                    ),
                                                  ),

                                                  Text(
                                                    "$currentQty",
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  GestureDetector(
                                                    onTap: () =>
                                                        _updateCart(doc, 1),
                                                    child: const Padding(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                          ),

                                                      child: Icon(
                                                        Icons.add,
                                                        color: Colors.white,
                                                        size: 18,
                                                      ),
                                                    ),
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

                  SliverToBoxAdapter(child: _buildReviewsSection()),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
                ],
              );
            },
          ),

          // ── Floating Cart Bottom Bar ──────────────────────────────────────────
          if (_cart.isNotEmpty)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(scale: value, child: child);
                },

                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),

                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),

                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${_getTotalItems()} ITEM${_getTotalItems() > 1 ? 'S' : ''}",

                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),

                          const SizedBox(height: 2),

                          Text(
                            "₹${_getTotalPrice()}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,

                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),

                      ElevatedButton(
                        onPressed: () => _handleCheckout(context),

                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          elevation: 0,
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
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Image Slideshow Widget ───────────────────────────────────────────────────

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

          // Clean dots indicator
          Positioned(
            bottom: 50, // Pushed up slightly to avoid text overlap
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.images.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? const Color(0xFF00bf63)
                        : Colors.white.withOpacity(0.4),

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
