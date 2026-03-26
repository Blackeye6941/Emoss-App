import 'package:flutter/material.dart';

class EmossSidebar extends StatelessWidget {
  const EmossSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF0F0F12),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [

          // Header
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFF1A1A1D),
            ),
            child: Text(
              "EMOSS",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // New Chat
          ListTile(
            leading: const Icon(Icons.add, color: Colors.white),
            title: const Text(
              "New Chat",
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
            },
          ),

          // History
          ListTile(
            leading: const Icon(Icons.history, color: Colors.white),
            title: const Text(
              "History",
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {},
          ),

          // Settings
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.white),
            title: const Text(
              "Settings",
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {},
          ),

          // Privacy
          ListTile(
            leading: const Icon(Icons.lock, color: Colors.white),
            title: const Text(
              "Privacy",
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}