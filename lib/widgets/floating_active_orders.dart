import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:food_now/screens/buyer_orders_screen.dart';

// ─── Design Tokens ──────────────────────────────────────────────────────────
class _AppColors {
  static const Color primary = Color(0xFF00BF63);
  static const Color primaryLight = Color(0xFFE8FAF0);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  static const Color background = Color(0xFFF7F8FA); 
}

class FloatingActiveOrders extends StatefulWidget {
  const FloatingActiveOrders({super.key});

  @override
  State<FloatingActiveOrders> createState() => _FloatingActiveOrdersState();
}

class _FloatingActiveOrdersState extends State<FloatingActiveOrders> {
  StreamSubscription<QuerySnapshot>? _subscription;
  List<DocumentSnapshot> _pendingOrders = [];
  final Set<String> _dismissedOrders = {};
  int _currentOrderPage = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.93);
    _listenForPendingOrders();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _listenForPendingOrders() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _subscription = FirebaseFirestore.instance
        .collection('orders')
        .where('buyerId', isEqualTo: user.uid)
        .where('status', whereIn: ['pending', 'cancelled'])
        .snapshots()
        .listen((snapshot) {
      final List<DocumentSnapshot> validDocs = [];

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'];

        if (status == 'cancelled') {
          if (data['dismissedByBuyer'] == true) continue;
          if (_dismissedOrders.contains(doc.id)) continue;

          final createdAt = data['createdAt'] as Timestamp?;
          if (createdAt != null) {
            if (DateTime.now().difference(createdAt.toDate()).inHours > 24) {
              continue;
            }
          }
        }
        validDocs.add(doc);
      }

      validDocs.sort((a, b) {
        final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
        final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });

      if (mounted) {
        setState(() {
          _pendingOrders = validDocs;
          if (_currentOrderPage >= _pendingOrders.length && _pendingOrders.isNotEmpty) {
            _currentOrderPage = _pendingOrders.length - 1;
          }
        });
      }
    });
  }

  Future<void> _launchNavigation(Map<String, dynamic> orderData) async {
    double? lat;
    double? lng;

    if (orderData.containsKey('shopLocation') && orderData['shopLocation'] != null) {
      final GeoPoint point = orderData['shopLocation'];
      lat = point.latitude;
      lng = point.longitude;
    } else if (orderData.containsKey('shopId')) {
      try {
        final shopDoc = await FirebaseFirestore.instance
            .collection('shops')
            .doc(orderData['shopId'])
            .get();
        if (shopDoc.exists) {
          final shopData = shopDoc.data()!;
          if (shopData.containsKey('location') && shopData['location'] != null) {
            final GeoPoint point = shopData['location']['geopoint'];
            lat = point.latitude;
            lng = point.longitude;
          }
        }
      } catch (e) {
        debugPrint("Error fetching shop location: $e");
      }
    }

    String url = '';
    if (lat != null && lng != null) {
      url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    } else {
      final shopName = orderData['shopName'] ?? 'Restaurant';
      final encodedName = Uri.encodeComponent(shopName);
      url = 'https://www.google.com/maps/search/?api=1&query=$encodedName';
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps')),
        );
      }
    }
  }

  Widget _buildSingleOrderCard(String orderId, Map<String, dynamic> data, {required bool isSingle}) {
    final shopName = data['shopName'] ?? 'Your Order';
    final status = data['status'] ?? 'pending';
    final isCancelled = status == 'cancelled';
    final otp = data['otp'] ?? '----';
    final cancelReason = data['cancelReason'] ?? 'Cancelled by seller';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BuyerOrdersScreen()),
            );
          },
          child: Container(
            margin: isSingle
                ? const EdgeInsets.symmetric(horizontal: 16)
                : const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: isCancelled ? Colors.red.shade200 : _AppColors.border,
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: isCancelled ? Colors.red.shade50 : _AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      isCancelled ? Icons.error_outline_rounded : Icons.storefront_rounded,
                      color: isCancelled ? Colors.red.shade400 : _AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        shopName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: _AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      if (isCancelled) ...[
                        const SizedBox(height: 4),
                        Text(
                          cancelReason,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      ] else ...[
                        const SizedBox(height: 2),
                        // ─── THE FIX: Opaque Hit Testing & Pill Background ───
                        GestureDetector(
                          behavior: HitTestBehavior.opaque, // Forces Flutter to catch taps here
                          onTap: () => _launchNavigation(data),
                          child: Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50, // Subtle blue pill background
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.near_me_rounded, size: 14, color: Colors.blue.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  "Get Directions",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade600,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (!isCancelled)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _AppColors.primary.withOpacity(0.15)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "OTP",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: _AppColors.primary.withOpacity(0.8),
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          otp,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: _AppColors.primary,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        if (isCancelled)
          Positioned(
            top: isSingle ? -8 : -8,
            right: isSingle ? 8 : -2,
            child: GestureDetector(
              onTap: () async {
                setState(() {
                  _dismissedOrders.add(orderId);
                  _pendingOrders.removeWhere((doc) => doc.id == orderId);
                  if (_currentOrderPage >= _pendingOrders.length && _pendingOrders.isNotEmpty) {
                    _currentOrderPage = _pendingOrders.length - 1;
                  }
                });
                try {
                  await FirebaseFirestore.instance
                      .collection('orders')
                      .doc(orderId)
                      .update({'dismissedByBuyer': true});
                } catch (e) {
                  debugPrint("Error updating dismissal: $e");
                }
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: _AppColors.border),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                  ],
                ),
                child: const Icon(Icons.close_rounded, size: 14, color: _AppColors.textSecondary),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingOrders.isEmpty) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
      key: ValueKey(_pendingOrders.length),
      child: _pendingOrders.length == 1
          ? _buildSingleOrderCard(_pendingOrders.first.id, _pendingOrders.first.data() as Map<String, dynamic>, isSingle: true)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 82,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentOrderPage = index);
                    },
                    itemCount: _pendingOrders.length,
                    itemBuilder: (context, index) {
                      final orderId = _pendingOrders[index].id;
                      final orderData = _pendingOrders[index].data() as Map<String, dynamic>;
                      return _buildSingleOrderCard(orderId, orderData, isSingle: false);
                    },
                  ),
                ),
                const SizedBox(height: 2),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pendingOrders.length, (index) {
                    final bool isActive = _currentOrderPage == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isActive ? 16 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isActive ? _AppColors.primary : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    );
                  }),
                ),
              ],
            ),
    );
  }
}