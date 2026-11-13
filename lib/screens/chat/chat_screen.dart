import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/hive_models.dart';
import '../../providers/chat_session.dart';
import '../../providers/provider_manager.dart';
import '../../services/storage/hive_service.dart';
import '../settings/ai_provider_settings.dart';

/// 聊天页面（核心）
///
/// 功能：
/// - SSE 流式对话
/// - 多轮上下文
/// - 切换人设/系统提示词
/// - 切换 AI Provider
class ChatScreen extends StatefulWidget {
  final String? conversationId;
  final String? initialPersonaId;

  const ChatScreen({super.key, this.conversationId, this.initialPersonaId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatSession _session;
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  PersonaBox? _persona;

  @override
  void initState() {
    super.initState();
    _session = ChatSession(conversationId: widget.conversationId, personaId: widget.initialPersonaId);
    _session.load();
    if (widget.initialPersonaId != null) {
      _persona = HiveService.instance.getPersona(widget.initialPersonaId!);
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final pm = context.read<ProviderManager>();
    if (pm.active == null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiProviderSettings()));
      return;
    }

    _inputController.clear();
    await _session.send(
      text: text,
      provider: pm.active!,
      personaSystemPrompt: _persona?.systemPrompt,
    );

    // 滚到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pm = context.watch<ProviderManager>();

    return ChangeNotifierProvider.value(
      value: _session,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('对话'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // 如果是新空对话，删掉
              if (_session.messages.isEmpty && !_session.isStreaming) {
                HiveService.instance.deleteConversation(_session.conversationId);
              }
              Navigator.of(context).pop();
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: '切换 AI 接口',
              onPressed: () => _showProviderPicker(),
            ),
            IconButton(
              icon: const Icon(Icons.person),
              tooltip: '选择人设',
              onPressed: () => _showPersonaPicker(),
            ),
          ],
        ),
        body: Column(
          children: [
            // AI Provider 信息条
            if (pm.active != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: Row(
                  children: [
                    Icon(Icons.cloud, size: 14, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${pm.active!.name} · ${pm.active!.model}${_persona != null ? ' · ${_persona!.emoji ?? ''}${_persona!.name}' : ''}',
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(child: _buildMessageList()),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return Consumer<ChatSession>(
      builder: (_, session, __) {
        final hasContent = session.messages.isNotEmpty || session.assistantBuffer.isNotEmpty;
        if (!hasContent) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.waving_hand, size: 48, color: Colors.deepPurpleAccent),
                const SizedBox(height: 12),
                Text('开始一段对话吧', style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 4),
                Text('Enter 发送 · Shift+Enter 换行', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: session.messages.length + (session.assistantBuffer.isNotEmpty ? 1 : 0),
          itemBuilder: (ctx, i) {
            if (i < session.messages.length) {
              final msg = session.messages[i];
              return GestureDetector(
                onLongPress: () => _showMessageActions(msg.role, msg.content),
                child: _buildBubble(msg.role, msg.content, isStreaming: false),
              );
            }
            // 正在流式输出的 assistant 回复
            return _buildBubble('assistant', session.assistantBuffer, isStreaming: true);
          },
        );
      },
    );
  }

  Widget _buildBubble(String role, String content, {required bool isStreaming}) {
    final isUser = role == 'user';
    final bubbleColor = isUser
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final textColor = isUser ? Colors.white : Theme.of(context).colorScheme.onSurface;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          content,
          style: TextStyle(color: textColor, height: 1.45),
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                maxLines: null,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: '输入消息…',
                  isDense: true,
                  suffixIcon: Consumer<ChatSession>(
                    builder: (_, session, __) {
                      if (session.isStreaming) {
                        return IconButton(
                          icon: const Icon(Icons.stop_circle_outlined),
                          tooltip: '停止生成',
                          onPressed: session.stop,
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            Consumer<ChatSession>(
              builder: (_, session, __) => FloatingActionButton.small(
                onPressed: session.isStreaming ? null : _send,
                child: Icon(session.isStreaming ? Icons.hourglass_empty : Icons.send),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 消息长按：复制 / 收藏 ─────────────────────────────────────────────

  void _showMessageActions(String role, String content) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('复制'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: content));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('已复制')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_border),
              title: const Text('收藏到话术库'),
              onTap: () {
                HiveService.instance.addFavorite(
                  content: content,
                  source: 'chat',
                  scene: role == 'user' ? '我说的' : 'AI 回复',
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('已收藏')));
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── 切换 AI Provider ────────────────────────────────────────────────

  void _showProviderPicker() {
    final pm = context.read<ProviderManager>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: Text('选择 AI 接口', style: Theme.of(ctx).textTheme.titleMedium)),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiProviderSettings()));
                    },
                    child: const Text('管理'),
                  ),
                ],
              ),
            ),
            if (pm.providers.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Text('暂无配置'))
            else
              ...pm.providers.map((p) => ListTile(
                    leading: Icon(p.id == pm.active?.id ? Icons.check_circle : Icons.radio_button_unchecked),
                    title: Text(p.name),
                    subtitle: Text(p.model),
                    selected: p.id == pm.active?.id,
                    onTap: () {
                      pm.activate(p.id);
                      Navigator.pop(ctx);
                    },
                  )),
          ],
        ),
      ),
    );
  }

  // ─── 切换人设 ────────────────────────────────────────────────────────

  void _showPersonaPicker() {
    final personas = HiveService.instance.listPersonas();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: Text('选择人设', style: Theme.of(ctx).textTheme.titleMedium)),
                ],
              ),
            ),
            if (personas.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('暂无预设人设。\n你可以在设置的系统提示词里自定义。', textAlign: TextAlign.center),
              )
            else
              ...personas.map((p) => ListTile(
                    leading: Text(p.emoji ?? '👤', style: const TextStyle(fontSize: 24)),
                    title: Text(p.name),
                    subtitle: Text(p.description),
                    onTap: () {
                      setState(() => _persona = p);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已切换人设「${p.name}」')),
                      );
                    },
                  )),
          ],
        ),
      ),
    );
  }
}
