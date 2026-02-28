import 'package:flutter/material.dart';
import '../widgets/custom_loader.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_now/services/user_service.dart';
import 'package:intl/intl.dart';

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
                      // Update status to completed
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

        // Wrap everything in DefaultTabController
        return DefaultTabController(
          length: 2, // Two tabs: Pending & Completed
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

              // Filter orders into two lists
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
                    // Tab 1: Pending Orders
                    _buildOrderList(pendingOrders, isPendingTab: true),

                    // Tab 2: Completed/Past Orders
                    _buildOrderList(completedOrders, isPendingTab: false),
                  ],
                ),
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
      padding: const EdgeInsets.all(16),
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
          // Header
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

          // Items
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
            child: Row(
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
                    onPressed: () =>
                        _showVerifyOTPDialog(context, orderId, otp, buyerName),
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
          ),
        ],
      ),
    );
  }
}
