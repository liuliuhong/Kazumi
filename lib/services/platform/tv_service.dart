import 'dart:io';

import 'package:flutter/services.dart';
import 'package:kazumi/utils/dandan_credentials.dart';

/// Explicit TV builds also work on vendor launchers without Leanback features.
class TvService {
  TvService._();

  static const isTvBuild = bool.fromEnvironment('KAZUMI_TV');
  static const _channel = MethodChannel('com.predidit.kazumi/intent');
  static bool _isTelevision = isTvBuild;

  static bool get isTelevision => _isTelevision;

  static Future<String?> searchInput(String initialText) =>
      _channel.invokeMethod<String>('showTvSearchInput', initialText);

  static Future<String?> textInput(
    String initialText, {
    required String title,
    bool obscure = false,
    bool numeric = false,
  }) => _channel.invokeMethod<String>('showTvTextInput', {
    'text': initialText,
    'title': title,
    'obscure': obscure,
    'numeric': numeric,
  });

  static Future<void> initialize() async {
    if (Platform.isAndroid && isTvBuild) {
      final saved = await _channel.invokeMapMethod<String, String>(
        'getTvDanmakuCredentials',
      );
      if (saved != null &&
          saved['id']?.isNotEmpty == true &&
          saved['value']?.isNotEmpty == true) {
        setDeviceDandanCredentials(saved);
      }
    }
    if (!Platform.isAndroid || isTvBuild) return;
    try {
      _isTelevision =
          await _channel.invokeMethod<bool>('isTelevision') ?? false;
    } on MissingPluginException {
      _isTelevision = false;
    } on PlatformException {
      _isTelevision = false;
    }
  }

  static Future<void> saveDanmakuCredentials(String id, String secret) async {
    await _channel.invokeMethod<void>('setTvDanmakuCredentials', {
      'id': id,
      'value': secret,
    });
    setDeviceDandanCredentials(
      id.isEmpty || secret.isEmpty ? null : {'id': id, 'value': secret},
    );
  }
}
