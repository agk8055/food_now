import 'package:flutter/material.dart';
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
  late final TextEditingController imageController;
  late final TextEditingController image2Controller;
  late final TextEditingController mapUrlController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.doc.data() as Map<String, dynamic>;

    nameController = TextEditingController(text: data['shopName']);
    addressController = TextEditingController(text: data['location']?['address'] ?? '');
    emailController = TextEditingController(text: data['publicEmail'] ?? '');
    imageController = TextEditingController(
      text: (data['images'] as List?)?.isNotEmpty == true ? (data['images'] as List).first : '',
    );
    image2Controller = TextEditingController(
      text: (data['images'] as List?) != null && (data['images'] as List).length > 1
          ? (data['images'] as List)[1]
          : '',
    );
    mapUrlController = TextEditingController(text: data['mapUrl'] ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    addressController.dispose();
    emailController.dispose();
    imageController.dispose();
    image2Controller.dispose();
    mapUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.doc.id)
          .update({
        'shopName': nameController.text.trim(),
        'publicEmail': emailController.text.trim(),
        'location.address': addressController.text.trim(),
        'images': [
          if (imageController.text.trim().isNotEmpty) imageController.text.trim(),
          if (image2Controller.text.trim().isNotEmpty) image2Controller.text.trim(),
        ],
        'mapUrl': mapUrlController.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Shop Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Shop Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: "Public Contact Email",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: "Address",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: imageController,
              decoration: const InputDecoration(
                labelText: "Image URL 1",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: image2Controller,
              decoration: const InputDecoration(
                labelText: "Image URL 2 (Optional)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: mapUrlController,
              decoration: InputDecoration(
                labelText: "Google Map URL (Optional)",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.open_in_new),
                  tooltip: 'Open Google Maps to copy link',
                  onPressed: () async {
                    final Uri url = Uri.parse('https://maps.google.com');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00bf63),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        "SAVE CHANGES",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
