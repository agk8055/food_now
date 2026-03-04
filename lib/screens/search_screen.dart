import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/custom_loader.dart';
import '../widgets/shop_card.dart';
import 'shop_menu_screen.dart';

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

  // Helper method for Zomato-style "starts with" / word boundary search
  bool _matchesSearch(String text, String query) {
    if (query.isEmpty) return true;
    final t = text.toLowerCase();
    final q = query.toLowerCase();
    
    // Returns true if the word starts with the query 
    // OR if any subsequent word starts with the query (indicated by a space)
    return t.startsWith(q) || t.contains(' $q');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
              hintText: "Search for restaurants, food...",
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.grey),
            ),
            onChanged: (value) {
              setState(() {
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
          bottom: const TabBar(
            labelColor: Color(0xFF00bf63),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF00bf63),
            tabs: [
              Tab(text: "Restaurants"),
              Tab(text: "Food Items"),
            ],
          ),
        ),
        body: _searchQuery.isEmpty 
            ? _buildInitialState() 
            : TabBarView(
                children: [
                  _buildShopSearchResults(),
                  _buildFoodSearchResults(),
                ],
              ),
      ),
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

  // 1. Shop Search Logic with updated word boundary check
  Widget _buildShopSearchResults() {
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
          return _buildNoResults("No matching restaurants found.");
        }

        final queryLower = _searchQuery.toLowerCase();

        final results = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final shopName = (data['shopName'] ?? '').toString();
          final category = (data['category'] ?? '').toString();

          // Replaced .contains with _matchesSearch
          return _matchesSearch(shopName, queryLower) ||
                 _matchesSearch(category, queryLower);
        }).toList();

        if (results.isEmpty) {
          return _buildNoResults("No matching restaurants found.");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final doc = results[index];
            final data = doc.data() as Map<String, dynamic>;
            return ShopCard(
              shopId: doc.id,
              data: data,
              isCompact: true,
              defaultIcon: Icons.restaurant,
              defaultCategory: "Restaurant",
            );
          },
        );
      },
    );
  }

  // 2. Food Search Logic with updated word boundary check
  Widget _buildFoodSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('food_items')
          .where('isSoldOut', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CustomLoader());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoResults("No matching food found.");
        }

        final queryLower = _searchQuery.toLowerCase();

        final results = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final itemName = (data['name'] ?? '').toString();
          
          // Replaced .contains with _matchesSearch
          return _matchesSearch(itemName, queryLower);
        }).toList();

        if (results.isEmpty) {
          return _buildNoResults("No matching food found.");
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final doc = results[index];
            final data = doc.data() as Map<String, dynamic>;
            
            return _buildFoodItemCard(context, data);
          },
        );
      },
    );
  }

  // Card design specifically for food items
  Widget _buildFoodItemCard(BuildContext context, Map<String, dynamic> data) {
    final String shopId = data['shopId'] ?? '';
    final String shopName = data['shopName'] ?? 'Unknown Shop';
    final String imageUrl = data['imageUrl'] ?? '';

    return GestureDetector(
      onTap: () {
        if (shopId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ShopMenuScreen(
                shopId: shopId,
                shopName: shopName,
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      height: 80,
                      width: 80,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      height: 80,
                      width: 80,
                      color: Colors.grey[200],
                      child: const Icon(Icons.fastfood, color: Colors.grey),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data['name'] ?? 'Unknown Item',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "From: $shopName",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        "₹${data['discountedPrice']}",
                        style: const TextStyle(
                          color: Color(0xFF00bf63),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "₹${data['originalPrice']}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                          decoration: TextDecoration.lineThrough,
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
    );
  }

  Widget _buildNoResults(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            message,
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
}