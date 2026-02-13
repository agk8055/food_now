import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'checkout_screen.dart';

class ShopMenuScreen extends StatefulWidget {
  final String shopId;
  final String shopName;

  const ShopMenuScreen({
    super.key,
    required this.shopId,
    required this.shopName,
  });

  @override
  State<ShopMenuScreen> createState() => _ShopMenuScreenState();
}

class _ShopMenuScreenState extends State<ShopMenuScreen> {
  // Cart maps Item ID to a Map of item details including selected quantity
  final Map<String, Map<String, dynamic>> _cart = {};
  
  // 1. Declare a Stream variable
  late Stream<QuerySnapshot> _foodItemsStream;

  @override
  void initState() {
    super.initState();
    // 2. Initialize the stream exactly once here
    _foodItemsStream = FirebaseFirestore.instance
        .collection('food_items')
        .where('shopId', isEqualTo: widget.shopId)
        .where('isSoldOut', isEqualTo: false)
        .snapshots();
  }

  void _updateCart(DocumentSnapshot doc, int change) {
    final item = doc.data() as Map<String, dynamic>;
    final id = doc.id;

    setState(() {
      if (_cart.containsKey(id)) {
        _cart[id]!['cartQuantity'] += change;
        if (_cart[id]!['cartQuantity'] <= 0) {
          _cart.remove(id); // Remove if quantity drops to 0
        }
      } else if (change > 0) {
        _cart[id] = {
          'itemId': id,
          'name': item['name'],
          'price': (item['discountedPrice'] as num).toDouble(),
          'cartQuantity': 1,
        };
      }
    });
  }

  int _getTotalItems() {
    return _cart.values.fold(0, (sum, item) => sum + (item['cartQuantity'] as int));
  }

  double _getTotalPrice() {
    return _cart.values.fold(0.0, (sum, item) => sum + ((item['price'] as double) * (item['cartQuantity'] as int)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.shopName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _foodItemsStream, // 3. Use the cached stream here
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF00bf63)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No items available right now."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80), // Space for cart bar
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final item = doc.data() as Map<String, dynamic>;
                    final int currentQty = _cart[doc.id]?['cartQuantity'] ?? 0;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'],
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "₹${item['discountedPrice']}",
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Expires: ${item['expiryDate']} at ${item['expiryTime']}",
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 110,
                            height: 120, 
                            child: Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: (item['imageUrl'] != null && item['imageUrl'] != "")
                                      ? Image.network(
                                          item['imageUrl'],
                                          width: 110,
                                          height: 105,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          width: 110,
                                          height: 105,
                                          color: Colors.grey[100],
                                          child: const Icon(Icons.fastfood, color: Colors.grey),
                                        ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  child: Container(
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey.shade300),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ],
                                    ),
                                    child: currentQty == 0
                                        ? InkWell(
                                            onTap: () => _updateCart(doc, 1),
                                            child: Container(
                                              width: 90,
                                              alignment: Alignment.center,
                                              child: const Text(
                                                "ADD",
                                                style: TextStyle(
                                                  color: Color(0xFF00bf63),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.remove, color: Colors.black54, size: 18),
                                                onPressed: () => _updateCart(doc, -1),
                                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                padding: EdgeInsets.zero,
                                              ),
                                              Text(
                                                "$currentQty",
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.add, color: Color(0xFF00bf63), size: 18),
                                                onPressed: () => _updateCart(doc, 1),
                                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                padding: EdgeInsets.zero,
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          if (_cart.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))],
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${_getTotalItems()} ITEM${_getTotalItems() > 1 ? 'S' : ''}", style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                        Text("₹${_getTotalPrice()}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CheckoutScreen(
                              shopId: widget.shopId,
                              shopName: widget.shopName,
                              cartItems: _cart.values.toList(),
                              totalAmount: _getTotalPrice(),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00bf63),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text("Next ➔", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}