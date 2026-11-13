import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'models/hive_models.dart';
import 'providers/provider_manager.dart';
import 'services/floating/floating_window_service.dart';
import 'services/storage/hive_adapters.dart';
import 'services/storage/hive_service.dart';
import 'screens/home/home_screen.dart';
import 'screens/settings/ai_provider_settings.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // 注册 Hive 类型适配器
  Hive.registerAdapter(ChatMessageBoxAdapter());
  Hive.registerAdapter(ConversationBoxAdapter());
  Hive.registerAdapter(PersonaBoxAdapter());
  Hive.registerAdapter(FavoriteBoxAdapter());

  // 打开 box
  await Hive.openBox<ChatMessageBox>('messages');
  await Hive.openBox<ConversationBox>('conversations');
  await Hive.openBox<PersonaBox>('personas');
  await Hive.openBox<FavoriteBox>('favorites');
  await Hive.openBox('providers');

  // 首次启动：写入内置人设（日常 / 感情 / 职场）
  await HiveService.instance.ensureDefaultPersonas();

  // 悬浮窗通道（截屏识图 → AI 看图回复）
  FloatingWindowService.instance.init();

  runApp(const CompanionAiApp());
}

class CompanionAiApp extends StatelessWidget {
  const CompanionAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProviderManager()),
      ],
      child: MaterialApp(
        title: 'Companion AI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const _AppRoot(),
        routes: {
          '/settings': (_) => const AiProviderSettings(),
        },
      ),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProviderManager>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final pm = context.watch<ProviderManager>();

    if (pm.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 无活跃配置 → 先引导去设置页
    if (pm.active == null) {
      return const _FirstRunScreen();
    }

    return const HomeScreen();
  }
}

class _FirstRunScreen extends StatelessWidget {
  const _FirstRunScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              const Icon(Icons.chat_bubble_outline, size: 72, color: Colors.deepPurpleAccent),
              const SizedBox(height: 24),
              Text(
                '欢迎使用 Companion AI',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '请先配置一个 AI 提供商，填 Base URL + API Key + 模型名即可。\n支持 DeepSeek / 通义千问 / GLM / Kimi / 豆包 等所有 OpenAI 兼容服务。',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed('/settings');
                },
                icon: const Icon(Icons.settings),
                label: const Text('去配置 AI 接口'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
