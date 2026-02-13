import 'package:flutter/material.dart';
import 'package:food_now/services/auth_service.dart';
import 'package:food_now/screens/login_screen.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

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

  Future<void> _updateShopStatus(
    BuildContext context,
    String shopId,
    String status,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
        'verificationStatus': status,
        'isVerified': status == 'approved',
      });
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Shop $status successfully')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating shop status: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: const Color(0xFF00bf63),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shops')
            .where('verificationStatus', isEqualTo: 'pending')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No pending applications'));
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: snapshot.data!.docs.map((DocumentSnapshot document) {
              return ShopApplicationCard(
                shopDoc: document,
                onApprove: () =>
                    _updateShopStatus(context, document.id, 'approved'),
                onReject: () =>
                    _updateShopStatus(context, document.id, 'rejected'),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class ShopApplicationCard extends StatelessWidget {
  final DocumentSnapshot shopDoc;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const ShopApplicationCard({
    super.key,
    required this.shopDoc,
    required this.onApprove,
    required this.onReject,
  });

  Future<DocumentSnapshot> _fetchOwnerDetails(String ownerId) {
    return FirebaseFirestore.instance.collection('users').doc(ownerId).get();
  }

  @override
  Widget build(BuildContext context) {
    final shopData = shopDoc.data()! as Map<String, dynamic>;
    final ownerId = shopData['ownerId'] as String?;
    final images = shopData['images'] as List<dynamic>?;
    final String? imageUrl = (images != null && images.isNotEmpty)
        ? images.first as String
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null)
            Image.network(
              imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                height: 200,
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.broken_image, size: 50, color: Colors.grey),
                ),
              ),
            )
          else
            Container(
              height: 150,
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.store, size: 50, color: Colors.grey),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shopData['shopName'] ?? 'Unknown Shop',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(Icons.category, shopData['category'] ?? 'N/A'),
                const SizedBox(height: 4),
                _buildInfoRow(
                  Icons.location_on,
                  shopData['location']?['address'] ?? 'N/A',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Description:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(shopData['description'] ?? 'No description'),
                const Divider(height: 32),
                const Text(
                  'Owner Details:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (ownerId != null)
                  FutureBuilder<DocumentSnapshot>(
                    future: _fetchOwnerDetails(ownerId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const LinearProgressIndicator();
                      }
                      if (snapshot.hasError) {
                        return Text('Error loading owner: ${snapshot.error}');
                      }
                      final userDoc = snapshot.data;
                      if (userDoc == null || !userDoc.exists) {
                        return const Text('Owner not found');
                      }
                      final userData = userDoc.data() as Map<String, dynamic>;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow(
                            Icons.person,
                            userData['name'] ?? 'Unknown',
                          ),
                          const SizedBox(height: 4),
                          _buildInfoRow(
                            Icons.email,
                            userData['email'] ?? 'Unknown',
                          ),
                          const SizedBox(height: 4),
                          _buildInfoRow(
                            Icons.phone,
                            userData['phoneNumber'] ??
                                userData['phone'] ??
                                'N/A',
                          ),
                        ],
                      );
                    },
                  )
                else
                  const Text('No Owner ID found'),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: onReject,
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Reject'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: onApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Approve'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }
}
