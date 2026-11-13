import 'package:flutter_test/flutter_test.dart';

import 'package:ai_assistant/config/ai_provider_config.dart';

void main() {
  group('AiProviderConfig', () {
    test('拼接 chat/completions URL（去掉结尾斜杠）', () {
      const c = AiProviderConfig(
        id: 'x',
        name: 'DeepSeek',
        baseUrl: 'https://api.deepseek.com/v1/',
        apiKey: 'k',
        model: 'deepseek-chat',
      );
      expect(c.chatCompletionsUrl,
          'https://api.deepseek.com/v1/chat/completions');
    });

    test('无结尾斜杠时同样正确', () {
      const c = AiProviderConfig(
        id: 'y',
        name: 'OpenAI',
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'k',
        model: 'gpt-4o-mini',
      );
      expect(c.chatCompletionsUrl,
          'https://api.openai.com/v1/chat/completions');
    });

    test('JSON 往返序列化', () {
      const c = AiProviderConfig(
        id: 'z',
        name: '自定义',
        baseUrl: 'https://example.com/v1',
        apiKey: 'sk-123',
        model: 'my-model',
        systemPrompt: '你是助手',
      );
      final back = AiProviderConfig.fromJson(c.toJson());
      expect(back.baseUrl, c.baseUrl);
      expect(back.model, c.model);
      expect(back.systemPrompt, c.systemPrompt);
    });
  });
}
