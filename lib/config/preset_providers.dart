import 'package:uuid/uuid.dart';
import 'ai_provider_config.dart';

/// 国内主流 AI 提供商预设（OpenAI 兼容协议）
///
/// 用户可以直接选一个预设，再填 API Key 和模型名就能用。
/// 也可以选 "自定义" 手动输入 Base URL。
class PresetProviders {
  static const _uuid = Uuid();

  static const deepseek = AiProviderConfig(
    id: 'preset-deepseek',
    name: 'DeepSeek',
    baseUrl: 'https://api.deepseek.com/v1',
    apiKey: '',
    model: 'deepseek-chat',
    isActive: false,
  );

  static const qwen = AiProviderConfig(
    id: 'preset-qwen',
    name: '通义千问 (阿里云)',
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    apiKey: '',
    model: 'qwen-turbo',
    isActive: false,
  );

  static const glm = AiProviderConfig(
    id: 'preset-glm',
    name: '智谱 GLM',
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    apiKey: '',
    model: 'glm-4-flash',
    isActive: false,
  );

  static const kimi = AiProviderConfig(
    id: 'preset-kimi',
    name: '月之暗面 Kimi',
    baseUrl: 'https://api.moonshot.cn/v1',
    apiKey: '',
    model: 'moonshot-v1-8k',
    isActive: false,
  );

  static const ark = AiProviderConfig(
    id: 'preset-ark',
    name: '豆包 (火山引擎)',
    baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
    apiKey: '',
    model: '', // 豆包需要 endpoint_id，用户自己填
    isActive: false,
  );

  static const siliconflow = AiProviderConfig(
    id: 'preset-siliconflow',
    name: 'SiliconFlow',
    baseUrl: 'https://api.siliconflow.cn/v1',
    apiKey: '',
    model: '', // 有几百个模型，用户自己选
    isActive: false,
  );

  static const openai = AiProviderConfig(
    id: 'preset-openai',
    name: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
    apiKey: '',
    model: 'gpt-4o-mini',
    isActive: false,
  );

  static const claude = AiProviderConfig(
    id: 'preset-claude',
    name: 'Anthropic Claude',
    baseUrl: 'https://api.anthropic.com/v1',
    apiKey: '',
    model: 'claude-3-5-sonnet-latest',
    // 注：Claude 不兼容 OpenAI 协议，但 baseUrl 仍可参考
    // 实际调用需要用 Anthropic 专属协议
    isActive: false,
  );

  static List<AiProviderConfig> all() => [
        deepseek,
        qwen,
        glm,
        kimi,
        ark,
        siliconflow,
        openai,
        claude,
      ];

  static AiProviderConfig custom() => AiProviderConfig(
        id: _uuid.v4(),
        name: '自定义提供商',
        baseUrl: '',
        apiKey: '',
        model: '',
        isActive: false,
      );
}
