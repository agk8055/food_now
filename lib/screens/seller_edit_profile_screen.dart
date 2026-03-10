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
  final List<TextEditingController> imageControllers = [];
  late final TextEditingController mapUrlController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.doc.data() as Map<String, dynamic>;

    nameController = TextEditingController(text: data['shopName']);
    addressController = TextEditingController(
      text: data['location']?['address'] ?? '',
    );
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
    setState(() {
      imageControllers.add(TextEditingController());
    });
  }

  void _removeImageField(int index) {
    setState(() {
      imageControllers[index].dispose();
      imageControllers.removeAt(index);
    });
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
            'images': imageControllers
                .map((c) => c.text.trim())
                .where((text) => text.isNotEmpty)
                .toList(),
            'mapUrl': mapUrlController.text.trim(),
          });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
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
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Shop Images",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            ...imageControllers.asMap().entries.map((entry) {
              int idx = entry.key;
              TextEditingController controller = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          labelText: "Image URL ${idx + 1}",
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    if (imageControllers.length > 1)
                      IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => _removeImageField(idx),
                      ),
                  ],
                ),
              );
            }).toList(),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _addImageField,
                icon: const Icon(Icons.add),
                label: const Text("ADD IMAGE"),
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
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
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
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "SAVE CHANGES",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
