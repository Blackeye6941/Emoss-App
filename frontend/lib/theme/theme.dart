import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class T {
  static const bg = Color(0xFF000000);
  static const surface = Color(0xFF0D0D0D);
  static const surfaceHi = Color(0xFF1A1A1A);
  static const border = Color(0xFF262626);
  static const sage = Color(0xFF40916C); // Soothing green
  static const gold = Color(0xFFD4A96A);
  static const textHi = Color(0xFFF8F9FA);
  static const textMid = Color(0xFFADB5BD);
  static const textLo = Color(0xFF6C757D);
  static const userBubble = Color(0xFF1B4332);
  static const aiBubble = Color(0xFF121212);

  static ThemeData get theme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
            primary: sage, secondary: gold, surface: surface),
        textTheme: GoogleFonts.jetBrainsMonoTextTheme(ThemeData.dark().textTheme)

            .apply(bodyColor: textHi, displayColor: textHi),
        appBarTheme: AppBarTheme(
          backgroundColor: bg,
          elevation: 0,
          titleTextStyle: GoogleFonts.playfairDisplay(
              color: textHi, fontSize: 24, fontWeight: FontWeight.w700),
          iconTheme: const IconThemeData(color: textHi),
        ),
      );
}
