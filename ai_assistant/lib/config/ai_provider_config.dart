/// AI Provider 配置模型
///
/// 设计目标：一个通用配置，填 Base URL + API Key + Model 就能跑。
/// 绝大多数国内 AI 厂商（DeepSeek/通义千问/GLM/Kimi/豆包）都兼容
/// OpenAI 的 `/v1/chat/completions` 协议。
class AiProviderConfig {
  /// 本地唯一 ID
  final String id;

  /// 显示名称，如 "DeepSeek", "通义千问"
  final String name;

  /// 基础 URL（必须以 /v1 结尾或不含路径）
  /// 例：https://api.deepseek.com/v1
  final String baseUrl;

  /// API Key
  final String apiKey;

  /// 模型名，如 deepseek-chat, qwen-turbo, glm-4, kimi-k2
  final String model;

  /// 系统提示词（可选，用户可以自定义）
  final String? systemPrompt;

  /// 额外 Header（可选，部分厂商需要额外鉴权头）
  final Map<String, String>? extraHeaders;

  /// 是否为当前激活的配置
  final bool isActive;

  const AiProviderConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.systemPrompt,
    this.extraHeaders,
    this.isActive = false,
  });

  /// 发送流式请求的完整 URL
  String get chatCompletionsUrl =>
      '${baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl}/chat/completions';

  AiProviderConfig copyWith({
    String? name,
    String? baseUrl,
    String? apiKey,
    String? model,
    String? systemPrompt,
    Map<String, String>? extraHeaders,
    bool? isActive,
  }) {
    return AiProviderConfig(
      id: id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      extraHeaders: extraHeaders ?? this.extraHeaders,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'systemPrompt': systemPrompt,
        'extraHeaders': extraHeaders,
        'isActive': isActive,
      };

  factory AiProviderConfig.fromJson(Map<String, dynamic> json) => AiProviderConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        baseUrl: json['baseUrl'] as String,
        apiKey: json['apiKey'] as String,
        model: json['model'] as String,
        systemPrompt: json['systemPrompt'] as String?,
        extraHeaders: (json['extraHeaders'] as Map<String, dynamic>?)?.cast<String, String>(),
        isActive: json['isActive'] as bool? ?? false,
      );
}
