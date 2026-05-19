import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

class EmotionResult {
  final String emotion;
  final double confidence;
  final bool isAtRisk;
  final double riskProb;
  final bool crisisAlert;

  EmotionResult({
    required this.emotion,
    required this.confidence,
    required this.isAtRisk,
    required this.riskProb,
    required this.crisisAlert,
  });
}

class EmotionClassifier {
  static OrtSession? _session;
  static Map<String, int>? _vocab;
  static List<String>? _emotionLabels;
  static int _maxLength = 128;


  static const double _riskThreshold = 0.25;
  static const double _crisisThreshold = 0.35;
  static const double _dampeningFactor = 0.25;
  static const Set<String> _dampenedEmotions = {'sadness'};

  static Future<void> initialize() async {
    try{
      OrtEnv.instance.init();
      debugPrint('OrtEnv initialized');
      // Load classifier config
      final configData = await rootBundle.loadString('assets/classifier/classifier_config.json');
      final config = json.decode(configData);
      _emotionLabels = List<String>.from(config['emotion_labels']);
      _maxLength = config['max_length'] ?? 128;
      debugPrint('Config loaded: labels=$_emotionLabels, maxLength=$_maxLength');

      // Load vocab
      final vocabData = await rootBundle.loadString('assets/classifier/vocab.txt');
      _vocab = {};
      final lines = vocabData.split('\n');
      for (int i = 0; i < lines.length; i++) {
        final token = lines[i].trim();
        if (token.isNotEmpty) {
          _vocab![token] = i;
        }
      }
      debugPrint('Vocab loaded: ${_vocab!.length} tokens');
      // Load ONNX model
      final modelData = await rootBundle.load('assets/classifier/classifier.onnx');
      final bytes = modelData.buffer.asUint8List();
      final sessionOptions = OrtSessionOptions();
      _session = OrtSession.fromBuffer(bytes, sessionOptions);
      debugPrint('ONNX session created successfully');
    } catch (e, st){
      debugPrint('EmotionClassifier init error: $e\n$st');
    }
  }

  static EmotionResult classify(String text) {
    if (_session == null || _vocab == null || _emotionLabels == null) {
      return EmotionResult(
        emotion: 'neutral',
        confidence: 0.5,
        isAtRisk: false,
        riskProb: 0.0,
        crisisAlert: false,
      );
    }

    try {
      // Tokenize
      final encoded = _tokenize(text);
      final inputIds = encoded['input_ids']!;
      final attentionMask = encoded['attention_mask']!;

      // Run inference
      final inputIdsTensor = OrtValueTensor.createTensorWithDataList(
        Int64List.fromList(inputIds),
        [1, inputIds.length],
      );
      final attentionMaskTensor = OrtValueTensor.createTensorWithDataList(
        Int64List.fromList(attentionMask),
        [1, attentionMask.length],
      );

      final inputs = {
        'input_ids': inputIdsTensor,
        'attention_mask': attentionMaskTensor,
      };

      final outputs = _session!.run(OrtRunOptions(), inputs);

      // Parse emotion logits
      //final emotionLogits = (outputs[0]?.value as List<List<double>>)[0];
      //final riskLogit = (outputs[1]?.value as List<List<double>>)[0][0];

      final rawEmotion = outputs[0]?.value;
      final rawRisk = outputs[1]?.value;


      debugPrint('Emotion output type: ${rawEmotion.runtimeType}');
      debugPrint('Risk output type: ${rawRisk.runtimeType}');

      List<double> emotionLogits;
      double riskLogit;

      if (rawEmotion is List<List<double>>) {
        emotionLogits = rawEmotion[0];
      } else if (rawEmotion is List<double>) {
        emotionLogits = rawEmotion;
      } else {
        emotionLogits = (rawEmotion as List).map((e) => (e as num).toDouble()).toList();
      }

      if (rawRisk is List<List<double>>) {
        riskLogit = rawRisk[0][0];
      } else if (rawRisk is List<double>) {
        riskLogit = rawRisk[0];
      } else {
        riskLogit = ((rawRisk as List)[0] as num).toDouble();
      }

      // Softmax on emotions
      final emotionProbs = _softmax(emotionLogits);
      int emotionId = 0;
      for (int i = 1; i < emotionProbs.length; i++) {
        if (emotionProbs[i] > emotionProbs[emotionId]) emotionId = i;
      }
      final emotion = _emotionLabels![emotionId];
      final confidence = emotionProbs[emotionId];

      // Sigmoid on risk
      double riskProb = 1.0 / (1.0 + exp(-riskLogit));

      // Dampen risk for sadness in borderline range
      double adjustedRisk = riskProb;
      if (_dampenedEmotions.contains(emotion) &&
          riskProb >= 0.25 && riskProb <= 0.80) {
        adjustedRisk = riskProb * _dampeningFactor;
      }

      final isAtRisk = adjustedRisk >= _riskThreshold;
      final crisisAlert = adjustedRisk >= _crisisThreshold;

      // Cleanup
      inputIdsTensor.release();
      attentionMaskTensor.release();
      outputs.forEach((e) => e?.release());

      debugPrint('=== CLASSIFIER RESULT ===');
      debugPrint('Text: $text');
      debugPrint('Emotion: $emotion (${(confidence * 100).toStringAsFixed(1)}%)');
      debugPrint('Risk raw: ${riskProb.toStringAsFixed(4)}');
      debugPrint('Risk adjusted: ${adjustedRisk.toStringAsFixed(4)}');
      debugPrint('Is at risk: $isAtRisk');
      debugPrint('Crisis alert: $crisisAlert');
      debugPrint('=========================');

      return EmotionResult(
        emotion: emotion,
        confidence: confidence,
        isAtRisk: isAtRisk,
        riskProb: adjustedRisk,
        crisisAlert: crisisAlert,
      );
    } catch (e) {
      debugPrint('Classifier error: $e');
      return EmotionResult(
        emotion: 'neutral',
        confidence: 0.5,
        isAtRisk: false,
        riskProb: 0.0,
        crisisAlert: false,
      );
    }
  }

  static Map<String, List<int>> _tokenize(String text) {
    final vocab = _vocab!;
    // Basic WordPiece tokenization
    final clsId = vocab['[CLS]'] ?? 101;
    final sepId = vocab['[SEP]'] ?? 102;
    final unkId = vocab['[UNK]'] ?? 100;
    final padId = vocab['[PAD]'] ?? 0;

    // Lowercase and split
    final words = text.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    final tokens = <int>[clsId];

    for (final word in words) {
      final wordTokens = _wordpieceTokenize(word, vocab, unkId);
      tokens.addAll(wordTokens);
      if (tokens.length >= _maxLength - 1) break;
    }

    tokens.add(sepId);

    // Pad or truncate to maxLength
    final inputIds = List<int>.filled(_maxLength, padId);
    final attentionMask = List<int>.filled(_maxLength, 0);

    for (int i = 0; i < min(tokens.length, _maxLength); i++) {
      inputIds[i] = tokens[i];
      attentionMask[i] = 1;
    }

    return {'input_ids': inputIds, 'attention_mask': attentionMask};
  }

  static List<int> _wordpieceTokenize(
      String word, Map<String, int> vocab, int unkId) {
    if (vocab.containsKey(word)) return [vocab[word]!];

    final tokens = <int>[];
    int start = 0;
    while (start < word.length) {
      int end = word.length;
      int? curId;
      while (start < end) {
        final substr = start == 0
            ? word.substring(start, end)
            : '##${word.substring(start, end)}';
        if (vocab.containsKey(substr)) {
          curId = vocab[substr];
          break;
        }
        end--;
      }
      if (curId == null) return [unkId];
      tokens.add(curId);
      start = end;
    }
    return tokens.isEmpty ? [unkId] : tokens;
  }

  static List<double> _softmax(List<double> logits) {
    final maxVal = logits.reduce(max);
    final expVals = logits.map((v) => exp(v - maxVal)).toList();
    final sum = expVals.reduce((a, b) => a + b);
    return expVals.map((v) => v / sum).toList();
  }
}