import 'package:flutter/material.dart';
import 'package:food_now/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_now/services/user_service.dart';
import 'package:food_now/screens/login_screen.dart';

// Modular screens and widget
import 'package:food_now/widgets/seller_bottom_navigation_bar.dart';
import 'package:food_now/screens/seller_orders_screen.dart';
import 'package:food_now/screens/seller_inventory_screen.dart';
import 'package:food_now/screens/seller_analytics_screen.dart';
import 'package:food_now/screens/seller_profile_screen.dart';

class SellerDashboard extends StatefulWidget {
  const SellerDashboard({super.key});

  @override
  State<SellerDashboard> createState() => _SellerDashboardState();
}

class _SellerDashboardState extends State<SellerDashboard> {
  int _selectedIndex = 0;
  
  // 1. Declare a Future variable
  late Future<DocumentSnapshot?> _shopFuture;
  final _user = AuthService().currentUser;

  // List of our modular screens
  final List<Widget> _screens = const [
    SellerOrdersScreen(),
    SellerInventoryScreen(),
    SellerAnalyticsScreen(),
    SellerProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // 2. Initialize the future exactly once in initState
    if (_user != null) {
      _shopFuture = UserService().getShop(_user.uid);
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Backup logout for users stuck on the "Pending" screen
  Future<void> _handleEmergencyLogout(BuildContext context) async {
    await AuthService().signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(body: Center(child: Text("Not Authenticated")));
    }

    return FutureBuilder<DocumentSnapshot?>(
      future: _shopFuture, // 3. Use the cached future here
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Color(0xFF00bf63))),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(body: Center(child: Text("No Shop Found")));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final status = data['verificationStatus'];

        if (status == 'pending') {
          // Pending screen UI
          return Scaffold(
            appBar: AppBar(
              title: const Text("Seller Dashboard"),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => _handleEmergencyLogout(context),
                ),
              ],
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.hourglass_empty,
                      size: 80,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Verification Pending",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Your shop is currently under review by our admin team. You will be notified once it is approved.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else if (status == 'approved') {
          // Render the new Navigation Structure
          return Scaffold(
            // 4. Use IndexedStack to preserve the state of each page when switching tabs
            body: IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
            bottomNavigationBar: SellerBottomNavigationBar(
              selectedIndex: _selectedIndex,
              onItemTapped: _onItemTapped,
            ),
          );
        } else {
          return Scaffold(body: Center(child: Text("Status: $status")));
        }
      },
    );
  }
}