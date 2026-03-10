import 'package:flutter/material.dart';
import '../widgets/custom_loader.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_now/services/user_service.dart';
import 'package:intl/intl.dart';

class SellerAddItemScreen extends StatefulWidget {
  const SellerAddItemScreen({super.key});

  @override
  State<SellerAddItemScreen> createState() => _SellerAddItemScreenState();
}

class _SellerAddItemScreenState extends State<SellerAddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _discountedPriceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _expiryDateController = TextEditingController();
  final _expiryTimeController = TextEditingController();
  final _imageUrlController = TextEditingController();

  final Color primaryGreen = const Color(0xFF00bf63);
  String? _shopCategory;
  String _dietType = 'Veg';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchShopCategory();
    // Listeners to update preview in real-time
    _nameController.addListener(() => setState(() {}));
    _imageUrlController.addListener(() => setState(() {}));
  }

  Future<void> _fetchShopCategory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final shopDoc = await UserService().getShop(user.uid);
        if (shopDoc != null && mounted) {
          setState(() {
            _shopCategory = shopDoc['category'];
          });
        }
      }
    } catch (e) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _originalPriceController.dispose();
    _discountedPriceController.dispose();
    _quantityController.dispose();
    _expiryDateController.dispose();
    _expiryTimeController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: primaryGreen),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _expiryDateController.text = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) {
      setState(() => _expiryTimeController.text = picked.format(context));
    }
  }

  Future<void> _submitItem() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");
      final shopDoc = await UserService().getShop(user.uid);
      if (shopDoc == null) throw Exception("Shop not found");

      final itemData = {
        'sellerId': user.uid,
        'shopId': shopDoc.id,
        'shopName': shopDoc['shopName'],
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'originalPrice': double.parse(_originalPriceController.text),
        'discountedPrice': double.parse(_discountedPriceController.text),
        'quantity': int.parse(_quantityController.text),
        'expiryDate': _expiryDateController.text,
        'expiryTime': _expiryTimeController.text,
        'imageUrl': _imageUrlController.text.trim(),
        if (_shopCategory != 'Supermarket') 'dietType': _dietType,
        'isSoldOut': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('food_items').add(itemData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing published!'), behavior: SnackBarBehavior.floating));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Create Listing", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: -0.5)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildLivePreview(),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader("BASIC INFORMATION"),
                    _buildTextField(
                      controller: _nameController,
                      label: 'Item Name',
                      hint: 'e.g., Organic Avocado Sandwich',
                      icon: Icons.fastfood_outlined,
                      validator: (v) => v!.isEmpty ? 'What are you selling?' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Description',
                      hint: 'Mention ingredients or special notes...',
                      icon: Icons.notes_rounded,
                      maxLines: 3,
                      validator: (v) => v!.isEmpty ? 'Add a small description' : null,
                    ),
                    const SizedBox(height: 24),

                    if (_shopCategory != 'Supermarket') ...[
                      _buildSectionHeader("DIET TYPE"),
                      _buildDietSelector(),
                      const SizedBox(height: 24),
                    ],

                    _buildSectionHeader("PRICING & STOCK"),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _originalPriceController,
                            label: 'Original (₹)',
                            icon: Icons.money_off_rounded,
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _discountedPriceController,
                            label: 'Sale (₹)',
                            icon: Icons.local_offer_outlined,
                            keyboardType: TextInputType.number,
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _quantityController,
                      label: 'Units Available',
                      icon: Icons.inventory_2_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),

                    _buildSectionHeader("EXPIRATION LOGISTICS"),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _selectDate,
                            child: _buildTextField(
                              controller: _expiryDateController,
                              label: 'Expiry Date',
                              icon: Icons.calendar_today_rounded,
                              enabled: false,
                              validator: (v) => v!.isEmpty ? 'Pick a date' : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _selectTime,
                            child: _buildTextField(
                              controller: _expiryTimeController,
                              label: 'Expiry Time',
                              icon: Icons.access_time_rounded,
                              enabled: false,
                              validator: (v) => v!.isEmpty ? 'Pick time' : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    _buildSectionHeader("VISUALS"),
                    _buildTextField(
                      controller: _imageUrlController,
                      label: 'Image URL',
                      hint: 'Paste a high-quality link',
                      icon: Icons.link_rounded,
                    ),
                    const SizedBox(height: 40),

                    _buildSubmitButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLivePreview() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _imageUrlController.text.isNotEmpty
                  ? Image.network(_imageUrlController.text, fit: BoxFit.cover, errorBuilder: (c, e, s) => Icon(Icons.broken_image, color: Colors.grey[300]))
                  : Icon(Icons.image_search, color: Colors.grey[300]),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("PREVIEW", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: primaryGreen, letterSpacing: 1)),
                Text(
                  _nameController.text.isEmpty ? "Item Name" : _nameController.text,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 1.2)),
    );
  }

  Widget _buildDietSelector() {
    return Row(
      children: ['Veg', 'Non-Veg'].map((type) {
        bool isSelected = _dietType == type;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _dietType = type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: type == 'Veg' ? 12 : 0),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? (type == 'Veg' ? Colors.green[50] : Colors.red[50]) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isSelected ? (type == 'Veg' ? Colors.green : Colors.red) : Colors.grey[200]!),
              ),
              child: Center(
                child: Text(type, style: TextStyle(color: isSelected ? (type == 'Veg' ? Colors.green[700] : Colors.red[700]) : Colors.grey[600], fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: enabled,
      validator: validator,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.normal),
        prefixIcon: Icon(icon, color: primaryGreen, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primaryGreen, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.redAccent)),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitItem,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: primaryGreen.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isLoading
              ? const CustomLoader(width: 25, height: 25)
              : const Text("PUBLISH LISTING", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
        ),
      ),
    );
  }
}