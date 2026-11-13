import 'package:flutter/foundation.dart';

import '../config/ai_provider_config.dart';
import '../config/preset_providers.dart';
import '../services/storage/hive_service.dart';

/// AI Provider 状态管理
class ProviderManager extends ChangeNotifier {
  final HiveService _hive = HiveService.instance;

  List<AiProviderConfig> _providers = [];
  AiProviderConfig? _active;
  bool _isLoading = true;

  List<AiProviderConfig> get providers => _providers;
  AiProviderConfig? get active => _active;
  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    _providers = _hive.listProviders();
    _active = _hive.getActiveProvider();

    // 如果用户从未配置过，预设列表里挑一个当作"模板"
    if (_providers.isEmpty) {
      await saveProvider(PresetProviders.deepseek);
      await saveProvider(PresetProviders.qwen);
      await saveProvider(PresetProviders.glm);
      _providers = _hive.listProviders();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> saveProvider(AiProviderConfig config, {bool activate = false}) async {
    await _hive.saveProvider(config, activate: activate);
    _providers = _hive.listProviders();
    if (activate || config.id == _active?.id) {
      _active = config;
    }
    notifyListeners();
  }

  Future<void> activate(String id) async {
    await _hive.activateProvider(id);
    _active = _hive.getActiveProvider();
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _hive.deleteProvider(id);
    _providers = _hive.listProviders();
    if (_active?.id == id) _active = _hive.getActiveProvider();
    notifyListeners();
  }
}
