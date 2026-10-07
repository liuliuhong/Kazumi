const tvUpdateRepository = 'liuliuhong/Kazumi';
const tvUpdatePackage = 'com.predidit.kazumi.tv';
const tvLatestReleaseApi =
    'https://api.github.com/repos/$tvUpdateRepository/releases/latest';

class TvUpdateException implements Exception {
  const TvUpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

class TvInstalledVersion {
  const TvInstalledVersion({
    required this.name,
    required this.code,
    required this.sdk,
    required this.abis,
  });
  final String name;
  final int code;
  final int sdk;
  final List<String> abis;
}

class TvRelease {
  TvRelease(Map<String, dynamic> data)
    : tag = data['tag_name'] as String? ?? '',
      notes = (data['body'] as String? ?? '').substring(
        0,
        (data['body'] as String? ?? '').length.clamp(0, 12000),
      ),
      assets = List<Map<String, dynamic>>.from(
        (data['assets'] as List? ?? []).map(
          (a) => Map<String, dynamic>.from(a as Map),
        ),
      ) {
    if (data['draft'] != false ||
        data['prerelease'] != false ||
        !RegExp(r'^Kazumi_tv_base\d+\.\d+\.\d+_\d+\.\d+\.\d+$').hasMatch(tag)) {
      throw const TvUpdateException('最新发布不是正式 TV 版本，请联系本仓库维护者');
    }
  }
  final String tag;
  final String notes;
  final List<Map<String, dynamic>> assets;

  Map<String, dynamic> asset(String name) {
    final found = assets.where((a) => a['name'] == name).toList();
    if (found.length != 1 || found.single['state'] != 'uploaded') {
      throw TvUpdateException('发布附件缺失或不完整：$name');
    }
    final value = found.single;
    final uri = Uri.tryParse(value['browser_download_url'] as String? ?? '');
    final expected = [
      'liuliuhong',
      'Kazumi',
      'releases',
      'download',
      tag,
      name,
    ];
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'github.com' ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.pathSegments.join('/') != expected.join('/')) {
      throw const TvUpdateException('更新附件不属于指定的社区仓库');
    }
    return value;
  }

  // The two historical releases predate update.json. They are never downloaded
  // by this updater; a newer client may report them as older than itself.
  int? get legacyBuild => switch (tag) {
    'Kazumi_tv_base2.3.7_1.0.0' => 20307,
    'Kazumi_tv_base2.3.7_1.1.0' => 20307110,
    _ => null,
  };
}

class TvUpdateManifest {
  TvUpdateManifest.parse(
    Map<String, dynamic> json,
    TvRelease release,
    TvInstalledVersion installed,
  ) : versionName = json['versionName'] as String? ?? '',
      versionCode = json['versionCode'] as int? ?? 0,
      minSdk = json['minSdk'] as int? ?? 0,
      fileName = json['fileName'] as String? ?? '',
      size = json['size'] as int? ?? 0,
      sha256 = (json['sha256'] as String? ?? '').toLowerCase(),
      notes = release.notes,
      abis = List<String>.from(json['abis'] as List? ?? []) {
    if (json['schemaVersion'] != 1 ||
        json['channel'] != 'stable' ||
        json['packageName'] != tvUpdatePackage ||
        versionName != release.tag ||
        versionName !=
            'Kazumi_tv_base${json['baseVersion']}_${json['tvVersion']}' ||
        versionCode <= 0 ||
        minSdk < 24 ||
        fileName != '$versionName-arm.apk' ||
        size <= 0 ||
        size > 300 * 1024 * 1024 ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256) ||
        abis.isEmpty) {
      throw const TvUpdateException('TV 更新信息格式无效或与发布版本不一致');
    }
    final apk = release.asset(fileName);
    downloadUrl = apk['browser_download_url'] as String;
    if (apk['size'] != size || apk['digest'] != 'sha256:$sha256') {
      throw const TvUpdateException('APK 大小或哈希与 GitHub 附件记录不一致');
    }
    if (versionCode > installed.code &&
        (minSdk > installed.sdk || !abis.any(installed.abis.contains))) {
      throw const TvUpdateException('此更新不支持当前盒子的系统或 CPU 架构');
    }
  }
  final String versionName;
  final int versionCode;
  final int minSdk;
  final String fileName;
  final int size;
  final String sha256;
  final List<String> abis;
  final String notes;
  late final String downloadUrl;
  bool isNewerThan(TvInstalledVersion installed) =>
      versionCode > installed.code;
}
