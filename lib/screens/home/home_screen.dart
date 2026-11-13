import 'package:flutter/material.dart';

import '../../services/storage/hive_service.dart';
import '../chat/chat_screen.dart';
import '../favorites/favorites_screen.dart';
import '../settings/ai_provider_settings.dart';
import '../settings/floating_window_settings.dart';
import '../topics/topics_screen.dart';

/// 主页：底部导航 = 会话列表 / 话题库 / 收藏
///
/// 对照原应用主页：聊天记录列表 + 话题库入口 + 工具入口
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final conversations = HiveService.instance.listConversations();

    return Scaffold(
      appBar: _tab == 0
          ? AppBar(
              title: const Text('Companion AI'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.picture_in_picture_alt),
                  tooltip: '悬浮窗',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FloatingWindowSettings()),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: '新建对话',
                  onPressed: _newChat,
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: 'AI 接口设置',
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const AiProviderSettings())),
                ),
              ],
            )
          : null,
      body: IndexedStack(
        index: _tab,
        children: [
          _buildConversationList(conversations),
          const TopicsScreen(),
          const FavoritesScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: '对话',
          ),
          NavigationDestination(
            icon: Icon(Icons.topic_outlined),
            selectedIcon: Icon(Icons.topic),
            label: '话题库',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border),
            selectedIcon: Icon(Icons.bookmark),
            label: '收藏',
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList(List conversations) {
    return conversations.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text('暂无对话', style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _newChat,
                  icon: const Icon(Icons.add),
                  label: const Text('开始新对话'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _tab = 1),
                  child: const Text('先去话题库逛逛 →'),
                ),
              ],
            ),
          )
        : ListView.builder(
            itemCount: conversations.length,
            itemBuilder: (ctx, i) {
              final conv = conversations[i];
              final effectiveTitle = conv.aiTitle ?? conv.title;
              final topics = conv.topics ?? <String>[];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(effectiveTitle.isNotEmpty ? effectiveTitle[0].toUpperCase() : '?'),
                  ),
                  title: Text(effectiveTitle),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (conv.contactName != null && conv.contactName!.isNotEmpty)
                        Text(
                          '📞 ${conv.contactName}',
                          style: const TextStyle(fontSize: 11, color: Colors.blueAccent),
                        ),
                      if (conv.judgment != null && conv.judgment!.isNotEmpty)
                        Text(
                          conv.judgment!,
                          style: const TextStyle(fontSize: 11, color: Colors.deepOrangeAccent),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (topics.isNotEmpty)
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: topics.take(4).map((t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(t, style: const TextStyle(fontSize: 10, color: Colors.purpleAccent)),
                          )).toList(),
                        )
                      else
                        Text(
                          conv.lastMessagePreview ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  trailing: Text(
                    _formatTime(conv.updatedAt),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ChatScreen(conversationId: conv.id),
                    ));
                  },
                  onLongPress: () {
                    showDialog(
                      context: ctx,
                      builder: (_) => AlertDialog(
                        title: Text('删除"${conv.title}"?'),
                        content: const Text('此操作不可撤销'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                          FilledButton.tonal(
                            onPressed: () {
                              HiveService.instance.deleteConversation(conv.id);
                              setState(() {});
                              Navigator.pop(ctx);
                            },
                            child: const Text('删除'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
  }

  void _newChat() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const ChatScreen(),
    ));
  }

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    return '${t.month}/${t.day}';
  }
}
