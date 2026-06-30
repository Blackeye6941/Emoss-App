import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/theme.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: T.bg,
        appBar: AppBar(
            backgroundColor: T.bg,
            centerTitle: true,
            leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: T.textMid, size: 18),
                onPressed: () => Navigator.pop(context)),
            title: Text('YOU MATTER',
                style: GoogleFonts.playfairDisplay(
                    color: T.textHi,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2))),
        body: SingleChildScrollView(
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(children: [
                const SizedBox(height: 40),
                TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.9, end: 1.05),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeInOut,
                    builder: (_, s, c) => Transform.scale(scale: s, child: c),
                    child: const Icon(Icons.favorite_rounded,
                        color: Colors.redAccent, size: 90)),
                const SizedBox(height: 32),
                Text('You are not alone.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.playfairDisplay(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: T.textHi)),
                const SizedBox(height: 16),
                Text(
                    'If you are in immediate danger or need to speak to a trained professional, please reach out below.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 16, color: T.textMid, height: 1.6)),
                const SizedBox(height: 40),
                const _EBtn(
                    label: 'Call Emergency Services',
                    icon: Icons.phone_rounded,
                    color: Colors.redAccent),
                const SizedBox(height: 16),
                const _EBtn(
                    label: 'Text a Crisis Counselor',
                    icon: Icons.message_rounded,
                    color: T.surfaceHi),
                const SizedBox(height: 16),
                const _EBtn(
                    label: 'iCall (India): 9152987821',
                    icon: Icons.support_agent_rounded,
                    color: T.surface),
                const SizedBox(height: 32),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("I'm safe — take me back",
                        style: GoogleFonts.jetBrainsMono(
                            color: T.textLo,
                            fontSize: 14,
                            fontWeight: FontWeight.w500))),
                const SizedBox(height: 20),
              ])),
        ),
      );
}

class _EBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _EBtn({required this.label, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: color,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16))),
          onPressed: () {/* TODO: url_launcher → tel: / sms: */},
          icon: Icon(icon, color: Colors.white, size: 22),
          label: Text(label,
              style: GoogleFonts.jetBrainsMono(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16))));
}
