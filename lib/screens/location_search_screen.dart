import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Consistency with your existing theme
  final Color primaryGreen = const Color(0xFF00bf63);

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // --- Logic remains identical ---

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
        _showSnackBar('Failed to fetch locations');
      }
    } catch (e) {
      _showSnackBar('Error: $e');
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
        _showSnackBar('Could not get current location');
      }
    } catch (e) {
      _showSnackBar('Error getting location: $e');
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_address', formattedAddress);
      await prefs.setDouble('cached_geopoint_lat', latDouble);
      await prefs.setDouble('cached_geopoint_lon', lonDouble);
      await prefs.setString('cached_geohash', geohash);

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
          Navigator.pop(context, true);
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- Premium UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        title: const Text(
          'Find Nearby Shops',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildSearchHeader(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isLoading
                  ? const Center(child: CustomLoader())
                  : _buildResultsList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Enter pickup area, street, city...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.search_rounded, color: primaryGreen),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.cancel_rounded,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
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
          const SizedBox(height: 16),
          _buildCurrentLocationButton(),
        ],
      ),
    );
  }

  Widget _buildCurrentLocationButton() {
    return InkWell(
      onTap: _useCurrentLocation,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: primaryGreen.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
          color: primaryGreen.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Icon(Icons.my_location_rounded, color: primaryGreen, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Use current location',
                style: TextStyle(
                  color: primaryGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: primaryGreen,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    if (_searchResults.isEmpty && _searchController.text.isEmpty) {
      return _buildEmptyState(
        icon: Icons.storefront_outlined,
        title: 'Where are you looking?',
        subtitle:
            'Search for an area to find the best shops available for pickup near you.',
      );
    }

    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return _buildEmptyState(
        icon: Icons.location_off_outlined,
        title: 'Area not found',
        subtitle:
            'We couldn\'t find that location. Please try searching for a different area.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return AnimatedContainer(
          duration: Duration(milliseconds: 200 + (index * 50)),
          curve: Curves.easeOut,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.grey,
                  size: 22,
                ),
              ),
              title: Text(
                result['name'] ?? 'Unknown Place',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  result['display_name'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ),
              onTap: () => _selectLocation(result),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], height: 1.4),
          ),
        ],
      ),
    );
  }
}
