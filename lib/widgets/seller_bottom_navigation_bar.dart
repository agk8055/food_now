import 'package:flutter/material.dart';

class SellerBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const SellerBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: selectedIndex,
      onTap: onItemTapped,
      selectedItemColor: const Color(0xFF00bf63), // App primary green
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long_outlined),
          activeIcon: Icon(Icons.receipt_long),
          label: 'Orders',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_outlined),
          activeIcon: Icon(Icons.inventory_2),
          label: 'Inventory',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_outlined),
          activeIcon: Icon(Icons.bar_chart),
          label: 'Analytics',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.store_outlined),
          activeIcon: Icon(Icons.store),
          label: 'Shop',
        ),
      ],
    );
  }
}