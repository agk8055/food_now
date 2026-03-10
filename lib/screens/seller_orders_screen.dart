import 'package:flutter/material.dart';
import '../widgets/custom_loader.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_now/services/user_service.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  late Future<DocumentSnapshot?> _shopFuture;
  final _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    if (_user != null) {
      _shopFuture = UserService().getShop(_user.uid);
    }
  }

  void _showCancelOrderDialog(
    BuildContext context,
    String orderId,
    String buyerName,
    String buyerId,
    String shopName,
  ) {
    final TextEditingController reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Cancel Order",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Are you sure you want to cancel $buyerName's order? This action cannot be undone.",
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Reason for Cancellation",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: "e.g. Item out of stock",
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Colors.redAccent,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Please enter a reason";
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "BACK",
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final String reason = reasonController.text.trim();
                  try {
                    await FirebaseFirestore.instance
                        .collection('orders')
                        .doc(orderId)
                        .update({
                          'status': 'cancelled',
                          'cancelReason': reason,
                          'cancelledAt': FieldValue.serverTimestamp(),
                        });

                    if (context.mounted) {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context);
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text("Order Cancelled successfully."),
                          backgroundColor: Color(0xFF00bf63),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text("Error cancelling order: $e"),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "CANCEL ORDER",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showVerifyOTPDialog(
    BuildContext context,
    String orderId,
    String correctOtp,
    String buyerName,
  ) {
    final TextEditingController otpController = TextEditingController();
    bool isError = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                "Verify Pickup",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Enter the 4-digit code from $buyerName's app to complete this order.",
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 32,
                      letterSpacing: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: "0000",
                      counterText: "",
                      errorText: isError
                          ? "Incorrect OTP. Please try again."
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF00bf63),
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (val) {
                      if (isError) setState(() => isError = false);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "CANCEL",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (otpController.text == correctOtp) {
                      FirebaseFirestore.instance
                          .collection('orders')
                          .doc(orderId)
                          .update({'status': 'completed'});
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("✅ Order Verified & Completed!"),
                          backgroundColor: Color(0xFF00bf63),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      setState(() => isError = true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00bf63),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "VERIFY",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Show the Global Scanner Screen ---
  void _openGlobalQRScanner(BuildContext context, String shopId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _GlobalQRScannerScreen(shopId: shopId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const Center(child: Text("Not Authenticated"));

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
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('shopId', isEqualTo: shopId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, orderSnapshot) {
              if (orderSnapshot.hasError) {
                return Scaffold(
                  body: Center(child: Text('Error: ${orderSnapshot.error}')),
                );
              }
              if (orderSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CustomLoader()));
              }

              final docs = orderSnapshot.data?.docs ?? [];

              final pendingOrders = docs.where((doc) {
                final status =
                    (doc.data() as Map<String, dynamic>)['status'] ?? 'pending';
                return status == 'pending';
              }).toList();

              final completedOrders = docs.where((doc) {
                final status =
                    (doc.data() as Map<String, dynamic>)['status'] ?? 'pending';
                return status == 'completed' || status == 'cancelled';
              }).toList();

              return Scaffold(
                backgroundColor: const Color(0xFFF8F9FA),
                appBar: AppBar(
                  title: const Text(
                    "Orders & Pickups",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  backgroundColor: Colors.white,
                  elevation: 0.5,
                  centerTitle: false,
                  bottom: const TabBar(
                    labelColor: Color(0xFF00bf63),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Color(0xFF00bf63),
                    tabs: [
                      Tab(text: "Pending Pickup"),
                      Tab(text: "Completed / Past"),
                    ],
                  ),
                ),
                body: TabBarView(
                  children: [
                    _buildOrderList(pendingOrders, isPendingTab: true),
                    _buildOrderList(completedOrders, isPendingTab: false),
                  ],
                ),
                // --- Global Scanner FAB ---
                floatingActionButton: FloatingActionButton.extended(
                  onPressed: () => _openGlobalQRScanner(context, shopId),
                  backgroundColor: const Color(0xFF00bf63),
                  elevation: 4,
                  icon: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                  ),
                  label: const Text(
                    "SCAN QR",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                floatingActionButtonLocation:
                    FloatingActionButtonLocation.centerFloat,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildOrderList(
    List<QueryDocumentSnapshot> orders, {
    required bool isPendingTab,
  }) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPendingTab
                  ? Icons.assignment_turned_in_outlined
                  : Icons.history,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              isPendingTab ? "No active orders" : "No past orders",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isPendingTab
                  ? "New reservations will appear here."
                  : "Completed and cancelled orders appear here.",
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 80,
      ), // Padding for FAB
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final orderDoc = orders[index];
        final data = orderDoc.data() as Map<String, dynamic>;
        return _buildOrderCard(context, orderDoc.id, data);
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

    String formattedDate = "Just now";
    if (data['createdAt'] != null) {
      final DateTime date = (data['createdAt'] as Timestamp).toDate();
      formattedDate = DateFormat('MMM dd • hh:mm a').format(date);
    }

    Color statusColor;
    String statusText;
    if (status == 'completed') {
      statusColor = const Color(0xFF00bf63);
      statusText = "COMPLETED";
    } else if (status == 'cancelled') {
      statusColor = Colors.redAccent;
      statusText = "CANCELLED";
    } else {
      statusColor = Colors.orange;
      statusText = "PENDING";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(
                          0xFF00bf63,
                        ).withOpacity(0.1),
                        child: const Icon(
                          Icons.person,
                          color: Color(0xFF00bf63),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              buyerName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFEEEEEE)),

          if (status == 'cancelled' && data['cancelReason'] != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "REASON FOR CANCELLATION",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.orange,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data['cancelReason'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[800],
                            height: 1.4,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          if (status == 'cancelled')
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF00bf63).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF00bf63).withOpacity(0.1),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.currency_rupee_rounded,
                    size: 14,
                    color: Color(0xFF00bf63),
                  ),
                  SizedBox(width: 8),
                  Text(
                    "REFUND INITIATED",
                    style: TextStyle(
                      color: Color(0xFF00bf63),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    children: [
                      Text(
                        "${item['cartQuantity']}x",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item['name'],
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Action Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "Total: ₹$totalAmount",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (status == 'pending')
                      ElevatedButton.icon(
                        onPressed: () => _showVerifyOTPDialog(
                          context,
                          orderId,
                          otp,
                          buyerName,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00bf63),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        icon: const Icon(
                          Icons.verified_user_outlined,
                          color: Colors.white,
                          size: 16,
                        ),
                        label: const Text(
                          "VERIFY OTP",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                if (status == 'pending' && data['createdAt'] != null) ...[
                  const SizedBox(height: 8),
                  CancellationTimer(
                    createdAt: (data['createdAt'] as Timestamp).toDate(),
                    onExpired: () {},
                    onCancel: () => _showCancelOrderDialog(
                      context,
                      orderId,
                      buyerName,
                      data['buyerId'] ?? '',
                      data['shopName'] ?? 'Seller',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- The NEW Global Camera Scanner Screen ---
class _GlobalQRScannerScreen extends StatefulWidget {
  final String shopId;

  const _GlobalQRScannerScreen({required this.shopId});

  @override
  State<_GlobalQRScannerScreen> createState() => _GlobalQRScannerScreenState();
}

class _GlobalQRScannerScreenState extends State<_GlobalQRScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _isProcessing = false;

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("❌ $message"),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
    // Allow scanning again after a brief pause
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isProcessing = false);
    });
  }

  void _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.startsWith("foodnow_pickup:")) {
        setState(() => _isProcessing = true);

        final parts = rawValue.split(":");
        if (parts.length == 3) {
          final String orderId = parts[1];
          final String scannedOtp = parts[2];

          try {
            final doc = await FirebaseFirestore.instance
                .collection('orders')
                .doc(orderId)
                .get();

            if (!doc.exists) {
              _showError("Order not found in database.");
              return;
            }

            final data = doc.data() as Map<String, dynamic>;

            if (data['shopId'] != widget.shopId) {
              _showError("This order belongs to a different shop.");
              return;
            }

            if (data['status'] == 'completed') {
              _showError("This order is already completed.");
              return;
            }

            if (data['status'] == 'cancelled') {
              _showError("This order was cancelled.");
              return;
            }

            if (data['otp'] != scannedOtp) {
              _showError("Invalid OTP in QR code.");
              return;
            }

            // All checks passed! Mark as completed.
            await FirebaseFirestore.instance
                .collection('orders')
                .doc(orderId)
                .update({'status': 'completed'});

            if (mounted) {
              Navigator.pop(context); // Close scanner
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("✅ Order Verified & Completed!"),
                  backgroundColor: Color(0xFF00bf63),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (e) {
            _showError("Error verifying order: $e");
          }
        } else {
          _showError("Invalid QR Code Format.");
        }
        break; // Stop loop after processing the first matching QR
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Scan Pickup QR",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(controller: controller, onDetect: _handleBarcode),
          // Simple scanning overlay
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF00bf63), width: 4),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Center the QR code in the box",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(child: CustomLoader()),
            ),
        ],
      ),
    );
  }
}

class CancellationTimer extends StatefulWidget {
  final DateTime createdAt;
  final VoidCallback onExpired;
  final VoidCallback onCancel;

  const CancellationTimer({
    super.key,
    required this.createdAt,
    required this.onExpired,
    required this.onCancel,
  });

  @override
  State<CancellationTimer> createState() => _CancellationTimerState();
}

class _CancellationTimerState extends State<CancellationTimer> {
  Timer? _timer;
  late Duration _remainingTime;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _calculateRemainingTime();
    if (!_isExpired) {
      _startTimer();
    }
  }

  void _calculateRemainingTime() {
    final expiryTime = widget.createdAt.add(const Duration(minutes: 5));
    _remainingTime = expiryTime.difference(DateTime.now());
    if (_remainingTime.isNegative) {
      _remainingTime = Duration.zero;
      _isExpired = true;
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _calculateRemainingTime();
          if (_isExpired) {
            timer.cancel();
            widget.onExpired();
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
    if (_isExpired) {
      return const SizedBox(
        width: double.infinity,
        child: Text(
          "cancellation expired",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    final minutes = _remainingTime.inMinutes.toString().padLeft(2, '0');
    final seconds = (_remainingTime.inSeconds % 60).toString().padLeft(2, '0');

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: widget.onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
            icon: const Icon(Icons.cancel_outlined, size: 16),
            label: const Text(
              "CANCEL ORDER",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
          ),
          child: Text(
            "$minutes:$seconds",
            style: const TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}
