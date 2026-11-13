import 'package:flutter/material.dart';

import '../../services/floating/floating_window_service.dart';

/// 悬浮窗设置页
///
/// 流程（对齐原应用）：
/// 1. 授予「显示在其他应用上层」权限
/// 2. 启动悬浮窗服务（前台服务，显示气泡）
/// 3. 点击气泡 → 截屏授权 → AI 分析截图 → 面板流式显示回复
///
/// 注意：截屏分析需要视觉模型（glm-4v / qwen-vl-max / gpt-4o / 豆包 vision 等），
/// 纯文本模型（如 deepseek-chat）会返回错误提示。
class FloatingWindowSettings extends StatefulWidget {
  const FloatingWindowSettings({super.key});

  @override
  State<FloatingWindowSettings> createState() => _FloatingWindowSettingsState();
}

class _FloatingWindowSettingsState extends State<FloatingWindowSettings> {
  bool _overlayGranted = false;
  bool _running = false;
  bool _busy = false;
  late final TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: FloatingWindowService.instance.prompt);
    FloatingWindowService.instance.onCaptureResult = _onCaptureResult;
    _refresh();
  }

  @override
  void dispose() {
    FloatingWindowService.instance.onCaptureResult = null;
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _overlayGranted = await FloatingWindowService.instance.isOverlayPermissionGranted();
    _running = FloatingWindowService.instance.serviceRunning;
    if (mounted) setState(() {});
  }

  void _onCaptureResult(bool success) {
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FloatingWindowService.instance.lastError ?? '截屏未完成'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('悬浮窗')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 权限
          Card(
            child: ListTile(
              leading: Icon(
                _overlayGranted ? Icons.check_circle : Icons.error_outline,
                color: _overlayGranted ? Colors.greenAccent : Colors.orangeAccent,
              ),
              title: const Text('悬浮窗权限'),
              subtitle: Text(_overlayGranted ? '已授予' : '需要「显示在其他应用上层」权限'),
              trailing: _overlayGranted
                  ? null
                  : FilledButton.tonal(
                      onPressed: _busy ? null : () async {
                        await FloatingWindowService.instance.requestOverlayPermission();
                      },
                      child: const Text('去授权'),
                    ),
            ),
          ),
          // 服务开关
          Card(
            child: ListTile(
              leading: const Icon(Icons.picture_in_picture_alt),
              title: const Text('悬浮窗服务'),
              subtitle: Text(_running ? '运行中 · 在任意应用上方点击 AI 气泡' : '未启动'),
              trailing: Switch(
                value: _running,
                onChanged: _busy ? null : (v) async {
                  setState(() => _busy = true);
                  try {
                    if (v) {
                      if (!await FloatingWindowService.instance.isOverlayPermissionGranted()) {
                        await FloatingWindowService.instance.requestOverlayPermission();
                        return;
                      }
                      await FloatingWindowService.instance.startService();
                    } else {
                      await FloatingWindowService.instance.stopService();
                    }
                  } finally {
                    setState(() => _busy = false);
                    await _refresh();
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 提示词
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology_alt, size: 20),
                      const SizedBox(width: 8),
                      Text('截屏分析提示词', style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AI 拿到截图后按这段提示词生成回复',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _promptController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: FloatingWindowService.defaultPrompt,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: () {
                        FloatingWindowService.instance.prompt =
                            _promptController.text.trim().isEmpty
                                ? FloatingWindowService.defaultPrompt
                                : _promptController.text.trim();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('提示词已保存')),
                        );
                      },
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 使用说明
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('使用方法', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  const Text(
                    '1. 打开悬浮窗开关 → 回到桌面\n'
                    '2. 在任意聊天应用界面，点击悬浮 AI 气泡\n'
                    '3. 系统弹出「截屏授权」，点「立即开始」\n'
                    '4. 面板显示 AI 分析出的回复建议，点「复制」直接粘贴\n\n'
                    '⚠️ 需要在 AI 接口设置中配置支持看图的模型\n'
                    '（glm-4v / qwen-vl-max / gpt-4o / doubao-vision 等），\n'
                    '纯文本模型（deepseek-chat 等）无法分析截图。',
                    style: TextStyle(height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
