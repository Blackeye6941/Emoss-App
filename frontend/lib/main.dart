import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'emotion_classifier.dart';
import 'models/models.dart';
import 'screens/emergency_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/services.dart';
import 'theme/theme.dart';

// ============================================================
// EMO — OFFLINE EMOTIONAL SUPPORT ASSISTANT
// Flutter + Hive + TinyLlama (llamadart 0.6.10, on-device)
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF000000),
  ));
  await Hive.initFlutter();
  Hive.registerAdapter(MessageModelAdapter());
  Hive.registerAdapter(ConversationModelAdapter());
  await Hive.openBox<ConversationModel>('conversations');
  await Hive.openBox<MessageModel>('messages');
  await EmotionClassifier.initialize();
  TinyLlamaService().initialize(); // background, non-blocking
  runApp(const EMO());
}

class EMO extends StatelessWidget {
  const EMO({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'EMO',
        debugShowCheckedModeBanner: false,
        theme: T.theme,
        home: const SplashScreen(),
        routes: {
          '/home': (_) => const HomeScreen(),
          '/emergency': (_) => const EmergencyScreen()
        },
      );
}
