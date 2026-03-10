import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/custom_loader.dart';
import '../widgets/shop_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  GeoPoint? _userLocation;

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
            if (mounted) {
              setState(() {
                _userLocation = location['geopoint'] as GeoPoint;
              });
            }
            return;
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final double? lat = prefs.getDouble('cached_geopoint_lat');
      final double? lon = prefs.getDouble('cached_geopoint_lon');

      if (lat != null && lon != null) {
        if (mounted) {
          setState(() {
            _userLocation = GeoPoint(lat, lon);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching user location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            "Favorites",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: const BackButton(color: Colors.black),
          centerTitle: true,
        ),
        body: const Center(
          child: Text("Please log in to view your favorites."),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Favorites",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting &&
              !userSnapshot.hasData) {
            return const Center(child: CustomLoader());
          }

          if (userSnapshot.hasError) {
            return Center(child: Text("Error: ${userSnapshot.error}"));
          }

          final userData =
              userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
          final List<dynamic> favoriteShops = userData['favoriteShops'] ?? [];

          if (favoriteShops.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No favorites yet",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tap the heart icon on restaurants you love\nto see them here.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('shops')
                .where('verificationStatus', isEqualTo: 'approved')
                .snapshots(),
            builder: (context, shopsSnapshot) {
              if (shopsSnapshot.connectionState == ConnectionState.waiting &&
                  !shopsSnapshot.hasData) {
                return const Center(child: CustomLoader());
              }

              if (shopsSnapshot.hasError) {
                return Center(child: Text("Error: ${shopsSnapshot.error}"));
              }

              if (!shopsSnapshot.hasData || shopsSnapshot.data!.docs.isEmpty) {
                return const Center(child: Text("Unable to load restaurants."));
              }

              // Filter shops to only include those in the user's favorites list
              final favoriteShopsDocs = shopsSnapshot.data!.docs.where((doc) {
                return favoriteShops.contains(doc.id);
              }).toList();

              if (favoriteShopsDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        "Favorites not found",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Some restaurants might be temporarily unavailable.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: favoriteShopsDocs.length,
                itemBuilder: (context, index) {
                  final shop = favoriteShopsDocs[index];
                  final data = shop.data() as Map<String, dynamic>;

                  return ShopCard(
                    shopId: shop.id,
                    data: data,
                    userLocation: _userLocation,
                    defaultIcon: Icons.restaurant,
                    defaultCategory: "Restaurant",
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
