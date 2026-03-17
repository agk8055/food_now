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

class _SellerProfileScreenState extends State<SellerProfileScreen>
    with TickerProviderStateMixin {
  final User? _user = FirebaseAuth.instance.currentUser;
  final Color _primaryGreen = const Color(0xFF00bf63);

  late AnimationController _headerAnimController;
  late AnimationController _contentAnimController;
  late Animation<double> _headerFadeAnim;
  late Animation<Offset> _contentSlideAnim;
  late Animation<double> _contentFadeAnim;

  @override
  void initState() {
    super.initState();

    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _contentAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _headerFadeAnim = CurvedAnimation(
      parent: _headerAnimController,
      curve: Curves.easeOut,
    );
    _contentSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentAnimController,
      curve: Curves.easeOutCubic,
    ));
    _contentFadeAnim = CurvedAnimation(
      parent: _contentAnimController,
      curve: Curves.easeOut,
    );

    _headerAnimController.forward();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _contentAnimController.forward();
    });
  }

  @override
  void dispose() {
    _headerAnimController.dispose();
    _contentAnimController.dispose();
    super.dispose();
  }

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

  void _confirmSignOut() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.logout_rounded,
                    color: Colors.redAccent, size: 28),
              ),
              const SizedBox(height: 20),
              const Text(
                "Sign Out",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3),
              ),
              const SizedBox(height: 10),
              Text(
                "Are you sure you want to log out of your shop profile?",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey[800], fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.grey.shade100,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel",
                          style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.red.shade50,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        await AuthService().signOut();
                        if (mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (context) => const LoginScreen()),
                            (route) => false,
                          );
                        }
                      },
                      child: const Text(
                        "Sign Out",
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return const Scaffold(body: Center(child: Text("Not Authenticated")));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        actions: [
          FadeTransition(
            opacity: _headerFadeAnim,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.logout_rounded,
                    color: Colors.white, size: 20),
                onPressed: _confirmSignOut,
              ),
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
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storefront_outlined,
                      size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text("Shop profile not found.",
                      style: TextStyle(color: Colors.grey[700], fontSize: 16)),
                ],
              ),
            );
          }

          final doc = snapshot.data!.docs.first;
          final data = doc.data() as Map<String, dynamic>;
          final bool isOpen = data['isOpen'] ?? true;
          final String imageUrl =
              (data['images'] as List?)?.isNotEmpty == true
                  ? data['images'][0]
                  : "";

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                // ── 1. HERO HEADER ──────────────────────────────────────────
                _buildHeroHeader(context, doc, data, imageUrl, isOpen),

                // ── 2. QUICK STATS ROW ──────────────────────────────────────
                SlideTransition(
                  position: _contentSlideAnim,
                  child: FadeTransition(
                    opacity: _contentFadeAnim,
                    child: _buildQuickStats(data, isOpen),
                  ),
                ),

                const SizedBox(height: 20),

                // ── 3. STATUS TOGGLE CARD ───────────────────────────────────
                SlideTransition(
                  position: _contentSlideAnim,
                  child: FadeTransition(
                    opacity: _contentFadeAnim,
                    child: _buildStatusCard(doc.id, isOpen),
                  ),
                ),

                const SizedBox(height: 20),

                // ── 4. INFO SECTION ─────────────────────────────────────────
                SlideTransition(
                  position: _contentSlideAnim,
                  child: FadeTransition(
                    opacity: _contentFadeAnim,
                    child: _buildInfoSection(doc, data),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── HERO HEADER ────────────────────────────────────────────────────────────
  Widget _buildHeroHeader(BuildContext context, DocumentSnapshot doc,
      Map<String, dynamic> data, String imageUrl, bool isOpen) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Background image with gradient
        Hero(
          tag: 'shop_image',
          child: Container(
            height: 340,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              image: imageUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(imageUrl), fit: BoxFit.cover)
                  : null,
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.35, 0.75, 1.0],
                  colors: [
                    Colors.black.withOpacity(0.55),
                    Colors.transparent,
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.85),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Shop name + category overlay
        Positioned(
          bottom: 55,
          left: 22,
          right: 22,
          child: FadeTransition(
            opacity: _headerFadeAnim,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status pill
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Container(
                    key: ValueKey(isOpen),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isOpen
                          ? _primaryGreen.withOpacity(0.9)
                          : Colors.black45,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.3), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isOpen ? Colors.white : Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOpen ? "OPEN NOW" : "CLOSED",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  data['shopName'] ?? "My Shop",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      height: 1.1),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.storefront_rounded,
                        color: Colors.white.withOpacity(0.7), size: 14),
                    const SizedBox(width: 5),
                    Text(
                      (data['category'] ?? "General").toUpperCase(),
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.75),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Curved bottom cutout
        Positioned(
          bottom: -1,
          child: Container(
            height: 32,
            width: MediaQuery.of(context).size.width,
            decoration: const BoxDecoration(
              color: Color(0xFFF4F7F6),
              borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
            ),
          ),
        ),

        // Edit FAB
        Positioned(
          right: 22,
          bottom: 8,
          child: FadeTransition(
            opacity: _headerFadeAnim,
            child: _AnimatedEditButton(
              onPressed: () => _navigateToEditScreen(context, doc),
              primaryGreen: _primaryGreen,
            ),
          ),
        ),
      ],
    );
  }

  // ── QUICK STATS ────────────────────────────────────────────────────────────
  Widget _buildQuickStats(Map<String, dynamic> data, bool isOpen) {
    final String address = data['location']?['address'] ?? "";
    final bool hasMap = data['mapUrl']?.isNotEmpty == true;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildStatChip(
            icon: Icons.location_on_rounded,
            label: address.isNotEmpty ? "Location Set" : "No Location",
            iconColor:
                address.isNotEmpty ? Colors.grey[700]! : Colors.grey[400]!,
            active: address.isNotEmpty,
          ),
          const SizedBox(width: 10),
          _buildStatChip(
            icon: Icons.map_rounded,
            label: hasMap ? "Maps Linked" : "No Map",
            iconColor: hasMap ? Colors.grey[700]! : Colors.grey[400]!,
            active: hasMap,
          ),
          const SizedBox(width: 10),
          _buildStatChip(
            icon: Icons.email_rounded,
            label: "Email Set",
            iconColor: Colors.grey[700]!,
            active: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color iconColor,
    required bool active,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.black87 : Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // ── STATUS TOGGLE CARD ─────────────────────────────────────────────────────
  Widget _buildStatusCard(String shopId, bool isOpen) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isOpen
                ? [
                    _primaryGreen.withOpacity(0.08),
                    _primaryGreen.withOpacity(0.02)
                  ]
                : [Colors.grey.shade100, Colors.white],
          ),
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color:
                isOpen ? _primaryGreen.withOpacity(0.25) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isOpen
                  ? _primaryGreen.withOpacity(0.12)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Container(
                key: ValueKey(isOpen),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isOpen
                      ? _primaryGreen.withOpacity(0.12)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isOpen
                      ? Icons.storefront_rounded
                      : Icons.do_not_disturb_on_rounded,
                  color: isOpen ? Colors.grey[700] : Colors.grey[400],
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      isOpen ? "Shop is Open" : "Shop is Closed",
                      key: ValueKey(isOpen),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color:
                            isOpen ? Colors.grey[700]! : Colors.grey[800]!,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isOpen
                        ? "Visible to customers & accepting orders"
                        : "Hidden from customers",
                    style:
                        TextStyle(color: Colors.grey[700], fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch.adaptive(
              activeColor: _primaryGreen,
              value: isOpen,
              onChanged: (val) => _toggleShopStatus(shopId, isOpen),
            ),
          ],
        ),
      ),
    );
  }

  // ── INFO SECTION ───────────────────────────────────────────────────────────
  Widget _buildInfoSection(DocumentSnapshot doc, Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 14),
            child: Text(
              "Shop Details",
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[700],
                  letterSpacing: 0.8),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 6))
              ],
            ),
            child: Column(
              children: [
                _buildModernInfoTile(
                  Icons.location_on_rounded,
                  "Location",
                  data['location']?['address'] ?? "No address set",
                  iconColor: Colors.grey[700]!,
                  isFirst: true,
                ),
                _buildDivider(),
                _buildModernInfoTile(
                  Icons.alternate_email_rounded,
                  "Public Email",
                  data['publicEmail'] ?? _user!.email ?? "No email",
                  iconColor: Colors.grey[700]!,
                ),
                _buildDivider(),
                _buildModernInfoTile(
                  Icons.fingerprint_rounded,
                  "Unique Shop ID",
                  doc.id,
                  isCopyable: true,
                  iconColor: Colors.grey[700]!,
                  isLast: data['mapUrl']?.isNotEmpty != true,
                ),
                if (data['mapUrl']?.isNotEmpty == true) ...[
                  _buildDivider(),
                  _buildModernInfoTile(
                    Icons.map_rounded,
                    "Navigation",
                    "Open in Google Maps",
                    iconColor: Colors.grey[700]!,
                    isLink: true,
                    isLast: true,
                    onTap: () async {
                      final Uri url = Uri.parse(data['mapUrl']);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── HELPER WIDGETS ─────────────────────────────────────────────────────────
  Widget _buildModernInfoTile(
    IconData icon,
    String title,
    String subtitle, {
    bool isCopyable = false,
    bool isLink = false,
    VoidCallback? onTap,
    required Color iconColor,
    bool isFirst = false,
    bool isLast = false,
  }) {
    BorderRadius radius = BorderRadius.only(
      topLeft: Radius.circular(isFirst ? 28 : 0),
      topRight: Radius.circular(isFirst ? 28 : 0),
      bottomLeft: Radius.circular(isLast ? 28 : 0),
      bottomRight: Radius.circular(isLast ? 28 : 0),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ??
            (isCopyable
                ? () {
                    Clipboard.setData(ClipboardData(text: subtitle));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 10),
                            Text("Shop ID copied to clipboard"),
                          ],
                        ),
                        backgroundColor: const Color(0xFF00bf63),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        margin: const EdgeInsets.all(16),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                : null),
        borderRadius: radius,
        splashColor: iconColor.withOpacity(0.06),
        highlightColor: iconColor.withOpacity(0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: isLink ? const Color(0xFF00bf63) : Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isCopyable)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.copy_all_rounded,
                      size: 16, color: Colors.grey),
                ),
              if (isLink)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00bf63).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_forward_ios_rounded,
                      size: 13, color: Colors.grey[700]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
        height: 1, thickness: 1, color: Colors.grey.withOpacity(0.06), indent: 80);
  }
}

// ── ANIMATED EDIT BUTTON ──────────────────────────────────────────────────────
class _AnimatedEditButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Color primaryGreen;

  const _AnimatedEditButton(
      {required this.onPressed, required this.primaryGreen});

  @override
  State<_AnimatedEditButton> createState() => _AnimatedEditButtonState();
}

class _AnimatedEditButtonState extends State<_AnimatedEditButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6)),
              BoxShadow(
                  color: widget.primaryGreen.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Icon(Icons.edit_rounded, color: Colors.black87, size: 22),
        ),
      ),
    );
  }
}