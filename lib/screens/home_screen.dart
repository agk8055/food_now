import 'package:flutter/material.dart';
import 'package:food_now/screens/profile_screen.dart';
import 'package:food_now/widgets/bottom_navigation_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  // List of screens for navigation
  // Using a method to build screens to access context if needed, or simple list
  static final List<Widget> _screens = <Widget>[
    const HomeBody(), // Extracted Home content
    const Center(child: Text("Food Screen Placeholder")), // Placeholder
    const Center(child: Text("Supermart Screen Placeholder")), // Placeholder
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // Only show AppBar on Home Screen for now, or customize per screen
      appBar: _selectedIndex == 0 ? _buildAppBar() : null,
      body: _screens[_selectedIndex],
      bottomNavigationBar: CustomBottomNavigationBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF4CAF50), // Main Green
      elevation: 0,
      titleSpacing: 0,
      toolbarHeight: 80,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                const Text(
                  "Food Now",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                const Spacer(),

                InkWell(
                  onTap: () {
                    // Navigate to profile tab
                    setState(() {
                      _selectedIndex = 3;
                    });
                  },
                  child: const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person_outline, color: Color(0xFF4CAF50)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              "Kochi, Kerala 682022, India",
              style: TextStyle(fontSize: 12, color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class HomeBody extends StatelessWidget {
  const HomeBody({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 16),
          _buildPromoBanner(),
          const SizedBox(height: 24),
          _buildCategoryGrid(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              "FEATURED FOR YOU",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Placeholder for Featured section (bottom part of image)
          Container(
            height: 150,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              image: const DecorationImage(
                image: NetworkImage(
                  'https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?auto=format&fit=crop&q=80&w=1000',
                ), // Placeholder
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 80), // Space for bottom nav
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: const Color(0xFF4CAF50), // Extend app bar color
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            SizedBox(width: 16),
            Icon(Icons.search, color: Colors.grey),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "search for restaurants,supermarkets and...",
                style: TextStyle(color: Colors.grey),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.mic, color: Color(0xFF4CAF50)), // Green Mic
            SizedBox(width: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      height: 220, // Increased height to prevent overflow
      decoration: BoxDecoration(
        color: const Color(0xFF66BB6A), // Lighter green gradient start
        gradient: const LinearGradient(
          colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Content
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 30),
                const SizedBox(height: 12),
                const Text(
                  "SAVE FOOD\nSAVE MONEY",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(
                      0xFF1B1B1B,
                    ), // Dark button color
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min, // Shrink to fit text
                    children: [
                      Text("ORDER NOW"),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Circular Image/Graphic on right
          Positioned(
            right: 20,
            top: 30, // Adjust position
            bottom: 30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2), // Circle background
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fastfood,
                    size: 40,
                    color: Colors.orangeAccent,
                  ), // Placeholder icon
                ),
              ),
            ),
          ),
          // 50% OFF Tag
          Positioned(
            right: 20,
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD740), // Yellow
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "50% OFF",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final categories = [
      {
        "title": "FOOD",
        "subtitle": "FROM RESTAURANTS",
        "offer": "UP TO 40% OFF & FREE DEL",
        "offerColor": Colors.red,
        "image":
            "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&q=80&w=200", // Salad/Food
      },
      {
        "title": "SUPERMART",
        "subtitle": "GET ANYTHING INSTANTLY",
        "offer": "UP TO ₹100 OFF",
        "offerColor": Colors.red,
        "image":
            "https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&q=80&w=200", // Grocery
      },
      {
        "title": "BAKERY & CAFE",
        "subtitle": "FRESH BREAD & PASTRIES",
        "offer": "UP TO 50% OFF",
        "offerColor": Colors.red,
        "image":
            "https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&q=80&w=200", // Bakery
      },
      {
        "title": "CATERING",
        "subtitle": "DISCOVER NEARBY",
        "offer": "SURPLUS SPECIALS",
        "offerColor": const Color(0xFF4CAF50), // Green for this one
        "image":
            "https://images.unsplash.com/photo-1555244162-803834f70033?auto=format&fit=crop&q=80&w=200", // Catering/Venue
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GridView.builder(
        shrinkWrap: true, // Important for using inside SingleChildScrollView
        physics:
            const NeverScrollableScrollPhysics(), // Disable internal scrolling
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8, // Adjust for height vs width
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final item = categories[index];
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'] as String,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['subtitle'] as String,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['offer'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: item['offerColor'] as Color,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    alignment: Alignment.bottomRight,
                    padding: const EdgeInsets.only(bottom: 12, right: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        item['image'] as String,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
