import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class SellerEditScreen extends StatefulWidget {
  final DocumentSnapshot doc;

  const SellerEditScreen({super.key, required this.doc});

  @override
  State<SellerEditScreen> createState() => _SellerEditScreenState();
}

class _SellerEditScreenState extends State<SellerEditScreen> {
  late final TextEditingController nameController;
  late final TextEditingController addressController;
  late final TextEditingController emailController;
  final List<TextEditingController> imageControllers = [];
  late final TextEditingController mapUrlController;

  final Color _primaryGreen = const Color(0xFF00bf63);
  final Color _textPrimary = const Color(0xFF1A1C1E); // Deep Black
  final Color _textSecondary = const Color(0xFF6C757D); // Soft Grey
  final Color _borderColor = const Color(0xFFE9ECEF); // Thin border color
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.doc.data() as Map<String, dynamic>;

    nameController = TextEditingController(text: data['shopName']);
    addressController = TextEditingController(text: data['location']?['address'] ?? '');
    emailController = TextEditingController(text: data['publicEmail'] ?? '');

    final images = data['images'] as List?;
    if (images != null && images.isNotEmpty) {
      for (var url in images) {
        imageControllers.add(TextEditingController(text: url.toString()));
      }
    } else {
      imageControllers.add(TextEditingController());
    }

    mapUrlController = TextEditingController(text: data['mapUrl'] ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    addressController.dispose();
    emailController.dispose();
    for (var controller in imageControllers) {
      controller.dispose();
    }
    mapUrlController.dispose();
    super.dispose();
  }

  void _addImageField() {
    HapticFeedback.lightImpact();
    setState(() {
      imageControllers.add(TextEditingController());
    });
  }

  void _removeImageField(int index) {
    HapticFeedback.mediumImpact();
    setState(() {
      imageControllers[index].dispose();
      imageControllers.removeAt(index);
    });
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact();

    try {
      await FirebaseFirestore.instance.collection('shops').doc(widget.doc.id).update({
        'shopName': nameController.text.trim(),
        'publicEmail': emailController.text.trim(),
        'location.address': addressController.text.trim(),
        'images': imageControllers
            .map((c) => c.text.trim())
            .where((text) => text.isNotEmpty)
            .toList(),
        'mapUrl': mapUrlController.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Edit Profile', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w800)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionLabel("GENERAL INFORMATION"),
            _buildCard([
              _buildModernField(nameController, "Shop Name", Icons.store_rounded),
              const SizedBox(height: 12),
              _buildModernField(emailController, "Public Email", Icons.email_rounded),
              const SizedBox(height: 12),
              _buildModernField(addressController, "Address", Icons.location_on_rounded, maxLines: 2),
            ]),
            const SizedBox(height: 30),
            _buildSectionLabel("GOOGLE MAPS LINK"),
            _buildCard([
              _buildModernField(mapUrlController, "Map URL", Icons.map_rounded),
            ]),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionLabel("IMAGE GALLERY"),
                TextButton.icon(
                  onPressed: _addImageField,
                  icon: Icon(Icons.add, size: 18, color: _primaryGreen),
                  label: Text("ADD URL", style: TextStyle(color: _primaryGreen, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            ...imageControllers.asMap().entries.map((entry) => _buildImageEditTile(entry.key, entry.value)).toList(),
            const SizedBox(height: 40),
            _buildSaveButton(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        label,
        style: TextStyle(color: _textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildModernField(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w500, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _textSecondary, fontSize: 14),
        floatingLabelStyle: TextStyle(color: _primaryGreen, fontWeight: FontWeight.bold),
        prefixIcon: Icon(icon, color: _textSecondary, size: 20),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _borderColor, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryGreen, width: 1.5),
        ),
        filled: true,
        fillColor: const Color(0xFFFDFDFD),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
    );
  }

  Widget _buildImageEditTile(int index, TextEditingController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor, width: 1.0), // Outer thin border for the row
      ),
      child: Row(
        children: [
          // IMAGE PREVIEW BOX
          ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, value, child) {
              final url = controller.text.trim();
              return Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  image: url.isNotEmpty ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover) : null,
                ),
                child: url.isEmpty ? Icon(Icons.image_search, color: Colors.grey[400]) : null,
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(color: _textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Paste Image URL here",
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: InputBorder.none, // Kept borderless inside the row card for cleaner look
              ),
            ),
          ),
          if (imageControllers.length > 1)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
              onPressed: () => _removeImageField(index),
            ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveChanges,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryGreen,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
        ),
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text("SAVE CHANGES", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}