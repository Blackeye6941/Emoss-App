import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/services.dart';
import '../theme/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fade, _pulse;

  @override
  void initState() {
    super.initState();
    _fade = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..forward();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    TinyLlamaService().addListener(_check);
    Future.delayed(const Duration(seconds: 3), _go);
  }

  void _check() {
    if (TinyLlamaService().isReady) _go();
  }

  void _go() {
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  void dispose() {
    TinyLlamaService().removeListener(_check);
    _fade.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: T.bg,
        body: FadeTransition(
          opacity: CurvedAnimation(parent: _fade, curve: Curves.easeIn),
          child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                ScaleTransition(
                  scale: Tween(begin: 0.88, end: 1.0).animate(
                      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
                  child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: T.sage.withOpacity(0.2), width: 2),
                          gradient: RadialGradient(colors: [
                            T.sage.withOpacity(0.1),
                            Colors.transparent
                          ])),
                      child: Center(
                        child: Image.asset(
                          'assets/logo/emo.png',
                          width: 60,
                          height: 60,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.shield_moon_rounded,
                            color: T.sage,
                            size: 60,
                          ),
                        ),
                      )),
                ),
                const SizedBox(height: 32),
                Text('EMO',
                    style: GoogleFonts.playfairDisplay(
                        fontSize: 64,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 16,
                        color: T.textHi)),
                const SizedBox(height: 12),
                Text('YOUR PRIVATE SANCTUARY',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 6,
                        color: T.textLo)),
                const SizedBox(height: 48),
                ListenableBuilder(
                  listenable: TinyLlamaService(),
                  builder: (_, __) {
                    final s = TinyLlamaService();
                    return switch (s.state) {
                      ModelState.ready => Text('● AI ready',
                          style: GoogleFonts.sourceCodePro(
                              fontSize: 11, color: T.sage, letterSpacing: 2)),
                      ModelState.error => Text('⚠ ${s.errorMsg}',
                          style: GoogleFonts.sourceCodePro(
                              fontSize: 11, color: Colors.redAccent)),
                      _ => Column(children: [
                          SizedBox(
                              width: 150,
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                      value: s.loadProgress,
                                      backgroundColor: T.surfaceHi,
                                      color: T.sage,
                                      minHeight: 2))),
                          const SizedBox(height: 10),
                          Text(
                              s.loadProgress < 0.30
                                  ? 'Extracting native library…'
                                  : s.loadProgress < 0.85
                                      ? 'Copying AI model…'
                                      : 'Loading weights…',
                              style: GoogleFonts.sourceCodePro(
                                  fontSize: 10,
                                  color: T.textLo,
                                  letterSpacing: 2)),
                        ]),
                    };
                  },
                ),
              ])),
        ),
      );
}
