import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/shop_menu_screen.dart';

class ShopCard extends StatefulWidget {
  final String shopId;
  final Map<String, dynamic> data;
  final bool isCompact;
  final IconData defaultIcon;
  final String defaultCategory;

  const ShopCard({
    super.key,
    required this.shopId,
    required this.data,
    this.isCompact = false,
    this.defaultIcon = Icons.restaurant,
    this.defaultCategory = "Restaurant",
  });

  @override
  State<ShopCard> createState() => _ShopCardState();
}

class _ShopCardState extends State<ShopCard> {
  bool _isFavorite = false;
  bool _isTogglingFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
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

  @override
  Widget build(BuildContext context) {
    if (widget.isCompact) {
      return _buildCompactCard(context);
    } else {
      return _buildNormalCard(context);
    }
  }

  Widget _buildNormalCard(BuildContext context) {
    final images = widget.data['images'] as List<dynamic>?;
    final bool isOpen = widget.data['isOpen'] ?? true;

    return GestureDetector(
      onTap: isOpen
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ShopMenuScreen(
                    shopId: widget.shopId,
                    shopName: widget.data['shopName'],
                    shopData: widget.data,
                  ),
                ),
              );
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        foregroundDecoration: isOpen
            ? null
            : BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
        child: ColorFiltered(
          colorFilter: isOpen
              ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
              : const ColorFilter.matrix(<double>[
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
                      child: (images != null && images.isNotEmpty)
                          ? Image.network(
                              images.first,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              height: 180,
                              color: Colors.grey[200],
                              child: Icon(
                                widget.defaultIcon,
                                size: 50,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                    if (!isOpen)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.4),
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "TEMPORARILY CLOSED",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Favorite Heart Icon
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: _isTogglingFavorite ? null : _toggleFavorite,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              _isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              key: ValueKey(_isFavorite),
                              color: _isFavorite ? Colors.red : Colors.grey,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.data['shopName'] ?? "Unknown",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isOpen)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                "★ ${widget.data['rating'] ?? '4.0'}",
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.data['category'] ?? widget.defaultCategory,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: Color(0xFF00bf63),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.data['location']?['address'] ??
                                  "Address not available",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  Widget _buildCompactCard(BuildContext context) {
    final images = widget.data['images'] as List<dynamic>?;
    final bool isOpen = widget.data['isOpen'] ?? true;

    return GestureDetector(
      onTap: isOpen
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ShopMenuScreen(
                    shopId: widget.shopId,
                    shopName: widget.data['shopName'],
                    shopData: widget.data,
                  ),
                ),
              );
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        foregroundDecoration: isOpen
            ? null
            : BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
        child: ColorFiltered(
          colorFilter: isOpen
              ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
              : const ColorFilter.matrix(<double>[
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Left Side Image
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: (images != null && images.isNotEmpty)
                          ? Image.network(
                              images.first,
                              height: 80,
                              width: 80,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              height: 80,
                              width: 80,
                              color: Colors.grey[200],
                              child: Icon(
                                widget.defaultIcon,
                                size: 30,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                    if (!isOpen)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            "CLOSED",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    // Favorite Heart Icon for Compact
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: _isTogglingFavorite ? null : _toggleFavorite,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              _isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              key: ValueKey(_isFavorite),
                              color: _isFavorite ? Colors.red : Colors.grey,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),

                // 2. Right Side Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.data['shopName'] ?? "Unknown",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isOpen)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "★ ${widget.data['rating'] ?? '4.0'}",
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.data['category'] ?? widget.defaultCategory,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: Color(0xFF00bf63),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.data['location']?['address'] ??
                                  "Address not available",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}
