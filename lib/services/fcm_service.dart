import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:food_now/services/user_service.dart';

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
      } else {
        print('User declined or has not accepted permission');
      }
    } catch (e) {
      print("Error initializing FCM: $e");
    }
  }
}
