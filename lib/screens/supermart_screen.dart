import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_loader.dart';
import '../widgets/shop_card.dart';

class SupermartScreen extends StatefulWidget {
  const SupermartScreen({super.key});

  @override
  State<SupermartScreen> createState() => _SupermartScreenState();
}

class _SupermartScreenState extends State<SupermartScreen>
    with SingleTickerProviderStateMixin {
  GeoPoint? _userLocation;
  bool _isLoadingLocation = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const _primaryGreen = Color(0xFF00bf63);
  static const _bgColor = Color(0xFFF6F8FA);
  static const _textDark = Color(0xFF1A1D23);
  static const _textMuted = Color(0xFF8A93A2);

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
            setState(() {
              _userLocation = location['geopoint'] as GeoPoint;
              _isLoadingLocation = false;
            });
            _animationController.forward();
            return;
          }
        }
      }

      // If no valid auth user or location not found in Firestore, try SharedPreferences
      if (_userLocation == null) {
        final prefs = await SharedPreferences.getInstance();
        final double? lat = prefs.getDouble('cached_geopoint_lat');
        final double? lon = prefs.getDouble('cached_geopoint_lon');

        if (lat != null && lon != null) {
          setState(() {
            _userLocation = GeoPoint(lat, lon);
            _isLoadingLocation = false;
          });
          _animationController.forward();
          return;
        }
      }
    } catch (e) {
      print('Error fetching user location: $e');
    }

    if (mounted) {
      setState(() {
        _isLoadingLocation = false;
      });
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bgColor,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _isLoadingLocation
            ? const Center(child: CustomLoader())
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .where('category', isEqualTo: 'Supermarket')
          .where('verificationStatus', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CustomLoader());
        }
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        List<QueryDocumentSnapshot> shops = snapshot.data!.docs;

        if (_userLocation != null) {
          // Filter by distance (10km = 10000m)
          shops = shops.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final location = data['location'] as Map<String, dynamic>?;
            if (location == null || location['geopoint'] == null) return false;

            final GeoPoint shopPoint = location['geopoint'] as GeoPoint;
            final double distance = Geolocator.distanceBetween(
              _userLocation!.latitude,
              _userLocation!.longitude,
              shopPoint.latitude,
              shopPoint.longitude,
            );
            return distance <= 10000;
          }).toList();

          // Sort by distance (nearest first)
          shops.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;

            final aLoc = aData['location']['geopoint'] as GeoPoint;
            final bLoc = bData['location']['geopoint'] as GeoPoint;

            final double distA = Geolocator.distanceBetween(
              _userLocation!.latitude,
              _userLocation!.longitude,
              aLoc.latitude,
              aLoc.longitude,
            );
            final double distB = Geolocator.distanceBetween(
              _userLocation!.latitude,
              _userLocation!.longitude,
              bLoc.latitude,
              bLoc.longitude,
            );
            return distA.compareTo(distB);
          });
        }

        if (shops.isEmpty) return _buildEmptyState();

        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Result count header ──
                SliverToBoxAdapter(
                  child: _buildResultsHeader(shops.length),
                ),

                // ── Shop list ──
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final shop = shops[index];
                        final data = shop.data() as Map<String, dynamic>;
                        return _AnimatedListItem(
                          index: index,
                          child: ShopCard(
                            shopId: shop.id,
                            data: data,
                            defaultIcon: Icons.storefront,
                            defaultCategory: "Supermarket",
                          ),
                        );
                      },
                      childCount: shops.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Result count header ────────────────────────────────────────────────────
  Widget _buildResultsHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Text(
            '$count ${count == 1 ? 'supermarket' : 'supermarkets'} nearby',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textMuted,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: _primaryGreen,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _primaryGreen.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront_outlined,
                size: 36,
                color: _primaryGreen,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No supermarkets found nearby',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'There are no supermarkets within 10 km of your location.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _textMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Error state ────────────────────────────────────────────────────────────
  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 36,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: _textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Staggered list item animation ─────────────────────────────────────────────
class _AnimatedListItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedListItem({required this.index, required this.child});

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Staggered delay based on index (capped at 6 items to avoid long waits)
    final delay = Duration(milliseconds: 60 * (widget.index % 6));
    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}