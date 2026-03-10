import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:food_now/services/location_service.dart';
import 'package:food_now/screens/not_serviceable_screen.dart';
import 'package:food_now/widgets/custom_loader.dart';
import 'package:food_now/widgets/seller_banner.dart';
import 'package:food_now/screens/profile_screen.dart';
import 'package:food_now/widgets/bottom_navigation_bar.dart';
import 'package:food_now/screens/food_screen.dart';
import 'package:food_now/screens/supermart_screen.dart';
import 'package:food_now/screens/buyer_orders_screen.dart';
import 'package:food_now/widgets/app_bar.dart';
import 'package:food_now/widgets/review_bottom_sheet.dart';
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
  StreamSubscription<QuerySnapshot>? _pendingOrdersSubscription;

  final Set<String> _processingOrders = {};

  // State for multiple floating active order cards
  List<DocumentSnapshot> _pendingOrders = [];
  final Set<String> _dismissedOrders = {}; // Local state for instant UI updates
  int _currentOrderPage = 0;
  final PageController _pageController = PageController(viewportFraction: 0.92);

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
    _listenForPendingOrders();
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

  void _listenForPendingOrders() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _pendingOrdersSubscription = FirebaseFirestore.instance
        .collection('orders')
        .where('buyerId', isEqualTo: user.uid)
        .where('status', whereIn: ['pending', 'cancelled'])
        .snapshots()
        .listen((snapshot) {
          final List<DocumentSnapshot> validDocs = [];

          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'];

            if (status == 'cancelled') {
              // 1. Check if the database says it was already dismissed
              if (data['dismissedByBuyer'] == true) continue;

              // 2. Check local state (just to make UI feel snappy before DB updates)
              if (_dismissedOrders.contains(doc.id)) continue;

              // 3. Only show recent cancellations (within 24 hours)
              final createdAt = data['createdAt'] as Timestamp?;
              if (createdAt != null) {
                if (DateTime.now().difference(createdAt.toDate()).inHours >
                    24) {
                  continue;
                }
              }
            }
            validDocs.add(doc);
          }

          validDocs.sort((a, b) {
            final aTime =
                (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            final bTime =
                (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

          if (mounted) {
            setState(() {
              _pendingOrders = validDocs;
              if (_currentOrderPage >= _pendingOrders.length &&
                  _pendingOrders.isNotEmpty) {
                _currentOrderPage = _pendingOrders.length - 1;
              }
            });
          }
        });
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    _pendingOrdersSubscription?.cancel();
    _pageController.dispose();
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

  // ── Navigation Link Logic ───────────────────────────────────────────────

  Future<void> _launchNavigation(Map<String, dynamic> orderData) async {
    double? lat;
    double? lng;

    if (orderData.containsKey('shopLocation') &&
        orderData['shopLocation'] != null) {
      final GeoPoint point = orderData['shopLocation'];
      lat = point.latitude;
      lng = point.longitude;
    } else if (orderData.containsKey('shopId')) {
      try {
        final shopDoc = await FirebaseFirestore.instance
            .collection('shops')
            .doc(orderData['shopId'])
            .get();
        if (shopDoc.exists) {
          final shopData = shopDoc.data()!;
          if (shopData.containsKey('location') &&
              shopData['location'] != null) {
            final GeoPoint point = shopData['location']['geopoint'];
            lat = point.latitude;
            lng = point.longitude;
          }
        }
      } catch (e) {
        debugPrint("Error fetching shop location: $e");
      }
    }

    String url = '';
    if (lat != null && lng != null) {
      url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    } else {
      final shopName = orderData['shopName'] ?? 'Restaurant';
      final encodedName = Uri.encodeComponent(shopName);
      url = 'https://www.google.com/maps/search/?api=1&query=$encodedName';
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open maps')));
      }
    }
  }

  // ── Build Active Order Floating Slider ───────────────────────────────────

  Widget _buildActiveOrdersSlider() {
    if (_pendingOrders.isEmpty) return const SizedBox.shrink();

    if (_pendingOrders.length == 1) {
      final orderId = _pendingOrders.first.id;
      final orderData = _pendingOrders.first.data() as Map<String, dynamic>;
      return _buildSingleOrderCard(orderId, orderData, isSingle: true);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 105,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentOrderPage = index);
            },
            itemCount: _pendingOrders.length,
            itemBuilder: (context, index) {
              final orderId = _pendingOrders[index].id;
              final orderData =
                  _pendingOrders[index].data() as Map<String, dynamic>;
              return _buildSingleOrderCard(orderId, orderData, isSingle: false);
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_pendingOrders.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentOrderPage == index ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentOrderPage == index
                    ? _AppColors.primary
                    : Colors.grey[400],
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSingleOrderCard(
    String orderId,
    Map<String, dynamic> data, {
    required bool isSingle,
  }) {
    final shopName = data['shopName'] ?? 'Your Order';
    final status = data['status'] ?? 'pending';
    final isCancelled = status == 'cancelled';
    final otp = data['otp'] ?? '----';
    final cancelReason = data['cancelReason'] ?? 'Cancelled by seller';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BuyerOrdersScreen(),
              ),
            );
          },
          child: Container(
            margin: isSingle
                ? const EdgeInsets.symmetric(horizontal: 16)
                : const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: isCancelled
                    ? Colors.redAccent.withOpacity(0.3)
                    : _AppColors.border,
                width: isCancelled ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isCancelled
                        ? Colors.red.withOpacity(0.1)
                        : _AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCancelled
                        ? Icons.cancel_outlined
                        : Icons.shopping_bag_rounded,
                    color: isCancelled ? Colors.redAccent : _AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        shopName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: _AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      if (isCancelled)
                        Text(
                          "Cancelled: $cancelReason",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        GestureDetector(
                          onTap: () => _launchNavigation(data),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _AppColors.primaryLight.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.directions,
                                  size: 14,
                                  color: _AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  "Get Directions",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isCancelled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _AppColors.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "OTP",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white70,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          otp,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ── Database Sync Dismissal Logic ──
        if (isCancelled)
          Positioned(
            top: isSingle ? -4 : -4,
            right: isSingle ? 6 : -4,
            child: GestureDetector(
              onTap: () async {
                // 1. Immediately hide it from the UI for a snappy feel
                setState(() {
                  _dismissedOrders.add(orderId);
                  _pendingOrders.removeWhere((doc) => doc.id == orderId);
                  if (_currentOrderPage >= _pendingOrders.length &&
                      _pendingOrders.isNotEmpty) {
                    _currentOrderPage = _pendingOrders.length - 1;
                  }
                });

                // 2. Update the document in Firestore so it syncs across all devices!
                try {
                  await FirebaseFirestore.instance
                      .collection('orders')
                      .doc(orderId)
                      .update({'dismissedByBuyer': true});
                } catch (e) {
                  debugPrint("Error updating dismissal status: $e");
                }
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
      ],
    );
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

            // Floating Active Order Card Slider
            if (_pendingOrders.isNotEmpty)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    return SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0, 1),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutBack,
                            ),
                          ),
                      child: child,
                    );
                  },
                  key: ValueKey(_pendingOrders.length),
                  child: _buildActiveOrdersSlider(),
                ),
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
