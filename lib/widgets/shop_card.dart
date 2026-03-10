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

class _ShopCardState extends State<ShopCard>
    with SingleTickerProviderStateMixin {
  bool _isFavorite = false;
  bool _isTogglingFavorite = false;
  late AnimationController _heartController;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadFavoriteStatus();
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
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
    } catch (e) {
      debugPrint('Error loading favorite status: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _isTogglingFavorite) return;

    setState(() => _isTogglingFavorite = true);
    _heartController.forward(from: 0.0); // trigger bounce

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update favorite: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingFavorite = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.isCompact ? _buildCompactCard() : _buildNormalCard();
  }

  Widget _buildNormalCard() {
    final images = widget.data['images'] as List<dynamic>?;
    final bool isOpen = widget.data['isOpen'] ?? true;
    final rating = (widget.data['rating'] as num?)?.toDouble() ?? 4.0;
    final shopName = widget.data['shopName'] as String? ?? 'Unknown';
    final category =
        widget.data['category'] as String? ?? widget.defaultCategory;
    final address =
        widget.data['location']?['address'] as String? ??
        'Address not available';

    return GestureDetector(
      onTap: isOpen ? () => _navigateToMenu() : null,
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0.95, end: 1.0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        builder: (context, double scale, child) {
          return Transform.scale(scale: scale, child: child);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          foregroundDecoration: isOpen
              ? null
              : BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(20),
            shadowColor: Colors.grey.shade300,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // Background image
                  Hero(
                    tag: 'shop_image_${widget.shopId}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: (images != null && images.isNotEmpty)
                          ? Image.network(
                              images.first,
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  height: 220,
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 220,
                                  color: Colors.grey[200],
                                  child: Icon(
                                    widget.defaultIcon,
                                    size: 80,
                                    color: Colors.grey[400],
                                  ),
                                );
                              },
                            )
                          : Container(
                              height: 220,
                              width: double.infinity,
                              color: Colors.grey[200],
                              child: Icon(
                                widget.defaultIcon,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                            ),
                    ),
                  ),
                  // Gradient overlay for text readability
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  // Content
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                shopName,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isOpen)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[300],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Closed overlay
                  if (!isOpen)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.5),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Text(
                            "TEMPORARILY CLOSED",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Favorite heart with animation
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: _isTogglingFavorite ? null : _toggleFavorite,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.8, end: 1.2).animate(
                          CurvedAnimation(
                            parent: _heartController,
                            curve: Curves.elasticOut,
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            _isFavorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: _isFavorite ? Colors.red : Colors.grey,
                            size: 22,
                            semanticLabel: _isFavorite
                                ? 'Remove from favorites'
                                : 'Add to favorites',
                          ),
                        ),
                      ),
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

  Widget _buildCompactCard() {
    final images = widget.data['images'] as List<dynamic>?;
    final bool isOpen = widget.data['isOpen'] ?? true;
    final rating = (widget.data['rating'] as num?)?.toDouble() ?? 4.0;
    final shopName = widget.data['shopName'] as String? ?? 'Unknown';
    final category =
        widget.data['category'] as String? ?? widget.defaultCategory;
    final address =
        widget.data['location']?['address'] as String? ??
        'Address not available';

    return GestureDetector(
      onTap: isOpen ? () => _navigateToMenu() : null,
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0.98, end: 1.0),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        builder: (context, double scale, child) {
          return Transform.scale(scale: scale, child: child);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          foregroundDecoration: isOpen
              ? null
              : BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
          child: Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(16),
            shadowColor: Colors.grey.shade200,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.white,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image with hero tag and loading
                  Hero(
                    tag: 'shop_image_${widget.shopId}_compact',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: (images != null && images.isNotEmpty)
                          ? Image.network(
                              images.first,
                              height: 90,
                              width: 90,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  height: 90,
                                  width: 90,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 90,
                                  width: 90,
                                  color: Colors.grey[200],
                                  child: Icon(
                                    widget.defaultIcon,
                                    size: 30,
                                    color: Colors.grey[400],
                                  ),
                                );
                              },
                            )
                          : Container(
                              height: 90,
                              width: 90,
                              color: Colors.grey[200],
                              child: Icon(
                                widget.defaultIcon,
                                size: 30,
                                color: Colors.grey[400],
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                shopName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
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
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      rating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
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
                                address,
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
                        if (!isOpen) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Closed',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Favorite heart
                  GestureDetector(
                    onTap: _isTogglingFavorite ? null : _toggleFavorite,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: ScaleTransition(
                        scale: Tween(begin: 0.8, end: 1.2).animate(
                          CurvedAnimation(
                            parent: _heartController,
                            curve: Curves.elasticOut,
                          ),
                        ),
                        child: Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: _isFavorite ? Colors.red : Colors.grey,
                          size: 18,
                        ),
                      ),
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

  void _navigateToMenu() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShopMenuScreen(
          shopId: widget.shopId,
          shopName: widget.data['shopName'],
          shopData: widget.data,
          heroTag: widget.isCompact
              ? 'shop_image_${widget.shopId}_compact'
              : 'shop_image_${widget.shopId}',
        ),
      ),
    );
  }
}
