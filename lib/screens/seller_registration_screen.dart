import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../widgets/custom_loader.dart';
import 'seller_dashboard.dart';

import 'package:food_now/services/location_service.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Theme Constants ──────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF00bf63);
const _kPrimaryDark = Color(0xFF009e52);
const _kPrimaryLight = Color(0xFFe6fff4);
const _kSurface = Color(0xFFfafafa);
const _kCard = Colors.white;
const _kTextPrimary = Color(0xFF1a1a2e);
const _kTextSecondary = Color(0xFF6b7280);
const _kBorder = Color(0xFFe5e7eb);
const _kShadowLight = Color(0x0F000000);
const _kShadowMedium = Color(0x1A000000);

class SellerRegistrationScreen extends StatefulWidget {
  const SellerRegistrationScreen({super.key});

  @override
  State<SellerRegistrationScreen> createState() =>
      _SellerRegistrationScreenState();
}

class _SellerRegistrationScreenState extends State<SellerRegistrationScreen>
    with TickerProviderStateMixin {
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
  final _imageUrlController = TextEditingController();
  final _imageUrl2Controller = TextEditingController();
  final _mapUrlController = TextEditingController();

  bool _isSigningUp = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final List<String> _categories = [
    'Restaurant',
    'Bakery',
    'Supermarket',
    'Other',
  ];

  String? _existingShopId;

  // Animation controllers
  late AnimationController _pageAnimController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _pageAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.04, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _pageAnimController,
      curve: Curves.easeOutCubic,
    ));

    _pageAnimController.forward();
    _fadeController.forward();
    _checkExistingShop();
  }

  Future<void> _checkExistingShop() async {
    final user = _authService.currentUser;
    if (user != null) {
      setState(() => _isSigningUp = false);
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

            final geopoint = data['location']?['geopoint'] as GeoPoint?;
            if (geopoint != null) {
              _latController.text = geopoint.latitude.toString();
              _lngController.text = geopoint.longitude.toString();
            } else {
              _latController.text =
                  (data['location']?['lat'] ?? 0.0).toString();
              _lngController.text =
                  (data['location']?['lng'] ?? 0.0).toString();
            }

            final images = data['images'] as List<dynamic>?;
            if (images != null) {
              if (images.isNotEmpty) {
                _imageUrlController.text = images[0].toString();
              }
              if (images.length > 1) {
                _imageUrl2Controller.text = images[1].toString();
              }
            }
            _mapUrlController.text = data['mapUrl'] ?? '';
          });
        }
      } catch (e) {
        print("Error fetching existing shop: $e");
      }
    }
  }

  @override
  void dispose() {
    _pageAnimController.dispose();
    _fadeController.dispose();
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
    _imageUrl2Controller.dispose();
    _mapUrlController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('Location permissions are denied', isError: true);
          setState(() => _isLoading = false);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnack(
          'Location permissions are permanently denied.',
          isError: true,
        );
        setState(() => _isLoading = false);
        return;
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _latController.text = position.latitude.toString();
      _lngController.text = position.longitude.toString();
      _showSnack('Location captured successfully!');
    } catch (e) {
      _showSnack('Error getting location: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      UserCredential? credential =
          await _authService.signUpWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (credential != null && credential.user != null) {
        await _userService.saveUser(
          user: credential.user!,
          role: 'seller',
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
        );
        _animateToNextStep();
      }
    } catch (e) {
      _showSnack('Registration Failed: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _animateToNextStep() async {
    await _fadeController.reverse();
    setState(() => _isSigningUp = false);
    _pageAnimController.reset();
    _pageAnimController.forward();
    _fadeController.forward();
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
          if (_imageUrl2Controller.text.isNotEmpty)
            _imageUrl2Controller.text.trim(),
        ],
        'mapUrl': _mapUrlController.text.trim(),
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
        'isOpen': true,
        'rating': 0.0,
        'verificationStatus': 'pending',
        'isVerified': false,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_existingShopId != null) {
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(_existingShopId)
            .update(shopData);
        _showSnack('Shop updated! Resubmitted for approval.');
      } else {
        shopData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('shops').add(shopData);
        _showSnack('Shop created! Pending admin approval.');
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SellerDashboard()),
        (route) => false,
      );
    } catch (e) {
      _showSnack('Error saving shop: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFef4444) : _kPrimaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    child: Form(
                      key: _formKey,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: child,
                        ),
                        child: _isSigningUp
                            ? _buildSignupContent(key: const ValueKey('signup'))
                            : _buildShopContent(key: const ValueKey('shop')),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kPrimaryDark, _kPrimary],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.storefront_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Column(
                      key: ValueKey(_isSigningUp),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isSigningUp
                              ? 'Create Account'
                              : (_existingShopId != null
                                  ? 'Edit Shop'
                                  : 'Set Up Shop'),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isSigningUp
                              ? 'Join FoodNow as a seller'
                              : (_existingShopId != null
                                  ? 'Update your shop details'
                                  : 'Tell us about your shop'),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildStepIndicator(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _stepDot(1, 'Account', isActive: _isSigningUp, isDone: !_isSigningUp),
        _stepLine(!_isSigningUp),
        _stepDot(2, 'Shop', isActive: !_isSigningUp),
      ],
    );
  }

  Widget _stepDot(int num, String label,
      {bool isActive = false, bool isDone = false}) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive || isDone
                ? Colors.white
                : Colors.white.withOpacity(0.3),
            shape: BoxShape.circle,
            boxShadow: (isActive || isDone)
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check_rounded, color: _kPrimary, size: 18)
                : Text(
                    '$num',
                    style: TextStyle(
                      color: isActive ? _kPrimary : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive || isDone
                ? Colors.white
                : Colors.white.withOpacity(0.6),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _stepLine(bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        width: 40,
        height: 2,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  // ─── Signup Form ─────────────────────────────────────────────────────────────
  Widget _buildSignupContent({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        _buildCard(
          children: [
            _buildSectionLabel('Personal Information'),
            const SizedBox(height: 16),
            _buildField(
              controller: _nameController,
              label: 'Full Name',
              hint: 'John Doe',
              icon: Icons.person_outline_rounded,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _emailController,
              label: 'Email Address',
              hint: 'you@example.com',
              icon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              validator: (v) => !v!.contains('@') ? 'Invalid email' : null,
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _passwordController,
              label: 'Password',
              hint: 'Min. 6 characters',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              suffixIcon: GestureDetector(
                onTap: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    key: ValueKey(_obscurePassword),
                    color: _kTextSecondary,
                    size: 22,
                  ),
                ),
              ),
              validator: (v) => v!.length < 6 ? 'Minimum 6 characters' : null,
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _phoneController,
              label: 'Phone Number',
              hint: '+91 98765 43210',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _isLoading
            ? _buildLoadingButton()
            : _buildPrimaryButton(
                label: 'Continue to Shop Details',
                icon: Icons.arrow_forward_rounded,
                onTap: _registerUser,
              ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: _kTextSecondary),
            child: const Text(
              'Already have an account? Login',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Shop Form ───────────────────────────────────────────────────────────────
  Widget _buildShopContent({Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),

        // Basic Info Card
        _buildCard(
          children: [
            _buildSectionLabel('Shop Information'),
            const SizedBox(height: 16),
            _buildField(
              controller: _shopNameController,
              label: 'Shop Name',
              hint: 'e.g. The Green Kitchen',
              icon: Icons.storefront_outlined,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _buildCategoryDropdown(),
            const SizedBox(height: 16),
            _buildField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Describe your shop in a few words...',
              icon: Icons.notes_rounded,
              maxLines: 3,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Location Card
        _buildCard(
          children: [
            _buildSectionLabel('Location'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                    controller: _latController,
                    label: 'Latitude',
                    hint: '10.0261',
                    icon: Icons.gps_fixed_rounded,
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildField(
                    controller: _lngController,
                    label: 'Longitude',
                    hint: '76.3125',
                    icon: Icons.gps_not_fixed_rounded,
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildLocationButton(),
            const SizedBox(height: 16),
            _buildField(
              controller: _addressController,
              label: 'Full Address',
              hint: 'Street, City, State, Pincode',
              icon: Icons.home_outlined,
              maxLines: 2,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Media Card
        _buildCard(
          children: [
            _buildSectionLabel('Media & Links'),
            const SizedBox(height: 4),
            Text(
              'Add images and map links to help customers find you.',
              style: TextStyle(
                  fontSize: 13,
                  color: _kTextSecondary.withOpacity(0.8)),
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _imageUrlController,
              label: 'Image URL 1',
              hint: 'https://...',
              icon: Icons.image_outlined,
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _imageUrl2Controller,
              label: 'Image URL 2',
              hint: 'https://...',
              icon: Icons.photo_library_outlined,
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _mapUrlController,
              label: 'Google Maps URL',
              hint: 'https://maps.google.com/...',
              icon: Icons.map_outlined,
              suffixIcon: GestureDetector(
                onTap: () async {
                  final Uri url = Uri.parse('https://maps.google.com');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url,
                        mode: LaunchMode.externalApplication);
                  }
                },
                child: const Icon(Icons.open_in_new_rounded,
                    color: _kPrimary, size: 20),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        _isLoading
            ? _buildLoadingButton()
            : _buildPrimaryButton(
                label: _existingShopId != null
                    ? 'Update & Resubmit'
                    : 'Submit for Approval',
                icon: _existingShopId != null
                    ? Icons.update_rounded
                    : Icons.send_rounded,
                onTap: _submitShop,
              ),

        const SizedBox(height: 16),

        if (_existingShopId == null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kPrimaryLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kPrimary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: _kPrimary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your shop will be reviewed by an admin before going live.',
                    style: TextStyle(
                        fontSize: 13,
                        color: _kPrimaryDark.withOpacity(0.85)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ─── Reusable Widgets ────────────────────────────────────────────────────────

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: _kShadowLight, blurRadius: 12, offset: Offset(0, 2)),
          BoxShadow(
              color: _kShadowMedium, blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: _kPrimary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _kTextPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        color: _kTextPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
            color: _kTextSecondary.withOpacity(0.5), fontSize: 14),
        labelStyle:
            const TextStyle(color: _kTextSecondary, fontSize: 14),
        prefixIcon: Icon(icon, color: _kPrimary, size: 22),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _kSurface,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBorder, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBorder, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kPrimary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFef4444), width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFef4444), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _categoryController.text.isNotEmpty
          ? _categoryController.text
          : null,
      items: _categories
          .map((c) => DropdownMenuItem(
                value: c,
                child: Text(c,
                    style: const TextStyle(
                        color: _kTextPrimary, fontSize: 15)),
              ))
          .toList(),
      onChanged: (val) => setState(() => _categoryController.text = val!),
      validator: (v) => v == null ? 'Required' : null,
      style: const TextStyle(
          fontSize: 15, color: _kTextPrimary, fontWeight: FontWeight.w500),
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: _kPrimary, size: 24),
      dropdownColor: _kCard,
      decoration: InputDecoration(
        labelText: 'Category',
        labelStyle: const TextStyle(color: _kTextSecondary, fontSize: 14),
        prefixIcon:
            const Icon(Icons.category_outlined, color: _kPrimary, size: 22),
        filled: true,
        fillColor: _kSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBorder, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBorder, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kPrimary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: Color(0xFFef4444), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildLocationButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _getCurrentLocation,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding:
                const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: _kPrimary.withOpacity(0.4), width: 1.5),
              borderRadius: BorderRadius.circular(14),
              color: _kPrimaryLight,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.my_location_rounded,
                    color: _kPrimary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Use Current Location',
                  style: TextStyle(
                    color: _kPrimaryDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kPrimary, _kPrimaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _kPrimary.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 17),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(icon, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: _kPrimary.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }
}