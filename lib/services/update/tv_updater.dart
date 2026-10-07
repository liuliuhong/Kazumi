import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/tv_menu_support.dart';
import 'package:kazumi/navigation.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'tv_update_client.dart';
import 'tv_update_controller.dart';
import 'tv_update_dialog.dart';
import 'tv_update_manifest.dart';

class TvUpdater {
  TvUpdater._();
  static final instance = TvUpdater._();
  final _platform = AndroidTvUpdatePlatform();
  bool _checking = false;
  bool _showing = false;
  Timer? _pendingTimer;
  TvUpdateManifest? _pending;
  TvInstalledVersion? _pendingInstalled;
  CancelToken? _backgroundToken;
  final _checkCache = TvUpdateCheckCache();
  TvUpdateClient get _client =>
      TvUpdateClient(DioFactory.downloadDio, cache: _checkCache);

  Future<bool> check({required bool automatic}) async {
    if (_showing) return false;
    if (!automatic) {
      _backgroundToken?.cancel();
      _pending = null;
      _pendingTimer?.cancel();
      await _show();
      return true;
    }
    if (_checking) return false;
    if (!GStorage.getSetting(SettingsKeys.autoUpdate)) return false;
    final last = GStorage.getSetting(SettingsKeys.tvUpdateLastCheck);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now >= last && now - last < const Duration(days: 1).inMilliseconds) {
      return false;
    }
    _checking = true;
    try {
      await GStorage.putSetting(SettingsKeys.tvUpdateLastCheck, now);
      final token = _backgroundToken = CancelToken();
      final installed = await _platform.installed();
      final update = await _client.latest(installed, token);
      token.throwIfCancellationRequested();
      if (update != null &&
          update.versionCode !=
              GStorage.getSetting(SettingsKeys.tvUpdateSkippedBuild)) {
        _pending = update;
        _pendingInstalled = installed;
        _pendingTimer?.cancel();
        _pendingTimer = Timer.periodic(
          const Duration(seconds: 3),
          (_) => _showPending(),
        );
        _showPending();
      }
      return true;
    } catch (e) {
      KazumiLogger().w('TV update: background check failed', error: e);
      return false;
    } finally {
      _checking = false;
    }
  }

  void _showPending() {
    if (!GStorage.getSetting(SettingsKeys.autoUpdate)) {
      _pending = null;
      _pendingTimer?.cancel();
      return;
    }
    final context = rootNavigatorKey.currentContext;
    if (_showing ||
        _pending == null ||
        context == null ||
        KazumiDialog.observer.hasKazumiDialog ||
        TvMenuSupport.isOpen ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    String path;
    try {
      path = context.routeState(listen: false).uri.path;
    } catch (_) {
      return;
    }
    if (!const [
      '/tab/popular/',
      '/tab/timeline/',
      '/tab/collect/',
      '/tab/my/',
      '/tab/popular',
      '/tab/timeline',
      '/tab/collect',
      '/tab/my',
    ].contains(path)) {
      return;
    }
    final update = _pending!;
    _pending = null;
    _pendingTimer?.cancel();
    unawaited(_show(initial: update, installed: _pendingInstalled));
  }

  Future<void> _show({
    TvUpdateManifest? initial,
    TvInstalledVersion? installed,
  }) async {
    _showing = true;
    final opener = FocusManager.instance.primaryFocus;
    final controller = TvUpdateController(
      client: _client,
      platform: _platform,
      initial: initial,
      directory: () async =>
          Directory('${(await getTemporaryDirectory()).path}/tv-updates'),
    );
    final handle = KazumiDialogHandle<void>();
    controller.current = installed;
    if (initial == null) unawaited(controller.check());
    try {
      await KazumiDialog.show<void>(
        handle: handle,
        clickMaskDismiss: false,
        builder: (_) => TvUpdateDialog(
          controller: controller,
          onClose: handle.dismiss,
          onSkip: (code) =>
              GStorage.putSetting(SettingsKeys.tvUpdateSkippedBuild, code),
        ),
      );
    } finally {
      controller.dispose();
      _showing = false;
      if (opener?.context != null && opener!.canRequestFocus) {
        opener.requestFocus();
      }
    }
  }
}
