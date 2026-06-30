import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/services.dart';
import '../theme/theme.dart';

class OfflinePill extends StatelessWidget {
  const OfflinePill({super.key});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          color: T.sage.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: T.sage.withOpacity(0.25))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, size: 12, color: T.sage),
        const SizedBox(width: 4),
        Text('offline',
            style: GoogleFonts.sourceCodePro(
                color: T.sage, fontSize: 10, letterSpacing: 0.5)),
      ]));
}

class StatusDot extends StatelessWidget {
  final Color color;
  final String tooltip;
  const StatusDot({super.key, required this.color, required this.tooltip});

  @override
  Widget build(BuildContext context) => Tooltip(
      message: tooltip,
      child: Container(
          margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)));
}

class AiAvatar extends StatelessWidget {
  const AiAvatar({super.key});

  @override
  Widget build(BuildContext context) => Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
          color: T.sage.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: T.sage.withOpacity(0.3))),
      child: Center(
        child: Image.asset(
          'assets/logo/emo.png',
          width: 20,
          height: 20,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.shield_moon_rounded,
            color: T.sage,
            size: 16,
          ),
        ),
      ));
}

class EmotionBadge extends StatelessWidget {
  final String emotion;
  const EmotionBadge(this.emotion, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = EmotionDetector.getEmotionColor(emotion);
    return Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: c.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.withOpacity(0.2))),
        child: Text(emotion.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
                color: c, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)));
  }
}
