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

  String? _shopCategory;
  String _dietType = 'Veg';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchShopCategory();
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
    } catch (e) {
      // ignore
    }
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF00bf63)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _expiryDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _expiryTimeController.text = picked.format(context);
      });
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item added successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding item: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Add Surplus Food",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField(
                controller: _nameController,
                label: 'Item Name',
                icon: Icons.fastfood_outlined,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _descriptionController,
                label: 'Description',
                icon: Icons.description_outlined,
                maxLines: 2,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              if (_shopCategory != 'Supermarket') ...[
                DropdownButtonFormField<String>(
                  initialValue: _dietType,
                  items: const [
                    DropdownMenuItem(value: 'Veg', child: Text('Veg')),
                    DropdownMenuItem(value: 'Non-Veg', child: Text('Non-Veg')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _dietType = val);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Diet Type',
                    prefixIcon: Icon(
                      Icons.restaurant_menu,
                      color: _dietType == 'Veg' ? Colors.green : Colors.red,
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _originalPriceController,
                      label: 'Original Price (₹)',
                      icon: Icons.money_off,
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _discountedPriceController,
                      label: 'Discount Price (₹)',
                      icon: Icons.attach_money,
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildTextField(
                controller: _quantityController,
                label: 'Available Quantity',
                icon: Icons.inventory_2_outlined,
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),

              const Text(
                "Expiration Details",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectDate,
                      child: IgnorePointer(
                        child: _buildTextField(
                          controller: _expiryDateController,
                          label: 'Expiry Date',
                          icon: Icons.calendar_today,
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: _selectTime,
                      child: IgnorePointer(
                        child: _buildTextField(
                          controller: _expiryTimeController,
                          label: 'Expiry Time',
                          icon: Icons.access_time,
                          validator: (v) => v!.isEmpty ? 'Required' : null,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _buildTextField(
                controller: _imageUrlController,
                label: 'Image URL (Optional)',
                icon: Icons.image_outlined,
                hintText: 'https://example.com/image.jpg',
              ),
              const SizedBox(height: 32),

              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00bf63),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CustomLoader(width: 30, height: 30)
                      : const Text(
                          "List Food Item",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: Icon(icon, color: const Color(0xFF00bf63)),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00bf63), width: 2),
        ),
      ),
    );
  }
}
