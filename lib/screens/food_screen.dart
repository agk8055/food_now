import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_loader.dart';
import '../widgets/shop_card.dart';

class FoodScreen extends StatefulWidget {
  final String? initialCategory;

  const FoodScreen({super.key, this.initialCategory});

  @override
  State<FoodScreen> createState() => _FoodScreenState();
}

class _FoodScreenState extends State<FoodScreen> {
  GeoPoint? _userLocation;
  bool _isLoadingLocation = true;
  late String _selectedCategory;

  final List<String> _categories = [
    'All',
    'Restaurant',
    'Bakery & Cafe',
    'Catering',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? 'All';
    _fetchUserLocation();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle = _selectedCategory == 'All'
        ? 'Food'
        : _selectedCategory;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoadingLocation
          ? const Center(child: CustomLoader())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('shops')
                  .where('verificationStatus', isEqualTo: 'approved')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CustomLoader());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("No restaurants found nearby."),
                  );
                }

                List<QueryDocumentSnapshot> shops = snapshot.data!.docs.where((
                  doc,
                ) {
                  final data = doc.data() as Map<String, dynamic>;
                  final category = data['category'] ?? 'Other';

                  // Hide Supermarkets
                  if (category == 'Supermarket') return false;

                  // Apply filter
                  if (_selectedCategory == 'Restaurant' &&
                      category != 'Restaurant') {
                    return false;
                  }
                  if (_selectedCategory == 'Bakery & Cafe' &&
                      category != 'Bakery') {
                    return false;
                  }
                  if (_selectedCategory == 'Catering' && category != 'Catering') {
                    return false;
                  }

                  // If 'All', keeping everything EXCEPT Supermarket (already handled)
                  return true;
                }).toList();

                if (_userLocation != null) {
                  // Filter by distance (10km = 10000m)
                  shops = shops.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final location = data['location'] as Map<String, dynamic>?;
                    if (location == null || location['geopoint'] == null) {
                      return false;
                    }

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

                if (shops.isEmpty) {
                  return const Center(
                    child: Text("No restaurants found nearby."),
                  );
                }

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        color: Colors.white,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: _categories.map((category) {
                              final isSelected = _selectedCategory == category;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedCategory = category;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF00bf63)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF00bf63)
                                          : Colors.grey.withOpacity(0.2),
                                      width: isSelected ? 0 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF00bf63,
                                              ).withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.02,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                  ),
                                  child: Text(
                                    category,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey[700],
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      fontSize: 14,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      // --- ADDED BOTTOM PADDING HERE ---
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final shop = shops[index];
                          final data = shop.data() as Map<String, dynamic>;

                          return ShopCard(
                            shopId: shop.id,
                            data: data,
                            defaultIcon: Icons.restaurant,
                            defaultCategory: "Restaurant",
                          );
                        }, childCount: shops.length),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
