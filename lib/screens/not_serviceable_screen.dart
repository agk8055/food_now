import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:food_now/screens/location_search_screen.dart';
import 'package:food_now/screens/home_screen.dart';
import 'package:food_now/screens/profile_screen.dart';
import 'package:food_now/services/location_service.dart';

class NotServiceableScreen extends StatefulWidget {
  const NotServiceableScreen({super.key});

  @override
  State<NotServiceableScreen> createState() => _NotServiceableScreenState();
}

class _NotServiceableScreenState extends State<NotServiceableScreen> {
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

    // 2. If no address found, try device location
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

    // 3. Update State & Cache
    if (fetchedAddress != null && fetchedAddress.isNotEmpty) {
      await prefs.setString('cached_address', fetchedAddress);
      if (mounted) {
        setState(() {
          _address = fetchedAddress!;
        });
      }
    } else {
      if (mounted && _address == "Fetching location...") {
        setState(() {
          _address = "Location not set";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 70, // Increase slightly for location text
        title: InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LocationSearchScreen(),
              ),
            );

            if (result == true) {
              _loadAddress();
              // Try to navigate to Home if location changed, let main handle check
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              }
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min, // Wrap content loosely
            children: [
              const Icon(Icons.location_on, color: Color(0xFF00bf63), size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            // Split address and take the first part
                            _address.split(',')[0].trim(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.black87,
                          size: 20,
                        ),
                      ],
                    ),
                    // Display the rest of the address if available
                    if (_address.contains(','))
                      Text(
                        _address.split(',').sublist(1).join(',').trim(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
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
        actions: [
          IconButton(
            icon: const Icon(
              Icons.account_circle,
              color: Colors.black,
              size: 40,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Lottie Animation showing coming soon
              Lottie.asset(
                'assets/animations/coming_soon.json',
                height: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 32),

              Text(
                "COMING \nSOON TO YOUR",
                style: GoogleFonts.titanOne(
                  fontSize: 30,
                  fontWeight: FontWeight.w800, // Very broad
                  color: const Color.fromARGB(221, 63, 60, 60),
                  height: 1.2,
                ),
                
                textAlign: TextAlign.center,
              ),
              Text(
                "LOCATION",
                style: GoogleFonts.titanOne(
                  fontSize: 30,
                  fontWeight: FontWeight.w800, // Very broad
                  color: const Color.fromARGB(255, 3, 133, 70),
                  height: 1.2,
                ),  
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LocationSearchScreen(),
                    ),
                  );

                  // If result is true, it means location was successfully selected/changed.
                  // We can replace this screen with HomeScreen so it re-checks
                  if (result == true && context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.edit_location_alt),
                label: const Text("Change Location"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00bf63),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
