import 'package:zephyr/plugin/utils/plugin_catalog_merge.dart';
import 'package:zephyr/util/json/json_value.dart';

class CloudPluginItem {
  const CloudPluginItem({
    required this.repo,
    required this.manifest,
    this.formalRelease,
  });

  final String repo;
  final CloudPluginManifest manifest;
  final FormalPluginRelease? formalRelease;

  factory CloudPluginItem.fromJson(
    Map<String, dynamic> json, {
    FormalPluginRelease? formalRelease,
  }) {
    return CloudPluginItem(
      repo: json['repo']?.toString().trim() ?? '',
      manifest: CloudPluginManifest.fromJson(asJsonMap(json['manifest'])),
      formalRelease: formalRelease,
    );
  }

  /// 直达 GitHub 仓库的 URL：优先 manifest 的 `breeze-plugin-github-repository`，
  /// 缺失时由顶层 `repo`（owner/name）推导；仍无效则为空，调用方隐藏按钮。
  String get githubRepositoryUrl {
    final explicit = manifest.githubRepository.trim();
    if (_isHttpUrl(explicit)) return explicit;
    final slug = repo.trim();
    if (RegExp(r'^[\w.\-]+/[\w.\-]+$').hasMatch(slug)) {
      return 'https://github.com/$slug';
    }
    return '';
  }
}

bool _isHttpUrl(String value) {
  if (value.isEmpty) return false;
  final uri = Uri.tryParse(value);
  return uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty;
}

class CloudPluginManifest {
  const CloudPluginManifest({
    required this.name,
    required this.uuid,
    required this.iconUrl,
    required this.describe,
    required this.version,
    required this.home,
    required this.updateUrl,
    required this.npmName,
    required this.githubRepository,
    this.compatibilityMetadata = const {},
    this.scriptSha256 = '',
  });

  final String name;
  final String uuid;
  final String iconUrl;
  final String describe;
  final String version;
  final String home;
  final String updateUrl;
  final String npmName;
  final String githubRepository;
  final Map<String, dynamic> compatibilityMetadata;
  final String scriptSha256;

  factory CloudPluginManifest.fromJson(Map<String, dynamic> json) {
    return CloudPluginManifest(
      name: json['name']?.toString() ?? '',
      uuid: json['uuid']?.toString() ?? '',
      iconUrl: json['iconUrl']?.toString() ?? '',
      describe: json['describe']?.toString() ?? '',
      version: json['version']?.toString() ?? '',
      home: json['home']?.toString() ?? '',
      updateUrl: json['updateUrl']?.toString() ?? '',
      npmName: json['npmName']?.toString() ?? '',
      githubRepository:
          json['breeze-plugin-github-repository']?.toString().trim() ?? '',
      scriptSha256: json['scriptSha256']?.toString() ?? '',
      compatibilityMetadata: Map.unmodifiable({
        'uuid': json['uuid'],
        'name': json['name'],
        'version': json['version'],
        if (json.containsKey('requirements'))
          'requirements': json['requirements'],
      }),
    );
  }

  /// 插件作者：由云端 `repo`（owner/name）取 `/` 前的 owner，不再读 manifest creator。
  String authorOf(String repo) {
    final slug = repo.trim();
    final parts = slug.split('/');
    if (parts.length == 2 &&
        parts[0].trim().isNotEmpty &&
        RegExp(r'^[\w.\-]+$').hasMatch(parts[0].trim())) {
      return parts[0].trim();
    }
    return '';
  }
}
