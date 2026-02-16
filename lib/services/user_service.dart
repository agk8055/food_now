import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'location_service.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveUser({
    required User user,
    String role = 'buyer',
    Position? position,
    String? address,
    String? name,
    String? phone,
    String? profileImage,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      final Map<String, dynamic> data = {
        'userId': user.uid,
        'email': user.email ?? '',
        // Only set role if it's not already there? Or maybe just overwrite it?
        // Since we are explicitly creating/saving a user, we should probably set it.
        // But if an admin changes a role, we don't want to overwrite it on next login.
        // Let's set it only if it doesn't exist or if we want to enforce it.
        // For now, let's set it if not present in existing data, or valid 'role' arg is passed for new registration.
      };

      if (!userDoc.exists || userDoc.data()?['createdAt'] == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }

      if (!userDoc.exists) {
        data['role'] = role;
      } else {
        // If doc exists, don't overwrite role unless we specifically want to (maybe add a forceUpdateRole flag later if needed).
        // For this issue, we just want to ensure profile data is saved.
        if (role != 'buyer') {
          // If we are registering as seller, we assume we want to be seller.
          // But 'buyer' is default.
        }
        // Let's trusting the passed role if it is 'seller' or 'admin', otherwise keep existing?
        // Actually, for simplicity and to fix the "missing role" issue on new account creation (even if partial doc exists),
        // we should set the role if the current doc doesn't have one or we are essentially "initializing" the user.
        // Let's set role if it is missing in the doc.
        if (userDoc.data()?['role'] == null) {
          data['role'] = role;
        }
      }

      // Update checks
      if (name != null && name.isNotEmpty) {
        data['name'] = name;
      } else if (!userDoc.exists || userDoc.data()?['name'] == null) {
        // Fallback to auth name if not provided and not in doc
        data['name'] = user.displayName ?? '';
      }

      if (phone != null && phone.isNotEmpty) {
        data['phone'] = phone;
      } else if (!userDoc.exists || userDoc.data()?['phone'] == null) {
        // Fallback?
        data['phone'] = '';
      }

      if (profileImage != null && profileImage.isNotEmpty) {
        data['profileImage'] = profileImage;
      } else if (!userDoc.exists || userDoc.data()?['profileImage'] == null) {
        data['profileImage'] = user.photoURL ?? '';
      }

      // Always update location if provided
      if (position != null || address != null) {
        final double lat =
            position?.latitude ??
            userDoc.data()?['location']?['geopoint']?.latitude ??
            0.0;
        final double lng =
            position?.longitude ??
            userDoc.data()?['location']?['geopoint']?.longitude ??
            0.0;

        final LocationService locationService = LocationService();
        final String geohash = locationService.getGeohash(lat, lng);

        data['location'] = {
          'geohash': geohash,
          'geopoint': GeoPoint(lat, lng),
          'address': address ?? userDoc.data()?['location']?['address'] ?? '',
        };
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));
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

  Future<bool> hasFcmToken(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists && doc.data()?['fcmToken'] != null;
    } catch (e) {
      print("Error checking FCM token: $e");
      return false;
    }
  }
}
