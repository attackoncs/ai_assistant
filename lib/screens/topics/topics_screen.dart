import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/preset_topics.dart';
import '../../services/storage/hive_service.dart';
import '../favorites/favorites_screen.dart';

/// 话题库（对应原应用「话题库：话术卡片，一键复制」）
///
/// TabBar 按场景分类浏览，卡片支持一键复制 + 收藏。
class TopicsScreen extends StatelessWidget {
  const TopicsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: presetTopics.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('话题库'),
          actions: [
            IconButton(
              icon: const Icon(Icons.collections_bookmark_outlined),
              tooltip: '我的收藏',
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const FavoritesScreen())),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final c in presetTopics)
                Tab(text: '${c.emoji} ${c.name}'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final c in presetTopics) _TopicList(category: c),
          ],
        ),
      ),
    );
  }
}

class _TopicList extends StatefulWidget {
  final TopicCategory category;
  const _TopicList({required this.category});

  @override
  State<_TopicList> createState() => _TopicListState();
}

class _TopicListState extends State<_TopicList> {
  late TopicCategory category = widget.category;

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制，去粘贴吧'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = category.cards;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: cards.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final card = cards[i];
        final favorited = HiveService.instance.isFavorited(card.text);
        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.text, style: Theme.of(context).textTheme.bodyLarge),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: '复制',
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      onPressed: () => _copy(card.text),
                    ),
                    IconButton(
                      tooltip: favorited ? '已收藏' : '收藏',
                      icon: Icon(
                        favorited ? Icons.bookmark : Icons.bookmark_border,
                        size: 20,
                        color: favorited ? Colors.amber : null,
                      ),
                      onPressed: favorited
                          ? null
                          : () {
                              HiveService.instance.addFavorite(
                                content: card.text,
                                source: 'topic',
                                scene: category.name,
                              );
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('已收藏'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                              setState(() {}); // 刷新收藏状态
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
