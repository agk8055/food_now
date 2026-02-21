import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_now/screens/search_screen.dart';
import 'package:food_now/screens/location_search_screen.dart';
import 'package:food_now/services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeAppBar extends StatefulWidget implements PreferredSizeWidget {
  const HomeAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(140);

  @override
  State<HomeAppBar> createState() => _HomeAppBarState();
}

class _HomeAppBarState extends State<HomeAppBar> {
  String _address = "Fetching location...";

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedAddress = prefs.getString('cached_address');

    if (cachedAddress != null && cachedAddress.isNotEmpty) {
      if (mounted) {
        setState(() {
          _address = cachedAddress;
        });
      }
    }

    // Always try to fetch fresh data if possible to keep it up to date
    // Stale-while-revalidate: Show cache first, then update
    _fetchAddress(prefs);
  }

  Future<void> _fetchAddress(SharedPreferences prefs) async {
    final user = FirebaseAuth.instance.currentUser;
    String? fetchedAddress;

    // 1. Try fetching from Firestore if user is logged in
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data();
          final location = data?['location'] as Map<String, dynamic>?;
          fetchedAddress = location?['address'] as String?;
        }
      } catch (e) {
        debugPrint("Error fetching address from Firestore: $e");
      }
    }

    // 2. If no address found from Firestore, check cache first to avoid overwriting manual selections
    if (fetchedAddress == null || fetchedAddress.isEmpty) {
      fetchedAddress = prefs.getString('cached_address');
    }

    // 3. If STILL no address, try getting the device location
    if (fetchedAddress == null || fetchedAddress.isEmpty) {
      try {
        final locationService = LocationService();
        final position = await locationService.getCurrentPosition();
        if (position != null) {
          fetchedAddress = await locationService.getAddressFromPosition(
            position,
          );

          final String geohash = locationService.getGeohash(
            position.latitude,
            position.longitude,
          );
          await prefs.setDouble('cached_geopoint_lat', position.latitude);
          await prefs.setDouble('cached_geopoint_lon', position.longitude);
          await prefs.setString('cached_geohash', geohash);
        }
      } catch (e) {
        debugPrint("Error fetching device location: $e");
      }
    }

    // 4. Update State & Cache
    if (fetchedAddress != null && fetchedAddress.isNotEmpty) {
      await prefs.setString('cached_address', fetchedAddress);
      if (mounted) {
        setState(() {
          _address = fetchedAddress!;
        });
      }
    } else {
      // Only update to error message if we still have the placeholder
      if (mounted && _address == "Fetching location...") {
        setState(() {
          _address = "Location not set";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors
          .transparent, // Make background transparent to show rounded Container
      elevation: 0,
      titleSpacing: 0,
      toolbarHeight: 140,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF00bf63),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(40),
            bottomRight: Radius.circular(40),
          ),
        ),
      ),
      title: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LocationSearchScreen(),
                ),
              );

              if (result == true) {
                _loadAddress();
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                // Split address and take the first part
                                _address.split(',')[0].trim(),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white,
                            ),
                          ],
                        ),
                        // Display the rest of the address if available
                        if (_address.contains(','))
                          Text(
                            _address.split(',').sublist(1).join(',').trim(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSearchBar(context),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SearchScreen()),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.search, color: Colors.grey),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "search for restaurants,supermarkets and...",
                style: TextStyle(color: Colors.grey, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.mic, color: Color(0xFF00bf63)), // Green Mic
          ],
        ),
      ),
    );
  }
}
