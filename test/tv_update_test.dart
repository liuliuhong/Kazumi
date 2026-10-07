import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/bean/widget/tv_app_support.dart';
import 'package:kazumi/services/update/tv_update_manifest.dart';
import 'package:kazumi/services/update/tv_update_client.dart';
import 'package:kazumi/services/update/tv_update_controller.dart';
import 'package:kazumi/services/update/tv_update_dialog.dart';

const tag = 'Kazumi_tv_base2.3.7_1.3.0';
const installed = TvInstalledVersion(
  name: 'Kazumi_tv_base2.3.7_1.2.0',
  code: 20307120,
  sdk: 34,
  abis: ['armeabi-v7a'],
);
final payload = utf8.encode('an APK fixture payload');
Map<String, dynamic> metadata() => {
  'schemaVersion': 1,
  'channel': 'stable',
  'packageName': tvUpdatePackage,
  'baseVersion': '2.3.7',
  'tvVersion': '1.3.0',
  'versionName': tag,
  'versionCode': 20307130,
  'minSdk': 24,
  'abis': ['armeabi-v7a', 'arm64-v8a'],
  'fileName': '$tag-arm.apk',
  'size': payload.length,
  'sha256': sha256.convert(payload).toString(),
};
Map<String, dynamic> asset(String name, List<int> bytes) => {
  'name': name,
  'state': 'uploaded',
  'size': bytes.length,
  'digest': 'sha256:${sha256.convert(bytes)}',
  'browser_download_url':
      'https://github.com/$tvUpdateRepository/releases/download/$tag/$name',
};
Map<String, dynamic> release({Map<String, dynamic>? manifest}) {
  final bytes = utf8.encode(jsonEncode(manifest ?? metadata()));
  return {
    'tag_name': tag,
    'draft': false,
    'prerelease': false,
    'body': List.filled(50, '修复 TV 遥控焦点导航。').join('\n'),
    'assets': [asset('update.json', bytes), asset('$tag-arm.apk', payload)],
  };
}

TvUpdateManifest offer() =>
    TvUpdateManifest.parse(metadata(), TvRelease(release()), installed);

class FixtureAdapter implements HttpClientAdapter {
  FixtureAdapter({this.modify, this.badDownload = false});
  final void Function(Map<String, dynamic>)? modify;
  final bool badDownload;
  int requests = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    if (options.uri.toString() == tvLatestReleaseApi) {
      final data = release();
      modify?.call(data);
      return ResponseBody.fromString(jsonEncode(data), 200);
    }
    if (options.uri.path.endsWith('update.json')) {
      return ResponseBody.fromString(jsonEncode(metadata()), 200);
    }
    final bytes = badDownload ? utf8.encode('bad file') : payload;
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        'content-length': ['${bytes.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

TvUpdateClient client({
  void Function(Map<String, dynamic>)? modify,
  bool badDownload = false,
}) => TvUpdateClient(
  Dio()
    ..httpClientAdapter = FixtureAdapter(
      modify: modify,
      badDownload: badDownload,
    ),
);

class FakePlatform implements TvUpdatePlatform {
  bool allowed = true;
  Object? invalid;
  int installs = 0;
  int permissions = 0;
  @override
  Future<TvInstalledVersion> installed() async => installedVersion;
  TvInstalledVersion get installedVersion => const TvInstalledVersion(
    name: 'Kazumi_tv_base2.3.7_1.2.0',
    code: 20307120,
    sdk: 34,
    abis: ['armeabi-v7a'],
  );
  @override
  Future<void> verify(String path, TvUpdateManifest update) async {
    if (invalid != null) throw invalid!;
  }

  @override
  Future<bool> canInstall() async => allowed;
  @override
  Future<void> openPermission() async {
    permissions++;
  }

  @override
  Future<void> install(String path, TvUpdateManifest update) async {
    installs++;
  }
}

class DelayedClient extends TvUpdateClient {
  DelayedClient() : super(Dio());
  final completed = Completer<void>();
  int downloads = 0;
  @override
  Future<String> download(
    TvUpdateManifest update,
    Directory directory,
    CancelToken token,
    void Function(int, int) progress,
  ) async {
    downloads++;
    progress(5, update.size);
    await completed.future;
    token.throwIfCancellationRequested();
    return 'fixture.apk';
  }
}

void main() {
  test(
    'successful checks share five minute cache and revalidate changed build',
    () async {
      var now = DateTime.utc(2026, 10, 7, 3);
      final adapter = FixtureAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      final cache = TvUpdateCheckCache();
      final first = TvUpdateClient(dio, cache: cache, now: () => now);
      expect(await first.latest(installed, CancelToken()), isNotNull);
      expect(adapter.requests, 2);
      final reopened = TvUpdateClient(dio, cache: cache, now: () => now);
      expect(await reopened.latest(installed, CancelToken()), isNotNull);
      expect(reopened.usedCachedResult, isTrue);
      expect(adapter.requests, 2);
      final updated = TvInstalledVersion(
        name: tag,
        code: 20307130,
        sdk: installed.sdk,
        abis: installed.abis,
      );
      expect(await reopened.latest(updated, CancelToken()), isNull);
      expect(adapter.requests, 4);
      expect(await reopened.latest(updated, CancelToken()), isNull);
      expect(adapter.requests, 4);
      now = now.add(const Duration(minutes: 5));
      expect(await reopened.latest(updated, CancelToken()), isNull);
      expect(adapter.requests, 6);
      expect(reopened.usedCachedResult, isFalse);
    },
  );

  test('legacy no update result is cached too', () async {
    final adapter = FixtureAdapter(
      modify: (data) {
        data['tag_name'] = 'Kazumi_tv_base2.3.7_1.1.0';
        data['assets'] = [];
      },
    );
    final updater = TvUpdateClient(Dio()..httpClientAdapter = adapter);
    expect(await updater.latest(installed, CancelToken()), isNull);
    expect(await updater.latest(installed, CancelToken()), isNull);
    expect(adapter.requests, 1);
  });

  test(
    'rate limit reports reset time and blocks requests until reset',
    () async {
      var now = DateTime.utc(2026, 10, 7, 3);
      final reset = now.add(const Duration(minutes: 10));
      var requests = 0;
      final dio = Dio()..httpClientAdapter = FixtureAdapter();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests++;
            if (requests == 1) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.badResponse,
                  response: Response(
                    requestOptions: options,
                    statusCode: 403,
                    data: 'API rate limit exceeded',
                    headers: Headers.fromMap({
                      'x-ratelimit-remaining': ['0'],
                      'x-ratelimit-reset': [
                        '${reset.millisecondsSinceEpoch ~/ 1000}',
                      ],
                    }),
                  ),
                ),
              );
            } else {
              handler.next(options);
            }
          },
        ),
      );
      final cache = TvUpdateCheckCache();
      final updater = TvUpdateClient(dio, cache: cache, now: () => now);
      final message = predicate<Object>(
        (e) =>
            e.toString().contains('2026-10-07') &&
            e.toString().contains('本机时间'),
      );
      await expectLater(
        updater.latest(installed, CancelToken()),
        throwsA(message),
      );
      expect(cache.retryAt, reset);
      final reopened = TvUpdateClient(dio, cache: cache, now: () => now);
      await expectLater(
        reopened.latest(installed, CancelToken()),
        throwsA(message),
      );
      expect(requests, 1);
      now = reset;
      expect(await reopened.latest(installed, CancelToken()), isNotNull);
      expect(requests, 3);
    },
  );

  test(
    'Retry-After controls cooldown; ordinary 403 is not a rate limit',
    () async {
      final now = DateTime.utc(2026, 10, 7, 3);
      final cache = TvUpdateCheckCache();
      final dio = Dio();
      var requests = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requests++;
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: 429,
                  headers: Headers.fromMap({
                    'retry-after': ['120'],
                  }),
                ),
              ),
            );
          },
        ),
      );
      final updater = TvUpdateClient(dio, cache: cache, now: () => now);
      await expectLater(
        updater.latest(installed, CancelToken()),
        throwsA(isA<TvUpdateException>()),
      );
      await expectLater(
        updater.latest(installed, CancelToken()),
        throwsA(isA<TvUpdateException>()),
      );
      expect(requests, 1);
      expect(cache.retryAt, now.add(const Duration(minutes: 2)));
      final options = RequestOptions(path: tvLatestReleaseApi);
      final denied = DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: 403,
          data: 'Forbidden',
        ),
      );
      expect(tvUpdateError(denied), contains('拒绝访问'));
      expect(tvUpdateError(denied), isNot(contains('限制')));
    },
  );

  test(
    'build number controls upgrade; malformed, wrong repo or incompatible releases fail',
    () {
      final update = offer();
      expect(update.isNewerThan(installed), isTrue);
      expect(
        update.isNewerThan(
          const TvInstalledVersion(
            name: tag,
            code: 20307130,
            sdk: 34,
            abis: ['armeabi-v7a'],
          ),
        ),
        isFalse,
      );
      for (final change in <void Function(Map<String, dynamic>)>[
        (m) => m['packageName'] = 'com.predidit.kazumi',
        (m) => m['versionName'] = '2.3.7',
        (m) => m['versionCode'] = 0,
        (m) => m['sha256'] = 'invalid',
        (m) => m['size'] = payload.length + 1,
        (m) => m['minSdk'] = 35,
        (m) => m['abis'] = ['arm64-v8a'],
      ]) {
        final m = metadata();
        change(m);
        expect(
          () => TvUpdateManifest.parse(m, TvRelease(release()), installed),
          throwsA(isA<TvUpdateException>()),
        );
      }
      final wrong = release();
      (wrong['assets'] as List).last['browser_download_url'] =
          'https://github.com/Predidit/Kazumi/releases/download/$tag/$tag-arm.apk';
      expect(
        () => TvUpdateManifest.parse(metadata(), TvRelease(wrong), installed),
        throwsA(isA<TvUpdateException>()),
      );
      expect(
        () => TvRelease({...release(), 'prerelease': true}),
        throwsA(isA<TvUpdateException>()),
      );
    },
  );

  test(
    'metadata, missing assets and metadata digest are checked before download',
    () async {
      expect(
        (await client().latest(installed, CancelToken()))!.versionCode,
        20307130,
      );
      await expectLater(
        client(
          modify: (r) => (r['assets'] as List).removeAt(0),
        ).latest(installed, CancelToken()),
        throwsA(isA<TvUpdateException>()),
      );
      await expectLater(
        client(
          modify: (r) =>
              (r['assets'] as List).first['digest'] = 'sha256:${'0' * 64}',
        ).latest(installed, CancelToken()),
        throwsA(isA<TvUpdateException>()),
      );
      final legacy = client(
        modify: (r) {
          r['tag_name'] = 'Kazumi_tv_base2.3.7_1.1.0';
          r['assets'] = [];
        },
      );
      expect(await legacy.latest(installed, CancelToken()), isNull);
      expect(
        tvUpdateError(
          DioException(
            requestOptions: RequestOptions(),
            response: Response(
              requestOptions: RequestOptions(),
              statusCode: 403,
              headers: Headers.fromMap({
                'x-ratelimit-remaining': ['0'],
              }),
            ),
          ),
        ),
        contains('限制'),
      );
    },
  );

  test(
    'download validates size/hash; bad files are cleaned and valid cache reused',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kazumi-tv-update-test-',
      );
      try {
        await expectLater(
          client(
            badDownload: true,
          ).download(offer(), directory, CancelToken(), (_, _) {}),
          throwsA(isA<TvUpdateException>()),
        );
        expect(await directory.list().isEmpty, isTrue);
        final path = await client().download(
          offer(),
          directory,
          CancelToken(),
          (_, _) {},
        );
        expect(await File(path).readAsBytes(), payload);
        expect(
          await client(
            badDownload: true,
          ).download(offer(), directory, CancelToken(), (_, _) {}),
          path,
        );
        final token = CancelToken()..cancel();
        await expectLater(
          client().download(offer(), directory, token, (_, _) {}),
          throwsA(isA<DioException>()),
        );
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'verification blocks installation; permission denial retains ready file',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kazumi-tv-update-controller-',
      );
      final platform = FakePlatform()
        ..invalid = const TvUpdateException('签名不一致');
      final c = TvUpdateController(
        client: client(),
        platform: platform,
        directory: () async => directory,
        initial: offer(),
      );
      try {
        await c.download();
        expect(c.stage, TvUpdateStage.error);
        expect(c.path, isNull);
        await c.install();
        expect(platform.installs, 0);
        platform.invalid = null;
        platform.allowed = false;
        await c.download();
        expect(c.stage, TvUpdateStage.ready);
        await c.install();
        expect(c.stage, TvUpdateStage.permission);
        expect(c.path, isNotNull);
        await c.openPermission();
        expect(platform.permissions, 1);
        expect(platform.installs, 0);
        platform.allowed = true;
        await c.install();
        expect(platform.installs, 1);
      } finally {
        c.dispose();
        await directory.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'TV update defaults to later; Back asks before cancel and closes only update',
    (tester) async {
      final delayed = DelayedClient();
      final c = TvUpdateController(
        client: delayed,
        platform: FakePlatform(),
        directory: () async => Directory.systemTemp,
        initial: offer(),
      );
      var skipped = 0;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => TvAppSupport(child: child!),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => TvUpdateDialog(
                    controller: c,
                    onClose: () => Navigator.of(context).pop(),
                    onSkip: (code) async {
                      skipped = code;
                    },
                  ),
                ),
                child: const Text('检查更新'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('检查更新'));
      await tester.pumpAndSettle();
      expect(
        FocusManager.instance.primaryFocus!.debugLabel,
        'TV update safe action',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pump();
      expect(c.stage, TvUpdateStage.downloading);
      await c.download();
      expect(delayed.downloads, 1);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('取消更新下载？'), findsOneWidget);
      await tester.tap(find.text('继续下载'));
      await tester.pumpAndSettle();
      expect(c.stage, TvUpdateStage.downloading);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消下载').last);
      await tester.pumpAndSettle();
      expect(c.stage, TvUpdateStage.offer);
      delayed.completed.complete();
      await tester.pumpAndSettle();
      expect(c.stage, TvUpdateStage.offer);
      expect(c.path, isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('检查更新'), findsOneWidget);
      expect(find.byType(TvUpdateDialog), findsNothing);
      expect(skipped, 0);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
