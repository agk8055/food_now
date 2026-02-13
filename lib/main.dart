import 'package:flutter/material.dart';
import 'package:food_now/screens/home_screen.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:food_now/firebase_options.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_now/services/user_service.dart';
import 'package:food_now/screens/admin_dashboard.dart';
import 'package:food_now/screens/seller_dashboard.dart';
import 'package:food_now/screens/seller_registration_screen.dart';
import 'package:food_now/screens/shop_rejected_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Now',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          primary: const Color(0xFF4CAF50),
        ),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final User user = snapshot.data!;
          return FutureBuilder<String?>(
            future: UserService().getUserRole(user.uid),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final role = roleSnapshot.data;
              if (role == 'admin') {
                return const AdminDashboard();
              } else if (role == 'seller') {
                return FutureBuilder<DocumentSnapshot?>(
                  future: UserService().getShop(user.uid),
                  builder: (context, shopSnapshot) {
                    if (shopSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final shopDoc = shopSnapshot.data;

                    if (shopDoc == null) {
                      // Case 1: No shop
                      return const SellerRegistrationScreen();
                    }

                    final data = shopDoc.data() as Map<String, dynamic>;
                    final status = data['verificationStatus'];

                    if (status == 'rejected') {
                      // Case 3: Rejected
                      return const ShopRejectedScreen();
                    }

                    // Case 2: Exists (Pending/Approved)
                    return const SellerDashboard();
                  },
                );
              } else {
                // Default to HomeScreen for buyers or unknown roles
                return const HomeScreen();
              }
            },
          );
        }

        // Not logged in
        return const HomeScreen();
      },
    );
  }
}
