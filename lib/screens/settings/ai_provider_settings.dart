import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/ai_provider_config.dart';
import '../../config/preset_providers.dart';
import '../../providers/provider_manager.dart';
import '../../services/ai/ai_provider_service.dart';

/// AI Provider 设置页
///
/// 用户在这里：
/// 1. 选预设提供商
/// 2. 或自定义 Base URL + API Key + Model
/// 3. 测试连接
/// 4. 保存并激活
class AiProviderSettings extends StatefulWidget {
  const AiProviderSettings({super.key});

  @override
  State<AiProviderSettings> createState() => _AiProviderSettingsState();
}

class _AiProviderSettingsState extends State<AiProviderSettings> {
  AiProviderConfig? _draft;
  bool _obscureKey = true;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pm = context.read<ProviderManager>();
      _draft = pm.active ?? PresetProviders.deepseek.copyWith(apiKey: '', model: '');
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final pm = context.watch<ProviderManager>();

    return Scaffold(
      appBar: AppBar(title: const Text('AI 接口设置')),
      body: _draft == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildPresetPicker(),
                const SizedBox(height: 16),
                _buildTextField('显示名称', _draft!.name, (v) => _draft = _draft!.copyWith(name: v)),
                const SizedBox(height: 12),
                _buildTextField('Base URL (结尾不带 /chat/completions)', _draft!.baseUrl, (v) => _draft = _draft!.copyWith(baseUrl: v),
                    hint: 'https://api.deepseek.com/v1'),
                const SizedBox(height: 12),
                _buildTextField('API Key', _draft!.apiKey, (v) => _draft = _draft!.copyWith(apiKey: v),
                    obscure: _obscureKey,
                    suffix: IconButton(
                      icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscureKey = !_obscureKey),
                    )),
                const SizedBox(height: 12),
                _buildTextField('模型名', _draft!.model, (v) => _draft = _draft!.copyWith(model: v),
                    hint: 'deepseek-chat / qwen-turbo / glm-4-flash'),
                const SizedBox(height: 12),
                _buildTextField('系统提示词 (可选)', _draft!.systemPrompt ?? '', (v) => _draft = _draft!.copyWith(systemPrompt: v.isEmpty ? null : v),
                    maxLines: 3,
                    hint: '你是一个温柔、善于倾听的 AI 伴侣...'),

                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _testing ? null : _testConnection,
                        icon: _testing
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.wifi_tethering),
                        label: Text(_testing ? '测试中…' : '测试连接'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saveAndActivate,
                        icon: const Icon(Icons.save),
                        label: const Text('保存并激活'),
                      ),
                    ),
                  ],
                ),
                if (_testResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _testResult!.startsWith('✅') ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_testResult!, style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ],

                const SizedBox(height: 24),
                _buildSavedList(pm),
              ],
            ),
    );
  }

  Widget _buildPresetPicker() {
    final presets = PresetProviders.all();
    final isCustom = _draft?.name == '自定义提供商';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('选择 AI 接口', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(width: 6),
            const Icon(Icons.swipe_left, size: 14, color: Colors.grey),
            Text(' 左右滑动查看', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: presets.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) {
              if (i == presets.length) {
                return _presetCard(
                  emoji: '🛠️',
                  name: '自定义',
                  model: '任意 OpenAI 兼容服务',
                  baseUrl: '自己填 Base URL',
                  selected: isCustom,
                  onTap: () => setState(() => _draft = PresetProviders.custom()),
                );
              }
              final p = presets[i];
              final selected = _draft?.name == p.name && _draft?.baseUrl == p.baseUrl;
              return _presetCard(
                emoji: _presetEmoji(p.name),
                name: p.name,
                model: p.model.isEmpty ? '填模型名' : p.model,
                baseUrl: p.baseUrl,
                selected: selected,
                onTap: () => setState(() {
                  _draft = p.copyWith(apiKey: _draft!.apiKey); // 保留用户填的 Key
                }),
              );
            },
          ),
        ),
      ],
    );
  }

  static const _emojiMap = {
    'DeepSeek': '🐋',
    '通义千问': '🧠',
    '智谱 GLM': '⚡',
    'Kimi': '🌙',
    '豆包': '🌋',
    'SiliconFlow': '💨',
    'OpenAI': '🌐',
    'Claude': '✳️',
  };

  String _presetEmoji(String name) {
    for (final k in _emojiMap.keys) {
      if (name.contains(k)) return _emojiMap[k]!;
    }
    return '🤖';
  }

  Widget _presetCard({
    required String emoji,
    required String name,
    required String model,
    required String baseUrl,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 168,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer.withValues(alpha: 0.5) : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? cs.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const Spacer(),
                if (selected) Icon(Icons.check_circle, size: 18, color: cs.primary),
              ],
            ),
            const Spacer(),
            Text(
              name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              model,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.primary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              baseUrl,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String value,
    ValueChanged<String> onChanged, {
    bool obscure = false,
    Widget? suffix,
    int maxLines = 1,
    String? hint,
  }) {
    return TextFormField(
      // 用 key 绑定初值，切换预设时能重建输入框拿到新值
      key: ValueKey('$label::$value'),
      initialValue: value,
      obscureText: obscure,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffix,
      ),
    );
  }

  Widget _buildSavedList(ProviderManager pm) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('已保存的配置', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        if (pm.providers.isEmpty)
          const Text('（暂无）', style: TextStyle(color: Colors.grey))
        else
          ...pm.providers.map((p) => Card(
                child: ListTile(
                  leading: Icon(
                    p.id == pm.active?.id ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: p.id == pm.active?.id ? Colors.green : null,
                  ),
                  title: Text(p.name),
                  subtitle: Text('${p.baseUrl}\n${p.model}', maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: PopupMenuButton<String>(
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('编辑')),
                      PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                    onSelected: (v) async {
                      if (v == 'edit') {
                        setState(() => _draft = p.copyWith());
                      } else if (v == 'delete') {
                        await pm.delete(p.id);
                      }
                    },
                  ),
                  onTap: () => pm.activate(p.id),
                ),
              )),
      ],
    );
  }

  Future<void> _testConnection() async {
    if (_draft == null || _draft!.apiKey.isEmpty || _draft!.baseUrl.isEmpty || _draft!.model.isEmpty) {
      setState(() => _testResult = '❌ 请先填写 Base URL / API Key / 模型名');
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final result = await AiProviderService(_draft!).testConnection();
    setState(() {
      _testing = false;
      _testResult = result;
    });
  }

  Future<void> _saveAndActivate() async {
    if (_draft == null) return;
    if (_draft!.baseUrl.isEmpty || _draft!.apiKey.isEmpty || _draft!.model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先填写完整的配置')),
      );
      return;
    }
    await context.read<ProviderManager>().saveProvider(_draft!, activate: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存并激活 ✅')),
      );
      Navigator.of(context).maybePop();
    }
  }
}
