import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:food_now/services/user_service.dart';
import 'package:food_now/main.dart'; // Import navigatorKey
import 'package:food_now/screens/shop_menu_screen.dart'; // Target navigation screen
import 'package:food_now/screens/buyer_orders_screen.dart'; // Added Buyer Orders Screen

class FcmService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final UserService _userService = UserService();

  Future<void> initialize(String uid) async {
    try {
      // Request permission for notifications
      NotificationSettings settings = await _firebaseMessaging
          .requestPermission(alert: true, badge: true, sound: true);

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted permission');

        // Get the token
        String? token = await _firebaseMessaging.getToken();
        if (token != null) {
          print("FCM Token: $token");
          await _userService.updateFcmToken(uid, token);
        }

        // Listen for token refreshes
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          print("FCM Token Refreshed: $newToken");
          _userService.updateFcmToken(uid, newToken);
        });

        // --- Notification Click Listeners ---

        // 1. App is in the background and opened via notification tap
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          _handleNotificationClick(message);
        });

        // 2. App is completely terminated and opened via notification tap
        FirebaseMessaging.instance.getInitialMessage().then((
          RemoteMessage? message,
        ) {
          if (message != null) {
            _handleNotificationClick(message);
          }
        });
      } else {
        print('User declined or has not accepted permission');
      }
    } catch (e) {
      print("Error initializing FCM: $e");
    }
  }

  // Handle routing based on the data payload from the backend
  void _handleNotificationClick(RemoteMessage message) {
    if (message.data.containsKey('type')) {
      final String type = message.data['type'];

      if (type == 'favorite_food_alert') {
        final String? shopId = message.data['shopId'];
        // Extract shopName from payload, provide a fallback just in case
        final String shopName = message.data['shopName'] ?? 'Favorite Shop';

        // Navigate to the Shop Menu Screen if we have a valid context and shopId
        if (shopId != null && navigatorKey.currentState != null) {
          navigatorKey.currentState!.push(
            MaterialPageRoute(
              builder: (context) => ShopMenuScreen(
                shopId: shopId,
                shopName: shopName, // <-- NOW PASSING BOTH REQUIRED PARAMETERS
              ),
            ),
          );
        }
      } else if (type == 'order_cancelled') {
        // Navigate to the Buyer Orders screen when a cancellation happens
        if (navigatorKey.currentState != null) {
          navigatorKey.currentState!.push(
            MaterialPageRoute(builder: (context) => const BuyerOrdersScreen()),
          );
        }
      }
    }
  }
}
