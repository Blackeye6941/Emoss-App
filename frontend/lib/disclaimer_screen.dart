import 'package:flutter/material.dart';

class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 30),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A22), Color(0xFF0F0F12)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield_moon_outlined, size: 80, color: Color(0xFF6C63FF)),
            const SizedBox(height: 40),
            const Text(
              "Safe & Private",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              "EMOSS is a 100% offline emotional support tool. Your conversations never leave this device. We are here to listen, but we are not a medical replacement.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7), height: 1.5),
            ),
            const SizedBox(height: 50),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 10,
                  shadowColor: const Color(0xFF6C63FF).withOpacity(0.4),
                ),
                onPressed: () => Navigator.pushReplacementNamed(context, '/chat'),
                child: const Text(
                  "ENTER SANCTUARY",
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}