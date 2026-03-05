import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/custom_loader.dart';
import 'package:food_now/screens/edit_profile_screen.dart';
import 'package:food_now/screens/login_screen.dart';
import 'package:food_now/screens/buyer_orders_screen.dart';
import 'package:food_now/screens/favorites_screen.dart';
import 'package:food_now/services/auth_service.dart';
import 'package:food_now/widgets/seller_banner.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final Color primaryGreen = const Color(0xFF00bf63);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CustomLoader()));
        }

        if (snapshot.hasData) {
          return _buildLoggedInView(context, snapshot.data!);
        } else {
          return _buildGuestView(context);
        }
      },
    );
  }

  // ── Guest View (Logged Out) ────────────────────────────────────────────────
  Widget _buildGuestView(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // Soft premium background
      appBar: AppBar(
        title: const Text(
          "Profile",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryGreen.withOpacity(0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_rounded,
                  size: 64,
                  color: primaryGreen,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              "Come on in!",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Log in or Sign up to view your orders, update your profile, and save your favorite foods.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(flex: 3),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  shadowColor: primaryGreen.withOpacity(0.5),
                ),
                child: const Text(
                  "Login / Sign Up",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SellerBanner(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLoggedInView(BuildContext context, User user) {
    return LoggedInUserProfile(user: user);
  }
}

// ── Logged In User Profile ───────────────────────────────────────────────────
class LoggedInUserProfile extends StatefulWidget {
  final User user;

  const LoggedInUserProfile({super.key, required this.user});

  @override
  State<LoggedInUserProfile> createState() => _LoggedInUserProfileState();
}

class _LoggedInUserProfileState extends State<LoggedInUserProfile> {
  final AuthService _authService = AuthService();
  final Color primaryGreen = const Color(0xFF00bf63);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(body: Center(child: CustomLoader()));
        }

        final userData = snapshot.data?.data() as Map<String, dynamic>?;

        String displayName = (userData?['name'] as String?) ?? "";
        if (displayName.isEmpty) {
          displayName = widget.user.displayName ?? "User";
        }
        final String? profileImage =
            userData?['profileImage'] ?? widget.user.photoURL;

        return Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(
                context,
                widget.user,
                displayName,
                profileImage,
                userData,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildMenuSection(
                        title: "Account",
                        items: [
                          _buildMenuItem(
                            icon: Icons.receipt_long_rounded,
                            title: "Your Orders",
                            subtitle: "View past orders & reorder",
                            isFirst: true,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const BuyerOrdersScreen(),
                                ),
                              );
                            },
                          ),
                          _buildMenuItem(
                            icon: Icons.favorite_rounded,
                            title: "Favorites",
                            subtitle: "Your favorite restaurants & items",
                            isLast: true,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const FavoritesScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildMenuSection(
                        title: "Settings & Support",
                        items: [
                          _buildMenuItem(
                            icon: Icons.notifications_active_rounded,
                            title: "Notifications",
                            isFirst: true,
                            onTap: () {},
                          ),
                          _buildMenuItem(
                            icon: Icons.help_outline_rounded,
                            title: "Help & Support",
                            isLast: true,
                            onTap: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _buildLogoutButton(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Profile Header (SliverAppBar) ──────────────────────────────────────────
  Widget _buildSliverAppBar(
    BuildContext context,
    User user,
    String displayName,
    String? profileImage,
    Map<String, dynamic>? userData,
  ) {
    return SliverAppBar(
      expandedHeight: 240,
      backgroundColor: Colors.transparent,
      pinned: true,
      elevation: 0,
      stretch: true,
      shape: const ContinuousRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(64)),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0, top: 8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfileScreen(user: user, userData: userData),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text("Edit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        background: Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            gradient: LinearGradient(
              colors: [Color(0xFF388E3C), Color(0xFF00bf63)],
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0xFF00bf63),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                // Avatar with premium border
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: 90,
                    height: 90,
                    child: ClipOval(
                      child: (profileImage != null && profileImage.isNotEmpty)
                          ? Image.network(
                              profileImage,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildAvatarPlaceholder();
                              },
                            )
                          : _buildAvatarPlaceholder(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.email ?? "No email provided",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      color: Colors.grey[100],
      child: const Icon(
        Icons.person_rounded,
        size: 50,
        color: Color(0xFF00bf63),
      ),
    );
  }

  // ── Menu Sections & Items ────────────────────────────────────────────────────
  Widget _buildMenuSection({required String title, required List<Widget> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.grey[500],
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(24) : Radius.zero,
          bottom: isLast ? const Radius.circular(24) : Radius.zero,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: primaryGreen, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: Colors.grey[300],
                  ),
                ],
              ),
            ),
            if (!isLast)
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.grey.shade100,
                indent: 70, // Aligns divider with text
                endIndent: 20,
              ),
          ],
        ),
      ),
    );
  }

  // ── Logout Button ────────────────────────────────────────────────────────────
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () async {
          await _authService.signOut();
        },
        icon: const Icon(Icons.logout_rounded, size: 22),
        label: const Text(
          "Log Out",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.red[600],
          backgroundColor: Colors.red[50],
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}