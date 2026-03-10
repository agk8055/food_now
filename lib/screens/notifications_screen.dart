import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../widgets/custom_loader.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final User? _user = FirebaseAuth.instance.currentUser;

  Future<void> _updateSetting(String key, bool value) async {
    if (_user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
        'notificationSettings': {key: value},
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update setting: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Notifications")),
        body: const Center(child: Text("Please log in to view settings.")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          "Notification Settings",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_user!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CustomLoader());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final settings =
              userData['notificationSettings'] as Map<String, dynamic>? ?? {};

          // Default all toggleable notifications to true if not explicitly set to false
          final bool favoriteAlerts = settings['favoriteAlerts'] ?? true;
          final bool pickupReminders = settings['pickupReminders'] ?? true;
          final bool promotions = settings['promotions'] ?? true;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            children: [
              _buildSectionTitle("Orders"),
              _buildSettingTile(
                title: "Order Updates",
                subtitle:
                    "Confirmations, cancellations, and pickup completion.",
                value: true,
                onChanged: null, // null makes it disabled
                icon: Icons.receipt_long_rounded,
                isMandatory: true,
              ),
              const SizedBox(height: 24),

              _buildSectionTitle("Alerts & Reminders"),
              _buildSettingTile(
                title: "Favorite Shop Alerts",
                subtitle:
                    "Get notified when your favorite shops add new surplus food.",
                value: favoriteAlerts,
                onChanged: (val) => _updateSetting('favoriteAlerts', val),
                icon: Icons.favorite_rounded,
              ),
              _buildSettingTile(
                title: "Pickup Reminders",
                subtitle: "Alerts when your reserved order is about to expire.",
                value: pickupReminders,
                onChanged: (val) => _updateSetting('pickupReminders', val),
                icon: Icons.access_time_filled_rounded,
              ),
              const SizedBox(height: 24),

              _buildSectionTitle("Offers"),
              _buildSettingTile(
                title: "Promotions & Announcements",
                subtitle: "Special offers, discounts, and app updates.",
                value: promotions,
                onChanged: (val) => _updateSetting('promotions', val),
                icon: Icons.local_offer_rounded,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.grey[500],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool)? onChanged,
    required IconData icon,
    bool isMandatory = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        activeColor: const Color(0xFF00bf63),
        title: Row(
          children: [
            Icon(
              icon,
              color: isMandatory ? Colors.grey : const Color(0xFF00bf63),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0, left: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              if (isMandatory)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    "Mandatory for core app functionality",
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
