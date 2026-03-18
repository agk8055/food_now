import 'package:flutter/material.dart';
import '../widgets/custom_loader.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_now/services/user_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../widgets/cancel_order_dialog.dart';
import '../widgets/verify_otp_dialog.dart';
import 'global_qr_scanner_screen.dart';

// ── Design Tokens ─────────────────────────────────────────────────────────────
class _DesignTokens {
  static const Color primary = Color(0xFF00bf63);
  static const Color primaryDim = Color(0xFF00a355);
  static const Color surface = Colors.white;
  static const Color background = Color(0xFFF2F4F7);
  static const Color cardSurface = Colors.white;
  static const Color textPrimary = Color(0xFF0D1117);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color pending = Color(0xFFF59E0B);
  static const Color cancelled = Color(0xFFEF4444);
  static const Color expired = Color(0xFF6B7280);

  static const double radiusXS = 8;
  static const double radiusSM = 12;
  static const double radiusMD = 16;
  static const double radiusLG = 20;
  static const double radiusXL = 24;

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: primary.withOpacity(0.35),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: primary.withOpacity(0.15),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];
}

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen>
    with TickerProviderStateMixin {
  late Future<DocumentSnapshot?> _shopFuture;
  final _user = FirebaseAuth.instance.currentUser;

  late AnimationController _fabAnimController;
  late AnimationController _headerAnimController;
  late Animation<double> _fabScaleAnim;
  late Animation<double> _headerFadeAnim;
  late Animation<Offset> _headerSlideAnim;

  Future<void> _handleRefresh() async {
    if (_user != null) {
      setState(() {
        _shopFuture = UserService().getShop(_user.uid);
      });
      await Future.wait([
        _shopFuture,
        Future.delayed(const Duration(milliseconds: 800)),
      ]);
    }
  }

  @override
  void initState() {
    super.initState();
    if (_user != null) {
      _shopFuture = UserService().getShop(_user.uid);
    }

    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fabScaleAnim = CurvedAnimation(
      parent: _fabAnimController,
      curve: Curves.elasticOut,
    );

    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerFadeAnim = CurvedAnimation(
      parent: _headerAnimController,
      curve: Curves.easeOut,
    );
    _headerSlideAnim = Tween<Offset>(
      begin: const Offset(0, -0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _headerAnimController, curve: Curves.easeOutCubic),
    );

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _headerAnimController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _fabAnimController.forward();
    });
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    _headerAnimController.dispose();
    super.dispose();
  }

  void _showCancelOrderDialog(
    BuildContext context,
    String orderId,
    String buyerName,
    String buyerId,
    String shopName,
  ) {
    showDialog(
      context: context,
      builder: (context) => CancelOrderDialog(
        orderId: orderId,
        buyerName: buyerName,
        buyerId: buyerId,
        shopName: shopName,
      ),
    );
  }

  void _showVerifyOTPDialog(
    BuildContext context,
    String orderId,
    String correctOtp,
    String buyerName,
  ) {
    showDialog(
      context: context,
      builder: (context) => VerifyOTPDialog(
        orderId: orderId,
        correctOtp: correctOtp,
        buyerName: buyerName,
        primaryGreen: _DesignTokens.primary,
      ),
    );
  }

  void _openGlobalQRScanner(BuildContext context, String shopId) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            GlobalQRScannerScreen(shopId: shopId),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        backgroundColor: _DesignTokens.background,
        body: Center(child: _buildUnauthenticatedState()),
      );
    }

    return FutureBuilder<DocumentSnapshot?>(
      future: _shopFuture,
      builder: (context, shopSnapshot) {
        if (shopSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CustomLoader()),
          );
        }
        if (!shopSnapshot.hasData || shopSnapshot.data == null) {
          return const Scaffold(
            body: Center(child: Text("Error loading shop details.")),
          );
        }

        final String shopId = shopSnapshot.data!.id;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: _DesignTokens.background,
            extendBodyBehindAppBar: false,
            appBar: _buildAppBar(),
            body: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('shopId', isEqualTo: shopId)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, orderSnapshot) {
                if (orderSnapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${orderSnapshot.error}',
                      style: const TextStyle(color: _DesignTokens.cancelled),
                    ),
                  );
                }
                if (orderSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CustomLoader());
                }

                final docs = orderSnapshot.data?.docs ?? [];
                final now = DateTime.now();

                final pendingOrders = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'pending';
                  final expiryTimestamp = data['expiryTime'] as Timestamp?;
                  final isExpired = status == 'pending' &&
                      expiryTimestamp != null &&
                      now.isAfter(expiryTimestamp.toDate());
                  return status == 'pending' && !isExpired;
                }).toList();

                final completedOrders = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'pending';
                  final expiryTimestamp = data['expiryTime'] as Timestamp?;
                  final isExpired = status == 'pending' &&
                      expiryTimestamp != null &&
                      now.isAfter(expiryTimestamp.toDate());
                  return status == 'completed' ||
                      status == 'cancelled' ||
                      status == 'expired' ||
                      isExpired;
                }).toList();

                return TabBarView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildOrderList(pendingOrders, isPendingTab: true),
                    _buildOrderList(completedOrders, isPendingTab: false),
                  ],
                );
              },
            ),
            floatingActionButton: ScaleTransition(
              scale: _fabScaleAnim,
              child: _buildScanFAB(context, shopId),
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
          ),
        );
      },
    );
  }

  Widget _buildUnauthenticatedState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _DesignTokens.surface,
            shape: BoxShape.circle,
            boxShadow: _DesignTokens.cardShadow,
          ),
          child: Icon(
            Icons.lock_outline_rounded,
            size: 40,
            color: _DesignTokens.textMuted,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          "Not Authenticated",
          style: TextStyle(
            color: _DesignTokens.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Please sign in to manage your orders.",
          style: TextStyle(
            color: _DesignTokens.textSecondary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildScanFAB(BuildContext context, String shopId) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: _DesignTokens.elevatedShadow,
      ),
      child: Material(
        color: _DesignTokens.primary,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openGlobalQRScanner(context, shopId),
          splashColor: Colors.white.withOpacity(0.15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  "SCAN QR",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    // Calculate appbar height: title row (10t+10b padding + ~44 content) + tab bar (42h + 8t+10b padding) = 124
    // SafeArea padding is handled by the system, so PreferredSize only needs the non-status-bar portion.
    return PreferredSize(
      preferredSize: const Size.fromHeight(106),
      child: FadeTransition(
        opacity: _headerFadeAnim,
        child: SlideTransition(
          position: _headerSlideAnim,
          child: Container(
            decoration: BoxDecoration(
              color: _DesignTokens.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: _DesignTokens.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(_DesignTokens.radiusSM),
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            color: _DesignTokens.primary,
                            size: 19,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "Orders & Pickups",
                              style: TextStyle(
                                color: _DesignTokens.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 19,
                                letterSpacing: -0.5,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              "Manage your store reservations",
                              style: TextStyle(
                                color: _DesignTokens.textMuted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildTabBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: _DesignTokens.background,
          borderRadius: BorderRadius.circular(_DesignTokens.radiusSM),
        ),
        padding: const EdgeInsets.all(3),
        child: TabBar(
          labelColor: Colors.white,
          unselectedLabelColor: _DesignTokens.textSecondary,
          indicator: BoxDecoration(
            color: _DesignTokens.primary,
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(
                color: _DesignTokens.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: 0.1,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: "Pending Pickup"),
            Tab(text: "Completed / Past"),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(
    List<QueryDocumentSnapshot> orders, {
    required bool isPendingTab,
  }) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: _DesignTokens.primary,
      backgroundColor: _DesignTokens.surface,
      displacement: 20,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: orders.isEmpty
            ? _buildEmptyState(isPendingTab)
            : _buildList(orders),
      ),
    );
  }

  Widget _buildEmptyState(bool isPendingTab) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          key: const ValueKey('empty_state'),
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
              minWidth: constraints.maxWidth,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Layered icon with rings
                SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer ring
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          color: _DesignTokens.primary.withOpacity(0.04),
                          shape: BoxShape.circle,
                        ),
                      ),
                      // Mid ring
                      Container(
                        width: 98,
                        height: 98,
                        decoration: BoxDecoration(
                          color: _DesignTokens.primary.withOpacity(0.07),
                          shape: BoxShape.circle,
                        ),
                      ),
                      // Icon container
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: _DesignTokens.surface,
                          shape: BoxShape.circle,
                          boxShadow: _DesignTokens.cardShadow,
                        ),
                        child: Center(
                          child: Icon(
                            isPendingTab
                                ? Icons.assignment_turned_in_rounded
                                : Icons.history_rounded,
                            size: 30,
                            color: _DesignTokens.primary.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  isPendingTab ? "All caught up!" : "No past orders",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _DesignTokens.textPrimary,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 52),
                  child: Text(
                    isPendingTab
                        ? "New reservations will appear here in real-time."
                        : "Completed, cancelled, and expired orders will show up here.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _DesignTokens.textSecondary,
                      fontSize: 14,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildList(List<QueryDocumentSnapshot> orders) {
    return ListView.builder(
      key: const ValueKey('list_state'),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.only(left: 16, right: 16, top: 18, bottom: 110),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final orderDoc = orders[index];
        final data = orderDoc.data() as Map<String, dynamic>;
        return _AnimatedOrderCard(
          key: ValueKey(orderDoc.id),
          index: index,
          child: _buildOrderCard(context, orderDoc.id, data),
        );
      },
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    String orderId,
    Map<String, dynamic> data,
  ) {
    final String buyerName = data['buyerName'] ?? 'Customer';
    final String status = data['status'] ?? 'pending';
    final String otp = data['otp'] ?? '';
    final double totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final List<dynamic> items = data['items'] ?? [];

    DateTime createdAt = DateTime.now();
    String formattedDate = "Just now";
    if (data['createdAt'] != null) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
      formattedDate = DateFormat('MMM dd • h:mm a').format(createdAt);
    }

    DateTime? expiryTime;
    if (data['expiryTime'] != null) {
      expiryTime = (data['expiryTime'] as Timestamp).toDate();
    }

    String displayStatus = status;
    if (status == 'pending' &&
        expiryTime != null &&
        DateTime.now().isAfter(expiryTime)) {
      displayStatus = 'expired';
    }

    final _StatusConfig statusConfig = _StatusConfig.from(displayStatus);

    final String initials = buyerName.isNotEmpty
        ? buyerName.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : 'C';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _DesignTokens.cardSurface,
        borderRadius: BorderRadius.circular(_DesignTokens.radiusXL),
        boxShadow: _DesignTokens.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_DesignTokens.radiusXL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status accent strip
            Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    statusConfig.color.withOpacity(0.6),
                    statusConfig.color.withOpacity(0.1),
                  ],
                ),
              ),
            ),

            // Header
            _buildCardHeader(
              buyerName: buyerName,
              initials: initials,
              formattedDate: formattedDate,
              statusConfig: statusConfig,
              displayStatus: displayStatus,
              expiryTime: expiryTime,
            ),

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey.withOpacity(0.08),
              ),
            ),

            // Alerts
            if ((displayStatus == 'cancelled' || displayStatus == 'expired') &&
                data['cancelReason'] != null)
              _buildCancelReasonBanner(
                data['cancelReason'],
                isExpired: displayStatus == 'expired',
              ),

            if (displayStatus == 'cancelled') _buildRefundBanner(),

            // Items
            _buildItemsList(items),

            // Footer
            _buildCardFooter(
              context: context,
              orderId: orderId,
              data: data,
              displayStatus: displayStatus,
              expiryTime: expiryTime,
              createdAt: createdAt,
              otp: otp,
              buyerName: buyerName,
              totalAmount: totalAmount,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardHeader({
    required String buyerName,
    required String initials,
    required String formattedDate,
    required _StatusConfig statusConfig,
    required String displayStatus,
    required DateTime? expiryTime,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Row(
        children: [
          // Avatar
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _DesignTokens.primary.withOpacity(0.12),
                  _DesignTokens.primary.withOpacity(0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: _DesignTokens.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Name & date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  buyerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _DesignTokens.textPrimary,
                    letterSpacing: -0.3,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 11,
                      color: _DesignTokens.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _DesignTokens.textMuted,
                      ),
                    ),
                  ],
                ),
                if (displayStatus == 'pending' && expiryTime != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 11,
                        color: _DesignTokens.pending.withOpacity(0.8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        () {
                          final now = DateTime.now();
                          final isToday = expiryTime.year == now.year &&
                              expiryTime.month == now.month &&
                              expiryTime.day == now.day;
                          return isToday
                              ? "Expires today at ${DateFormat('h:mm a').format(expiryTime)}"
                              : "Expires on ${DateFormat('MMM dd').format(expiryTime)} at ${DateFormat('h:mm a').format(expiryTime)}";
                        }(),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _DesignTokens.pending.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Status badge
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusConfig.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: statusConfig.color.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusConfig.icon, size: 10, color: statusConfig.color),
                const SizedBox(width: 5),
                Text(
                  statusConfig.label,
                  style: TextStyle(
                    color: statusConfig.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelReasonBanner(String reason, {required bool isExpired}) {
    final Color bannerColor = isExpired ? _DesignTokens.expired : _DesignTokens.pending;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(_DesignTokens.radiusMD),
        border: Border.all(
          color: bannerColor.withOpacity(0.18),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: bannerColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isExpired ? Icons.timer_off_rounded : Icons.info_outline_rounded,
              color: bannerColor,
              size: 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpired ? "EXPIRATION NOTICE" : "CANCELLATION REASON",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: bannerColor,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  reason,
                  style: TextStyle(
                    fontSize: 13,
                    color: _DesignTokens.textPrimary.withOpacity(0.75),
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefundBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _DesignTokens.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(_DesignTokens.radiusSM),
        border: Border.all(
          color: _DesignTokens.primary.withOpacity(0.18),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 15,
            color: _DesignTokens.primary,
          ),
          const SizedBox(width: 10),
          Text(
            "REFUND INITIATED",
            style: TextStyle(
              color: _DesignTokens.primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: _DesignTokens.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "Processing",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _DesignTokens.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(List<dynamic> items) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(_DesignTokens.radiusMD),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "ORDER ITEMS",
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: _DesignTokens.textMuted,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _DesignTokens.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "${items.length}",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: _DesignTokens.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            final isLast = i == items.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _DesignTokens.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${item['cartQuantity']}×",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: _DesignTokens.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item['name'],
                      style: const TextStyle(
                        color: _DesignTokens.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCardFooter({
    required BuildContext context,
    required String orderId,
    required Map<String, dynamic> data,
    required String displayStatus,
    required DateTime? expiryTime,
    required DateTime createdAt,
    required String otp,
    required String buyerName,
    required double totalAmount,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Total amount
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TOTAL AMOUNT",
                      style: TextStyle(
                        fontSize: 9,
                        color: _DesignTokens.textMuted,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "₹${totalAmount % 1 == 0 ? totalAmount.toStringAsFixed(0) : totalAmount.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: _DesignTokens.textPrimary,
                        letterSpacing: -0.8,
                        height: 1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Verify OTP button
              if (displayStatus == 'pending')
                _VerifyOTPButton(
                  onTap: () =>
                      _showVerifyOTPDialog(context, orderId, otp, buyerName),
                ),
            ],
          ),

          // Cancel timer row
          if (displayStatus == 'pending' && expiryTime != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OrderCancellationTimer(
                  createdAt: createdAt,
                  expiryTime: expiryTime,
                  onCancel: () => _showCancelOrderDialog(
                    context,
                    orderId,
                    buyerName,
                    data['buyerId'] ?? '',
                    data['shopName'] ?? 'Seller',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Status Config ─────────────────────────────────────────────────────────────
class _StatusConfig {
  final Color color;
  final String label;
  final IconData icon;

  const _StatusConfig({
    required this.color,
    required this.label,
    required this.icon,
  });

  factory _StatusConfig.from(String status) {
    switch (status) {
      case 'completed':
        return const _StatusConfig(
          color: _DesignTokens.primary,
          label: 'COMPLETED',
          icon: Icons.check_circle_rounded,
        );
      case 'cancelled':
        return const _StatusConfig(
          color: _DesignTokens.cancelled,
          label: 'CANCELLED',
          icon: Icons.cancel_rounded,
        );
      case 'expired':
        return const _StatusConfig(
          color: _DesignTokens.expired,
          label: 'EXPIRED',
          icon: Icons.timer_off_rounded,
        );
      default:
        return const _StatusConfig(
          color: _DesignTokens.pending,
          label: 'PENDING',
          icon: Icons.pending_rounded,
        );
    }
  }
}

// ── Animated Verify OTP Button ────────────────────────────────────────────────
class _VerifyOTPButton extends StatefulWidget {
  final VoidCallback onTap;

  const _VerifyOTPButton({required this.onTap});

  @override
  State<_VerifyOTPButton> createState() => _VerifyOTPButtonState();
}

class _VerifyOTPButtonState extends State<_VerifyOTPButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.93,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _pressed = true);
        _controller.reverse();
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        _controller.forward();
        widget.onTap();
      },
      onTapCancel: () {
        setState(() => _pressed = false);
        _controller.forward();
      },
      child: ScaleTransition(
        scale: _controller,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _DesignTokens.primary,
                Color.lerp(_DesignTokens.primary, Colors.teal, 0.2)!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(_DesignTokens.radiusSM),
            boxShadow: [
              BoxShadow(
                color: _DesignTokens.primary.withOpacity(_pressed ? 0.15 : 0.35),
                blurRadius: _pressed ? 6 : 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_user_rounded,
                size: 16,
                color: Colors.white,
              ),
              SizedBox(width: 8),
              Text(
                "VERIFY OTP",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.7,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Animated Order Card Entry ─────────────────────────────────────────────────
class _AnimatedOrderCard extends StatefulWidget {
  final Widget child;
  final int index;

  const _AnimatedOrderCard({
    super.key,
    required this.child,
    required this.index,
  });

  @override
  State<_AnimatedOrderCard> createState() => _AnimatedOrderCardState();
}

class _AnimatedOrderCardState extends State<_AnimatedOrderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _scale = Tween<double>(begin: 0.97, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(
      Duration(milliseconds: 55 * widget.index.clamp(0, 8)),
      () {
        if (mounted) _controller.forward();
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: SlideTransition(
          position: _slide,
          child: widget.child,
        ),
      ),
    );
  }
}

// ── Order Cancellation Timer ──────────────────────────────────────────────────
class OrderCancellationTimer extends StatefulWidget {
  final DateTime createdAt;
  final VoidCallback onCancel;
  final DateTime? expiryTime;

  const OrderCancellationTimer({
    super.key,
    required this.createdAt,
    required this.onCancel,
    this.expiryTime,
  });

  @override
  State<OrderCancellationTimer> createState() => _OrderCancellationTimerState();
}

class _OrderCancellationTimerState extends State<OrderCancellationTimer> {
  Timer? _timer;
  late Duration _cancelRemaining;
  bool _canCancel = false;

  @override
  void initState() {
    super.initState();
    _calculateRemainingTime();
    if (_canCancel) _startTimer();
  }

  void _calculateRemainingTime() {
    final now = DateTime.now();

    if (widget.expiryTime != null && now.isAfter(widget.expiryTime!)) {
      _canCancel = false;
      _cancelRemaining = Duration.zero;
      return;
    }

    final timeSinceCreated = now.difference(widget.createdAt);
    if (timeSinceCreated.inSeconds < 300) {
      _canCancel = true;
      _cancelRemaining = const Duration(minutes: 5) - timeSinceCreated;
    } else {
      _canCancel = false;
      _cancelRemaining = Duration.zero;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _calculateRemainingTime();
          if (!_canCancel) timer.cancel();
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_canCancel) return const SizedBox.shrink();

    final minutes =
        (_cancelRemaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds =
        (_cancelRemaining.inSeconds % 60).toString().padLeft(2, '0');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _DesignTokens.cancelled.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            "$minutes:$seconds",
            style: TextStyle(
              color: _DesignTokens.cancelled.withOpacity(0.8),
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: widget.onCancel,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _DesignTokens.cancelled.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _DesignTokens.cancelled.withOpacity(0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.close_rounded,
                  size: 13,
                  color: _DesignTokens.cancelled.withOpacity(0.85),
                ),
                const SizedBox(width: 5),
                Text(
                  "CANCEL",
                  style: TextStyle(
                    color: _DesignTokens.cancelled.withOpacity(0.85),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}