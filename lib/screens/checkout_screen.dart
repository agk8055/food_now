import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/custom_loader.dart';
import 'login_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final String shopId, shopName;
  final List<Map<String, dynamic>> cartItems;
  final double totalAmount;

  const CheckoutScreen({
    super.key,
    required this.shopId,
    required this.shopName,
    required this.cartItems,
    required this.totalAmount,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isProcessing = false;

  Future<void> _placeOrder() async {
    setState(() => _isProcessing = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
      setState(() => _isProcessing = false);
      return;
    }

    String otp = (Random().nextInt(9000) + 1000).toString();

    try {
      // 1. Initialize a Firestore Batch
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final WriteBatch batch = firestore.batch();

      // 2. Create the reference for the new order
      final DocumentReference orderRef = firestore.collection('orders').doc();

      batch.set(orderRef, {
        'buyerId': user.uid,
        'buyerName': user.displayName ?? "Buyer",
        'shopId': widget.shopId,
        'shopName': widget.shopName,
        'items': widget.cartItems,
        'totalAmount': widget.totalAmount,
        'otp': otp,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Loop through cart items and reduce the inventory stock
      for (var item in widget.cartItems) {
        final DocumentReference itemRef = firestore
            .collection('food_items')
            .doc(item['itemId']);

        // Use FieldValue.increment to safely subtract the stock
        batch.update(itemRef, {
          'quantity': FieldValue.increment(-(item['cartQuantity'] as int)),
        });
      }

      // 4. Commit the batch (executes everything at once)
      await batch.commit();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text("Order Reserved!", textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF00bf63),
                  size: 80,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Show this OTP at the restaurant counter to pickup your food:",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    otp,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).popUntil(
                    (route) => route.isFirst,
                  ), // Returns to Home Screen
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF00bf63),
                  ),
                  child: const Text(
                    "GO TO HOME",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Order failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Checkout",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "PICKUP FROM",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.shopName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Bill Summary",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        ...widget.cartItems.map((item) {
                          double itemTotal =
                              item['price'] * item['cartQuantity'];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.stop_circle_outlined,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "${item['name']}  x${item['cartQuantity']}",
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                Text(
                                  "₹$itemTotal",
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          );
                        }),

                        const Divider(height: 32),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "To Pay",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "₹${widget.totalAmount}",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    "PAYMENT METHOD",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const Icon(
                        Icons.account_balance_wallet,
                        color: Color(0xFF00bf63),
                      ),
                      title: const Text("Pay at Counter / Dummy UPI"),
                      trailing: const Icon(
                        Icons.check_circle,
                        color: Color(0xFF00bf63),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _placeOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00bf63),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isProcessing
                      ? const CustomLoader(width: 30, height: 30)
                      : Text(
                          "PAY ₹${widget.totalAmount} & RESERVE",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
