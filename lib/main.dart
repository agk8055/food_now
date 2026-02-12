import 'package:flutter/material.dart';
import 'package:food_now/screens/home_screen.dart';
import 'package:food_now/screens/login_screen.dart'; // Import LoginScreen
import 'package:firebase_core/firebase_core.dart';
import 'package:food_now/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            final User? user = snapshot.data;
            if (user == null) {
              return const LoginScreen();
            }
            // User is logged in, check role if needed or go to Home
            // For better UX, we might want to check data in a Splash Screen,
            // but for now, let's assume if logged in, they are a buyer or we handle it in Home
            return const HomeScreen();
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}
