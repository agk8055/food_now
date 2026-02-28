import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_now/screens/shop_menu_screen.dart';
import '../widgets/custom_loader.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Search for restaurants, bakeries...",
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey),
          ),
          onChanged: (value) {
            setState(() {
              // Update the search query state on every keystroke
              _searchQuery = value.trim();
            });
          },
        ),
        actions: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.black),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = "";
                });
              },
            ),
        ],
      ),
      body: _searchQuery.isEmpty ? _buildInitialState() : _buildSearchResults(),
    );
  }

  // Displayed when the user hasn't typed anything yet
  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            "What are you craving today?",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  // Displayed when the user is typing
  Widget _buildSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .where('verificationStatus', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CustomLoader());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoResults();
        }

        final queryLower = _searchQuery.toLowerCase();

        // Filter the shops locally to allow partial text matches starting with the query
        final results = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final shopName = (data['shopName'] ?? '').toString().toLowerCase();
          final category = (data['category'] ?? '').toString().toLowerCase();

          return shopName.startsWith(queryLower) || category.startsWith(queryLower);
        }).toList();

        if (results.isEmpty) {
          return _buildNoResults();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final doc = results[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildShopCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            "No matching restaurants found.",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  // Compact horizontal card layout
  Widget _buildShopCard(String shopId, Map<String, dynamic> data) {
    final images = data['images'] as List<dynamic>?;
    final bool isOpen = data['isOpen'] ?? true;

    return GestureDetector(
      onTap: isOpen
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ShopMenuScreen(
                    shopId: shopId,
                    shopName: data['shopName'],
                  ),
                ),
              );
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        foregroundDecoration: isOpen
            ? null
            : BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
        child: ColorFiltered(
          colorFilter: isOpen
              ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
              : const ColorFilter.matrix(<double>[
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0,      0,      0,      1, 0,
                ]),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Left Side Image
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: (images != null && images.isNotEmpty)
                          ? Image.network(
                              images.first,
                              height: 80,
                              width: 80,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              height: 80,
                              width: 80,
                              color: Colors.grey[200],
                              child: const Icon(
                                Icons.restaurant,
                                size: 30,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                    if (!isOpen)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            "CLOSED",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                
                // 2. Right Side Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              data['shopName'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isOpen)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "★ ${data['rating'] ?? '4.0'}",
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['category'] ?? "Restaurant",
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                              data['location']?['address'] ?? "Address not available",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              maxLines: 1,
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
  }
}