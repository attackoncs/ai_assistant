import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../services/storage/hive_service.dart';

/// 我的收藏
///
/// 原应用「展示面」的本地化变体：不依赖图床，
/// 收藏聊天中的 AI 回复、话题库卡片，随时复制复用。
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  static const _sourceLabel = {
    'topic': '话题库',
    'chat': '聊天',
    'manual': '手动',
  };

  @override
  Widget build(BuildContext context) {
    // listenable() 监听 box 变化：在话题库/聊天中新增收藏后，切到本页立即刷新
    return Scaffold(
      appBar: AppBar(title: const Text('我的收藏')),
      body: ValueListenableBuilder(
        valueListenable: HiveService.instance.favoritesBox.listenable(),
        builder: (ctx, box, _) {
          final items = box.values.toList().reversed.toList();
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bookmark_border, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text('暂无收藏', style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 4),
                  Text(
                    '在话题库点 🔖 或在聊天中长按消息即可收藏',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final f = items[i];
              return Card(
                child: ListTile(
                  title: Text(f.content),
                  subtitle: Text(
                    '${_sourceLabel[f.source] ?? f.source} · ${f.scene} · ${f.createdAt.month}/${f.createdAt.day}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: '复制',
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: f.content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('已复制'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: '删除',
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => HiveService.instance.removeFavorite(f.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
