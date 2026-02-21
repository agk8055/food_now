import 'package:flutter/material.dart';
import 'package:food_now/widgets/custom_loader.dart';
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
import 'package:food_now/services/fcm_service.dart';

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
          seedColor: const Color(0xFF00bf63),
          primary: const Color(0xFF00bf63),
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
          return const Scaffold(body: Center(child: CustomLoader()));
        }

        if (snapshot.hasData && snapshot.data != null) {
          final User user = snapshot.data!;
          return AuthenticatedUserHandler(key: ValueKey(user.uid), user: user);
        }

        // Not logged in
        return const HomeScreen();
      },
    );
  }
}

class AuthenticatedUserHandler extends StatefulWidget {
  final User user;
  const AuthenticatedUserHandler({super.key, required this.user});

  @override
  State<AuthenticatedUserHandler> createState() =>
      _AuthenticatedUserHandlerState();
}

class _AuthenticatedUserHandlerState extends State<AuthenticatedUserHandler> {
  @override
  void initState() {
    super.initState();
    FcmService().initialize(widget.user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: UserService().getUserRole(widget.user.uid),
      builder: (context, roleSnapshot) {
        if (roleSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CustomLoader()));
        }

        final role = roleSnapshot.data;
        if (role == 'admin') {
          return const AdminDashboard();
        } else if (role == 'seller') {
          return FutureBuilder<DocumentSnapshot?>(
            future: UserService().getShop(widget.user.uid),
            builder: (context, shopSnapshot) {
              if (shopSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CustomLoader()));
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
}
