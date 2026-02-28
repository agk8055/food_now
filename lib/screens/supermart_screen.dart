import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_loader.dart';
import 'shop_menu_screen.dart';

class SupermartScreen extends StatefulWidget {
  const SupermartScreen({super.key});

  @override
  State<SupermartScreen> createState() => _SupermartScreenState();
}

class _SupermartScreenState extends State<SupermartScreen> {
  GeoPoint? _userLocation;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Supermart",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
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
                  .where('category', isEqualTo: 'Supermarket')
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
                    child: Text("No supermarkets found nearby."),
                  );
                }

                List<QueryDocumentSnapshot> shops = snapshot.data!.docs;

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
                    child: Text("No supermarkets found nearby."),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: shops.length,
                  itemBuilder: (context, index) {
                    final shop = shops[index];
                    final data = shop.data() as Map<String, dynamic>;
                    final images = data['images'] as List<dynamic>?;

                    // Check if shop is open (default to true if field is missing)
                    final bool isOpen = data['isOpen'] ?? true;

                    return GestureDetector(
                      onTap: isOpen
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ShopMenuScreen(
                                    shopId: shop.id,
                                    shopName: data['shopName'],
                                  ),
                                ),
                              );
                            }
                          : null, // Disable tap if closed
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        foregroundDecoration: isOpen
                            ? null
                            : BoxDecoration(
                                color: Colors.grey.withOpacity(
                                  0.1,
                                ), // Subtle grey overlay
                                borderRadius: BorderRadius.circular(15),
                              ),
                        child: ColorFiltered(
                          // This applies the Black & White effect
                          colorFilter: isOpen
                              ? const ColorFilter.mode(
                                  Colors.transparent,
                                  BlendMode.multiply,
                                ) // Normal
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
                                ]), // Grayscale Matrix
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
                                      child:
                                          (images != null && images.isNotEmpty)
                                          ? Image.network(
                                              images.first,
                                              height: 180,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              height: 180,
                                              color: Colors.grey[200],
                                              child: const Icon(
                                                Icons.storefront,
                                                size: 50,
                                                color: Colors.grey,
                                              ),
                                            ),
                                    ),
                                    // "CLOSED" Badge Overlay
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
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
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
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            data['shopName'],
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (isOpen)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.green[50],
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                "★ ${data['rating'] ?? '4.0'}",
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
                                        data['category'] ?? "Supermarket",
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
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
                                              data['location']?['address'] ??
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
                  },
                );
              },
            ),
    );
  }
}
