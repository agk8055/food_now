import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveUser({
    required User user,
    String role = 'buyer',
    Position? position,
    String? address,
  }) async {
    try {
      // Check if user already exists to avoid overwriting existing data (like role if manually changed)
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'userId': user.uid,
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'phone': '', // Default empty as per request
          'role': role,
          'profileImage': user.photoURL ?? '',
          'location': {
            'lat': position?.latitude ?? 0.0,
            'lng': position?.longitude ?? 0.0,
            'address': address ?? '',
          },
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // If user exists, maybe update location?
        // For now, let's only update if location is provided, but keep other fields intact
        if (position != null || address != null) {
          await _firestore.collection('users').doc(user.uid).update({
            'location': {
              'lat':
                  position?.latitude ??
                  userDoc.data()?['location']?['lat'] ??
                  0.0,
              'lng':
                  position?.longitude ??
                  userDoc.data()?['location']?['lng'] ??
                  0.0,
              'address':
                  address ?? userDoc.data()?['location']?['address'] ?? '',
            },
          });
        }
      }
    } catch (e) {
      print("Error saving user: $e");
      rethrow;
    }
  }

  Future<String?> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data()?['role'] as String?;
      }
    } catch (e) {
      print("Error fetching user role: $e");
    }
    return null;
  }

  Stream<DocumentSnapshot> getUserStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  Future<void> updateUser({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
    } catch (e) {
      print("Error updating user: $e");
      rethrow;
    }
  }

  Future<DocumentSnapshot?> getShop(String uid) async {
    try {
      final query = await _firestore
          .collection('shops')
          .where('ownerId', isEqualTo: uid)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return query.docs.first;
      }
      return null;
    } catch (e) {
      print("Error fetching shop: $e");
      return null;
    }
  }

  Future<void> updateFcmToken(String uid, String token) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error updating FCM token: $e");
    }
  }
}
