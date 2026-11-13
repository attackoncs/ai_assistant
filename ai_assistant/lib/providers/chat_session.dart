import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/ai_provider_config.dart';
import '../models/hive_models.dart';
import '../services/ai/ai_provider_service.dart';
import '../services/storage/hive_service.dart';

/// 单聊会话状态
///
/// 对照原应用「记忆整合架构」：
/// - 自动标题（aiTitle）：首条对话后 AI 生成
/// - 话题提取（topics）：每条对话后提炼关键词
/// - 情绪判断（judgment）：分析用户当前情绪/意图
/// - 上下文截断：超过 20 条只保留最近 20 条（控制 token 消耗）
class ChatSession extends ChangeNotifier {
  final HiveService _hive = HiveService.instance;

  final String conversationId;
  List<ChatMessageBox> _messages = [];
  String _assistantBuffer = ''; // 正在流式写入的回复
  bool _isStreaming = false;
  String? _error;
  CancelToken? _cancelToken;
  bool _memoryLocked = false; // 防止并发触发重复记忆提取

  ChatSession({String? conversationId, String? personaId})
      : conversationId = conversationId ??
            HiveService.instance.newConversation(personaId: personaId);

  List<ChatMessageBox> get messages => _messages;
  String get assistantBuffer => _assistantBuffer;
  bool get isStreaming => _isStreaming;
  String? get error => _error;

  /// 中断正在进行的流式回复（对应原生层 SseClientAndroid 的 AtomicBoolean 中断）
  void stop() => _cancelToken?.cancel('user aborted');

  void load() {
    _messages = _hive.listMessages(conversationId);
    notifyListeners();
  }

  // ── 上下文截断：超过 MAX_HISTORY 条只保留最近的 ────────────────────
  static const int _maxHistory = 20;

  List<AiMessage> _truncatedHistory() {
    final recent = _messages.reversed.take(_maxHistory).toList().reversed.toList();
    return recent
        .where((m) => m.role != 'system')
        .map((m) => AiMessage(
              role: AiRole.values.firstWhere((r) => r.name == m.role),
              content: m.content,
            ))
        .toList();
  }

  /// 发送用户消息并调用 AI（流式）
  Future<void> send({
    required String text,
    required AiProviderConfig provider,
    String? personaSystemPrompt,
  }) async {
    if (text.trim().isEmpty || _isStreaming) return;

    _error = null;

    // 1. 存用户消息
    _hive.addMessage(conversationId: conversationId, role: 'user', content: text);
    _messages = _hive.listMessages(conversationId);
    _assistantBuffer = '';
    _isStreaming = true;
    notifyListeners();

    // 2. 构造 AI Provider（带上人设 system prompt）
    final effectiveProvider = personaSystemPrompt != null && personaSystemPrompt.isNotEmpty
        ? provider.copyWith(systemPrompt: personaSystemPrompt)
        : provider;

    final service = AiProviderService(effectiveProvider);

    // 3. 组装历史消息（带截断）
    final history = _truncatedHistory();

    // 4. 流式接收
    final token = CancelToken();
    _cancelToken = token;
    try {
      await for (final data in service.chatStream(messages: history, cancelToken: token)) {
        _assistantBuffer += data;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _cancelToken = null;
      _isStreaming = false;
      if (_assistantBuffer.isNotEmpty) {
        _hive.addMessage(
          conversationId: conversationId,
          role: 'assistant',
          content: _assistantBuffer,
        );
      }
      _messages = _hive.listMessages(conversationId);
      _assistantBuffer = '';
      notifyListeners();

      // 5. 后台异步触发记忆整合（对照原应用 store_chat_memory）
      _asyncUpdateMemory(provider);
    }
  }

  // ── 后台异步记忆整合（不阻塞 UI） ─────────────────────────────────

  Future<void> _asyncUpdateMemory(AiProviderConfig provider) async {
    if (_memoryLocked) return;
    _memoryLocked = true;
    try {
      final conv = _hive.getConversation(conversationId);
      if (conv == null) return;

      final hasAnyMemory = conv.aiTitle != null || conv.topics != null || conv.judgment != null;
      final isFirstMessage = _messages.length <= 2; // user + assistant

      // 如果已有记忆，只做轻量更新（避免每次都消耗大量 token）
      if (hasAnyMemory && !isFirstMessage) {
        // 增量更新：只追加新的话题关键词
        await _extractTopicsOnly(conv, provider);
        return;
      }

      // 首次或无记忆：一次性生成 标题 + 话题 + 情绪判断
      await _generateFullMemory(conv, provider);
    } catch (_) {
      // 记忆整合失败不影响主流程（网络抖动、token 不足等都静默跳过）
    } finally {
      _memoryLocked = false;
    }
  }

  Future<void> _generateFullMemory(ConversationBox conv, AiProviderConfig provider) async {
    final service = AiProviderService(provider);
    final history = _messages
        .where((m) => m.role != 'system')
        .map((m) => '${m.role == 'user' ? '用户' : 'AI'}: ${m.content}')
        .join('\n');

    final prompt = '''请根据以下对话，返回三个部分的分析（严格按格式）：

1. TITLE: 用5-8个字为这段对话起个贴切的标题（如"猫与咖啡""周末计划"）
2. TOPICS: 提炼3-5个话题关键词，用逗号分隔
3. JUDGMENT: 一句话分析用户当前的情绪/意图/状态

对话：
$history

严格按以下格式输出，不要其他内容：
TITLE: xxx
TOPICS: xxx, xxx, xxx
JUDGMENT: xxx''';

    final buffer = StringBuffer();
    await for (final token in service.chatStream(
      messages: [AiMessage(role: AiRole.system, content: '你是对话分析助手，严格按格式输出。'), AiMessage(role: AiRole.user, content: prompt)],
    )) {
      buffer.write(token);
    }
    final raw = buffer.toString();

    final titleMatch = RegExp(r'TITLE:\s*(.+)').firstMatch(raw);
    final topicsMatch = RegExp(r'TOPICS:\s*(.+)').firstMatch(raw);
    final judgmentMatch = RegExp(r'JUDGMENT:\s*(.+)').firstMatch(raw);

    if (titleMatch != null) {
      conv.aiTitle = titleMatch.group(1)!.trim();
      conv.title = conv.aiTitle!; // 直接设为标题（首条对话后自动替换"新对话"）
    }
    if (topicsMatch != null) {
      conv.topics = topicsMatch.group(1)!.split(RegExp(r'[,，、]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    if (judgmentMatch != null) {
      conv.judgment = judgmentMatch.group(1)!.trim();
    }
    conv.updatedAt = DateTime.now();
    conv.save();
    notifyListeners();
  }

  Future<void> _extractTopicsOnly(ConversationBox conv, AiProviderConfig provider) async {
    // 只取最后 2 条 user 消息做增量分析（轻量）
    final recentUserMsgs = _messages
        .where((m) => m.role == 'user')
        .toList()
        .reversed
        .take(2)
        .toList()
        .reversed
        .map((m) => m.content)
        .join('\n');

    final service = AiProviderService(provider);
    final prompt = '''从以下用户最近的消息中提炼2-3个新的话题关键词（可能已经存在，也可能是新出现的），用逗号分隔，只输出关键词：

$recentUserMsgs''';

    final buffer = StringBuffer();
    await for (final token in service.chatStream(
      messages: [AiMessage(role: AiRole.user, content: prompt)],
    )) {
      buffer.write(token);
    }
    final raw = buffer.toString().trim();
    final newTopics = raw.split(RegExp(r'[,，、\n]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    // 合并去重
    final existing = conv.topics ?? [];
    final merged = <String>{...existing, ...newTopics}.toList();
    if (merged.length > 12) merged.removeRange(0, merged.length - 12); // 最多保留 12 个
    conv.topics = merged;
    conv.updatedAt = DateTime.now();
    conv.save();
  }
}
