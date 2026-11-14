import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/util/json/json_value.dart';

/// Explicit video modules share the source navigation without changing its
/// primary comic search or inventing capabilities for legacy plugins.
class SourceVideoModule {
  const SourceVideoModule({
    required this.source,
    required this.title,
    required this.home,
    required this.catalogFn,
    required this.detailFn,
    required this.playbackFn,
    required this.capabilities,
    this.batchDetailFn,
  });

  final String source, title, catalogFn, detailFn, playbackFn;
  final String? batchDetailFn;
  final Uri home;
  final ApiVideoCapabilities capabilities;

  String get id => home.toString();

  static SourceVideoModule? fromAction(
    Map<String, dynamic> action,
    String source,
  ) {
    if (action['type'] != 'openVideoLibrary' || source.isEmpty) return null;
    final payload = asJsonMap(action['payload']);
    final home = Uri.tryParse(payload['url']?.toString() ?? '');
    final title =
        (payload['tabTitle'] ?? payload['title'])?.toString().trim() ?? '';
    String path(String key) => payload[key]?.toString().trim() ?? '';
    final function = RegExp(
      r'^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*$',
    );
    bool valid(String value) => value.length <= 120 && function.hasMatch(value);
    if (!const {1, 2}.contains(payload['protocol']) ||
        title.isEmpty ||
        home == null ||
        home.scheme != 'https' ||
        home.host.isEmpty ||
        home.userInfo.isNotEmpty ||
        home.hasQuery ||
        home.hasFragment ||
        (home.hasPort && home.port != 443) ||
        [
          'catalogFnPath',
          'detailFnPath',
          'playbackFnPath',
        ].any((key) => !valid(path(key)))) {
      return null;
    }
    final capabilities = ApiVideoCapabilities.fromJson(
      asJsonMap(payload['capabilities']),
    );
    // Website account shells have their own navigation and cannot be embedded
    // into a second source navigation.
    if (capabilities.animePresentation || capabilities.siteAccount) return null;
    return SourceVideoModule(
      source: source,
      title: title,
      home: home,
      catalogFn: path('catalogFnPath'),
      detailFn: path('detailFnPath'),
      playbackFn: path('playbackFnPath'),
      batchDetailFn: valid(path('batchDetailFnPath'))
          ? path('batchDetailFnPath')
          : null,
      capabilities: capabilities,
    );
  }

  ApiVideoRepository repository({ApiVideoPluginCall? pluginCall}) =>
      ApiVideoRepository(
        source: source,
        home: home,
        catalogFn: catalogFn,
        detailFn: detailFn,
        playbackFn: playbackFn,
        batchDetailFn: batchDetailFn,
        capabilities: capabilities,
        pluginCall: pluginCall,
      );
}
