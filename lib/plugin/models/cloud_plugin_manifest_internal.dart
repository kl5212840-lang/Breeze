import 'package:zephyr/plugin/utils/plugin_catalog_merge.dart';
import 'package:zephyr/util/json/json_value.dart';

class CloudPluginCatalogItem {
  const CloudPluginCatalogItem({
    required this.repo,
    required this.manifest,
    this.formalRelease,
  });

  final String repo;
  final CloudPluginManifestInternal manifest;
  final FormalPluginRelease? formalRelease;

  factory CloudPluginCatalogItem.fromJson(
    Map<String, dynamic> json, {
    FormalPluginRelease? formalRelease,
  }) {
    return CloudPluginCatalogItem(
      repo: json['repo']?.toString().trim() ?? '',
      manifest: CloudPluginManifestInternal.fromJson(
        asJsonMap(json['manifest']),
      ),
      formalRelease: formalRelease,
    );
  }
}

class CloudPluginManifestInternal {
  const CloudPluginManifestInternal({
    required this.uuid,
    required this.version,
    required this.updateUrl,
    required this.npmName,
    this.compatibilityMetadata = const {},
    this.scriptSha256 = '',
  });

  final String uuid;
  final String version;
  final String updateUrl;
  final String npmName;
  final Map<String, dynamic> compatibilityMetadata;
  final String scriptSha256;

  factory CloudPluginManifestInternal.fromJson(Map<String, dynamic> json) {
    return CloudPluginManifestInternal(
      uuid: json['uuid']?.toString().trim() ?? '',
      version: json['version']?.toString().trim() ?? '',
      updateUrl: json['updateUrl']?.toString().trim() ?? '',
      npmName: json['npmName']?.toString().trim() ?? '',
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
}
