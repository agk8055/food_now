import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_now/services/user_service.dart';

class SellerAnalyticsScreen extends StatefulWidget {
  const SellerAnalyticsScreen({super.key});

  @override
  State<SellerAnalyticsScreen> createState() => _SellerAnalyticsScreenState();
}

class _SellerAnalyticsScreenState extends State<SellerAnalyticsScreen> {
  late Future<DocumentSnapshot?> _shopFuture;
  final _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    if (_user != null) {
      _shopFuture = UserService().getShop(_user!.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const Center(child: Text("Not Authenticated"));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Analytics & Impact", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: false,
      ),
      body: FutureBuilder<DocumentSnapshot?>(
        future: _shopFuture,
        builder: (context, shopSnapshot) {
          if (shopSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00bf63)));
          }
          if (!shopSnapshot.hasData || shopSnapshot.data == null) {
            return const Center(child: Text("Error loading shop details."));
          }

          final String shopId = shopSnapshot.data!.id;

          // Fetch only COMPLETED orders to calculate earnings
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('shopId', isEqualTo: shopId)
                .where('status', isEqualTo: 'completed')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFF00bf63)));
              }

              final docs = snapshot.data?.docs ?? [];
              
              // --- CALCULATE METRICS ---
              double totalEarnings = 0;
              int totalItemsSaved = 0;
              int totalOrders = docs.length;

              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                totalEarnings += (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
                
                final items = data['items'] as List<dynamic>? ?? [];
                for (var item in items) {
                  totalItemsSaved += (item['cartQuantity'] as int?) ?? 0;
                }
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Total Earnings Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00bf63), Color(0xFF009e52)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF00bf63).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Total Revenue",
                            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "₹${totalEarnings.toStringAsFixed(0)}",
                            style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8)
                                ),
                                child: const Icon(Icons.trending_up, color: Colors.white, size: 16),
                              ),
                              const SizedBox(width: 8),
                              const Text("Lifetime Earnings", style: TextStyle(color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    const Text("Impact Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    // 2. Metrics Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: "Food Saved",
                            value: "$totalItemsSaved",
                            unit: "Items",
                            icon: Icons.fastfood_rounded,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMetricCard(
                            title: "Orders",
                            value: "$totalOrders",
                            unit: "Completed",
                            icon: Icons.check_circle_rounded,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    const Text("Recent Performance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    // 3. Recent Activity List (Simplified)
                    if (docs.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text("No completed orders yet.", style: TextStyle(color: Colors.grey[400])),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length > 5 ? 5 : docs.length, // Show only last 5
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final double amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
                          final String buyerName = data['buyerName'] ?? 'Customer';
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.withOpacity(0.1)),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey[100],
                                child: const Icon(Icons.receipt, color: Colors.grey),
                              ),
                              title: Text(buyerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: const Text("Order Completed"),
                              trailing: Text(
                                "+₹$amount",
                                style: const TextStyle(color: Color(0xFF00bf63), fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          );
        }
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          Text("$unit $title", style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}