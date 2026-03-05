import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
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
  late Razorpay _razorpay;
  
  // TODO: Replace with your actual backend URL (e.g., https://your-food-app.onrender.com)
  final String backendUrl = "https://backend-food-now.onrender.com"; 

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _startPaymentProcess() async {
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

    try {
      // 1. Create order on the backend
      final response = await http.post(
        Uri.parse('$backendUrl/api/payment/create-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': widget.totalAmount,
          'receipt': 'rcpt_${DateTime.now().millisecondsSinceEpoch}'
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // 2. Launch Razorpay Checkout
          var options = {
            'key': data['key_id'],
            'amount': data['amount'], 
            'currency': data['currency'],
            'name': 'Food Now',
            'description': 'Order from ${widget.shopName}',
            'order_id': data['order_id'],
            'prefill': {
              'contact': user.phoneNumber ?? '',
              'email': user.email ?? ''
            },
            'theme': {
              'color': '#00bf63' // Matches your app's primary color
            }
          };
          
          _razorpay.open(options);
        } else {
          _showErrorSnackBar("Failed to create order: ${data['error']}");
          setState(() => _isProcessing = false);
        }
      } else {
        _showErrorSnackBar("Server error: ${response.statusCode}");
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      _showErrorSnackBar("Network error: $e");
      setState(() => _isProcessing = false);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    // Payment was successful on client, now verify and save via backend
    try {
      final user = FirebaseAuth.instance.currentUser!;
      
      final verifyResponse = await http.post(
        Uri.parse('$backendUrl/api/payment/verify-payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'razorpay_order_id': response.orderId,
          'razorpay_payment_id': response.paymentId,
          'razorpay_signature': response.signature,
          'buyerId': user.uid,                     // Changed to buyerId
          'buyerName': user.displayName ?? "Buyer",// Added
          'shopId': widget.shopId,
          'shopName': widget.shopName,             // Added
          'items': widget.cartItems,
          'totalAmount': widget.totalAmount,
        }),
      );
      final data = jsonDecode(verifyResponse.body);
      
      if (verifyResponse.statusCode == 200 && data['success'] == true) {
        // Backend successfully verified signature, saved order, and updated stock
        if (mounted) {
          _showSuccessDialog(data['pickupCode']);
        }
      } else {
        _showErrorSnackBar("Verification failed: ${data['error']}");
      }
    } catch (e) {
      _showErrorSnackBar("Error completing order: $e");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _showErrorSnackBar("Payment Failed: ${response.message}");
    setState(() => _isProcessing = false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showErrorSnackBar("External Wallet Selected: ${response.walletName}");
    setState(() => _isProcessing = false);
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccessDialog(String pickupCode) {
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
                pickupCode,
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
                        Icons.security,
                        color: Color(0xFF00bf63),
                      ),
                      title: const Text("Pay securely via Razorpay"),
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
                  onPressed: _isProcessing ? null : _startPaymentProcess,
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