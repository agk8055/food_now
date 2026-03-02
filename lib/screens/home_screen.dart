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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isCheckingServiceability = true;

  @override
  void initState() {
    super.initState();
    _checkServiceability();
  }

  Future<void> _checkServiceability() async {
    try {
      GeoPoint? userLocation;
      final User? user = FirebaseAuth.instance.currentUser;

      // 1. Try Firestore
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

      // 2. Try SharedPreferences
      if (userLocation == null) {
        final prefs = await SharedPreferences.getInstance();
        final double? lat = prefs.getDouble('cached_geopoint_lat');
        final double? lon = prefs.getDouble('cached_geopoint_lon');
        if (lat != null && lon != null) {
          userLocation = GeoPoint(lat, lon);
        }
      }

      // 3. Try Device Location
      if (userLocation == null) {
        final locationService = LocationService();
        final position = await locationService.getCurrentPosition();
        if (position != null) {
          userLocation = GeoPoint(position.latitude, position.longitude);
        }
      }

      if (userLocation == null) {
        // Can't determine location at all, let them in to search
        if (mounted) {
          setState(() {
            _isCheckingServiceability = false;
          });
        }
        return;
      }

      // Check for nearby approved shops
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
            // 10km radius
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
          setState(() {
            _isCheckingServiceability = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error checking serviceability: $e");
      if (mounted) {
        setState(() {
          _isCheckingServiceability = false;
        });
      }
    }
  }

  // List of screens for navigation
  // Using a method to build screens to access context if needed, or simple list
  // List of screens for navigation
  List<Widget> get _screens => [
    HomeBody(
      onNavigate: _onItemTapped,
    ), // Extracted Home content with navigation callback
    const FoodScreen(),
    const SupermartScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingServiceability) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CustomLoader()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: _selectedIndex < 3
          ? NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [HomeAppBar(showBanner: _selectedIndex == 0)];
              },
              body: _screens[_selectedIndex],
            )
          : _screens[_selectedIndex],
      bottomNavigationBar: CustomBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}

class HomeBody extends StatelessWidget {
  final Function(int) onNavigate;

  const HomeBody({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildCategoryGrid(),
          const SizedBox(height: 24),
          if (FirebaseAuth.instance.currentUser == null) ...[
            const SellerBanner(),
            const SizedBox(height: 24),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              "FEATURED FOR YOU",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Placeholder for Featured section (bottom part of image)
          Container(
            height: 150,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              image: const DecorationImage(
                image: NetworkImage(
                  'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?auto=format&fit=crop&q=80&w=1000',
                ), // Placeholder
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 80), // Space for bottom nav
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final categories = [
      {
        "title": "FOOD",
        "subtitle": "FROM RESTAURANTS",
        "offer": "UP TO 40% OFF",
        "offerColor": Colors.red,
        "image":
            "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&q=80&w=200", // Salad/Food
        "index": 1, // Navigate to Food Tab
      },
      {
        "title": "SUPERMART",
        "subtitle": "GET ANYTHING INSTANTLY",
        "offer": "UP TO ₹100 OFF",
        "offerColor": Colors.red,
        "image":
            "https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&q=80&w=200", // Grocery
        "index": 2, // Navigate to Supermart Tab
      },
      {
        "title": "BAKERY & CAFE",
        "subtitle": "FRESH BREAD & PASTRIES",
        "offer": "UP TO 50% OFF",
        "offerColor": Colors.red,
        "image":
            "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&q=80&w=200", // Bakery
        "index": 1, // Also Food/Bakery? Let's keep it 1 for now or 0
      },
      {
        "title": "CATERING",
        "subtitle": "DISCOVER NEARBY",
        "offer": "SURPLUS SPECIALS",
        "offerColor": const Color(0xFF00bf63), // Green for this one
        "image":
            "https://images.unsplash.com/photo-1555244162-803834f70033?auto=format&fit=crop&q=80&w=200", // Catering/Venue
        "index": 1,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        shrinkWrap: true, // Important for using inside SingleChildScrollView
        physics:
            const NeverScrollableScrollPhysics(), // Disable internal scrolling
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8, // Adjust for height vs width
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final item = categories[index];
          return GestureDetector(
            onTap: () {
              // Navigate based on index
              if (item['index'] != null) {
                onNavigate(item['index'] as int);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: .05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['subtitle'] as String,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item['offer'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: item['offerColor'] as Color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      alignment: Alignment.bottomRight,
                      padding: const EdgeInsets.only(bottom: 12, right: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          item['image'] as String,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[300],
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
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
          );
        },
      ),
    );
  }
}
