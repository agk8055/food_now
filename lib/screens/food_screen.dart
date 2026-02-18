import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'shop_menu_screen.dart';

class FoodScreen extends StatelessWidget {
  const FoodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Restaurants",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shops')
            .where('verificationStatus', isEqualTo: 'approved')
            // Removed 'isOpen' filter so we can see closed shops too
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00bf63)),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No restaurants found nearby."));
          }

          // Filter out Supermarkets on client side to avoid index issues with 'isNotEqualTo'
          final shops = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['category'] != 'Supermarket';
          }).toList();

          if (shops.isEmpty) {
            return const Center(child: Text("No restaurants found nearby."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: shops.length,
            itemBuilder: (context, index) {
              final shop = shops[index];
              final data = shop.data() as Map<String, dynamic>;
              final images = data['images'] as List<dynamic>?;

              // Check if shop is open (default to true if field is missing)
              final bool isOpen = data['isOpen'] ?? true;

              return GestureDetector(
                onTap: isOpen
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ShopMenuScreen(
                              shopId: shop.id,
                              shopName: data['shopName'],
                            ),
                          ),
                        );
                      }
                    : null, // Disable tap if closed
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  foregroundDecoration: isOpen
                      ? null
                      : BoxDecoration(
                          color: Colors.grey.withOpacity(
                            0.1,
                          ), // Subtle grey overlay
                          borderRadius: BorderRadius.circular(15),
                        ),
                  child: ColorFiltered(
                    // This applies the Black & White effect
                    colorFilter: isOpen
                        ? const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.multiply,
                          ) // Normal
                        : const ColorFilter.matrix(<double>[
                            0.2126,
                            0.7152,
                            0.0722,
                            0,
                            0,
                            0.2126,
                            0.7152,
                            0.0722,
                            0,
                            0,
                            0.2126,
                            0.7152,
                            0.0722,
                            0,
                            0,
                            0,
                            0,
                            0,
                            1,
                            0,
                          ]), // Grayscale Matrix
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(15),
                                ),
                                child: (images != null && images.isNotEmpty)
                                    ? Image.network(
                                        images.first,
                                        height: 180,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        height: 180,
                                        color: Colors.grey[200],
                                        child: const Icon(
                                          Icons.restaurant,
                                          size: 50,
                                          color: Colors.grey,
                                        ),
                                      ),
                              ),
                              // "CLOSED" Badge Overlay
                              if (!isOpen)
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black.withOpacity(0.4),
                                    alignment: Alignment.center,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        "TEMPORARILY CLOSED",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      data['shopName'],
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (isOpen)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green[50],
                                          borderRadius: BorderRadius.circular(
                                            5,
                                          ),
                                        ),
                                        child: Text(
                                          "★ ${data['rating'] ?? '4.0'}",
                                          style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  data['category'] ?? "Restaurant",
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: Color(0xFF00bf63),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        data['location']?['address'] ??
                                            "Address not available",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
