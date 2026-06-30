import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:llamadart/llamadart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';

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

  static String getEmotionEmoji(String e) => '';
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
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        mode: FileMode.write,
        flush: true,
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
// TINYLLAMA SERVICE
// ─────────────────────────────────────────────────────────────

enum ModelState { uninitialized, loading, ready, error }

class TinyLlamaService extends ChangeNotifier {
  static final TinyLlamaService _i = TinyLlamaService._();
  factory TinyLlamaService() => _i;
  TinyLlamaService._();

  ModelState _state = ModelState.uninitialized;
  double _loadProgress = 0.0;
  String? _errorMsg;

  ModelState get state => _state;
  double get loadProgress => _loadProgress;
  String? get errorMsg => _errorMsg;
  bool get isReady => _state == ModelState.ready;

  static const Map<String, String> _systemPrompts = {
    'joy': 'You are EMO, an emotional support assistant. '
        'The user is joyful. Reply with ONE short warm response in 2 sentences maximum. '
        'Do not continue the conversation. Do not speak for the user. Stop after your response.',
    'sadness': 'You are EMO, an emotional support assistant. '
        'The user is sad. Acknowledge their feeling gently in 2 sentences maximum. '
        'Do not continue the conversation. Do not speak for the user. Stop after your response.',
    'anger': 'You are EMO, an emotional support assistant. '
        'The user is angry. Validate their feeling calmly in 2 sentences maximum. '
        'Do not continue the conversation. Do not speak for the user. Stop after your response.',
    'fear': 'You are EMO, an emotional support assistant. '
        'The user is anxious. Be soothing and grounding in 2 sentences maximum. '
        'Do not continue the conversation. Do not speak for the user. Stop after your response.',
    'disgust': 'You are EMO, an emotional support assistant. '
        'The user feels bothered. Acknowledge calmly in 2 sentences maximum. '
        'Do not continue the conversation. Do not speak for the user. Stop after your response.',
    'surprise': 'You are EMO, an emotional support assistant. '
        'The user is surprised. React with interest in 2 sentences maximum. '
        'Do not continue the conversation. Do not speak for the user. Stop after your response.',
    'neutral': 'You are EMO, an emotional support assistant. '
        'Listen and respond warmly in 2 sentences maximum. '
        'Do not continue the conversation. Do not speak for the user. Stop after your response.',
  };

  LlamaEngine? _engine;

  Future<void> initialize() async {
    if (_state == ModelState.loading || _state == ModelState.ready) return;
    _set(ModelState.loading, p: 0.0);

    try {
      String modelPath;
      if (kIsWeb) {
        modelPath = 'assets/models/tinyllama.gguf';
      } else {
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
        modelPath = modelFile.path;
      }

      _set(ModelState.loading, p: 0.90);

      _engine = LlamaEngine(LlamaBackend());
      await _engine!.loadModel(modelPath, modelParams: const ModelParams(
        contextSize: 512,
        gpuLayers: 0,
      ));

      _set(ModelState.ready, p: 1.0);
    } catch (e, st) {
      _errorMsg = e.toString();
      debugPrint('TinyLlama init error: $e\n$st');
      _set(ModelState.error);
    }
  }

  void _set(ModelState s, {double? p}) {
    _state = s;
    if (p != null) _loadProgress = p;
    notifyListeners();
  }

  Stream<String> streamResponse(String userMsg, String emotion) async* {
    if (_engine == null) {
      yield "Still setting up — give me a second.";
      return;
    }

    final system = _systemPrompts[emotion] ?? _systemPrompts['neutral']!;
    final messages = [
      LlamaChatMessage.fromText(role: LlamaChatRole.system, text: system),
      LlamaChatMessage.fromText(role: LlamaChatRole.user, text: userMsg),
    ];

    try {
      await for (final chunk in _engine!.create(messages, params: const GenerationParams(
        maxTokens: 50,
        stopSequences: [
          '<|im_end|>',
          '<|im_start|>',
          '</s>',
          '[/INST]',
          '\nUser:',
          '\nHuman:',
          '\n\n',
          '\n\n\n',
        ],
      ))) {
        final content = chunk.choices.firstOrNull?.delta.content;
        if (content != null && content.isNotEmpty) {
          yield content;
        }
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
    for (final m in _mb.values.where((m) => m.conversationId == id)) {
      await _mb.delete(m.id);
    }
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
