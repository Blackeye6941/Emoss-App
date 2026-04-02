// ============================================================
// EMOSS — OFFLINE EMOTIONAL SUPPORT ASSISTANT
// Flutter + Hive + TinyLlama (llama_cpp_dart 0.2.2, on-device)
// ============================================================
//
// ── pubspec.yaml ─────────────────────────────────────────────
//
// dependencies:
//   flutter:
//     sdk: flutter
//   hive: ^2.2.3
//   hive_flutter: ^1.1.0
//   path_provider: ^2.1.2
//   uuid: ^4.3.3
//   intl: ^0.19.0
//   google_fonts: ^6.1.0
//   llama_cpp_dart: ^0.2.2
//
// dev_dependencies:
//   hive_generator: ^2.0.1
//   build_runner: ^2.4.8
//
// flutter:
//   assets:
//     - assets/models/tinyllama.gguf
//     - assets/libs/libllama.so        ← compiled ARM64 .so (see below)
//
// ── CRITICAL: You must compile libllama.so yourself ──────────
//
//   git clone https://github.com/ggml-org/llama.cpp
//   cd llama.cpp
//   mkdir build-android && cd build-android
//   cmake .. \
//     -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
//     -DANDROID_ABI=arm64-v8a \
//     -DANDROID_PLATFORM=android-24 \
//     -DBUILD_SHARED_LIBS=ON \
//     -DLLAMA_BUILD_TESTS=OFF \
//     -DLLAMA_BUILD_EXAMPLES=OFF
//   cmake --build . --config Release -j8
//   cp libllama.so /your_project/assets/libs/libllama.so
//
// ── android/app/build.gradle.kts ─────────────────────────────
//   minSdk = 24
//   ndkVersion = "25.2.9519653"
//   ndk { abiFilters += listOf("arm64-v8a") }
//
// ── AndroidManifest.xml <application> tag ────────────────────
//   android:extractNativeLibs="true"
//
// ── After setup ───────────────────────────────────────────────
//   flutter pub get
//   dart run build_runner build
// ============================================================

// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:llamadart/llamadart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
//import 'dart:ffi' as ffi;
// ─────────────────────────────────────────────────────────────
// HIVE MODELS
// ─────────────────────────────────────────────────────────────

part 'main.g.dart'; // dart run build_runner build

@HiveType(typeId: 0)
class MessageModel extends HiveObject {
  @HiveField(0)
  late String id;
  @HiveField(1)
  late String conversationId;
  @HiveField(2)
  late String content;
  @HiveField(3)
  late bool isUser;
  @HiveField(4)
  late DateTime timestamp;
  @HiveField(5)
  late String emotion;
  @HiveField(6)
  late double emotionConfidence;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.content,
    required this.isUser,
    required this.timestamp,
    required this.emotion,
    required this.emotionConfidence,
  });
}

@HiveType(typeId: 1)
class ConversationModel extends HiveObject {
  @HiveField(0)
  late String id;
  @HiveField(1)
  late String title;
  @HiveField(2)
  late DateTime createdAt;
  @HiveField(3)
  late DateTime updatedAt;
  @HiveField(4)
  late String lastMessage;
  @HiveField(5)
  late String dominantEmotion;

  ConversationModel({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.lastMessage,
    required this.dominantEmotion,
  });
}

// ─────────────────────────────────────────────────────────────
// EMOTION DETECTOR
// ─────────────────────────────────────────────────────────────

class EmotionDetector {
  static const Map<String, List<String>> _keywords = {
    'joy': [
      'happy',
      'excited',
      'great',
      'amazing',
      'wonderful',
      'thrilled',
      'proud',
      'love',
      'fantastic',
      'excellent',
      'promoted',
      'celebrate',
      'elated',
      'delighted',
      'cheerful',
      'grateful',
      'blessed',
      'overjoyed'
    ],
    'sadness': [
      'sad',
      'depress',
      'cry',
      'lonely',
      'hopeless',
      'grief',
      'loss',
      'empty',
      'numb',
      'worthless',
      'miss',
      'alone',
      'hurt',
      'broken',
      'miserable',
      'devastated',
      'heartbroken',
      'tears',
      'weeping'
    ],
    'anger': [
      'angry',
      'anger',
      'furious',
      'rage',
      'frustrated',
      'irritated',
      'annoyed',
      'mad',
      'upset',
      'blame',
      'unfair',
      'hate',
      'livid',
      'outraged',
      'infuriated',
      'resentful',
      'bitter',
      'hostile'
    ],
    'fear': [
      'scared',
      'afraid',
      'anxious',
      'anxiety',
      'fear',
      'terror',
      'panic',
      'worry',
      'overwhelm',
      'stress',
      'nervous',
      'terrified',
      'dread',
      'phobia',
      'uneasy',
      'apprehensive',
      'shaking'
    ],
    'disgust': [
      'disgust',
      'sick',
      'gross',
      'repuls',
      'awful',
      'horrible',
      'revolting',
      'nauseating',
      'vile',
      'repugnant'
    ],
    'surprise': [
      'surprise',
      'shock',
      'unexpected',
      'sudden',
      'unbelievable',
      'wow',
      'omg',
      'cant believe',
      'astonished',
      'stunned',
      'speechless'
    ],
  };

  static MapEntry<String, double> detect(String text) {
    final lower = text.toLowerCase();
    final scores = <String, int>{};
    for (final e in _keywords.entries) {
      final c = e.value.where((kw) => lower.contains(kw)).length;
      if (c > 0) scores[e.key] = c;
    }
    if (scores.isEmpty) return const MapEntry('neutral', 0.5);
    final best = scores.entries.reduce((a, b) => a.value > b.value ? a : b);
    return MapEntry(best.key, (0.6 + best.value * 0.1).clamp(0.6, 0.95));
  }

  static Color getEmotionColor(String e) => switch (e) {
        'joy' => const Color(0xFFF5C842),
        'sadness' => const Color(0xFF6BA3D6),
        'anger' => const Color(0xFFE05C5C),
        'fear' => const Color(0xFFAA7CE8),
        'disgust' => const Color(0xFF6DBF6D),
        'surprise' => const Color(0xFFFF9F5E),
        _ => const Color(0xFF8A9BB0),
      };

  static String getEmotionEmoji(String e) => switch (e) {
        'joy' => '✨',
        'sadness' => '🌧',
        'anger' => '🔥',
        'fear' => '🌀',
        'disgust' => '😣',
        'surprise' => '💫',
        _ => '🌿',
      };
}

// ─────────────────────────────────────────────────────────────
// CRISIS DETECTOR
// ─────────────────────────────────────────────────────────────

class CrisisDetector {
  static const _kw = [
    'kill myself',
    'want to die',
    'end my life',
    'take my life',
    'commit suicide',
    'suicidal',
    'suicide',
    'no reason to live',
    'better off dead',
    'wish i was dead',
    "don't want to be alive",
    'want to disappear',
    "can't go on",
    'ending it all',
    'hurt myself',
    'self harm',
    'self-harm',
    'cutting myself',
    'harming myself',
    'injure myself',
    'overdose',
    'jump off',
    'hang myself',
    'goodbye forever',
    'nobody would miss me',
  ];
  static bool isCrisis(String t) => _kw.any((k) => t.toLowerCase().contains(k));
}

// ─────────────────────────────────────────────────────────────
// ASSET EXTRACTOR
// Copies GGUF + libllama.so from Flutter assets → writable disk.
// On subsequent launches it reuses the cached files instantly.
// ─────────────────────────────────────────────────────────────

class AssetExtractor {
  static String? _modelPath;

  static Future<String> _extract(
    String assetKey,
    String fileName, {
    void Function(double)? onProgress,
  }) async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/$fileName');
    if (!file.existsSync()) {
      onProgress?.call(0.0);
      final data = await rootBundle.load(assetKey);
      // 2. Write it all at once synchronously to ensure no 'busy' file handles
      // This is much safer for the C++ engine to read later
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        mode: FileMode.write,
        flush: true, // This forces the OS to finish the write before moving on
      );

      onProgress?.call(1.0);
    }
    return file.path;
  }

  static Future<String> getModelPath(
      {void Function(double)? onProgress}) async {
    _modelPath ??= await _extract(
        'assets/models/tinyllama.gguf', 'tinyllama.gguf',
        onProgress: onProgress);
    return _modelPath!;
  }
}

// ─────────────────────────────────────────────────────────────
// TINYLLAMA SERVICE  (llama_cpp_dart 0.2.2 — LlamaParent API)
//
// 0.2.2 uses a managed-isolate approach:
//   • LlamaLoad       — configuration object
//   • LlamaParent     — runs inference in a Dart isolate (non-blocking)
//   • parent.stream   — Stream<String> of generated tokens
//   • parent.sendPrompt(text) — feeds a prompt into the isolate
//
// The package does NOT ship libllama.so — you compile it yourself
// (see instructions at the top of this file) and load it via:
//   Llama.libraryPath = "/path/to/libllama.so"
// ─────────────────────────────────────────────────────────────

enum ModelState { uninitialized, loading, ready, error }

class TinyLlamaService extends ChangeNotifier {
  static final TinyLlamaService _i = TinyLlamaService._();
  factory TinyLlamaService() => _i;
  TinyLlamaService._();

  LlamaParent? _parent;
  ModelState _state = ModelState.uninitialized;
  double _loadProgress = 0.0;
  String? _errorMsg;

  ModelState get state => _state;
  double get loadProgress => _loadProgress;
  String? get errorMsg => _errorMsg;
  bool get isReady => _state == ModelState.ready;

  static const Map<String, String> _systemPrompts = {
    'joy': 'You are EMOSS, a warm empathetic companion. '
        'The user is joyful. Celebrate with genuine warmth and ask one '
        'thoughtful follow-up question. Reply in 2–3 sentences only.',
    'sadness': 'You are EMOSS, a compassionate listener. '
        'The user is sad or lonely. Acknowledge their pain gently and invite '
        'them to share more. Reply in 2–3 sentences only.',
    'anger': 'You are EMOSS, a calm steady companion. '
        'The user is angry or frustrated. Validate their feeling without '
        'escalating, then gently explore what happened. Reply in 2–3 sentences only.',
    'fear': 'You are EMOSS, a reassuring companion. '
        'The user is anxious or scared. Be soothing, acknowledge the feeling, '
        'and help them feel grounded. Reply in 2–3 sentences only.',
    'disgust': 'You are EMOSS, a patient non-judgmental companion. '
        'The user feels repulsed or bothered. Acknowledge what they feel and '
        'help them process it calmly. Reply in 2–3 sentences only.',
    'surprise': 'You are EMOSS, a curious warm companion. '
        'The user was caught off guard. React with genuine interest and help '
        'them process the unexpected event. Reply in 2–3 sentences only.',
    'neutral': 'You are EMOSS, a kind empathetic emotional support companion. '
        'Listen carefully, respond with warmth, and ask one thoughtful '
        'question to help the user open up. Reply in 2–3 sentences only.',
  };

  // ── Initialize ───────────────────────────────────────────────

  LlamaEngine? _engine;

  Future<void> initialize() async {
    if (_state == ModelState.loading || _state == ModelState.ready) return;
    _set(ModelState.loading, p: 0.0);

    try {
      final dir = await getApplicationSupportDirectory();
      final modelFile = File('${dir.path}/tinyllama.gguf');

      if (!modelFile.existsSync()) {
        final data = await rootBundle.load('assets/models/tinyllama.gguf');
        final bytes = data.buffer.asUint8List();
        const chunk = 4 * 1024 * 1024;
        final sink = modelFile.openWrite();
        int written = 0;
        while (written < bytes.length) {
          final end = (written + chunk).clamp(0, bytes.length);
          sink.add(bytes.sublist(written, end));
          written = end;
          _set(ModelState.loading, p: written / bytes.length * 0.85);
        }
        await sink.close();
      }

      _set(ModelState.loading, p: 0.90);

      _engine = LlamaEngine(LlamaBackend());
      await _engine!.loadModel(modelFile.path);

      _set(ModelState.ready, p: 1.0);
    } catch (e, st) {
      _errorMsg = e.toString();
      debugPrint('TinyLlama init error: $e\n$st');
      _set(ModelState.error);
    }
  }

  Stream<String> streamResponse(String userMsg, String emotion) async* {
    if (_engine == null) {
      yield "Still loading — give me a second.";
      return;
    }

    final system = _systemPrompts[emotion] ?? _systemPrompts['neutral']!;
    final messages = [
      LlamaChatMessage(role: 'system', content: system),
      LlamaChatMessage(role: 'user', content: userMsg),
    ];

    try {
      await for (final token in _engine!.chat(messages)) {
        yield token;
      }
    } catch (e) {
      yield '\n\n[Error: $e]';
    }
  }

  @override
  void dispose() {
    _engine?.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────
// HIVE SERVICE
// ─────────────────────────────────────────────────────────────

class HiveService {
  static const _uuid = Uuid();
  static Box<ConversationModel> get _cb => Hive.box('conversations');
  static Box<MessageModel> get _mb => Hive.box('messages');

  static Future<ConversationModel> createConversation(String msg) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    final c = ConversationModel(
        id: id,
        title: msg.length > 40 ? '${msg.substring(0, 40)}…' : msg,
        createdAt: now,
        updatedAt: now,
        lastMessage: msg,
        dominantEmotion: 'neutral');
    await _cb.put(id, c);
    return c;
  }

  static List<ConversationModel> getAllConversations() =>
      _cb.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  static Future<void> updateConversation(
      String id, String last, String emo) async {
    final c = _cb.get(id);
    if (c != null) {
      c
        ..lastMessage = last
        ..updatedAt = DateTime.now()
        ..dominantEmotion = emo;
      await c.save();
    }
  }

  static Future<void> deleteConversation(String id) async {
    for (final m in _mb.values.where((m) => m.conversationId == id))
      await _mb.delete(m.id);
    await _cb.delete(id);
  }

  static Future<MessageModel> saveMessage({
    required String conversationId,
    required String content,
    required bool isUser,
    required String emotion,
    required double emotionConfidence,
  }) async {
    final id = _uuid.v4();
    final m = MessageModel(
        id: id,
        conversationId: conversationId,
        content: content,
        isUser: isUser,
        timestamp: DateTime.now(),
        emotion: emotion,
        emotionConfidence: emotionConfidence);
    await _mb.put(id, m);
    return m;
  }

  static List<MessageModel> getMessages(String cid) =>
      _mb.values.where((m) => m.conversationId == cid).toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  static int get totalConversations => _cb.length;
}

// ─────────────────────────────────────────────────────────────
// THEME — deep forest-night
// ─────────────────────────────────────────────────────────────

class T {
  static const bg = Color(0xFF0C110E);
  static const surface = Color(0xFF141A16);
  static const surfaceHi = Color(0xFF1C2620);
  static const border = Color(0xFF28352C);
  static const sage = Color(0xFF7EB89A);
  static const gold = Color(0xFFD4A96A);
  static const textHi = Color(0xFFEAF0EC);
  static const textMid = Color(0xFF8FA898);
  static const textLo = Color(0xFF4A5E52);
  static const userBubble = Color(0xFF1E3828);
  static const aiBubble = Color(0xFF161D18);

  static ThemeData get theme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        colorScheme: const ColorScheme.dark(
            primary: sage, secondary: gold, surface: surface),
        textTheme: GoogleFonts.sourceSerif4TextTheme(ThemeData.dark().textTheme)
            .apply(bodyColor: textHi, displayColor: textHi),
        appBarTheme: AppBarTheme(
          backgroundColor: surface,
          elevation: 0,
          titleTextStyle: GoogleFonts.cormorantGaramond(
              color: textHi, fontSize: 22, fontWeight: FontWeight.w600),
          iconTheme: const IconThemeData(color: textMid),
        ),
      );
}

// ─────────────────────────────────────────────────────────────
// MAIN
// ─────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0C110E),
  ));
  await Hive.initFlutter();
  Hive.registerAdapter(MessageModelAdapter());
  Hive.registerAdapter(ConversationModelAdapter());
  await Hive.openBox<ConversationModel>('conversations');
  await Hive.openBox<MessageModel>('messages');
  TinyLlamaService().initialize(); // background, non-blocking
  runApp(const EmossApp());
}

class EmossApp extends StatelessWidget {
  const EmossApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'EMOSS',
        debugShowCheckedModeBanner: false,
        theme: T.theme,
        home: const SplashScreen(),
        routes: {
          '/home': (_) => const HomeScreen(),
          '/emergency': (_) => const EmergencyScreen()
        },
      );
}

// ─────────────────────────────────────────────────────────────
// SPLASH SCREEN
// ─────────────────────────────────────────────────────────────

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
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: T.sage.withOpacity(0.35), width: 1.5),
                          gradient: RadialGradient(colors: [
                            T.sage.withOpacity(0.15),
                            Colors.transparent
                          ])),
                      child: const Center(
                          child: Text('🌿', style: TextStyle(fontSize: 50)))),
                ),
                const SizedBox(height: 28),
                Text('EMOSS',
                    style: GoogleFonts.cormorantGaramond(
                        fontSize: 42,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 14,
                        color: T.textHi)),
                const SizedBox(height: 8),
                Text('YOUR PRIVATE SANCTUARY',
                    style: GoogleFonts.sourceCodePro(
                        fontSize: 10, letterSpacing: 5, color: T.textLo)),
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

// ─────────────────────────────────────────────────────────────
// HOME SCREEN
// ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  List<ConversationModel> _conversations = [];
  late AnimationController _fabAnim;

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _reload();
  }

  @override
  void dispose() {
    _fabAnim.dispose();
    super.dispose();
  }

  void _reload() =>
      setState(() => _conversations = HiveService.getAllConversations());

  Future<void> _newChat() async {
    final c = await HiveService.createConversation('New session');
    if (!mounted) return;
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ChatScreen(conversation: c)));
    _reload();
  }

  Future<void> _openChat(ConversationModel c) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ChatScreen(conversation: c)));
    _reload();
  }

  Future<void> _delete(ConversationModel c) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: T.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text('Delete session',
                  style: GoogleFonts.cormorantGaramond(
                      color: T.textHi,
                      fontSize: 20,
                      fontWeight: FontWeight.w600)),
              content: Text('This session will be permanently removed.',
                  style:
                      GoogleFonts.sourceSerif4(color: T.textMid, fontSize: 14)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('Cancel',
                        style: GoogleFonts.sourceSerif4(color: T.textMid))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('Delete',
                        style:
                            GoogleFonts.sourceSerif4(color: Colors.redAccent))),
              ],
            ));
    if (ok == true) {
      await HiveService.deleteConversation(c.id);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: T.bg,
        appBar: AppBar(
          backgroundColor: T.surface,
          title: Row(children: [
            const Text('🌿', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text('EMOSS',
                style: GoogleFonts.cormorantGaramond(
                    color: T.textHi,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4)),
          ]),
          actions: [
            _OfflinePill(),
            const SizedBox(width: 6),
            ListenableBuilder(
                listenable: TinyLlamaService(),
                builder: (_, __) => _StatusDot(
                      color: switch (TinyLlamaService().state) {
                        ModelState.ready => T.sage,
                        ModelState.loading => T.gold,
                        _ => Colors.redAccent
                      },
                      tooltip: switch (TinyLlamaService().state) {
                        ModelState.ready => 'AI ready',
                        ModelState.loading => 'Loading AI…',
                        _ => 'AI error'
                      },
                    )),
            const SizedBox(width: 6),
            IconButton(
                icon: const Icon(Icons.volunteer_activism_rounded,
                    color: Colors.redAccent, size: 22),
                tooltip: 'Support Resources',
                onPressed: () => Navigator.pushNamed(context, '/emergency')),
            const SizedBox(width: 4),
          ],
        ),
        body: _conversations.isEmpty ? _empty() : _list(),
        floatingActionButton: ScaleTransition(
          scale: CurvedAnimation(parent: _fabAnim, curve: Curves.elasticOut),
          child: FloatingActionButton.extended(
            onPressed: _newChat,
            backgroundColor: T.sage,
            icon: const Icon(Icons.add_comment_rounded,
                color: Color(0xFF0C110E), size: 20),
            label: Text('New Session',
                style: GoogleFonts.sourceSerif4(
                    color: const Color(0xFF0C110E),
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ),
        ),
      );

  Widget _empty() => Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🌿', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 20),
        Text('No sessions yet',
            style: GoogleFonts.cormorantGaramond(
                color: T.textHi, fontSize: 24, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Text('Begin a private conversation\nwith your AI companion.',
            textAlign: TextAlign.center,
            style: GoogleFonts.sourceSerif4(
                color: T.textMid, fontSize: 14, height: 1.6)),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _newChat,
          style: ElevatedButton.styleFrom(
              backgroundColor: T.sage,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30))),
          icon: const Icon(Icons.add_rounded, color: Color(0xFF0C110E)),
          label: Text('Begin',
              style: GoogleFonts.sourceSerif4(
                  color: const Color(0xFF0C110E),
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
        ),
      ]));

  Widget _list() => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
        itemCount: _conversations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _ConvTile(
            conv: _conversations[i],
            onTap: () => _openChat(_conversations[i]),
            onDelete: () => _delete(_conversations[i])),
      );
}

// ─────────────────────────────────────────────────────────────
// CONVERSATION TILE
// ─────────────────────────────────────────────────────────────

class _ConvTile extends StatelessWidget {
  final ConversationModel conv;
  final VoidCallback onTap, onDelete;
  const _ConvTile(
      {required this.conv, required this.onTap, required this.onDelete});

  String _fmt(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inDays < 1) return DateFormat('HH:mm').format(dt);
    if (d.inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final ec = EmotionDetector.getEmotionColor(conv.dominantEmotion);
    final ee = EmotionDetector.getEmotionEmoji(conv.dominantEmotion);
    return Dismissible(
      key: Key(conv.id),
      direction: DismissDirection.endToStart,
      background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.delete_outline_rounded,
              color: Colors.redAccent, size: 22)),
      onDismissed: (_) => onDelete(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: T.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: T.border)),
            child: Row(children: [
              Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                      color: ec.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ec.withOpacity(0.25))),
                  child: Center(
                      child: Text(ee, style: const TextStyle(fontSize: 20)))),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Expanded(
                          child: Text(conv.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cormorantGaramond(
                                  color: T.textHi,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15))),
                      Text(_fmt(conv.updatedAt),
                          style: GoogleFonts.sourceCodePro(
                              color: T.textLo, fontSize: 11)),
                    ]),
                    const SizedBox(height: 4),
                    Text(conv.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.sourceSerif4(
                            color: T.textMid, fontSize: 13)),
                  ])),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: T.textLo, size: 20),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CHAT SCREEN
// ─────────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  final ConversationModel conversation;
  const ChatScreen({super.key, required this.conversation});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final _ctl = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  final _llm = TinyLlamaService();

  List<MessageModel> _msgs = [];
  bool _generating = false;
  String _streaming = '';
  String _emotion = 'neutral';
  double _conf = 0.5;
  late AnimationController _dotAnim;

  @override
  void initState() {
    super.initState();
    _dotAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _load();
  }

  @override
  void dispose() {
    _ctl.dispose();
    _scroll.dispose();
    _focus.dispose();
    _dotAnim.dispose();
    super.dispose();
  }

  void _load() {
    setState(() => _msgs = HiveService.getMessages(widget.conversation.id));
    _end();
  }

  void _end() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients)
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  Future<void> _send() async {
    final text = _ctl.text.trim();
    if (text.isEmpty || _generating) return;
    _ctl.clear();
    if (CrisisDetector.isCrisis(text)) {
      await Navigator.push(
          context, MaterialPageRoute(builder: (_) => const EmergencyScreen()));
      return;
    }
    final er = EmotionDetector.detect(text);
    _emotion = er.key;
    _conf = er.value;

    final um = await HiveService.saveMessage(
        conversationId: widget.conversation.id,
        content: text,
        isUser: true,
        emotion: _emotion,
        emotionConfidence: _conf);
    await HiveService.updateConversation(
        widget.conversation.id, text, _emotion);

    if (_msgs.isEmpty) {
      widget.conversation.title =
          text.length > 40 ? '${text.substring(0, 40)}…' : text;
      await widget.conversation.save();
    }

    setState(() {
      _msgs.add(um);
      _generating = true;
      _streaming = '';
    });
    _end();

    final buf = StringBuffer();
    await for (final t in _llm.streamResponse(text, _emotion)) {
      buf.write(t);
      setState(() => _streaming = buf.toString());
      _end();
    }

    final aiText = buf.toString().trim();
    final am = await HiveService.saveMessage(
        conversationId: widget.conversation.id,
        content: aiText,
        isUser: false,
        emotion: _emotion,
        emotionConfidence: _conf);
    await HiveService.updateConversation(
        widget.conversation.id, aiText, _emotion);
    setState(() {
      _msgs.add(am);
      _generating = false;
      _streaming = '';
    });
    _end();
  }

  @override
  Widget build(BuildContext context) {
    final ec = EmotionDetector.getEmotionColor(_emotion);
    return Scaffold(
      backgroundColor: T.bg,
      appBar: AppBar(
        backgroundColor: T.surface,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: T.textMid, size: 18),
            onPressed: () => Navigator.pop(context)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('EMOSS',
              style: GoogleFonts.cormorantGaramond(
                  color: T.textHi, fontWeight: FontWeight.w600, fontSize: 18)),
          Row(children: [
            Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                    color: _llm.isReady ? T.sage : T.gold,
                    shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(_llm.isReady ? 'offline · private' : 'loading model…',
                style:
                    GoogleFonts.sourceCodePro(color: T.textLo, fontSize: 10)),
          ]),
        ]),
        actions: [
          if (_emotion != 'neutral') _EmotionBadge(_emotion),
          IconButton(
              icon: const Icon(Icons.volunteer_activism_rounded,
                  color: Colors.redAccent, size: 20),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EmergencyScreen()))),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            height: 2,
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
              ec.withOpacity(0.0),
              ec.withOpacity(0.7),
              ec.withOpacity(0.0)
            ]))),
        Expanded(
            child: _msgs.isEmpty && !_generating
                ? _welcome()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _msgs.length + (_generating ? 1 : 0),
                    itemBuilder: (_, i) => i == _msgs.length && _generating
                        ? _StreamBubble(text: _streaming, dot: _dotAnim)
                        : _Bubble(msg: _msgs[i]))),
        _bar(),
      ]),
    );
  }

  Widget _welcome() => Center(
      child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🌿', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 20),
            Text("I'm here with you",
                style: GoogleFonts.cormorantGaramond(
                    color: T.textHi,
                    fontSize: 26,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text('Everything you share stays\nentirely on your device.',
                textAlign: TextAlign.center,
                style: GoogleFonts.sourceSerif4(
                    color: T.textMid, fontSize: 14, height: 1.7)),
            const SizedBox(height: 32),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  "I'm feeling anxious",
                  "I had a great day!",
                  "I need to vent",
                  "I feel so alone"
                ]
                    .map((s) => _Chip(
                        text: s,
                        onTap: () {
                          _ctl.text = s;
                          _send();
                        }))
                    .toList()),
          ])));

  Widget _bar() => Container(
        padding: EdgeInsets.fromLTRB(
            16, 10, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: const BoxDecoration(
            color: T.surface, border: Border(top: BorderSide(color: T.border))),
        child: Row(children: [
          Expanded(
              child: TextField(
                  controller: _ctl,
                  focusNode: _focus,
                  style:
                      GoogleFonts.sourceSerif4(color: T.textHi, fontSize: 15),
                  maxLines: 4,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                      hintText: 'Share what\'s on your mind…',
                      hintStyle: GoogleFonts.sourceSerif4(
                          color: T.textLo, fontSize: 15),
                      filled: true,
                      fillColor: T.surfaceHi,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12)),
                  onSubmitted: (_) => _send())),
          const SizedBox(width: 10),
          GestureDetector(
              onTap: _generating ? null : _send,
              child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: _generating ? T.surfaceHi : T.sage,
                      borderRadius: BorderRadius.circular(20)),
                  child: _generating
                      ? const Center(
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: T.textMid)))
                      : const Icon(Icons.send_rounded,
                          color: Color(0xFF0C110E), size: 20))),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────
// STREAMING BUBBLE
// ─────────────────────────────────────────────────────────────

class _StreamBubble extends StatelessWidget {
  final String text;
  final AnimationController dot;
  const _StreamBubble({required this.text, required this.dot});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        _AiAvatar(),
        const SizedBox(width: 8),
        Flexible(
            child: Container(
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              color: T.aiBubble,
              border: Border.all(color: T.border),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4))),
          child: text.isEmpty
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                      3,
                      (i) => AnimatedBuilder(
                          animation: dot,
                          builder: (_, __) => Container(
                              margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: T.sage.withOpacity(
                                      (dot.value + i * 0.25)
                                          .clamp(0.2, 1.0)))))))
              : Text(text,
                  style: GoogleFonts.sourceSerif4(
                      color: T.textHi, fontSize: 15, height: 1.6)),
        )),
      ]));
}

// ─────────────────────────────────────────────────────────────
// MESSAGE BUBBLE
// ─────────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final MessageModel msg;
  const _Bubble({required this.msg});
  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;
    final ec = EmotionDetector.getEmotionColor(msg.emotion);
    final time = DateFormat('HH:mm').format(msg.timestamp);
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[_AiAvatar(), const SizedBox(width: 8)],
              Flexible(
                  child: Column(
                      crossAxisAlignment: isUser
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                    Container(
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.72),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                            color: isUser ? T.userBubble : T.aiBubble,
                            border: isUser
                                ? Border.all(color: T.sage.withOpacity(0.2))
                                : Border.all(color: T.border),
                            borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(isUser ? 18 : 4),
                                bottomRight: Radius.circular(isUser ? 4 : 18))),
                        child: Text(msg.content,
                            style: GoogleFonts.sourceSerif4(
                                color: T.textHi, fontSize: 15, height: 1.6))),
                    const SizedBox(height: 4),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      if (isUser && msg.emotion != 'neutral') ...[
                        Text(EmotionDetector.getEmotionEmoji(msg.emotion),
                            style: const TextStyle(fontSize: 11)),
                        const SizedBox(width: 4),
                        Text(msg.emotion,
                            style: GoogleFonts.sourceCodePro(
                                color: ec.withOpacity(0.75), fontSize: 10)),
                        const SizedBox(width: 6),
                      ],
                      Text(time,
                          style: GoogleFonts.sourceCodePro(
                              color: T.textLo, fontSize: 10)),
                    ]),
                  ])),
            ]));
  }
}

// ─────────────────────────────────────────────────────────────
// SMALL WIDGETS
// ─────────────────────────────────────────────────────────────

class _AiAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
          color: T.sage.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: T.sage.withOpacity(0.3))),
      child: const Center(child: Text('🌿', style: TextStyle(fontSize: 14))));
}

class _EmotionBadge extends StatelessWidget {
  final String emotion;
  const _EmotionBadge(this.emotion);
  @override
  Widget build(BuildContext context) {
    final c = EmotionDetector.getEmotionColor(emotion);
    final e = EmotionDetector.getEmotionEmoji(emotion);
    return Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: c.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.withOpacity(0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(e, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(emotion,
              style: GoogleFonts.sourceCodePro(
                  color: c, fontSize: 11, fontWeight: FontWeight.w600)),
        ]));
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _Chip({required this.text, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
      color: T.surfaceHi,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: T.border)),
              child: Text(text,
                  style: GoogleFonts.sourceSerif4(
                      color: T.textMid, fontSize: 13)))));
}

class _OfflinePill extends StatelessWidget {
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

class _StatusDot extends StatelessWidget {
  final Color color;
  final String tooltip;
  const _StatusDot({required this.color, required this.tooltip});
  @override
  Widget build(BuildContext context) => Tooltip(
      message: tooltip,
      child: Container(
          margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)));
}

// ─────────────────────────────────────────────────────────────
// EMERGENCY SCREEN
// ─────────────────────────────────────────────────────────────

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0F0D0D),
        appBar: AppBar(
            backgroundColor: const Color(0xFF0F0D0D),
            leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white38, size: 18),
                onPressed: () => Navigator.pop(context)),
            title: Text('You Matter',
                style: GoogleFonts.cormorantGaramond(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600))),
        body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(children: [
              const Spacer(),
              TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.9, end: 1.08),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeInOut,
                  builder: (_, s, c) => Transform.scale(scale: s, child: c),
                  child: const Icon(Icons.favorite_rounded,
                      color: Colors.redAccent, size: 80)),
              const SizedBox(height: 28),
              Text('You are not alone.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cormorantGaramond(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 16),
              Text(
                  'If you are in immediate danger or need to speak to a trained professional, please reach out below.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sourceSerif4(
                      fontSize: 15, color: Colors.white54, height: 1.7)),
              const Spacer(),
              _EBtn(
                  label: 'Call Emergency Services',
                  icon: Icons.phone_rounded,
                  color: Colors.redAccent),
              const SizedBox(height: 14),
              _EBtn(
                  label: 'Text a Crisis Counselor',
                  icon: Icons.message_rounded,
                  color: Colors.white12),
              const SizedBox(height: 14),
              _EBtn(
                  label: 'iCall (India): 9152987821',
                  icon: Icons.support_agent_rounded,
                  color: Colors.white10),
              const SizedBox(height: 24),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("I'm safe — take me back",
                      style: GoogleFonts.sourceSerif4(
                          color: Colors.white30, fontSize: 14))),
              const Spacer(),
            ])),
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
      height: 58,
      child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18))),
          onPressed: () {/* TODO: url_launcher → tel: / sms: */},
          icon: Icon(icon, color: Colors.white, size: 20),
          label: Text(label,
              style: GoogleFonts.sourceSerif4(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15))));
}

// ─────────────────────────────────────────────────────────────
// main.g.dart is auto-generated. Run:  dart run build_runner build
// ─────────────────────────────────────────────────────────────
