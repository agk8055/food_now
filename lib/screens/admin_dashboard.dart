import 'package:flutter/material.dart';
import '../widgets/custom_loader.dart';
import 'package:food_now/services/auth_service.dart';
import 'package:food_now/screens/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  late TabController _tabController;
  final Color primaryColor = const Color(0xFF00bf63);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shop $status successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: status == 'approved'
                ? Colors.green
                : Colors.redAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Admin Dashboard",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 24,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.2),
              child: IconButton(
                icon: const Icon(
                  Icons.logout_rounded,
                  size: 20,
                  color: Colors.white,
                ),
                onPressed: () => _handleLogout(context),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Pending"),
            Tab(text: "Approved"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildShopList(context, 'pending'),
          _buildShopList(context, 'approved'),
        ],
      ),
    );
  }

  Widget _buildShopList(BuildContext context, String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .where('verificationStatus', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return const Center(child: Text('Something went wrong'));
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CustomLoader());

        final allDocs = snapshot.data!.docs;

        if (allDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  status == 'pending'
                      ? 'No pending applications'
                      : 'No approved shops',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        final Set<String> categories = {'All'};
        for (var doc in allDocs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['category'] != null &&
              data['category'].toString().isNotEmpty) {
            categories.add(data['category'] as String);
          }
        }

        final filteredDocs = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['shopName'] ?? '').toString().toLowerCase();
          final matchesName = name.contains(_searchQuery.toLowerCase());
          final category = data['category'] as String?;
          final matchesCategory =
              _selectedCategory == 'All' || category == _selectedCategory;
          return matchesName && matchesCategory;
        }).toList();

        return Column(
          children: [
            if (status == 'approved') _buildFilterBar(categories),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: filteredDocs.isEmpty
                    ? const Center(child: Text("No matching shops found"))
                    : ListView.builder(
                        key: ValueKey('${status}_${filteredDocs.length}'),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          return ShopApplicationCard(
                            shopDoc: filteredDocs[index],
                            isApproved: status == 'approved',
                            onApprove: () => _updateShopStatus(
                              context,
                              filteredDocs[index].id,
                              'approved',
                            ),
                            onReject: () => _updateShopStatus(
                              context,
                              filteredDocs[index].id,
                              'rejected',
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterBar(Set<String> categories) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Search by shop name...',
              prefixIcon: Icon(Icons.search_rounded, color: primaryColor),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (selected) =>
                        setState(() => _selectedCategory = cat),
                    selectedColor: primaryColor,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    backgroundColor: Colors.grey[200],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide.none,
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class ShopApplicationCard extends StatelessWidget {
  final DocumentSnapshot shopDoc;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool isApproved;

  const ShopApplicationCard({
    super.key,
    required this.shopDoc,
    required this.onApprove,
    required this.onReject,
    this.isApproved = false,
  });

  @override
  Widget build(BuildContext context) {
    final shopData = shopDoc.data()! as Map<String, dynamic>;
    final images = shopData['images'] as List<dynamic>?;
    final String? imageUrl = (images != null && images.isNotEmpty)
        ? images.first as String
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () =>
              _showActionBottomSheet(context, shopData, shopData['ownerId']),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardImage(imageUrl, shopData['category']),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shopData['shopName'] ?? 'Unnamed Shop',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                size: 14,
                                color: Color(0xFF00bf63),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  shopData['location']?['address'] ??
                                      'Address not available',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardImage(String? url, String? category) {
    return Stack(
      children: [
        Hero(
          tag: 'shop_hero_${shopDoc.id}',
          child: Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(color: Colors.grey[100]),
            child: url != null
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => _imagePlaceholder(),
                  )
                : _imagePlaceholder(),
          ),
        ),
        if (category != null)
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: Text(
                category,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _imagePlaceholder() => Center(
    child: Icon(Icons.storefront_outlined, size: 48, color: Colors.grey[300]),
  );

  void _showActionBottomSheet(
    BuildContext context,
    Map<String, dynamic> data,
    String? ownerId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DetailsBottomSheet(
        data: data,
        ownerId: ownerId,
        isApproved: isApproved,
        onApprove: onApprove,
        onReject: onReject,
      ),
    );
  }
}

class _DetailsBottomSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final String? ownerId;
  final bool isApproved;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _DetailsBottomSheet({
    required this.data,
    required this.ownerId,
    required this.isApproved,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                controller: controller,
                children: [
                  Text(
                    data['shopName'] ?? 'Shop Details',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _infoTile(
                    Icons.info_outline_rounded,
                    "Description",
                    data['description'] ?? 'No description provided',
                  ),
                  _infoTile(
                    Icons.map_outlined,
                    "Address",
                    data['location']?['address'] ?? 'No address',
                  ),
                  const Divider(height: 40, thickness: 1),
                  const Text(
                    "Owner Information",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  if (ownerId != null)
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(ownerId)
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting)
                          return const LinearProgressIndicator(minHeight: 2);
                        if (!snapshot.hasData || !snapshot.data!.exists)
                          return const Text("Owner details missing");
                        final user =
                            snapshot.data!.data() as Map<String, dynamic>;
                        return Column(
                          children: [
                            _infoTile(
                              Icons.person_outline_rounded,
                              "Full Name",
                              user['name'] ?? 'N/A',
                            ),
                            _infoTile(
                              Icons.alternate_email_rounded,
                              "Email",
                              user['email'] ?? 'N/A',
                            ),
                            _infoTile(
                              Icons.phone_iphone_rounded,
                              "Phone",
                              user['phoneNumber'] ?? user['phone'] ?? 'N/A',
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onReject();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      isApproved ? "Revoke Approval" : "Reject Application",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (!isApproved) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onApprove();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00bf63),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Approve Shop",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF00bf63).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF00bf63)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
