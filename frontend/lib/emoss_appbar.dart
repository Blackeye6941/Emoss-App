import 'package:flutter/material.dart';

class EmossAppBar extends StatefulWidget implements PreferredSizeWidget {
  @override
  _EmossAppBarState createState() => _EmossAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(80); // Taller for better visual flow
}

class _EmossAppBarState extends State<EmossAppBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // Slow, calming animation
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return AppBar(
          backgroundColor: const Color(0xFF0F0F12),
          elevation: 0,
          centerTitle: true,
          leading: Builder(
          builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
          Scaffold.of(context).openDrawer();
    },
  ),
),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0.5),
                radius: 1.5,
                colors: [
                 const Color(0xFF0F0F12).withOpacity(0.5 + 0.5 * _controller.value),
                  const Color(0xFF0F0F12),
                ],
              ),
            ),
          ),
          title: Column(
            children: [
              Text(
                "EMOSS",
                style: TextStyle(
                  letterSpacing: 4 * _controller.value,
                  fontWeight: FontWeight.w800,
                  fontSize: 26 + 4 * _controller.value, // Subtle size increase
                  color: Color.fromRGBO(75, 69, 178, 1)  ),
              ),
            ],
          ),
          actions: [
            _buildEmergencyButton(),
          ],
        );
      },
    );
  }

  Widget _buildEmergencyButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulsing ring for the emergency button
            Container(
              width: 35 * _controller.value + 10,
              height: 35 * _controller.value + 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.redAccent.withOpacity(1 - _controller.value),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.crisis_alert, color: Colors.redAccent),
              onPressed: () => Navigator.pushNamed(context, '/emergency'),
            ),
          ],
        ),
      ),
    );
  }
}