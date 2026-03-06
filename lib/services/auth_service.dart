import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper method to ensure notification settings exist and are true by default
  Future<void> _initializeDefaultSettings(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final docSnap = await docRef.get();

    // If document doesn't exist, or doesn't have notificationSettings, add them.
    // SetOptions(merge: true) ensures we don't overwrite existing preferences.
    if (!docSnap.exists ||
        !(docSnap.data() as Map<String, dynamic>).containsKey(
          'notificationSettings',
        )) {
      await docRef.set({
        'notificationSettings': {
          'favoriteAlerts': true,
          'pickupReminders': true,
          'promotions': true,
        },
      }, SetOptions(merge: true));
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null; // The user canceled the sign-in
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      // Initialize settings for new or existing users
      if (userCredential.user != null) {
        await _initializeDefaultSettings(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      print("Error signing in with Google: $e");
      return null;
    }
  }

  // Sign in with Email and Password
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final UserCredential userCredential = await _auth
        .signInWithEmailAndPassword(email: email, password: password);

    // Initialize settings for existing users missing the field
    if (userCredential.user != null) {
      await _initializeDefaultSettings(userCredential.user!);
    }

    return userCredential;
  }

  // Sign up with Email and Password
  Future<UserCredential?> signUpWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final UserCredential userCredential = await _auth
        .createUserWithEmailAndPassword(email: email, password: password);

    // Initialize settings for new users
    if (userCredential.user != null) {
      await _initializeDefaultSettings(userCredential.user!);
    }

    return userCredential;
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
