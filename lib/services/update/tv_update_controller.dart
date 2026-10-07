import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'tv_update_client.dart';
import 'tv_update_manifest.dart';

abstract class TvUpdatePlatform {
  Future<TvInstalledVersion> installed();
  Future<void> verify(String path, TvUpdateManifest update);
  Future<bool> canInstall();
  Future<void> openPermission();
  Future<void> install(String path, TvUpdateManifest update);
}

class AndroidTvUpdatePlatform implements TvUpdatePlatform {
  static const _channel = MethodChannel('com.predidit.kazumi/tv_update');
  Map<String, Object> _arguments(String path, TvUpdateManifest update) => {
    'path': path,
    'versionName': update.versionName,
    'versionCode': update.versionCode,
    'size': update.size,
    'sha256': update.sha256,
  };
  @override
  Future<TvInstalledVersion> installed() async {
    final info = await _channel.invokeMapMethod<String, dynamic>('installed');
    if (info == null) throw const TvUpdateException('无法读取当前 TV 版本');
    return TvInstalledVersion(
      name: info['name'] as String,
      code: info['code'] as int,
      sdk: info['sdk'] as int,
      abis: List<String>.from(info['abis'] as List),
    );
  }

  @override
  Future<void> verify(String path, TvUpdateManifest update) async {
    try {
      await _channel.invokeMethod<void>('verify', _arguments(path, update));
    } on PlatformException catch (e) {
      throw TvUpdateException(e.message ?? 'APK 验证失败');
    }
  }

  @override
  Future<bool> canInstall() async =>
      await _channel.invokeMethod<bool>('canInstall') ?? false;
  @override
  Future<void> openPermission() =>
      _channel.invokeMethod<void>('openPermission');
  @override
  Future<void> install(String path, TvUpdateManifest update) async {
    try {
      await _channel.invokeMethod<void>('install', _arguments(path, update));
    } on PlatformException catch (e) {
      throw TvUpdateException(e.message ?? '无法启动系统安装界面');
    }
  }
}

enum TvUpdateStage {
  checking,
  current,
  offer,
  downloading,
  verifying,
  ready,
  permission,
  installing,
  error,
}

class TvUpdateController extends ChangeNotifier {
  TvUpdateController({
    required this.client,
    required this.platform,
    required this.directory,
    TvUpdateManifest? initial,
  }) : update = initial {
    if (initial != null) stage = TvUpdateStage.offer;
  }
  final TvUpdateClient client;
  final TvUpdatePlatform platform;
  final Future<Directory> Function() directory;
  TvUpdateStage stage = TvUpdateStage.checking;
  TvUpdateManifest? update;
  TvInstalledVersion? current;
  String? path;
  String? error;
  bool checkedFromCache = false;
  int received = 0;
  bool _disposed = false;
  bool _running = false;
  CancelToken? _token;
  bool get busy =>
      stage == TvUpdateStage.checking ||
      stage == TvUpdateStage.downloading ||
      stage == TvUpdateStage.verifying;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _failure(Object e) {
    error = tvUpdateError(e);
    stage = TvUpdateStage.error;
    _changed();
  }

  Future<void> check() async {
    if (_running || _disposed) return;
    _running = true;
    final token = _token = CancelToken();
    stage = TvUpdateStage.checking;
    error = null;
    _changed();
    try {
      current = await platform.installed();
      update = await client.latest(current!, token);
      checkedFromCache = client.usedCachedResult;
      token.throwIfCancellationRequested();
      path = null;
      stage = update == null ? TvUpdateStage.current : TvUpdateStage.offer;
      _changed();
    } catch (e) {
      if (!token.isCancelled) _failure(e);
    } finally {
      _running = false;
    }
  }

  Future<void> download() async {
    if (_running || _disposed || update == null) return;
    _running = true;
    final token = _token = CancelToken();
    stage = TvUpdateStage.downloading;
    received = 0;
    error = null;
    _changed();
    try {
      final downloaded = await client.download(
        update!,
        await directory(),
        token,
        (bytes, _) {
          if (!token.isCancelled) {
            received = bytes;
            _changed();
          }
        },
      );
      token.throwIfCancellationRequested();
      stage = TvUpdateStage.verifying;
      _changed();
      await platform.verify(downloaded, update!);
      token.throwIfCancellationRequested();
      path = downloaded;
      stage = TvUpdateStage.ready;
      _changed();
    } catch (e) {
      if (!token.isCancelled) _failure(e);
    } finally {
      _running = false;
      if (token.isCancelled && !_disposed) _changed();
    }
  }

  void cancelDownload() {
    _token?.cancel();
    stage = update == null ? TvUpdateStage.current : TvUpdateStage.offer;
    _changed();
  }

  Future<void> install() async {
    if (_running || _disposed || path == null || update == null) return;
    _running = true;
    try {
      if (!await platform.canInstall()) {
        stage = TvUpdateStage.permission;
        _changed();
        return;
      }
      // Native side rechecks hash, package, installed build and signature again.
      stage = TvUpdateStage.installing;
      _changed();
      await platform.install(path!, update!);
      stage = TvUpdateStage.ready;
      _changed();
    } catch (e) {
      _failure(e);
    } finally {
      _running = false;
    }
  }

  Future<void> openPermission() async {
    try {
      await platform.openPermission();
    } catch (e) {
      _failure(e);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _token?.cancel();
    super.dispose();
  }
}
