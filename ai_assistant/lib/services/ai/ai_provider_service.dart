import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../config/ai_provider_config.dart';

/// AI 消息角色
enum AiRole { system, user, assistant }

class AiMessage {
  final AiRole role;
  final String content;
  const AiMessage({required this.role, required this.content});

  Map<String, String> toJson() => {'role': role.name, 'content': content};
}

/// AI Provider 服务
///
/// 实现 OpenAI 兼容协议的 `/v1/chat/completions`（SSE 流式）。
/// 几乎所有国内 AI 厂商都支持这个协议的兼容模式。
class AiProviderService {
  final AiProviderConfig config;
  final Dio _dio;

  AiProviderService(this.config)
      : _dio = Dio(BaseOptions(
          headers: {
            'Authorization': 'Bearer ${config.apiKey}',
            'Content-Type': 'application/json',
            ...?config.extraHeaders,
          },
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 120),
        ));

  /// 发送流式请求，返回一个 token 流
  ///
  /// SSE 格式：每一行是 `data: {...}`，最后一行是 `data: [DONE]`
  /// [cancelToken] 用于中断（对应原应用 SseClientAndroid 的 AtomicBoolean 中断标志）
  Stream<String> chatStream({
    required List<AiMessage> messages,
    double temperature = 0.7,
    CancelToken? cancelToken,
  }) async* {
    final messagesJson = messages.map((m) => m.toJson()).toList();

    // 如果配置了 systemPrompt 且 messages 里没有 system 消息，自动插入
    if (config.systemPrompt != null && config.systemPrompt!.isNotEmpty) {
      final hasSystem = messages.any((m) => m.role == AiRole.system);
      if (!hasSystem) {
        messagesJson.insert(
          0,
          AiMessage(role: AiRole.system, content: config.systemPrompt!).toJson(),
        );
      }
    }

    yield* _streamTokens(
      _baseBody(messagesJson, temperature),
      cancelToken: cancelToken,
    );
  }

  /// 看图请求（OpenAI Vision 格式，悬浮窗截屏分析用）
  ///
  /// 消息 content 为多段结构：text + image_url(base64 data URI)。
  /// 需要模型支持视觉（如 glm-4v / qwen-vl / gpt-4o / 豆包 vision）。
  Stream<String> chatVisionStream({
    required List<int> imageBytes,
    required String prompt,
    String? systemPrompt,
    String mimeType = 'image/jpeg',
    double temperature = 0.7,
    CancelToken? cancelToken,
  }) async* {
    final messagesJson = <Map<String, dynamic>>[
      if (systemPrompt != null && systemPrompt.isNotEmpty)
        {'role': AiRole.system.name, 'content': systemPrompt},
      {
        'role': AiRole.user.name,
        'content': [
          {'type': 'text', 'text': prompt},
          {
            'type': 'image_url',
            'image_url': {
              'url': 'data:$mimeType;base64,${base64Encode(imageBytes)}',
            },
          },
        ],
      },
    ];
    yield* _streamTokens(
      _baseBody(messagesJson, temperature),
      cancelToken: cancelToken,
    );
  }

  Map<String, dynamic> _baseBody(List<Map<String, dynamic>> messages, double temperature) => {
        'model': config.model,
        'stream': true,
        'temperature': temperature,
        'messages': messages,
      };

  /// 发起流式 POST 并逐 token yield（聊天与看图共用的 SSE 循环）
  Stream<String> _streamTokens(
    Map<String, dynamic> body, {
    CancelToken? cancelToken,
  }) async* {
    try {
      final response = await _dio.post<ResponseBody>(
        config.chatCompletionsUrl,
        data: body,
        options: Options(responseType: ResponseType.stream),
        cancelToken: cancelToken,
      );

      // 用 utf8.decoder 变换器解码，避免多字节汉字被 chunk 边界切断时报错
      final stream = response.data!.stream
          .cast<List<int>>()
          .transform(const Utf8Decoder(allowMalformed: true));
      String buffer = '';

      await for (final text in stream) {
        buffer += text;

        // SSE 事件以 \n\n 分隔
        while (buffer.contains('\n\n')) {
          final idx = buffer.indexOf('\n\n');
          final event = buffer.substring(0, idx);
          buffer = buffer.substring(idx + 2);

          final token = _parseSseEvent(event);
          if (token != null) {
            yield token;
          }
        }
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return; // 用户主动中断，不算错误
      yield '【错误：${_friendlyError(e)}】';
    } catch (e) {
      yield '【错误：$e】';
    }
  }

  /// 解析 SSE 事件，提取 delta.content
  String? _parseSseEvent(String event) {
    final lines = event.split('\n');
    for (final line in lines) {
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data.isEmpty) continue;
      if (data == '[DONE]') return null;

      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        final choices = json['choices'] as List?;
        if (choices == null || choices.isEmpty) continue;

        final firstChoice = choices.first as Map<String, dynamic>;
        final delta = firstChoice['delta'] as Map<String, dynamic>?;
        if (delta == null) continue;

        final content = delta['content'] as String?;
        if (content != null && content.isNotEmpty) return content;
      } catch (_) {
        // JSON 解析失败（可能是心跳行），跳过
      }
    }
    return null;
  }

  /// 测试连接（发送一个最小的非流式请求）
  Future<String?> testConnection() async {
    try {
      final response = await _dio.post(
        config.chatCompletionsUrl,
        data: {
          'model': config.model,
          'stream': false,
          'messages': [
            const AiMessage(role: AiRole.user, content: 'ping').toJson(),
          ],
        },
      );
      return '✅ 连接成功 (${response.statusCode})';
    } on DioException catch (e) {
      return '❌ ${_friendlyError(e)}';
    } catch (e) {
      return '❌ $e';
    }
  }

  String _friendlyError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '网络超时，请检查 Base URL 或网络连接';
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        if (status == 401) return 'API Key 无效 (401)';
        if (status == 404) return 'Base URL 或模型名不存在 (404)';
        if (status == 429) return '请求过于频繁 (429)';
        return '服务器返回 $status';
      case DioExceptionType.connectionError:
        return '无法连接服务器，请检查 Base URL';
      default:
        return e.message ?? '未知错误';
    }
  }
}
