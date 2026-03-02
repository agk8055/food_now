import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:food_now/screens/search_screen.dart';
import 'package:food_now/screens/location_search_screen.dart';
import 'package:food_now/services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

final VideoPlayerController _sharedBannerController =
    VideoPlayerController.asset('assets/animations/banner.mp4');
bool _isSharedBannerInitialized = false;
bool _isSharedBannerInitializing = false;

class HomeAppBar extends StatefulWidget {
  final bool showBanner;

  const HomeAppBar({super.key, this.showBanner = true});

  @override
  State<HomeAppBar> createState() => _HomeAppBarState();
}

class _HomeAppBarState extends State<HomeAppBar> {
  String _address = "Fetching location...";

  @override
  void initState() {
    super.initState();
    _loadAddress();

    if (!_isSharedBannerInitializing) {
      _isSharedBannerInitializing = true;
      _sharedBannerController
          .initialize()
          .then((_) {
            _isSharedBannerInitialized = true;
            _sharedBannerController.setLooping(true);
            _sharedBannerController.setVolume(0.0); // Mute video by default
            if (mounted) {
              setState(() {});
              if (widget.showBanner) {
                _sharedBannerController.play();
              }
            }
          })
          .catchError((error) {
            debugPrint("Error initializing video: $error");
          });
    } else if (!_isSharedBannerInitialized) {
      _sharedBannerController.addListener(_videoListener);
    } else {
      if (widget.showBanner) {
        _sharedBannerController.play();
      } else {
        _sharedBannerController.pause();
      }
    }
  }

  void _videoListener() {
    if (_isSharedBannerInitialized && mounted) {
      setState(() {});
      _sharedBannerController.removeListener(_videoListener);
      if (widget.showBanner) {
        _sharedBannerController.play();
      } else {
        _sharedBannerController.pause();
      }
    }
  }

  @override
  void didUpdateWidget(HomeAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showBanner != oldWidget.showBanner) {
      if (_isSharedBannerInitialized) {
        if (widget.showBanner) {
          _sharedBannerController.play();
        } else {
          _sharedBannerController.pause();
        }
      }
    }
  }

  @override
  void dispose() {
    _sharedBannerController.removeListener(_videoListener);
    if (_isSharedBannerInitialized) {
      _sharedBannerController.pause();
    }
    super.dispose();
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
    return SliverAppBar(
      backgroundColor: const Color(0xFF00bf63),
      elevation: 0,
      titleSpacing: 0,
      toolbarHeight: 140,
      expandedHeight: widget.showBanner ? 340 : 140,
      pinned: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
      ),
      clipBehavior: Clip.antiAlias,
      title: SizedBox(
        height: 140,
        child: Column(
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
                    const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width * 0.5,
                                  ),
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
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.7,
                              ),
                              child: Text(
                                _address.split(',').sublist(1).join(',').trim(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
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
      ),
      flexibleSpace: widget.showBanner
          ? FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [_buildPromoVideo()],
              ),
            )
          : null,
    );
  }

  Widget _buildPromoVideo() {
    if (!_isSharedBannerInitialized) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: _sharedBannerController.value.size.width,
            height: _sharedBannerController.value.size.height,
            child: VideoPlayer(_sharedBannerController),
          ),
        ),
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
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Icon(Icons.search, color: Colors.grey),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Search for Restaurants, Supermarkets and...",
                style: TextStyle(color: Colors.grey, fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
