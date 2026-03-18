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

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen>
    with TickerProviderStateMixin {
  late Future<DocumentSnapshot?> _shopFuture;
  final _user = FirebaseAuth.instance.currentUser;

  final Color primaryGreen = const Color(0xFF00bf63);
  final Color backgroundLight = const Color(0xFFF4F6F8);

  late AnimationController _fabAnimController;
  late Animation<double> _fabScaleAnim;

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
      duration: const Duration(milliseconds: 600),
    );
    _fabScaleAnim = CurvedAnimation(
      parent: _fabAnimController,
      curve: Curves.elasticOut,
    );
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _fabAnimController.forward();
    });
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
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
        primaryGreen: primaryGreen,
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
        backgroundColor: backgroundLight,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 48,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Not Authenticated",
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot?>(
      future: _shopFuture,
      builder: (context, shopSnapshot) {
        if (shopSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CustomLoader()));
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
            backgroundColor: backgroundLight,
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
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }
                if (orderSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CustomLoader());
                }

                final docs = orderSnapshot.data?.docs ?? [];
                final now = DateTime.now();

                // Sort properly into tabs keeping the real-time expiry checks in mind
                final pendingOrders = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'pending';
                  final expiryTimestamp = data['expiryTime'] as Timestamp?;
                  final isExpired =
                      status == 'pending' &&
                      expiryTimestamp != null &&
                      now.isAfter(expiryTimestamp.toDate());

                  return status == 'pending' && !isExpired;
                }).toList();

                final completedOrders = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'pending';
                  final expiryTimestamp = data['expiryTime'] as Timestamp?;

                  // Ensure dynamically expired orders show in "Completed/Past"
                  final isExpired =
                      status == 'pending' &&
                      expiryTimestamp != null &&
                      now.isAfter(expiryTimestamp.toDate());

                  return status == 'completed' ||
                      status == 'cancelled' ||
                      status == 'expired' ||
                      isExpired;
                }).toList();

                return TabBarView(
                  children: [
                    _buildOrderList(pendingOrders, isPendingTab: true),
                    _buildOrderList(completedOrders, isPendingTab: false),
                  ],
                );
              },
            ),
            floatingActionButton: ScaleTransition(
              scale: _fabScaleAnim,
              child: FloatingActionButton.extended(
                heroTag: 'qr_scanner_fab',
                onPressed: () => _openGlobalQRScanner(context, shopId),
                backgroundColor: primaryGreen,
                elevation: 8,
                highlightElevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                icon: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                label: const Text(
                  "SCAN QR",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            "Orders & Pickups",
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w900,
              fontSize: 21,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: _buildTabBar(),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[100]!, width: 1.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(14),
        ),
        child: TabBar(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[600],
          indicator: BoxDecoration(
            color: primaryGreen,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: primaryGreen.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: 0.2,
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
      color: primaryGreen,
      backgroundColor: Colors.white,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Layered icon container
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 110,
                      width: 110,
                      decoration: BoxDecoration(
                        color: primaryGreen.withOpacity(0.06),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      height: 82,
                      width: 82,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isPendingTab
                          ? Icons.assignment_turned_in_rounded
                          : Icons.history_rounded,
                      size: 36,
                      color: primaryGreen.withOpacity(0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  isPendingTab ? "No active orders" : "No past orders",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey[800],
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    isPendingTab
                        ? "New reservations will appear here."
                        : "Completed and expired orders appear here.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                      height: 1.5,
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
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, top: 20, bottom: 110),
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
      formattedDate = DateFormat('MMM dd • hh:mm a').format(createdAt);
    }

    DateTime? expiryTime;
    if (data['expiryTime'] != null) {
      expiryTime = (data['expiryTime'] as Timestamp).toDate();
    }

    // Dynamic Expiration Check (UI ONLY - Backend handles DB update)
    String displayStatus = status;
    if (status == 'pending' &&
        expiryTime != null &&
        DateTime.now().isAfter(expiryTime)) {
      displayStatus = 'expired';
    }

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (displayStatus == 'completed') {
      statusColor = primaryGreen;
      statusText = "COMPLETED";
      statusIcon = Icons.check_circle_rounded;
    } else if (displayStatus == 'cancelled') {
      statusColor = Colors.redAccent;
      statusText = "CANCELLED";
      statusIcon = Icons.cancel_rounded;
    } else if (displayStatus == 'expired') {
      statusColor = Colors.grey.shade600;
      statusText = "EXPIRED";
      statusIcon = Icons.timer_off_rounded;
    } else {
      statusColor = const Color(0xFFFF9500);
      statusText = "PENDING";
      statusIcon = Icons.pending_rounded;
    }

    final String initials = buyerName.isNotEmpty
        ? buyerName
              .trim()
              .split(' ')
              .map((w) => w[0])
              .take(2)
              .join()
              .toUpperCase()
        : 'C';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ──────────────────────────────────────────────
            _buildCardHeader(
              buyerName: buyerName,
              initials: initials,
              formattedDate: formattedDate,
              statusColor: statusColor,
              statusText: statusText,
              statusIcon: statusIcon,
            ),

            // ── STATUS ALERTS ────────────────────────────────────────
            if ((displayStatus == 'cancelled' || displayStatus == 'expired') &&
                data['cancelReason'] != null)
              _buildCancelReasonBanner(
                data['cancelReason'],
                isExpired: displayStatus == 'expired',
              ),

            if (displayStatus == 'cancelled') _buildRefundBanner(),

            // ── ITEMS ────────────────────────────────────────────────
            _buildItemsList(items),

            // ── FOOTER ───────────────────────────────────────────────
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
    required Color statusColor,
    required String statusText,
    required IconData statusIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Row(
        children: [
          // Avatar
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryGreen.withOpacity(0.15),
                  primaryGreen.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: primaryGreen.withOpacity(0.15),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: primaryGreen,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
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
                    color: Colors.black87,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Status badge
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: statusColor.withOpacity(0.25),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusIcon, size: 11, color: statusColor),
                const SizedBox(width: 5),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isExpired ? Colors.grey.shade100 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpired ? Colors.grey.shade300 : Colors.orange.shade200,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isExpired ? Colors.grey.shade300 : Colors.orange.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isExpired ? Icons.timer_off_rounded : Icons.info_rounded,
              color: isExpired ? Colors.grey.shade700 : Colors.orange.shade700,
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
                    color: isExpired
                        ? Colors.grey.shade700
                        : Colors.orange.shade700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  reason,
                  style: TextStyle(
                    fontSize: 14,
                    color: isExpired ? Colors.black87 : Colors.orange.shade900,
                    height: 1.45,
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: primaryGreen.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryGreen.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 16, color: primaryGreen),
          const SizedBox(width: 10),
          Text(
            "REFUND INITIATED",
            style: TextStyle(
              color: primaryGreen,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "Processing",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(List<dynamic> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "ORDER ITEMS",
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Colors.grey[500],
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 9.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${item['cartQuantity']}×",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item['name'],
                      style: const TextStyle(
                        color: Colors.black87,
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
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              // Total amount
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TOTAL",
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "₹${totalAmount % 1 == 0 ? totalAmount.toStringAsFixed(0) : totalAmount.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Verify OTP button (Only if not expired or completed)
              if (displayStatus == 'pending')
                _VerifyOTPButton(
                  primaryGreen: primaryGreen,
                  onTap: () =>
                      _showVerifyOTPDialog(context, orderId, otp, buyerName),
                ),
            ],
          ),
          // Expiration & Cancellation Section
          if (displayStatus == 'pending' && expiryTime != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  "Expires at ${DateFormat(expiryTime.day == DateTime.now().day && expiryTime.month == DateTime.now().month && expiryTime.year == DateTime.now().year ? 'hh:mm a' : 'MMM dd, hh:mm a').format(expiryTime)}",
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
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

// ── Animated Verify OTP Button ────────────────────────────────────────────────
class _VerifyOTPButton extends StatefulWidget {
  final Color primaryGreen;
  final VoidCallback onTap;

  const _VerifyOTPButton({required this.primaryGreen, required this.onTap});

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
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.94,
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.primaryGreen,
                Color.lerp(widget.primaryGreen, Colors.teal, 0.25)!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: widget.primaryGreen.withOpacity(_pressed ? 0.2 : 0.4),
                blurRadius: _pressed ? 8 : 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_user_rounded, size: 17, color: Colors.white),
              SizedBox(width: 8),
              Text(
                "VERIFY OTP",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.6,
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _controller.forward();
    });
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
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ── Order Cancellation Timer ──────────────────────────────────────────
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
          if (!_canCancel) {
            timer.cancel();
          }
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

    final minutes = (_cancelRemaining.inMinutes % 60).toString().padLeft(
      2,
      '0',
    );
    final seconds = (_cancelRemaining.inSeconds % 60).toString().padLeft(
      2,
      '0',
    );
    final timeString = "$minutes:$seconds";

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timeString,
          style: TextStyle(
            color: Colors.redAccent.withOpacity(0.7),
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 10),
        OutlinedButton.icon(
          onPressed: widget.onCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: BorderSide(
              color: Colors.redAccent.withOpacity(0.4),
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            backgroundColor: Colors.redAccent.withOpacity(0.03),
          ),
          icon: const Icon(Icons.cancel_outlined, size: 16),
          label: const Text(
            "CANCEL",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}
