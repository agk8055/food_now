import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_now/services/auth_service.dart';
import 'package:food_now/screens/login_screen.dart';
import '../widgets/custom_loader.dart';

class SellerProfileScreen extends StatefulWidget {
  const SellerProfileScreen({super.key});

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;

  // Toggle Shop Availability
  Future<void> _toggleShopStatus(String shopId, bool currentStatus) async {
    await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
      'isOpen': !currentStatus,
    });
  }

  // Edit Shop Details Dialog (Restricted fields)
  void _showEditShopDialog(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Pre-fill controllers
    final nameController = TextEditingController(text: data['shopName']);
    final addressController = TextEditingController(
      text: data['location']?['address'] ?? '',
    );
    final emailController = TextEditingController(
      text: data['publicEmail'] ?? _user?.email ?? '',
    );
    final imageController = TextEditingController(
      text: (data['images'] as List?)?.first ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Edit Shop Details"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Shop Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: "Public Contact Email",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: "Address",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: imageController,
                decoration: const InputDecoration(
                  labelText: "Image URL",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              // Update specific fields only
              await FirebaseFirestore.instance
                  .collection('shops')
                  .doc(doc.id)
                  .update({
                    'shopName': nameController.text.trim(),
                    'publicEmail': emailController.text.trim(),
                    'location.address': addressController.text
                        .trim(), // Dot notation to update nested field
                    'images': [imageController.text.trim()],
                  });
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00bf63),
            ),
            child: const Text(
              "SAVE CHANGES",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const Center(child: Text("Not Authenticated"));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          "Shop Profile",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: () async {
              await AuthService().signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shops')
            .where('ownerId', isEqualTo: _user.uid)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CustomLoader());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Shop profile not found."));
          }

          final doc = snapshot.data!.docs.first;
          final data = doc.data() as Map<String, dynamic>;

          final String shopName = data['shopName'] ?? "My Shop";
          final String category = data['category'] ?? "General";
          final String address =
              data['location']?['address'] ?? "No address set";
          final String publicEmail =
              data['publicEmail'] ?? _user.email ?? "No email";
          final String imageUrl = (data['images'] as List?)?.isNotEmpty == true
              ? data['images'][0]
              : "";
          final bool isOpen = data['isOpen'] ?? true;

          return SingleChildScrollView(
            child: Column(
              children: [
                // 1. Header Section with Image
                Stack(
                  children: [
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        image: imageUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(imageUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: imageUrl.isEmpty
                          ? Icon(Icons.store, size: 80, color: Colors.grey[400])
                          : Container(
                              color: Colors.black.withOpacity(0.3),
                            ), // Dark overlay
                    ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shopName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(color: Colors.black54, blurRadius: 10),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00bf63),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              category
                                  .toUpperCase(), // Category displayed but not editable
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.black),
                          onPressed: () => _showEditShopDialog(context, doc),
                        ),
                      ),
                    ),
                  ],
                ),

                // 2. Status Toggle
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: SwitchListTile(
                    title: const Text(
                      "Accepting Orders",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isOpen
                          ? "Your shop is currently VISIBLE"
                          : "Your shop is currently HIDDEN",
                    ),
                    activeThumbColor: const Color(0xFF00bf63),
                    value: isOpen,
                    onChanged: (val) => _toggleShopStatus(doc.id, isOpen),
                    secondary: Icon(
                      isOpen ? Icons.check_circle : Icons.do_not_disturb_on,
                      color: isOpen ? const Color(0xFF00bf63) : Colors.grey,
                    ),
                  ),
                ),

                // 3. Details List
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      _buildInfoTile(
                        Icons.location_on_outlined,
                        "Address",
                        address,
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildInfoTile(
                        Icons.email_outlined,
                        "Public Email",
                        publicEmail,
                      ),
                      const Divider(height: 1, indent: 56),
                      _buildInfoTile(
                        Icons.verified_user_outlined,
                        "Shop ID",
                        doc.id,
                        isCopyable: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                TextButton(
                  onPressed: () async {
                    await AuthService().signOut();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  },
                  child: const Text(
                    "Sign Out",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoTile(
    IconData icon,
    String title,
    String subtitle, {
    bool isCopyable = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.black54, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 16, color: Colors.black87),
      ),
      trailing: isCopyable
          ? const Icon(Icons.copy, size: 16, color: Colors.grey)
          : null,
    );
  }
}
