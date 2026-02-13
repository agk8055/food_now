import 'package:flutter/material.dart';
import 'package:food_now/services/auth_service.dart';
import 'package:food_now/screens/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_now/services/user_service.dart';

class SellerDashboard extends StatelessWidget {
  const SellerDashboard({super.key});

  Future<void> _handleLogout(BuildContext context) async {
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
    final user = AuthService().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Seller Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text("Not Authenticated"))
          : FutureBuilder<DocumentSnapshot?>(
              future: UserService().getShop(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data == null) {
                  return const Center(child: Text("No Shop Found"));
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;
                final status = data['verificationStatus'];

                if (status == 'pending') {
                  return Center(
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
                  );
                } else if (status == 'approved') {
                  return const Center(
                    child: Text(
                      "Seller Dashboard - Validated & Active",
                      style: TextStyle(fontSize: 18, color: Colors.green),
                      textAlign: TextAlign.center,
                    ),
                  );
                } else {
                  return Center(child: Text("Status: $status"));
                }
              },
            ),
    );
  }
}
