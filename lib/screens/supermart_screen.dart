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
                  // --- ADDED BOTTOM PADDING HERE ---
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  itemCount: shops.length,
                  itemBuilder: (context, index) {
                    final shop = shops[index];
                    final data = shop.data() as Map<String, dynamic>;

                    return ShopCard(
                      shopId: shop.id,
                      data: data,
                      defaultIcon: Icons.storefront,
                      defaultCategory: "Supermarket",
                    );
                  },
                );
              },
            ),
    );
  }
}
