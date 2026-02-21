import 'package:flutter/material.dart';
import '../widgets/custom_loader.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_now/screens/seller_add_item_screen.dart';

class SellerInventoryScreen extends StatelessWidget {
  const SellerInventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Professional off-white
      appBar: AppBar(
        title: const Text(
          "Kitchen Inventory",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: const Color(0xFF00bf63).withOpacity(0.1),
              child: const Icon(
                Icons.restaurant_menu,
                color: Color(0xFF00bf63),
                size: 20,
              ),
            ),
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text("Not Authenticated"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('food_items')
                  .where('sellerId', isEqualTo: user.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Center(child: Text('Error: ${snapshot.error}'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CustomLoader());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final item = doc.data() as Map<String, dynamic>;
                    final int quantity = item['quantity'] ?? 0;
                    final String? imageUrl = item['imageUrl'];

                    return _buildInventoryCard(
                      context,
                      item,
                      doc.id,
                      quantity,
                      imageUrl,
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SellerAddItemScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xFF00bf63),
        elevation: 2,
        icon: const Icon(Icons.add_box_rounded, color: Colors.white),
        label: const Text(
          "ADD NEW ITEM",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryCard(
    BuildContext context,
    Map<String, dynamic> item,
    String docId,
    int quantity,
    String? imageUrl,
  ) {
    Color statusColor = const Color(0xFF00bf63); // Default Green
    String statusText = "IN STOCK";

    if (quantity == 0) {
      statusColor = Colors.redAccent;
      statusText = "OUT OF STOCK";
    } else if (quantity < 5) {
      statusColor = Colors.orangeAccent;
      statusText = "LOW STOCK";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[100],
                    child: (imageUrl != null && imageUrl.isNotEmpty)
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholderIcon(),
                          )
                        : _buildPlaceholderIcon(),
                  ),
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name']?.toUpperCase() ?? 'UNKNOWN ITEM',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Expires: ${item['expiryDate']} | ${item['expiryTime']}",
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            "₹${item['discountedPrice']}",
                            style: const TextStyle(
                              color: Color(0xFF00bf63),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "₹${item['originalPrice']}",
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 13,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
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
                    const SizedBox(height: 8),
                    Text(
                      "$quantity",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        height: 1,
                      ),
                    ),
                    const Text(
                      "UNITS",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => _showEditDialog(context, docId, item),
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: Color(0xFF00bf63),
                  ),
                  label: const Text(
                    "EDIT STOCK / PRICE",
                    style: TextStyle(
                      color: Color(0xFF00bf63),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _confirmDelete(context, docId),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.redAccent,
                  ),
                  label: const Text(
                    "REMOVE",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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

  void _showEditDialog(
    BuildContext context,
    String docId,
    Map<String, dynamic> item,
  ) {
    final TextEditingController stockController = TextEditingController(
      text: item['quantity'].toString(),
    );
    final TextEditingController priceController = TextEditingController(
      text: item['discountedPrice'].toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Edit ${item['name']}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Available Stock (Units)",
                prefixIcon: Icon(Icons.inventory_2_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Discounted Price (₹)",
                prefixIcon: Icon(Icons.currency_rupee),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('food_items')
                  .doc(docId)
                  .update({
                    'quantity':
                        int.tryParse(stockController.text) ?? item['quantity'],
                    'discountedPrice':
                        double.tryParse(priceController.text) ??
                        item['discountedPrice'],
                  });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00bf63),
            ),
            child: const Text(
              "UPDATE",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return const Icon(
      Icons.fastfood_rounded,
      color: Color(0xFFBDBDBD),
      size: 30,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "Inventory is Empty",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Start listing items to see them here.",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String docId) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Remove Item?"),
        content: const Text(
          "This action will immediately stop buyers from seeing this surplus listing.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('food_items')
                  .doc(docId)
                  .delete();
              Navigator.pop(context);
            },
            child: const Text(
              "CONFIRM REMOVAL",
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
