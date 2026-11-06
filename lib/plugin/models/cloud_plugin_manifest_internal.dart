import 'package:zephyr/util/json/json_value.dart';

class CloudPluginCatalogItem {
  const CloudPluginCatalogItem({required this.repo, required this.manifest});

  final String repo;
  final CloudPluginManifestInternal manifest;

  factory CloudPluginCatalogItem.fromJson(Map<String, dynamic> json) {
    return CloudPluginCatalogItem(
      repo: json['repo']?.toString().trim() ?? '',
      manifest: CloudPluginManifestInternal.fromJson(
        asJsonMap(json['manifest']),
      ),
    );
  }
}

class CloudPluginManifestInternal {
  const CloudPluginManifestInternal({
    required this.uuid,
    required this.version,
    required this.updateUrl,
    required this.npmName,
    this.releaseMetadata = const {},
  });

  final String uuid;
  final String version;
  final String updateUrl;
  final String npmName;
  final Map<String, dynamic> releaseMetadata;
  Map<String, dynamic> get releaseInfo => {
    ...releaseMetadata,
    'uuid': uuid,
    'version': version,
  };

  factory CloudPluginManifestInternal.fromJson(Map<String, dynamic> json) {
    return CloudPluginManifestInternal(
      uuid: json['uuid']?.toString().trim() ?? '',
      version: json['version']?.toString().trim() ?? '',
      updateUrl: json['updateUrl']?.toString().trim() ?? '',
      npmName: json['npmName']?.toString().trim() ?? '',
      releaseMetadata: Map<String, dynamic>.unmodifiable(json),
    );
  }
}
