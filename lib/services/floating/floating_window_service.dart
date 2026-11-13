import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../ai/ai_provider_service.dart';
import '../storage/hive_service.dart';

/// 悬浮窗服务封装
///
/// 对应原生 FloatingWindowService（MethodChannel: floating_window_channel）。
/// 数据流（复刻猫小泡架构，AI 层替换为用户自选 OpenAI 兼容接口）：
///
///   点击气泡 → 原生截屏授权 → MediaProjection 截屏
///     → capture_result_code + capture_data (JPEG bytes) → Dart
///     → chatVisionStream（OpenAI Vision 格式，流式）
///     → show_reply 逐 token 回传原生面板显示
class FloatingWindowService {
  FloatingWindowService._();

  static final FloatingWindowService instance = FloatingWindowService._();

  static const _channel = MethodChannel('floating_window_channel');
  static const defaultPrompt =
      '这是一张手机聊天界面的截图。请分析对方的消息和语境，帮我给出 2-3 条高情商的回复建议，'
      '每条一行、简短自然、口语化，直接输出建议本身，不要解释。';

  static const _promptKey = 'floating_prompt';
  static const _styleKey = 'floating_style';

  /// 回复风格（对照原应用风格条）
  static const styles = ['松弛', '通用', '幽默', '深度', '暧昧升温', '简短'];

  static const _styleHints = {
    '松弛': '轻松随意，像朋友间闲聊，不要太正式',
    '通用': '自然得体，口语化',
    '幽默': '俏皮幽默，可以适度调侃，但别油腻',
    '深度': '有思考有洞察，真诚走心，让人感到被理解',
    '暧昧升温': '略带暧昧和撩人气息，推进两人关系',
    '简短': '极简短句，每条不超过15个字',
  };

  bool serviceRunning = false;

  /// 最近一次截屏（风格切换时用同一张图重新生成）
  Uint8List? _lastJpeg;

  /// 截屏结果回调（设置页可用它刷新状态）
  void Function(bool success)? onCaptureResult;

  /// 在 main() 中调用一次
  void init() {
    _channel.setMethodCallHandler(_handle);
  }

  Future<dynamic> _handle(MethodCall call) async {
    debugPrint('[CompAI] Dart收到 ${call.method}');
    switch (call.method) {
      case 'onCaptureResult':
        // 只用 capture_data 判断成败：Android 的 RESULT_OK == -1，
        // Kotlin 会把 resultCode 原样透传，不能用 code 符号判断
        final data = call.arguments['capture_data'] as Uint8List?;
        if (data == null) {
          serviceRunning = false; // 授权被拒，服务自行退出了
          final err = call.arguments['capture_error'] as String?;
          onCaptureResult?.call(false);
          _lastError = err ?? '截屏未完成';
          return null;
        }
        _lastError = null;
        onCaptureResult?.call(true);
        await _analyze(data);
        return null;
      case 'regenerate':
        // 悬浮面板上切换了风格 → 保存并按新风格用同一张截图重新生成
        final s = call.arguments['style'] as String?;
        if (s != null && FloatingWindowService.styles.contains(s)) style = s;
        final jpeg = _lastJpeg;
        if (jpeg != null) await _analyze(jpeg);
        return null;
      case 'onServiceState':
        serviceRunning = call.arguments['state'] == 'running';
        return null;
    }
    return null;
  }

  String? _lastError;

  /// 最近一次截屏失败的详细原因（设置页展示用）
  String? get lastError => _lastError;

  // ─── Dart → 原生 ─────────────────────────────────────────────────────

  Future<bool> isOverlayPermissionGranted() async =>
      await _channel.invokeMethod<bool>('check_overlay_permission') ?? false;

  Future<void> requestOverlayPermission() =>
      _channel.invokeMethod('request_overlay_permission');

  Future<void> startService() => _channel.invokeMethod('start_service');

  Future<void> stopService() => _channel.invokeMethod('stop_service');

  /// 触发一次截屏（原生拉起授权 Activity，结果经 onCaptureResult 回调）
  Future<bool> requestCapture() async =>
      await _channel.invokeMethod<bool>('request_capture') ?? false;

  void showStatus(String text) =>
      _channel.invokeMethod('show_status', {'text': text});

  /// 流式更新多行回复（每行一张可复制卡片）
  void showReplyLines(List<String> lines) =>
      _channel.invokeMethod('show_reply', {'lines': lines});

  void hidePanel() => _channel.invokeMethod('hide_panel');

  // ─── 提示词配置（存 Hive providers box，与 provider 数据不冲突）──────

  String get prompt =>
      (Hive.box('providers').get(_promptKey) as String?) ?? defaultPrompt;

  set prompt(String value) => Hive.box('providers').put(_promptKey, value);

  /// 当前回复风格
  String get style =>
      (Hive.box('providers').get(_styleKey) as String?) ?? '通用';

  set style(String value) => Hive.box('providers').put(_styleKey, value);

  // ─── AI 分析 ─────────────────────────────────────────────────────────

  /// 把 AI 原始输出拆成单条建议（去掉序号/列表符号/空行）
  static List<String> splitSuggestions(String raw) {
    final lines = <String>[];
    for (var line in raw.split('\n')) {
      line = line.trim();
      if (line.isEmpty) continue;
      line = line.replaceFirst(RegExp(r'^\d+[.、)．]\s*'), '');
      line = line.replaceFirst(RegExp(r'^[-*•·]\s*'), '');
      line = line.trim();
      if (line.isEmpty) continue;
      lines.add(line);
    }
    return lines;
  }

  Future<void> _analyze(Uint8List jpeg) async {
    debugPrint('[CompAI] _analyze: 截图 ${jpeg.length} 字节, 开始请求视觉模型');
    _lastJpeg = jpeg;
    showStatus('正在分析屏幕内容…');

    final provider = HiveService.instance.getActiveProvider();
    if (provider == null) {
      debugPrint('[CompAI] _analyze: 无激活的 AI 接口');
      showReplyLines(['未配置 AI 接口，请打开应用 → 设置 → 添加 AI 接口']);
      return;
    }
    debugPrint('[CompAI] _analyze: provider=${provider.name} model=${provider.model} style=$style');

    // 视觉模型需要用户自己配置（如 glm-4v / qwen-vl-max / gpt-4o）
    final hint = _styleHints[style] ?? '';
    final fullPrompt =
        '$prompt\n\n本次要求：回复风格为「$style」（$hint）。'
        '请给出 3 条不同的回复建议，每条独立成一行；'
        '不要序号、不要引号、不要任何解释或补充说明。';

    final service = AiProviderService(provider);
    final buffer = StringBuffer();
    await for (final token in service.chatVisionStream(
      imageBytes: jpeg,
      prompt: fullPrompt,
    )) {
      buffer.write(token);
      // 流式过程中按行拆分，实时渲染成多张卡片
      final lines = splitSuggestions(buffer.toString());
      if (lines.isNotEmpty) showReplyLines(lines);
    }
  }
}
