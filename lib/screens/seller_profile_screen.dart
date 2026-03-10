import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_now/services/auth_service.dart';
import 'package:food_now/screens/login_screen.dart';
import 'package:food_now/screens/seller_edit_profile_screen.dart';
import '../widgets/custom_loader.dart';
import 'package:url_launcher/url_launcher.dart';

class SellerProfileScreen extends StatefulWidget {
  const SellerProfileScreen({super.key});

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;
  final Color _primaryGreen = const Color(0xFF00bf63);

  Future<void> _toggleShopStatus(String shopId, bool currentStatus) async {
    HapticFeedback.mediumImpact();
    await FirebaseFirestore.instance.collection('shops').doc(shopId).update({
      'isOpen': !currentStatus,
    });
  }

  void _navigateToEditScreen(BuildContext context, DocumentSnapshot doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SellerEditScreen(doc: doc),
      ),
    );
  }

  // --- REFINED LOGOUT WITH CONFIRMATION ---
  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Sign Out"),
        content: const Text("Are you sure you want to log out of your shop profile?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              await AuthService().signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text("Sign Out", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) return const Scaffold(body: Center(child: Text("Not Authenticated")));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
              onPressed: _confirmSignOut,
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('shops')
            .where('ownerId', isEqualTo: _user!.uid)
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
          final bool isOpen = data['isOpen'] ?? true;
          final String imageUrl = (data['images'] as List?)?.isNotEmpty == true ? data['images'][0] : "";

          return SingleChildScrollView(
            child: Column(
              children: [
                // 1. Header Section
                Stack(
                  children: [
                    Hero(
                      tag: 'shop_image',
                      child: Container(
                        height: 320,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          image: imageUrl.isNotEmpty
                              ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                              : null,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.6),
                                Colors.transparent,
                                Colors.black.withOpacity(0.8),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 40,
                      left: 20,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _primaryGreen,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              (data['category'] ?? "GENERAL").toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            data['shopName'] ?? "My Shop",
                            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: -1,
                      child: Container(
                        height: 30,
                        width: MediaQuery.of(context).size.width,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF4F7F6),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 25,
                      bottom: 10,
                      child: FloatingActionButton(
                        backgroundColor: Colors.white,
                        elevation: 4,
                        onPressed: () => _navigateToEditScreen(context, doc),
                        child: const Icon(Icons.edit_rounded, color: Colors.black),
                      ),
                    ),
                  ],
                ),

                // 2. Status Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: isOpen ? _primaryGreen.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isOpen ? Icons.stars_rounded : Icons.do_not_disturb_on_rounded,
                          color: isOpen ? _primaryGreen : Colors.grey,
                          size: 40,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Shop Visibility", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(
                                isOpen ? "Currently accepting orders" : "Currently closed to customers",
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          activeColor: _primaryGreen,
                          value: isOpen,
                          onChanged: (val) => _toggleShopStatus(doc.id, isOpen),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 3. Information Details
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        _buildModernInfoTile(
                          Icons.location_on_rounded,
                          "Location",
                          data['location']?['address'] ?? "No address set",
                          iconColor: Colors.redAccent,
                        ),
                        _buildDivider(),
                        _buildModernInfoTile(
                          Icons.alternate_email_rounded,
                          "Public Email",
                          data['publicEmail'] ?? _user!.email ?? "No email",
                          iconColor: Colors.blueAccent,
                        ),
                        _buildDivider(),
                        _buildModernInfoTile(
                          Icons.fingerprint_rounded,
                          "Unique Shop ID",
                          doc.id,
                          isCopyable: true,
                          iconColor: Colors.amber[700]!,
                        ),
                        if (data['mapUrl']?.isNotEmpty == true) ...[
                          _buildDivider(),
                          _buildModernInfoTile(
                            Icons.map_rounded,
                            "Navigation",
                            "Open in Google Maps",
                            iconColor: Colors.green,
                            isLink: true,
                            onTap: () async {
                              final Uri url = Uri.parse(data['mapUrl']);
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 50), // Healthy bottom padding
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Helper Widgets ---
  Widget _buildModernInfoTile(IconData icon, String title, String subtitle,
      {bool isCopyable = false, bool isLink = false, VoidCallback? onTap, required Color iconColor}) {
    return InkWell(
      onTap: onTap ?? (isCopyable ? () {
        Clipboard.setData(ClipboardData(text: subtitle));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ID copied to clipboard")));
      } : null),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 15, color: isLink ? Colors.blue : Colors.black87, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isCopyable) const Icon(Icons.copy_all_rounded, size: 18, color: Colors.grey),
            if (isLink) const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 1, color: Colors.grey.withOpacity(0.05), indent: 70);
  }
}