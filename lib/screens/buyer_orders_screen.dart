import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../widgets/custom_loader.dart';
import 'package:intl/intl.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const Color primary = Color(0xFF00BF63);
  static const Color primaryLight = Color(0xFFE8FAF2);
  static const Color primaryMid = Color(0xFFB8F0D8);
  static const Color bg = Color(0xFFF9FAFB);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF0D1117);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFFB0B7C3);
  static const Color border = Color(0xFFF0F1F3);
  static const Color borderMid = Color(0xFFE5E7EB);
  static const Color cancelRed = Color(0xFFEF4444);
  static const Color cancelRedLight = Color(0xFFFEF2F2);
  static const Color pendingAmber = Color(0xFFF59E0B);
  static const Color pendingAmberLight = Color(0xFFFFFBEB);
}

class BuyerOrdersScreen extends StatelessWidget {
  const BuyerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _C.bg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            automaticallyImplyLeading: false,
            expandedHeight: 110,
            floating: false,
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0.5,
            backgroundColor: _C.surface,
            surfaceTintColor: _C.surface,
            shadowColor: Colors.black.withOpacity(0.06),
            iconTheme: const IconThemeData(color: _C.textPrimary),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 22, bottom: 18, right: 22),
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "YOUR ORDERS",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _C.primary,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Order History",
                          style: TextStyle(
                            color: _C.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _C.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: _C.primary,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: user == null
            ? _buildLoggedOutState()
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('buyerId', isEqualTo: user.uid)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CustomLoader());
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: ListView.builder(
                      key: ValueKey(docs.length),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return _AnimatedOrderCard(
                          data: data,
                          orderId: doc.id,
                          index: index,
                        );
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildLoggedOutState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: _C.primaryLight,
                shape: BoxShape.circle,
                border: Border.all(color: _C.primaryMid, width: 2),
              ),
              child: const Icon(Icons.lock_outline_rounded, size: 36, color: _C.primary),
            ),
            const SizedBox(height: 24),
            const Text(
              "Not Logged In",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: _C.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Please log in to view your orders.",
              style: TextStyle(color: _C.textSecondary, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _C.cancelRedLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, size: 38, color: _C.cancelRed),
            ),
            const SizedBox(height: 20),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _C.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: _C.textSecondary, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: _C.primaryLight,
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _C.primaryMid,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    size: 38,
                    color: _C.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text(
              "No orders yet",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: _C.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "When you reserve surplus food,\nyour orders will appear here.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _C.textSecondary,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Animated Card Wrapper ────────────────────────────────────────────────────
class _AnimatedOrderCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String orderId;
  final int index;

  const _AnimatedOrderCard({
    required this.data,
    required this.orderId,
    required this.index,
  });

  @override
  State<_AnimatedOrderCard> createState() => _AnimatedOrderCardState();
}

class _AnimatedOrderCardState extends State<_AnimatedOrderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: 55 * widget.index), () {
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
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: _OrderCard(data: widget.data, orderId: widget.orderId),
      ),
    );
  }
}

// ─── Order Card ───────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String orderId;

  const _OrderCard({required this.data, required this.orderId});

  void _showQRCode(BuildContext context, String orderId, String otp) {
    final qrData = "foodnow_pickup:$orderId:$otp";

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'QR Code',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 380),
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutExpo);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.88, end: 1.0).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
      pageBuilder: (ctx, _, __) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                color: _C.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: _C.primary.withOpacity(0.12),
                    blurRadius: 60,
                    spreadRadius: -5,
                    offset: const Offset(0, 20),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    decoration: BoxDecoration(
                      color: _C.primaryLight,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: _C.primary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(Icons.qr_code_2_rounded, color: _C.primary, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Pickup QR Code",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _C.textPrimary,
                                letterSpacing: -0.4,
                              ),
                            ),
                            Text(
                              "Show to seller to confirm pickup",
                              style: TextStyle(
                                fontSize: 12,
                                color: _C.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    child: Column(
                      children: [
                        // QR Code — transparent bg, green, rounded
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: _C.primary.withOpacity(0.15),
                                blurRadius: 30,
                                spreadRadius: -5,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: RepaintBoundary(
                              child: QrImageView(
                                data: qrData,
                                version: QrVersions.auto,
                                size: 210.0,
                                backgroundColor: Colors.transparent,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.circle,
                                  color: _C.primary,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.circle,
                                  color: _C.primary,
                                ),
                                semanticsLabel: 'Order QR Code',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // OTP
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: _C.primaryLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _C.primaryMid, width: 1.5),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "ONE-TIME PASSWORD",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: _C.primary.withOpacity(0.6),
                                  letterSpacing: 2.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                otp,
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 10,
                                  color: _C.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Close
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: _C.bg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _C.borderMid),
                            ),
                            child: const Center(
                              child: Text(
                                "CLOSE",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _C.textSecondary,
                                  letterSpacing: 1.8,
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

  @override
  Widget build(BuildContext context) {
    final String shopName = data['shopName'] ?? 'Unknown Shop';
    final String status = data['status'] ?? 'pending';
    final String otp = data['otp'] ?? '----';
    final double totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final List<dynamic> items = data['items'] ?? [];

    String formattedDate = "Just now";
    if (data['createdAt'] != null) {
      final DateTime date = (data['createdAt'] as Timestamp).toDate();
      formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(date);
    }

    // Status config
    Color statusColor;
    Color statusBg;
    String statusText;
    IconData statusIcon;
    if (status == 'completed') {
      statusColor = _C.primary;
      statusBg = _C.primaryLight;
      statusText = "COMPLETED";
      statusIcon = Icons.check_circle_rounded;
    } else if (status == 'cancelled') {
      statusColor = _C.cancelRed;
      statusBg = _C.cancelRedLight;
      statusText = "CANCELLED";
      statusIcon = Icons.cancel_rounded;
    } else {
      statusColor = _C.pendingAmber;
      statusBg = _C.pendingAmberLight;
      statusText = "PENDING PICKUP";
      statusIcon = Icons.access_time_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _C.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: statusColor.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Color accent bar ──
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [statusColor, statusColor.withOpacity(0.3)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),

            // ── Card Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shop icon
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _C.primaryLight,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: _C.primaryMid, width: 1),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: _C.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shopName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: _C.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 11, color: _C.textTertiary),
                            const SizedBox(width: 4),
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: _C.textSecondary,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Status pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 11, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: _C.border, thickness: 1, indent: 18, endIndent: 18),

            // ── Cancellation Reason ──
            if (status == 'cancelled' && data['cancelReason'] != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _C.cancelRedLight,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _C.cancelRed.withOpacity(0.15)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: _C.cancelRed, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "REASON FOR CANCELLATION",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: _C.cancelRed.withOpacity(0.7),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            data['cancelReason'],
                            style: TextStyle(
                              fontSize: 13,
                              color: _C.cancelRed.withOpacity(0.85),
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // ── Refund Notice ──
            if (status == 'cancelled')
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _C.primaryLight,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _C.primaryMid, width: 1),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.currency_rupee_rounded, color: _C.primary, size: 15),
                    SizedBox(width: 8),
                    Text(
                      "REFUND INITIATED",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: _C.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Spacer(),
                    Icon(Icons.check_circle_rounded, color: _C.primary, size: 14),
                  ],
                ),
              ),

            // ── Order Items ──
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _C.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "ORDER ITEMS",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: _C.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...items.asMap().entries.map((entry) {
                    final item = entry.value;
                    final isLast = entry.key == items.length - 1;
                    final String itemName = item['name'] ?? 'Item';
                    final int qty = item['cartQuantity'] ?? 1;
                    return Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 9),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: _C.primaryLight,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: _C.primaryMid, width: 1),
                            ),
                            child: Center(
                              child: Text(
                                "$qty",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: _C.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: _C.textTertiary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              itemName,
                              style: const TextStyle(
                                color: _C.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),

            // ── Footer ──
            Container(
              decoration: BoxDecoration(
                color: _C.bg,
                border: Border(top: BorderSide(color: _C.border, width: 1)),
              ),
              padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
              child: Row(
                children: [
                  // Total
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "TOTAL PAID",
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: _C.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "₹${totalAmount % 1 == 0 ? totalAmount.toInt() : totalAmount}",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                          color: _C.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // QR action for pending
                  if (status == 'pending')
                    Row(
                      children: [
                        // OTP mini display
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              "OTP",
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: _C.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              otp,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                                color: _C.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),

                        // QR Button
                        _QRButton(onTap: () => _showQRCode(context, orderId, otp)),
                      ],
                    ),
                ],
              ),
            ),

            // ── Review Section ──
            if (status == 'completed')
              FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('reviews')
                    .where('orderId', isEqualTo: orderId)
                    .limit(1)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(14),
                      child: Center(
                        child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _C.primary,
                          ),
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const SizedBox();
                  }

                  final reviewData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                  final int rating = reviewData['rating'] ?? 0;
                  final String comment = reviewData['comment'] ?? '';

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: Container(
                      key: ValueKey(orderId),
                      decoration: BoxDecoration(
                        color: _C.surface,
                        border: Border(top: BorderSide(color: _C.border, width: 1)),
                      ),
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 3,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _C.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                "YOUR REVIEW",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                  color: _C.textSecondary,
                                ),
                              ),
                              const Spacer(),
                              Row(
                                children: List.generate(5, (index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 2),
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 200),
                                      child: Icon(
                                        index < rating
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                        key: ValueKey(index < rating),
                                        color: index < rating
                                            ? Colors.amber
                                            : _C.textTertiary,
                                        size: 18,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                          if (comment.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _C.bg,
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(color: _C.border),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.format_quote_rounded,
                                    size: 16,
                                    color: _C.primary.withOpacity(0.4),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      comment,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _C.textSecondary,
                                        fontStyle: FontStyle.italic,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─── QR Button with press feedback ───────────────────────────────────────────
class _QRButton extends StatefulWidget {
  final VoidCallback onTap;
  const _QRButton({required this.onTap});

  @override
  State<_QRButton> createState() => _QRButtonState();
}

class _QRButtonState extends State<_QRButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 110));
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF00BF63), Color(0xFF009A4F)],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _C.primary.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 20),
              SizedBox(width: 7),
              Text(
                "SHOW QR",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: Colors.white,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}