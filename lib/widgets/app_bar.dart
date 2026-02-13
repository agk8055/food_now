import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_now/screens/search_screen.dart';
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

    // Always try to fetch fresh data if possible or if cache is empty?
    // User requested: "this location can stored in shared preference, inoder to avoid unnessary reads from firestore"
    // So if cache exists, MAYBE don't fetch from Firestore, or fetch only if cache is empty?
    // Strict interpretation: "avoid unnecessary reads" -> prefer cache.
    // However, if user changes location, cache is stale.
    // Given the prompt, I will prioritize cache if available. If not available, fetch.
    if (cachedAddress == null || cachedAddress.isEmpty) {
      await _fetchAddress(prefs);
    }
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

    // 2. If no address found (user not logged in or data missing), try device location
    if (fetchedAddress == null || fetchedAddress.isEmpty) {
      try {
        final locationService = LocationService();
        final position = await locationService.getCurrentPosition();
        if (position != null) {
          fetchedAddress = await locationService.getAddressFromPosition(
            position,
          );
        }
      } catch (e) {
        debugPrint("Error fetching device location: $e");
      }
    }

    // 3. Update State & Cache
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
            onTap: () {
              // TODO: Open screen for changing location
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
                                _address,
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
