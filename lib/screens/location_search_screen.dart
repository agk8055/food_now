import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/custom_loader.dart';
import 'package:http/http.dart' as http;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:food_now/screens/not_serviceable_screen.dart';
import '../services/location_service.dart';

class LocationSearchScreen extends StatefulWidget {
  const LocationSearchScreen({super.key});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  final LocationService _locationService = LocationService();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _searchResults = [];
    });

    final url = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '5',
      'viewbox': '74.9,8.1,77.4,12.8',
      'bounded': '1',
      'countrycodes': 'in',
      'accept-language': 'en',
    });

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'FoodNowApp/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _searchResults = data;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to fetch locations')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        final address = await _locationService.getAddressFromPosition(position);
        if (address != null) {
          await _saveAndPop(
            lat: position.latitude.toString(),
            lon: position.longitude.toString(),
            formattedAddress: address,
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get current location')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectLocation(dynamic locationData) async {
    final lat = locationData['lat'];
    final lon = locationData['lon'];
    final addressObj = locationData['address'];
    final name = locationData['name'];

    // Construct the address as requested: name, state_district, state
    String stateDistrict = addressObj['state_district'] ?? '';
    String state = addressObj['state'] ?? '';

    List<String> addressParts = [name];
    if (stateDistrict.isNotEmpty) addressParts.add(stateDistrict);
    if (state.isNotEmpty) addressParts.add(state);

    final formattedAddress = addressParts.join(', ');

    await _saveAndPop(lat: lat, lon: lon, formattedAddress: formattedAddress);
  }

  Future<void> _saveAndPop({
    required String lat,
    required String lon,
    required String formattedAddress,
  }) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final double latDouble = double.tryParse(lat) ?? 0.0;
      final double lonDouble = double.tryParse(lon) ?? 0.0;
      final String geohash = _locationService.getGeohash(latDouble, lonDouble);

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_address', formattedAddress);
      await prefs.setDouble('cached_geopoint_lat', latDouble);
      await prefs.setDouble('cached_geopoint_lon', lonDouble);
      await prefs.setString('cached_geohash', geohash);

      // Save to Firestore if user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'location': {
                'geohash': geohash,
                'geopoint': GeoPoint(latDouble, lonDouble),
                'address': formattedAddress,
              },
            });
      }

      // Check serviceability
      final shopsSnapshot = await FirebaseFirestore.instance
          .collection('shops')
          .where('verificationStatus', isEqualTo: 'approved')
          .get();

      bool isServiceable = false;

      for (var doc in shopsSnapshot.docs) {
        final data = doc.data();
        final location = data['location'] as Map<String, dynamic>?;
        if (location != null && location['geopoint'] != null) {
          final GeoPoint shopPoint = location['geopoint'] as GeoPoint;
          final double distance = Geolocator.distanceBetween(
            latDouble,
            lonDouble,
            shopPoint.latitude,
            shopPoint.longitude,
          );

          if (distance <= 10000) {
            isServiceable = true;
            break;
          }
        }
      }

      if (mounted) {
        if (isServiceable) {
          Navigator.pop(context, true); // Return true to indicate update
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const NotServiceableScreen(),
            ),
            (route) => false,
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search Location',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for area, street name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchResults = [];
                    });
                  },
                ),
              ),
              onChanged: (value) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 500), () {
                  if (value.length >= 2) {
                    _searchLocation(value);
                  } else {
                    setState(() {
                      _searchResults = [];
                    });
                  }
                });
              },
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF00bf63)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: InkWell(
                onTap: _useCurrentLocation,
                borderRadius: BorderRadius.circular(10),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.my_location, color: Color(0xFF00bf63)),
                      SizedBox(width: 8),
                      Text(
                        'Use current location',
                        style: TextStyle(
                          color: Color(0xFF00bf63),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CustomLoader())
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _searchResults.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    final name = result['name'];
                    final displayName = result['display_name'];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(name ?? 'Unknown Place'),
                      subtitle: Text(displayName ?? ''),
                      onTap: () => _selectLocation(result),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
