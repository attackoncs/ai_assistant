import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class ChatMessageBox extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String conversationId;

  @HiveField(2)
  final String role; // 'system' | 'user' | 'assistant'

  @HiveField(3)
  final String content;

  @HiveField(4)
  final DateTime createdAt;

  ChatMessageBox({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
  });
}

@HiveType(typeId: 1)
class ConversationBox extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  final String? personaId;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  DateTime updatedAt;

  @HiveField(5)
  String? lastMessagePreview;

  // ── 以下字段对照原应用「记忆整合架构」，仅新增不改旧字段（向后兼容）──

  /// 联系人/聊天对象名（对应原应用 contact_name，按联系人分组会话）
  @HiveField(6)
  String? contactName;

  /// AI 生成的话题关键词列表（对应原应用 topics）
  @HiveField(7)
  List<String>? topics;

  /// AI 对用户情绪/意图的判断（对应原应用 judgment）
  @HiveField(8)
  String? judgment;

  /// AI 自动生成的标题（区别于用户手动设置的 title）
  @HiveField(9)
  String? aiTitle;

  ConversationBox({
    required this.id,
    required this.title,
    this.personaId,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessagePreview,
    this.contactName,
    this.topics,
    this.judgment,
    this.aiTitle,
  });
}

@HiveType(typeId: 2)
class PersonaBox extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String systemPrompt;

  @HiveField(4)
  final String? emoji;

  @HiveField(5)
  final String category;

  PersonaBox({
    required this.id,
    required this.name,
    required this.description,
    required this.systemPrompt,
    this.emoji,
    required this.category,
  });
}

/// 收藏的话术卡片（对应原应用「话题库收藏」+ 聊天回复收藏，本地化实现）
@HiveType(typeId: 3)
class FavoriteBox extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String content;

  /// 来源：'topic' 话题库 | 'chat' 聊天回复 | 'manual' 手动
  @HiveField(2)
  final String source;

  /// 场景/分类名（如「暧昧升温」）
  @HiveField(3)
  final String scene;

  @HiveField(4)
  final DateTime createdAt;

  FavoriteBox({
    required this.id,
    required this.content,
    required this.source,
    required this.scene,
    required this.createdAt,
  });
}
