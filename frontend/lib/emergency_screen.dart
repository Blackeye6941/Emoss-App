import 'package:flutter/material.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F12),
      appBar: AppBar(title: const Text("Support Resources")),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const Spacer(),
            const Icon(Icons.favorite, color: Colors.redAccent, size: 100),
            const SizedBox(height: 30),
            const Text(
              "You Matter.",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              "If you are in immediate danger or need to talk to a human professional, please reach out to the resources below.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.6), height: 1.5),
            ),
            const Spacer(),
            _emergencyButton("Call Local Emergency", Colors.redAccent, Icons.phone),
            const SizedBox(height: 15),
            _emergencyButton("Text a Crisis Line", Colors.white12, Icons.message),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _emergencyButton(String title, Color color, IconData icon) {
    return SizedBox(
      width: double.infinity,
      height: 65,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        onPressed: () {}, // Action for local dialer
        icon: Icon(icon, color: Colors.white),
        label: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }
}