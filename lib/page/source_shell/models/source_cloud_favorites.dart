import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/network/http/plugin/unified_plugin_envelope.dart';
import 'package:zephyr/util/json/json_dispose.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

Future<List<UnifiedComicListItem>> loadSourceCloudFavoritePreview(
  String source, {
  bool jmProfile = false,
}) async {
  final response = await callUnifiedComicPlugin(
    from: source,
    fnPath: jmProfile ? 'getCloudFavoriteData' : 'getFavoriteData',
    core: const <String, dynamic>{'page': 1},
    extern: jmProfile
        ? const <String, dynamic>{
            'source': 'cloudFavorite',
            'order': 'mr',
            'folderId': '',
          }
        : const <String, dynamic>{'source': 'cloudFavorite', 'sort': 'dd'},
  );
  return parseSourceCloudFavoritePreview(response, fallbackSource: source);
}

List<UnifiedComicListItem> parseSourceCloudFavoritePreview(
  Map<String, dynamic> response, {
  required String fallbackSource,
}) {
  final envelope = UnifiedPluginEnvelope.fromMap(response);
  final source = envelope.source.trim().isEmpty
      ? fallbackSource.trim()
      : envelope.source.trim();
  return asJsonList(envelope.data['items'])
      .map((item) => asJsonMap(replaceNestedNullList(asJsonMap(item))))
      .map((item) => unifiedComicFromPluginListMap(item, source: source))
      .toList();
}
