import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:food_now/screens/buyer_orders_screen.dart';

// ─── Design Tokens ──────────────────────────────────────────────────────────
class _AppColors {
  static const Color primary = Color(0xFF00BF63);
  static const Color primaryGlow = Color(0xFF00FF87);
  static const Color primaryDim = Color(0xFF00BF6326);
  static const Color surface = Color(0xFF111111);
  static const Color surfaceElevated = Color(0xFF1A1A1A);
  static const Color surfaceHighlight = Color(0xFF222222);
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFF8A8A8A);
  static const Color border = Color(0xFF2A2A2A);
  static const Color borderAccent = Color(0xFF00BF6340);
  static const Color cancelRed = Color(0xFFFF4D4D);
  static const Color cancelRedDim = Color(0xFFFF4D4D1A);
}

// ─── Glassmorphic Card Painter ────────────────────────────────────────────────
class _GlowBorderPainter extends CustomPainter {
  final Color glowColor;
  final double radius;
  final double opacity;

  _GlowBorderPainter({
    required this.glowColor,
    this.radius = 18,
    this.opacity = 0.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          glowColor.withOpacity(opacity),
          glowColor.withOpacity(0.0),
          glowColor.withOpacity(opacity * 0.3),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FloatingActiveOrders extends StatefulWidget {
  const FloatingActiveOrders({super.key});

  @override
  State<FloatingActiveOrders> createState() => _FloatingActiveOrdersState();
}

class _FloatingActiveOrdersState extends State<FloatingActiveOrders>
    with TickerProviderStateMixin {
  StreamSubscription<QuerySnapshot>? _subscription;
  List<DocumentSnapshot> _pendingOrders = [];
  final Set<String> _dismissedOrders = {};
  int _currentOrderPage = 0;
  late PageController _pageController;

  // Animation controllers
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _entryController;
  late Animation<Offset> _entrySlide;
  late Animation<double> _entryFade;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.94);

    // Pulse animation for live indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Entry animation
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutExpo));
    _entryFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOut),
    );

    _listenForPendingOrders();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pageController.dispose();
    _pulseController.dispose();
    _entryController.dispose();
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
            final data = doc.data();
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
            final aTime =
                (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            final bTime =
                (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

          if (mounted) {
            final wasEmpty = _pendingOrders.isEmpty;
            setState(() {
              _pendingOrders = validDocs;
              if (_currentOrderPage >= _pendingOrders.length &&
                  _pendingOrders.isNotEmpty) {
                _currentOrderPage = _pendingOrders.length - 1;
              }
            });
            if (wasEmpty && validDocs.isNotEmpty) {
              _entryController.forward(from: 0);
            }
          }
        });
  }

  Future<void> _launchNavigation(Map<String, dynamic> orderData) async {
    double? lat;
    double? lng;

    if (orderData.containsKey('shopLocation') &&
        orderData['shopLocation'] != null) {
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
          SnackBar(
            content: const Text('Could not open maps'),
            backgroundColor: _AppColors.surfaceElevated,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // ─── Premium QR Code Dialog ───
  void _showQRCode(BuildContext context, String orderId, String otp) {
    final qrData = "foodnow_pickup:$orderId:$otp";

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'QR Code',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (ctx, anim, secondAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutExpo);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
      pageBuilder: (ctx, _, __) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: _AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: _AppColors.border, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: _AppColors.primary.withOpacity(0.15),
                    blurRadius: 60,
                    spreadRadius: -10,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Glow border
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _GlowBorderPainter(
                        glowColor: _AppColors.primary,
                        radius: 28,
                        opacity: 0.6,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _AppColors.primaryDim,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.qr_code_2_rounded,
                                color: _AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Pickup QR Code",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: _AppColors.textPrimary,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                Text(
                                  "Show this to the seller",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // QR Container
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: _AppColors.primary.withOpacity(0.25),
                                blurRadius: 40,
                                spreadRadius: -5,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: RepaintBoundary(
                              child: QrImageView(
                                data: qrData,
                                version: QrVersions.auto,
                                size: 220.0,
                                backgroundColor: Colors.transparent,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.circle,
                                  color: _AppColors.primary,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.circle,
                                  color: _AppColors.primary,
                                ),
                                semanticsLabel: 'Order QR Code',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // OTP Display
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _AppColors.primaryDim,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _AppColors.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "ONE-TIME PASSWORD",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _AppColors.primary.withOpacity(0.7),
                                  letterSpacing: 2.0,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                otp,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 10,
                                  color: _AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Close Button
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _AppColors.surfaceHighlight,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _AppColors.border),
                            ),
                            child: const Center(
                              child: Text(
                                "CLOSE",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _AppColors.textSecondary,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSingleOrderCard(
    String orderId,
    Map<String, dynamic> data, {
    required bool isSingle,
  }) {
    final shopName = data['shopName'] ?? 'Your Order';
    final status = data['status'] ?? 'pending';
    final isCancelled = status == 'cancelled';
    final otp = data['otp'] ?? '----';
    final cancelReason = data['cancelReason'] ?? 'Cancelled by seller';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, anim, __) => const BuyerOrdersScreen(),
            transitionsBuilder: (_, anim, __, child) => FadeTransition(
              opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
              child: child,
            ),
          ),
        );
      },
      child: Container(
        margin: isSingle
            ? const EdgeInsets.symmetric(horizontal: 16)
            : const EdgeInsets.symmetric(horizontal: 5),
        child: Stack(
          children: [
            // Card Body
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: _AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isCancelled
                      ? _AppColors.cancelRed.withOpacity(0.25)
                      : _AppColors.borderAccent,
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isCancelled
                        ? _AppColors.cancelRed.withOpacity(0.08)
                        : _AppColors.primary.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // ─── Animated Icon ───
                  _AnimatedIconBadge(
                    isCancelled: isCancelled,
                    pulseAnimation: _pulseAnimation,
                  ),
                  const SizedBox(width: 13),

                  // ─── Center Details ───
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                shopName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isCancelled
                                      ? _AppColors.cancelRed.withOpacity(0.9)
                                      : _AppColors.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isCancelled) ...[
                              const SizedBox(width: 6),
                              _StatusBadge(label: "CANCELLED", isCancel: true),
                            ] else ...[
                              const SizedBox(width: 6),
                              _StatusBadge(label: "ACTIVE", isCancel: false),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),

                        if (isCancelled)
                          Text(
                            cancelReason,
                            style: TextStyle(
                              fontSize: 12,
                              color: _AppColors.cancelRed.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        else
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _launchNavigation(data),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.near_me_rounded,
                                  size: 12,
                                  color: _AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "Get Directions",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 9,
                                  color: _AppColors.primary.withOpacity(0.6),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ─── Right Action ───
                  if (isCancelled)
                    _DismissButton(
                      onTap: () async {
                        setState(() {
                          _dismissedOrders.add(orderId);
                          _pendingOrders.removeWhere((doc) => doc.id == orderId);
                          if (_currentOrderPage >= _pendingOrders.length &&
                              _pendingOrders.isNotEmpty) {
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
                    )
                  else
                    _QRButton(
                      onTap: () => _showQRCode(context, orderId, otp),
                    ),
                ],
              ),
            ),

            // Subtle top highlight line
            Positioned(
              top: 0,
              left: 24,
              right: 24,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      isCancelled
                          ? _AppColors.cancelRed.withOpacity(0.3)
                          : _AppColors.primary.withOpacity(0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingOrders.isEmpty) return const SizedBox.shrink();

    return SlideTransition(
      position: _entrySlide,
      child: FadeTransition(
        opacity: _entryFade,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          key: ValueKey(_pendingOrders.length),
          child: _pendingOrders.length == 1
              ? _buildSingleOrderCard(
                  _pendingOrders.first.id,
                  _pendingOrders.first.data() as Map<String, dynamic>,
                  isSingle: true,
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 86,
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() => _currentOrderPage = index);
                        },
                        itemCount: _pendingOrders.length,
                        itemBuilder: (context, index) {
                          final orderId = _pendingOrders[index].id;
                          final orderData = _pendingOrders[index].data()
                              as Map<String, dynamic>;
                          return _buildSingleOrderCard(
                            orderId,
                            orderData,
                            isSingle: false,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Dot indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pendingOrders.length, (index) {
                        final bool isActive = _currentOrderPage == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: isActive ? 20 : 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isActive
                                ? _AppColors.primary
                                : _AppColors.border,
                            borderRadius: BorderRadius.circular(5),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: _AppColors.primary.withOpacity(0.5),
                                      blurRadius: 8,
                                      spreadRadius: 0,
                                    ),
                                  ]
                                : null,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Sub-Widgets ─────────────────────────────────────────────────────────────

class _AnimatedIconBadge extends StatelessWidget {
  final bool isCancelled;
  final Animation<double> pulseAnimation;

  const _AnimatedIconBadge({
    required this.isCancelled,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer pulse ring (only for active orders)
        if (!isCancelled)
          AnimatedBuilder(
            animation: pulseAnimation,
            builder: (_, __) => Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _AppColors.primary.withOpacity(
                  0.06 * pulseAnimation.value,
                ),
              ),
            ),
          ),
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: isCancelled
                ? _AppColors.cancelRedDim
                : _AppColors.primaryDim,
            shape: BoxShape.circle,
            border: Border.all(
              color: isCancelled
                  ? _AppColors.cancelRed.withOpacity(0.3)
                  : _AppColors.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Center(
            child: Icon(
              isCancelled
                  ? Icons.info_outline_rounded
                  : Icons.storefront_rounded,
              color: isCancelled ? _AppColors.cancelRed : _AppColors.primary,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final bool isCancel;

  const _StatusBadge({required this.label, required this.isCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isCancel
            ? _AppColors.cancelRed.withOpacity(0.12)
            : _AppColors.primaryDim,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isCancel
              ? _AppColors.cancelRed.withOpacity(0.25)
              : _AppColors.primary.withOpacity(0.2),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          color: isCancel ? _AppColors.cancelRed : _AppColors.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _DismissButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DismissButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _AppColors.cancelRedDim,
          shape: BoxShape.circle,
          border: Border.all(
            color: _AppColors.cancelRed.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.close_rounded,
          size: 15,
          color: _AppColors.cancelRed,
        ),
      ),
    );
  }
}

class _QRButton extends StatefulWidget {
  final VoidCallback onTap;

  const _QRButton({required this.onTap});

  @override
  State<_QRButton> createState() => _QRButtonState();
}

class _QRButtonState extends State<_QRButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _tapController.forward(),
      onTapUp: (_) {
        _tapController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _tapController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          margin: const EdgeInsets.only(left: 10),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _AppColors.primary,
                Color(0xFF009A4F),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _AppColors.primary.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 19),
              SizedBox(height: 2),
              Text(
                "QR",
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}