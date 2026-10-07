import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'tv_update_manifest.dart';

extension TvUpdateCancellation on CancelToken {
  void throwIfCancellationRequested() {
    if (isCancelled) throw cancelError!;
  }
}

class TvUpdateCheckCache {
  DateTime? expires;
  String? installedKey;
  TvUpdateManifest? result;
  DateTime? retryAt;
}

class TvUpdateClient {
  TvUpdateClient(
    this.dio, {
    TvUpdateCheckCache? cache,
    DateTime Function()? now,
  }) : cache = cache ?? TvUpdateCheckCache(),
       _now = now ?? DateTime.now;
  final Dio dio;
  final TvUpdateCheckCache cache;
  final DateTime Function() _now;
  bool usedCachedResult = false;

  Future<TvUpdateManifest?> latest(
    TvInstalledVersion installed,
    CancelToken token,
  ) async {
    token.throwIfCancellationRequested();
    usedCachedResult = false;
    final now = _now();
    if (cache.retryAt?.isAfter(now) == true) {
      throw TvUpdateException(_rateLimitMessage(cache.retryAt!));
    }
    final key =
        '${installed.code}:${installed.sdk}:${installed.abis.join(',')}';
    if (cache.installedKey == key && cache.expires?.isAfter(now) == true) {
      usedCachedResult = true;
      return cache.result;
    }
    try {
      final result = await _fetchLatest(installed, token);
      token.throwIfCancellationRequested();
      cache.installedKey = key;
      cache.result = result;
      cache.expires = _now().add(const Duration(minutes: 5));
      cache.retryAt = null;
      return result;
    } on DioException catch (error) {
      if (_isRateLimit(error)) {
        cache.retryAt = _retryTime(error, _now());
        throw TvUpdateException(_rateLimitMessage(cache.retryAt!));
      }
      rethrow;
    }
  }

  Future<TvUpdateManifest?> _fetchLatest(
    TvInstalledVersion installed,
    CancelToken token,
  ) async {
    final response = await dio.get<String>(
      tvLatestReleaseApi,
      cancelToken: token,
      options: Options(
        responseType: ResponseType.plain,
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'Kazumi-TV-Updater',
        },
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    token.throwIfCancellationRequested();
    final raw = response.data ?? '';
    if (utf8.encode(raw).length > 2 * 1024 * 1024) {
      throw const TvUpdateException('发布信息过大');
    }
    final release = TvRelease(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
    if (!release.assets.any((a) => a['name'] == 'update.json') &&
        release.legacyBuild != null &&
        release.legacyBuild! <= installed.code) {
      return null;
    }
    final metadata = release.asset('update.json');
    if ((metadata['size'] as int? ?? 0) <= 0 || metadata['size'] > 65536) {
      throw const TvUpdateException('更新信息附件大小无效');
    }
    final content = await dio.get<String>(
      metadata['browser_download_url'] as String,
      cancelToken: token,
      options: Options(
        responseType: ResponseType.plain,
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    token.throwIfCancellationRequested();
    final bytes = utf8.encode(content.data ?? '');
    if (bytes.length != metadata['size'] ||
        bytes.length > 65536 ||
        metadata['digest'] != 'sha256:${sha256.convert(bytes)}') {
      throw const TvUpdateException('更新信息附件校验失败');
    }
    final manifest = TvUpdateManifest.parse(
      Map<String, dynamic>.from(jsonDecode(content.data!) as Map),
      release,
      installed,
    );
    return manifest.isNewerThan(installed) ? manifest : null;
  }

  Future<bool> validFile(
    File file,
    TvUpdateManifest update,
    CancelToken token,
  ) async {
    token.throwIfCancellationRequested();
    if (!await file.exists() || await file.length() != update.size) {
      return false;
    }
    final hash = await sha256.bind(file.openRead()).first;
    token.throwIfCancellationRequested();
    return hash.toString() == update.sha256;
  }

  Future<String> download(
    TvUpdateManifest update,
    Directory directory,
    CancelToken token,
    void Function(int, int) progress,
  ) async {
    await directory.create(recursive: true);
    token.throwIfCancellationRequested();
    final file = File('${directory.path}/${update.fileName}');
    if (await validFile(file, update, token)) return file.path;
    final partial = File('${file.path}.part');
    try {
      await dio.download(
        update.downloadUrl,
        partial.path,
        cancelToken: token,
        onReceiveProgress: progress,
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );
      if (!await validFile(partial, update, token)) {
        throw const TvUpdateException('下载文件大小或 SHA-256 校验失败，请重新下载');
      }
      token.throwIfCancellationRequested();
      if (await file.exists()) await file.delete();
      return (await partial.rename(file.path)).path;
    } finally {
      if (await partial.exists()) await partial.delete();
    }
  }
}

String tvUpdateError(Object error) {
  if (error is TvUpdateException) return error.message;
  if (error is DioException) {
    if (_isRateLimit(error)) {
      return _rateLimitMessage(_retryTime(error, DateTime.now()));
    }
    if (error.response?.statusCode == 403) {
      return 'GitHub 拒绝访问更新接口（403），请检查网络或代理后重试';
    }
    if (error.response?.statusCode == 404) return '未找到正式版本或更新附件';
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return '更新请求超时，请检查网络后重试';
    }
    return '无法连接 GitHub，请检查网络后重试';
  }
  return '更新信息读取或安装验证失败，请重试';
}

bool _isRateLimit(DioException error) {
  final response = error.response;
  if (response?.statusCode == 429) return true;
  if (response?.statusCode != 403) return false;
  return response!.headers.value('x-ratelimit-remaining') == '0' ||
      response.headers.value('retry-after') != null ||
      response.data.toString().toLowerCase().contains('rate limit');
}

DateTime _retryTime(DioException error, DateTime now) {
  final headers = error.response?.headers;
  DateTime? until;
  final retry = headers?.value('retry-after');
  final seconds = int.tryParse(retry ?? '');
  if (seconds != null && seconds >= 0) {
    until = now.add(Duration(seconds: seconds));
  } else if (retry != null) {
    try {
      until = HttpDate.parse(retry);
    } on FormatException {
      /* Ignore invalid header. */
    }
  }
  if (headers?.value('x-ratelimit-remaining') == '0') {
    final reset = int.tryParse(headers?.value('x-ratelimit-reset') ?? '');
    if (reset != null && reset > 0 && reset < 253402300800) {
      final time = DateTime.fromMillisecondsSinceEpoch(
        reset * 1000,
        isUtc: true,
      );
      if (until == null || time.isAfter(until)) until = time;
    }
  }
  return until != null && until.isAfter(now)
      ? until
      : now.add(const Duration(minutes: 1));
}

String _rateLimitMessage(DateTime retryAt) {
  final time = retryAt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final label =
      '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  return 'GitHub 暂时限制了请求。预计可重试时间：$label（本机时间）。'
      '此时间之前不会重复发起检查请求。';
}
