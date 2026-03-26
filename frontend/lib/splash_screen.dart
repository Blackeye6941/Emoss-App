import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  _navigateToNext() async {
    await Future.delayed(const Duration(milliseconds: 2500));
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/disclaimer');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F12),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing Logo Concept
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6C63FF).withOpacity(0.5),
                    Colors.transparent,
                  ],
                ),
              ),
              child: const Icon(
                Icons.spa_rounded,
                size: 60,
                color: Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "EMOSS",
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w900,
                letterSpacing: 12,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "OFFLINE SANCTUARY",
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 4,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}