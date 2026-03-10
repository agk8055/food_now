import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:food_now/services/location_service.dart';
import 'package:food_now/screens/not_serviceable_screen.dart';
import 'package:food_now/widgets/custom_loader.dart';
import 'package:food_now/widgets/seller_banner.dart';
import 'package:food_now/screens/profile_screen.dart';
import 'package:food_now/widgets/bottom_navigation_bar.dart';
import 'package:food_now/screens/food_screen.dart';
import 'package:food_now/screens/supermart_screen.dart';
import 'package:food_now/widgets/app_bar.dart';
import 'package:food_now/widgets/review_bottom_sheet.dart';
import 'package:food_now/widgets/floating_active_orders.dart'; // <-- Imported the new widget!
import 'dart:async';

// ─── Design Tokens ──────────────────────────────────────────────────────────

class _AppColors {
  static const Color primary = Color(0xFF00BF63);
  static const Color primaryLight = Color(0xFFE8FAF0);
  static const Color accent = Color(0xFFFF3B30);
  static const Color surface = Colors.white;
  static const Color background = Color(0xFFF7F8FA);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color shadow = Color(0x0A000000);
}

// ─── HomeScreen (stateful shell) ────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isCheckingServiceability = true;

  StreamSubscription<QuerySnapshot>? _ordersSubscription;
  final Set<String> _processingOrders = {};

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _checkServiceability();
    _listenForCompletedOrders();
  }

  // ── Business logic ────────────────────────────────────────────────────────

  void _listenForCompletedOrders() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _ordersSubscription = FirebaseFirestore.instance
        .collection('orders')
        .where('buyerId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added ||
                change.type == DocumentChangeType.modified) {
              final data = change.doc.data();
              if (data != null) {
                final orderId = change.doc.id;
                final shopId = data['shopId'] ?? '';
                final shopName = data['shopName'] ?? 'Unknown Shop';
                final buyerId = data['buyerId'] ?? '';
                final bool isReviewed = data['reviewed'] == true;

                if (buyerId == user.uid &&
                    shopId.isNotEmpty &&
                    !isReviewed &&
                    !_processingOrders.contains(orderId)) {
                  _processingOrders.add(orderId);
                  Future.delayed(const Duration(seconds: 3), () {
                    if (mounted) {
                      ReviewBottomSheet.show(
                        context,
                        orderId: orderId,
                        shopId: shopId,
                        shopName: shopName,
                        buyerId: buyerId,
                      );
                    }
                  });
                }
              }
            }
          }
        });
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _checkServiceability() async {
    try {
      GeoPoint? userLocation;
      final User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data();
          final location = data?['location'] as Map<String, dynamic>?;
          if (location != null && location['geopoint'] != null) {
            userLocation = location['geopoint'] as GeoPoint;
          }
        }
      }

      if (userLocation == null) {
        final prefs = await SharedPreferences.getInstance();
        final double? lat = prefs.getDouble('cached_geopoint_lat');
        final double? lon = prefs.getDouble('cached_geopoint_lon');
        if (lat != null && lon != null) {
          userLocation = GeoPoint(lat, lon);
        }
      }

      if (userLocation == null) {
        final locationService = LocationService();
        final position = await locationService.getCurrentPosition();
        if (position != null) {
          userLocation = GeoPoint(position.latitude, position.longitude);
        }
      }

      if (userLocation == null) {
        if (mounted) {
          setState(() => _isCheckingServiceability = false);
          _fadeController.forward();
        }
        return;
      }

      final shopsSnapshot = await FirebaseFirestore.instance
          .collection('shops')
          .where('verificationStatus', isEqualTo: 'approved')
          .get();

      bool hasNearbyShop = false;
      for (var doc in shopsSnapshot.docs) {
        final data = doc.data();
        final location = data['location'] as Map<String, dynamic>?;
        if (location != null && location['geopoint'] != null) {
          final GeoPoint shopPoint = location['geopoint'] as GeoPoint;
          final double distance = Geolocator.distanceBetween(
            userLocation.latitude,
            userLocation.longitude,
            shopPoint.latitude,
            shopPoint.longitude,
          );
          if (distance <= 10000) {
            hasNearbyShop = true;
            break;
          }
        }
      }

      if (mounted) {
        if (!hasNearbyShop) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const NotServiceableScreen(),
            ),
          );
        } else {
          setState(() => _isCheckingServiceability = false);
          _fadeController.forward();
        }
      }
    } catch (e) {
      debugPrint("Error checking serviceability: $e");
      if (mounted) {
        setState(() => _isCheckingServiceability = false);
        _fadeController.forward();
      }
    }
  }

  // ── Navigation ──────────────────────────────────────────────────────────

  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return HomeBody(onNavigate: _onItemTapped);
      case 1:
        return FoodScreen(initialCategory: _homeToFoodCategory);
      case 2:
        return const SupermartScreen();
      case 3:
        return const ProfileScreen();
      default:
        return HomeBody(onNavigate: _onItemTapped);
    }
  }

  String? _homeToFoodCategory;

  void _onItemTapped(int index, {String? category}) {
    setState(() {
      _selectedIndex = index;
      if (index == 1) {
        _homeToFoodCategory = category;
      } else {
        _homeToFoodCategory = null;
      }
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isCheckingServiceability) {
      return const Scaffold(
        backgroundColor: _AppColors.surface,
        body: Center(child: CustomLoader()),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: _AppColors.background,
        body: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: _selectedIndex < 3
                  ? NestedScrollView(
                      key: ValueKey('$_selectedIndex-$_homeToFoodCategory'),
                      headerSliverBuilder: (context, innerBoxIsScrolled) {
                        return [HomeAppBar(showBanner: _selectedIndex == 0)];
                      },
                      body: _getScreen(_selectedIndex),
                    )
                  : KeyedSubtree(
                      key: ValueKey(_selectedIndex),
                      child: _getScreen(_selectedIndex),
                    ),
            ),

            // Cleaned up UI: The floating widget handles everything itself!
            const Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: FloatingActiveOrders(),
            ),
          ],
        ),
        bottomNavigationBar: CustomBottomNavigationBar(
          selectedIndex: _selectedIndex,
          onItemTapped: _onItemTapped,
        ),
      ),
    );
  }
}

// ─── HomeBody ────────────────────────────────────────────────────────────────

class HomeBody extends StatelessWidget {
  final Function(int, {String? category}) onNavigate;

  const HomeBody({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _CategoryGrid(onNavigate: onNavigate),
          const SizedBox(height: 28),
          if (FirebaseAuth.instance.currentUser == null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: const SellerBanner(),
            ),
            const SizedBox(height: 28),
          ],
          _SectionHeader(label: "FEATURED FOR YOU"),
          const SizedBox(height: 16),
          const _FeaturedCard(),
          const SizedBox(height: 140),
        ],
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: _AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _AppColors.textSecondary,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Featured card ────────────────────────────────────────────────────────────

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Image.network(
              'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?auto=format&fit=crop&q=80&w=1000',
              height: 170,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 170,
                color: _AppColors.border,
                child: const Icon(
                  Icons.image_not_supported,
                  color: Colors.grey,
                ),
              ),
            ),
            Container(
              height: 170,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              left: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "TODAY'S SPECIAL",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Fresh & Healthy\nBowls",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Category grid ────────────────────────────────────────────────────────────

class _CategoryGrid extends StatelessWidget {
  final Function(int, {String? category}) onNavigate;

  const _CategoryGrid({required this.onNavigate});

  static const List<Map<String, dynamic>> _categories = [
    {
      "title": "FOOD",
      "subtitle": "FROM RESTAURANTS",
      "offer": "UP TO 40% OFF",
      "offerColor": Color(0xFFFF3B30),
      "image":
          "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&q=80&w=200",
      "bgColor": Color(0xFFFFF5F5),
      "iconBg": Color(0xFFFFECEC),
      "index": 1,
      "categoryValue": "Restaurant",
    },
    {
      "title": "SUPERMART",
      "subtitle": "GET ANYTHING INSTANTLY",
      "offer": "UP TO ₹100 OFF",
      "offerColor": Color(0xFFFF3B30),
      "image":
          "https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&q=80&w=200",
      "bgColor": Color(0xFFF0FDF4),
      "iconBg": Color(0xFFDCFCE7),
      "index": 2,
    },
    {
      "title": "BAKERY & CAFE",
      "subtitle": "FRESH BREAD & PASTRIES",
      "offer": "UP TO 50% OFF",
      "offerColor": Color(0xFFFF3B30),
      "image":
          "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&q=80&w=200",
      "bgColor": Color(0xFFFFFBEB),
      "iconBg": Color(0xFFFEF3C7),
      "index": 1,
      "categoryValue": "Bakery & Cafe",
    },
    {
      "title": "CATERING",
      "subtitle": "DISCOVER NEARBY",
      "offer": "SURPLUS SPECIALS",
      "offerColor": Color(0xFF00BF63),
      "image":
          "https://images.unsplash.com/photo-1555244162-803834f70033?auto=format&fit=crop&q=80&w=200",
      "bgColor": Color(0xFFF0F9FF),
      "iconBg": Color(0xFFE0F2FE),
      "index": 1,
      "categoryValue": "Catering",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.82,
        ),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          return _CategoryCard(
            category: _categories[index],
            onNavigate: onNavigate,
            animationDelay: Duration(milliseconds: 80 * index),
          );
        },
      ),
    );
  }
}

// ─── Category card ────────────────────────────────────────────────────────────

class _CategoryCard extends StatefulWidget {
  final Map<String, dynamic> category;
  final Function(int, {String? category}) onNavigate;
  final Duration animationDelay;

  const _CategoryCard({
    required this.category,
    required this.onNavigate,
    required this.animationDelay,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(widget.animationDelay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.category;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) {
              setState(() => _isPressed = false);
              if (item['index'] != null) {
                widget.onNavigate(
                  item['index'] as int,
                  category: item['categoryValue'] as String?,
                );
              }
            },
            onTapCancel: () => setState(() => _isPressed = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              curve: Curves.easeOut,
              transform: Matrix4.identity()..scale(_isPressed ? 0.96 : 1.0),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                color: item['bgColor'] as Color,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (item['bgColor'] as Color).withValues(alpha: 0.0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (item['offerColor'] as Color).withValues(
                      alpha: _isPressed ? 0.12 : 0.06,
                    ),
                    blurRadius: _isPressed ? 16 : 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (item['offerColor'] as Color).withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item['offer'] as String,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: item['offerColor'] as Color,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item['title'] as String,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _AppColors.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['subtitle'] as String,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: _AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 2,
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: item['iconBg'] as Color,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            item['image'] as String,
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: item['iconBg'] as Color,
                                child: const Icon(
                                  Icons.broken_image_outlined,
                                  color: _AppColors.textSecondary,
                                  size: 28,
                                ),
                              );
                            },
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
      ),
    );
  }
}
