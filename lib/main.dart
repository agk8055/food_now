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
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:food_now/services/location_service.dart';
import 'package:food_now/screens/not_serviceable_screen.dart';

// Global Navigator Key to handle routing from background notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  bool isServiceable = await _checkServiceability();

  runApp(MyApp(isServiceable: isServiceable));
}

Future<bool> _checkServiceability() async {
  try {
    GeoPoint? userLocation;
    final User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data();

        if (data?['role'] == 'admin' || data?['role'] == 'seller') {
          return true;
        }

        final location = data?['location'] as Map<String, dynamic>?;
        if (location != null && location['geopoint'] != null) {
          userLocation = location['geopoint'] as GeoPoint;
        }
      }
    }

    if (userLocation == null) {
      final prefs = await SharedPreferences.getInstance();
      final double? lat = prefs.getDouble('cached_geopoint_lat');
      final double? lon = prefs.getDouble('cached_geopoint_lon');
      if (lat != null && lon != null) {
        userLocation = GeoPoint(lat, lon);
      }
    }

    if (userLocation == null) {
      final locationService = LocationService();
      final position = await locationService.getCurrentPosition();
      if (position != null) {
        userLocation = GeoPoint(position.latitude, position.longitude);
      }
    }

    if (userLocation == null) {
      return true;
    }

    final shopsSnapshot = await FirebaseFirestore.instance
        .collection('shops')
        .where('verificationStatus', isEqualTo: 'approved')
        .get();

    for (var doc in shopsSnapshot.docs) {
      final data = doc.data();
      final location = data['location'] as Map<String, dynamic>?;
      if (location != null && location['geopoint'] != null) {
        final GeoPoint shopPoint = location['geopoint'] as GeoPoint;
        final double distance = Geolocator.distanceBetween(
          userLocation.latitude,
          userLocation.longitude,
          shopPoint.latitude,
          shopPoint.longitude,
        );

        if (distance <= 10000) {
          return true;
        }
      }
    }

    return false;
  } catch (e) {
    debugPrint("Error checking serviceability: $e");
    return true;
  }
}

class MyApp extends StatelessWidget {
  final bool isServiceable;
  const MyApp({super.key, required this.isServiceable});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Now',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // Attach the global key here
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00bf63),
          primary: const Color(0xFF00bf63),
        ),
        useMaterial3: true,
      ),
      home: isServiceable ? const AuthWrapper() : const NotServiceableScreen(),
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
                return const SellerRegistrationScreen();
              }

              final data = shopDoc.data() as Map<String, dynamic>;
              final status = data['verificationStatus'];

              if (status == 'rejected') {
                return const ShopRejectedScreen();
              }

              return const SellerDashboard();
            },
          );
        } else {
          return const HomeScreen();
        }
      },
    );
  }
}
