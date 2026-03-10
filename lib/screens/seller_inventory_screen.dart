import 'package:flutter/material.dart';
import '../widgets/custom_loader.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_now/screens/seller_add_item_screen.dart';
import 'package:intl/intl.dart';

class SellerInventoryScreen extends StatefulWidget {
  const SellerInventoryScreen({super.key});

  @override
  State<SellerInventoryScreen> createState() => _SellerInventoryScreenState();
}

class _SellerInventoryScreenState extends State<SellerInventoryScreen> {
  String? _shopCategory;
  final Color primaryGreen = const Color(0xFF00bf63);

  @override
  void initState() {
    super.initState();
    _fetchShopCategory();
  }

  Future<void> _fetchShopCategory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('shops')
            .doc(user.uid)
            .get();
        if (doc.exists && mounted) {
          setState(() {
            _shopCategory = doc['category'];
          });
        }
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Kitchen Inventory",
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: -0.8,
              ),
            ),
            Text(
              "Manage your live surplus listings",
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Container(
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () {}, // Potential for notifications/history
                icon: Icon(
                  Icons.restaurant_menu_rounded,
                  color: primaryGreen,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
      body: user == null
          ? const Center(child: Text("Not Authenticated"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('food_items')
                  .where('sellerId', isEqualTo: user.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return Center(child: Text('Error: ${snapshot.error}'));
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CustomLoader());

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                  return _buildEmptyState();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    100,
                  ), // Extra bottom padding for FAB
                  itemCount: snapshot.data!.docs.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final item = doc.data() as Map<String, dynamic>;

                    // Simple entrance animation
                    return TweenAnimationBuilder(
                      duration: Duration(milliseconds: 400 + (index * 100)),
                      tween: Tween<double>(begin: 0, end: 1),
                      builder: (context, double value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: _buildInventoryCard(context, item, doc.id),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SellerAddItemScreen()),
        ),
        backgroundColor: primaryGreen,
        elevation: 4,
        highlightElevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        label: const Text(
          "ADD ITEM",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryCard(
    BuildContext context,
    Map<String, dynamic> item,
    String docId,
  ) {
    final int quantity = item['quantity'] ?? 0;
    final String? imageUrl = item['imageUrl'];

    // Stock Logic
    bool isExpired = _checkIsExpired(item['expiryDate'], item['expiryTime']);
    Color statusColor = primaryGreen;
    String statusText = "IN STOCK";

    if (isExpired) {
      statusColor = Colors.redAccent;
      statusText = "EXPIRED";
    } else if (quantity == 0) {
      statusColor = Colors.orange[800]!;
      statusText = "OUT OF STOCK";
    } else if (quantity < 5) {
      statusColor = Colors.amber[700]!;
      statusText = "LOW STOCK";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Image Section with Hero-like feel
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Color(0xFFF1F3F4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: (imageUrl != null && imageUrl.isNotEmpty)
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => _buildPlaceholderIcon(),
                          )
                        : _buildPlaceholderIcon(),
                  ),
                ),
                const SizedBox(width: 16),
                // Content Section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['name']?.toString().toUpperCase() ??
                                  'NEW ITEM',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                                color: Color(0xFF1A1C1E),
                              ),
                            ),
                          ),
                          _buildStatusBadge(statusText, statusColor),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Exp: ${item['expiryDate']}",
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "₹${item['discountedPrice']}",
                            style: TextStyle(
                              color: primaryGreen,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              "₹${item['originalPrice']}",
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Stock Counter
                Column(
                  children: [
                    Text(
                      "$quantity",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      "UNITS",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey[400],
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Action Buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildCardButton(
                    icon: Icons.edit_note_rounded,
                    label: "MANAGE",
                    color: primaryGreen,
                    onTap: () => _showEditDialog(context, docId, item),
                  ),
                ),
                Container(width: 1, height: 20, color: Colors.grey[200]),
                Expanded(
                  child: _buildCardButton(
                    icon: Icons.delete_outline_rounded,
                    label: "REMOVE",
                    color: Colors.redAccent,
                    onTap: () => _confirmDelete(context, docId),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildCardButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _checkIsExpired(String? dateStr, String? timeStr) {
    if (dateStr == null || timeStr == null || dateStr.isEmpty) return false;
    try {
      DateTime date = DateFormat('yyyy-MM-dd').parse(dateStr);
      DateTime time;
      try {
        time = DateFormat('h:mm a').parse(timeStr);
      } catch (e) {
        time = DateFormat('HH:mm').parse(timeStr);
      }
      DateTime itemExpiry = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      return DateTime.now().isAfter(itemExpiry);
    } catch (e) {
      return false;
    }
  }

  void _showEditDialog(
    BuildContext context,
    String docId,
    Map<String, dynamic> item,
  ) {
    final stockController = TextEditingController(
      text: item['quantity'].toString(),
    );
    final priceController = TextEditingController(
      text: item['discountedPrice'].toString(),
    );
    final expiryDateController = TextEditingController(
      text: item['expiryDate'] ?? '',
    );
    final expiryTimeController = TextEditingController(
      text: item['expiryTime'] ?? '',
    );
    String currentDietType = item['dietType'] ?? 'Veg';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Update Listing",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item['name'] ?? "",
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
                const SizedBox(height: 24),
                _buildFieldLabel("INVENTORY & PRICING"),
                Row(
                  children: [
                    Expanded(
                      child: _buildModernField(
                        stockController,
                        "Stock Units",
                        Icons.inventory_2_outlined,
                        true,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildModernField(
                        priceController,
                        "Sale Price",
                        Icons.currency_rupee_rounded,
                        true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_shopCategory != 'Supermarket') ...[
                  _buildFieldLabel("DIETARY INFO"),
                  _buildDietToggle(
                    currentDietType,
                    (val) => setModalState(() => currentDietType = val),
                  ),
                  const SizedBox(height: 20),
                ],
                _buildFieldLabel("EXPIRY SCHEDULE"),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 30),
                            ),
                          );
                          if (picked != null)
                            setModalState(
                              () => expiryDateController.text = DateFormat(
                                'yyyy-MM-dd',
                              ).format(picked),
                            );
                        },
                        child: _buildModernField(
                          expiryDateController,
                          "Date",
                          Icons.calendar_today_rounded,
                          false,
                          enabled: false,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (picked != null)
                            setModalState(
                              () => expiryTimeController.text = picked.format(
                                context,
                              ),
                            );
                        },
                        child: _buildModernField(
                          expiryTimeController,
                          "Time",
                          Icons.access_time_rounded,
                          false,
                          enabled: false,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      FirebaseFirestore.instance
                          .collection('food_items')
                          .doc(docId)
                          .update({
                            'quantity':
                                int.tryParse(stockController.text) ??
                                item['quantity'],
                            'discountedPrice':
                                double.tryParse(priceController.text) ??
                                item['discountedPrice'],
                            'expiryDate': expiryDateController.text,
                            'expiryTime': expiryTimeController.text,
                            if (_shopCategory != 'Supermarket')
                              'dietType': currentDietType,
                          });
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "SAVE CHANGES",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.grey[500],
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildModernField(
    TextEditingController controller,
    String label,
    IconData icon,
    bool isNumber, {
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: primaryGreen),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildDietToggle(String current, Function(String) onChanged) {
    return Row(
      children: ['Veg', 'Non-Veg'].map((type) {
        bool isSelected = current == type;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: type == 'Veg' ? 12 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? (type == 'Veg' ? Colors.green[50] : Colors.red[50])
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? (type == 'Veg' ? Colors.green : Colors.red)
                      : Colors.transparent,
                ),
              ),
              child: Center(
                child: Text(
                  type,
                  style: TextStyle(
                    color: isSelected
                        ? (type == 'Veg' ? Colors.green[700] : Colors.red[700])
                        : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlaceholderIcon() =>
      Icon(Icons.fastfood_rounded, color: Colors.grey[300], size: 30);

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Icon(
              Icons.inventory_2_rounded,
              size: 80,
              color: primaryGreen.withOpacity(0.2),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            "No Surplus Listed",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1C1E),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Help reduce waste by listing\nyour unsold food items today.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, String docId) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text(
          "Remove Item?",
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          "This listing will be immediately hidden from buyers. This action cannot be undone.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "KEEP IT",
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[50],
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('food_items')
                  .doc(docId)
                  .delete();
              Navigator.pop(context);
            },
            child: const Text(
              "REMOVE",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
