import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../config/ai_provider_config.dart';
import '../../models/hive_models.dart';

/// 本地持久化服务
///
/// 用 Hive (NoSQL KV) 存：
/// - AI Provider 配置列表
/// - 聊天会话
/// - 会话内消息
/// - 人设卡片
class HiveService {
  HiveService._();
  static final instance = HiveService._();

  Box<ChatMessageBox> get messagesBox => Hive.box<ChatMessageBox>('messages');
  Box<ConversationBox> get conversationsBox => Hive.box<ConversationBox>('conversations');
  Box<PersonaBox> get personasBox => Hive.box<PersonaBox>('personas');
  Box<FavoriteBox> get favoritesBox => Hive.box<FavoriteBox>('favorites');

  /// 存 AI Provider 配置（同时存 provider 列表与 active id，故为动态类型 Box）
  Box get providersBox => Hive.box('providers');

  // ─── Conversation ──────────────────────────────────────────────────

  String newConversation({String? title, String? personaId}) {
    final now = DateTime.now();
    final conv = ConversationBox(
      id: const Uuid().v4(),
      title: title ?? '新对话',
      personaId: personaId,
      createdAt: now,
      updatedAt: now,
    );
    conversationsBox.put(conv.id, conv);
    return conv.id;
  }

  List<ConversationBox> listConversations() {
    final list = conversationsBox.values.toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  ConversationBox? getConversation(String id) => conversationsBox.get(id);

  ConversationBox updateConversation(ConversationBox conv) {
    conv.updatedAt = DateTime.now();
    conv.save();
    return conv;
  }

  void deleteConversation(String id) {
    messagesBox.values.where((m) => m.conversationId == id).forEach((m) => m.delete());
    conversationsBox.delete(id);
  }

  // ─── Message ───────────────────────────────────────────────────────

  void addMessage({
    required String conversationId,
    required String role,
    required String content,
  }) {
    final msg = ChatMessageBox(
      id: const Uuid().v4(),
      conversationId: conversationId,
      role: role,
      content: content,
      createdAt: DateTime.now(),
    );
    messagesBox.put(msg.id, msg);

    // 更新会话预览
    final conv = conversationsBox.get(conversationId);
    if (conv != null) {
      conv.lastMessagePreview = content.length > 40 ? '${content.substring(0, 40)}…' : content;
      conv.updatedAt = DateTime.now();
      conv.save();
    }
  }

  List<ChatMessageBox> listMessages(String conversationId) {
    final list = messagesBox.values.where((m) => m.conversationId == conversationId).toList();
    list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  // ─── Persona ────────────────────────────────────────────────────────

  String addPersona({
    required String name,
    required String description,
    required String systemPrompt,
    String? emoji,
    required String category,
  }) {
    final p = PersonaBox(
      id: const Uuid().v4(),
      name: name,
      description: description,
      systemPrompt: systemPrompt,
      emoji: emoji,
      category: category,
    );
    personasBox.put(p.id, p);
    return p.id;
  }

  List<PersonaBox> listPersonas() {
    final list = personasBox.values.toList();
    list.sort((a, b) => a.category.compareTo(b.category));
    return list;
  }

  PersonaBox? getPersona(String id) => personasBox.get(id);

  /// 首次启动时写入内置人设（对照原应用「人设库：日常/感情/职场」）
  Future<void> ensureDefaultPersonas() async {
    if (personasBox.isNotEmpty) return;
    final defaults = <List<String>>[
      ['日常闲聊', '轻松自然的日常聊天风格', '你是一位善于日常闲聊的伙伴，语气轻松自然、有分寸，回复简短不生硬。', '💬'],
      ['恋爱甜心', '温柔体贴的恋爱陪伴语气', '你是一位温柔体贴的恋人，说话亲昵带一点点撒娇，会主动关心对方，回复有情绪温度。', '💗'],
      ['高情商回复', '帮对方组织高情商的回话', '用户会发来别人的消息，请你帮他想一句高情商、得体又自然的回复话术。只输出话术本身。', '🎯'],
      ['职场沟通', '专业得体的职场沟通语气', '你是一位职场沟通顾问，帮用户写出专业、礼貌、高效的职场回复。', '💼'],
      ['幽默搞笑', '玩梗幽默，活跃气氛', '你是一位幽默段子手，善用网络热梗和反差，让对话轻松有趣但不过分冒犯。', '😂'],
    ];
    for (final p in defaults) {
      addPersona(
        name: p[0],
        description: p[1],
        systemPrompt: p[2],
        emoji: p[3],
        category: '内置',
      );
    }
  }

  // ─── Favorite（收藏话术） ────────────────────────────────────────────

  Future<FavoriteBox> addFavorite({
    required String content,
    required String source,
    required String scene,
  }) async {
    final f = FavoriteBox(
      id: const Uuid().v4(),
      content: content,
      source: source,
      scene: scene,
      createdAt: DateTime.now(),
    );
    await favoritesBox.put(f.id, f);
    return f;
  }

  List<FavoriteBox> listFavorites() {
    final list = favoritesBox.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  bool isFavorited(String content) =>
      favoritesBox.values.any((f) => f.content == content);

  Future<void> removeFavorite(String id) => favoritesBox.delete(id);

  // ─── AI Provider Config ─────────────────────────────────────────────

  /// 存 active provider 的 ID 到一个特殊 key
  static const _activeKey = '__active_provider__';

  List<AiProviderConfig> listProviders() {
    return providersBox.values
        .whereType<Map>()
        .map((m) => AiProviderConfig.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  AiProviderConfig? getActiveProvider() {
    final activeId = providersBox.get(_activeKey);
    if (activeId is! String) return null;
    final raw = providersBox.get(activeId);
    if (raw is! Map) return null;
    return AiProviderConfig.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<void> saveProvider(AiProviderConfig config, {bool activate = false}) async {
    await providersBox.put(config.id, config.toJson());
    if (activate) {
      await providersBox.put(_activeKey, config.id);
    }
  }

  Future<void> activateProvider(String id) async {
    await providersBox.put(_activeKey, id);
  }

  Future<void> deleteProvider(String id) async {
    await providersBox.delete(id);
    final active = providersBox.get(_activeKey);
    if (active == id) {
      await providersBox.delete(_activeKey);
    }
  }
}
