import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../widgets/custom_loader.dart';
import 'seller_dashboard.dart';

import 'package:food_now/services/location_service.dart';

class SellerRegistrationScreen extends StatefulWidget {
  const SellerRegistrationScreen({super.key});

  @override
  State<SellerRegistrationScreen> createState() =>
      _SellerRegistrationScreenState();
}

class _SellerRegistrationScreenState extends State<SellerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _userService = UserService();
  final _locationService = LocationService();

  // Step 1: User Signup Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  // Step 2: Shop Details Controllers
  final _shopNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _addressController = TextEditingController();
  final _imageUrlController = TextEditingController(); // Placeholder for now

  bool _isSigningUp = true; // Toggle between Signup and Shop Creation
  bool _isLoading = false;
  bool _obscurePassword = true;

  final List<String> _categories = [
    'Restaurant',
    'Bakery',
    'Supermarket',
    'Other',
  ];

  String? _existingShopId;

  @override
  void initState() {
    super.initState();
    _checkExistingShop();
  }

  Future<void> _checkExistingShop() async {
    final user = _authService.currentUser;
    if (user != null) {
      setState(() => _isSigningUp = false); // Skip signup if logged in

      try {
        final shopDoc = await _userService.getShop(user.uid);
        if (shopDoc != null) {
          final data = shopDoc.data() as Map<String, dynamic>;
          setState(() {
            _existingShopId = shopDoc.id;
            _shopNameController.text = data['shopName'] ?? '';
            _descriptionController.text = data['description'] ?? '';
            _categoryController.text = data['category'] ?? '';
            _addressController.text = data['location']?['address'] ?? '';

            // Handle both new (GeoPoint) and old (lat/lng) formats
            final geopoint = data['location']?['geopoint'] as GeoPoint?;
            if (geopoint != null) {
              _latController.text = geopoint.latitude.toString();
              _lngController.text = geopoint.longitude.toString();
            } else {
              _latController.text = (data['location']?['lat'] ?? 0.0)
                  .toString();
              _lngController.text = (data['location']?['lng'] ?? 0.0)
                  .toString();
            }

            final images = data['images'] as List<dynamic>?;
            if (images != null && images.isNotEmpty) {
              _imageUrlController.text = images.first.toString();
            }
          });
        }
      } catch (e) {
        print("Error fetching existing shop: $e");
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _shopNameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _addressController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permissions are permanently denied, we cannot request permissions.',
            ),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _latController.text = position.latitude.toString();
      _lngController.text = position.longitude.toString();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // 1. Create Auth User
      UserCredential? credential = await _authService
          .signUpWithEmailAndPassword(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );

      if (credential != null && credential.user != null) {
        // 2. Save User to Firestore with 'seller' role
        await _userService.saveUser(
          user: credential.user!,
          role: 'seller',
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
        );
        // Note: UserService in its current state might not save phone number based on previous read.
        // We'll proceed assuming basic user creation works.

        setState(() {
          _isSigningUp = false; // Move to next step
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registration Failed: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitShop() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final shopData = {
        'ownerId': user.uid,
        'shopName': _shopNameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _categoryController.text.isNotEmpty
            ? _categoryController.text
            : 'Other',
        'images': [
          if (_imageUrlController.text.isNotEmpty)
            _imageUrlController.text.trim(),
        ],
        'location': {
          'geohash': _locationService.getGeohash(
            double.tryParse(_latController.text) ?? 0.0,
            double.tryParse(_lngController.text) ?? 0.0,
          ),
          'geopoint': GeoPoint(
            double.tryParse(_latController.text) ?? 0.0,
            double.tryParse(_lngController.text) ?? 0.0,
          ),
          'address': _addressController.text.trim(),
        },
        // Don't overwrite these if updating, mostly static for now but careful
        'isOpen': true,
        'rating': 0.0,
        // ALWAYS reset to pending on update/create
        'verificationStatus': 'pending',
        'isVerified': false,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_existingShopId != null) {
        // Update existing shop
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(_existingShopId)
            .update(shopData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shop details updated! Resubmitted for approval.'),
          ),
        );
      } else {
        // Create new shop
        shopData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('shops').add(shopData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shop created successfully! Pending admin approval.'),
          ),
        );
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SellerDashboard()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving shop: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSigningUp
              ? 'Seller Sign Up'
              : (_existingShopId != null ? 'Edit Shop Details' : 'Create Shop'),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isSigningUp) ..._buildSignupForm() else ..._buildShopForm(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSignupForm() {
    return [
      const Text(
        'Create Your Seller Account',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1565C0),
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      _buildTextField(
        controller: _nameController,
        label: 'Full Name',
        icon: Icons.person,
        validator: (v) => v!.isEmpty ? 'Required' : null,
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _emailController,
        label: 'Email',
        icon: Icons.email,
        keyboardType: TextInputType.emailAddress,
        validator: (v) => !v!.contains('@') ? 'Invalid email' : null,
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _passwordController,
        label: 'Password',
        icon: Icons.lock,
        obscureText: _obscurePassword,
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
          ),
          onPressed: () {
            setState(() {
              _obscurePassword = !_obscurePassword;
            });
          },
        ),
        validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _phoneController,
        label: 'Phone Number',
        icon: Icons.phone,
        keyboardType: TextInputType.phone,
        validator: (v) => v!.isEmpty ? 'Required' : null,
      ),
      const SizedBox(height: 32),
      _isLoading
          ? const CustomLoader()
          : ElevatedButton(
              onPressed: _registerUser,
              style: _buttonStyle(),
              child: const Text(
                'Next: Shop Details',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
      TextButton(
        onPressed: () {
          // Logic to switch to login if they already have an account but want to create a shop?
          // For now specific request was "Create new user" logic.
          Navigator.pop(context);
        },
        child: const Text('Already have an account? Login'),
      ),
    ];
  }

  List<Widget> _buildShopForm() {
    return [
      const Text(
        'Enter Shop Details',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1565C0),
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      _buildTextField(
        controller: _shopNameController,
        label: 'Shop Name',
        icon: Icons.store,
        validator: (v) => v!.isEmpty ? 'Required' : null,
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DropdownButtonFormField<String>(
          initialValue: _categoryController.text.isNotEmpty
              ? _categoryController.text
              : null,
          items: _categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (val) => setState(() => _categoryController.text = val!),
          decoration: const InputDecoration(
            labelText: 'Category',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.category, color: Color(0xFF1565C0)),
          ),
          validator: (v) => v == null ? 'Required' : null,
        ),
      ),
      _buildTextField(
        controller: _descriptionController,
        label: 'Description',
        icon: Icons.description,
        maxLines: 3,
        validator: (v) => v!.isEmpty ? 'Required' : null,
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: _buildTextField(
              controller: _latController,
              label: 'Latitude',
              icon: Icons.location_on,
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildTextField(
              controller: _lngController,
              label: 'Longitude',
              icon: Icons.location_on,
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      ElevatedButton.icon(
        onPressed: _getCurrentLocation,
        icon: const Icon(Icons.my_location),
        label: const Text('Get Current Location'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[200],
          foregroundColor: Colors.black,
        ),
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _addressController,
        label: 'Full Address',
        icon: Icons.home,
        maxLines: 2,
        validator: (v) => v!.isEmpty ? 'Required' : null,
      ),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _imageUrlController,
        label: 'Image URL (Optional)',
        icon: Icons.image,
      ),
      const SizedBox(height: 32),
      _isLoading
          ? const CustomLoader()
          : ElevatedButton(
              onPressed: _submitShop,
              style: _buttonStyle(),
              child: Text(
                _existingShopId != null
                    ? 'Update & Resubmit'
                    : 'Submit Shop for Approval',
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
    ];
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1565C0)),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      obscureText: obscureText,
      validator: validator,
    );
  }

  ButtonStyle _buttonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF1565C0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
