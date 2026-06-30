import 'package:hive/hive.dart';

part 'models.g.dart';

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
