import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/video_source_action.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'dart:async';

typedef AggregateVideoPageReader =
    Future<ApiVideoResult> Function(int page, Map<String, dynamic>? cursor);

enum AggregateSourceNotice { inSource, unsupported }

class AggregateSourceEntryRequired implements Exception {
  const AggregateSourceEntryRequired(this.notice);
  final AggregateSourceNotice notice;
}

/// Browser-backed sources retain their own cookies and verification UI. They
/// get an explicit continuation, never a comic request or a hidden login browser.
class AggregateVideoSearch {
  AggregateVideoSearch({
    Future<Map<String, dynamic>> Function(String)? info,
    this.call,
  }) : info =
           info ??
           ((id) async =>
               PluginRegistryService.I.getCachedPluginInfo(id) ??
               await PluginRegistryService.I.fetchPluginInfo(
                 uuid: id,
                 runtimeName: id,
               ));
  final Future<Map<String, dynamic>> Function(String) info;
  final Future<Map<String, dynamic>> Function(
    String,
    String,
    Map<String, dynamic>,
  )?
  call;

  Future<AggregateVideoPageReader?> prepare(
    String source,
    String query, {
    String? taskGroupKey,
    bool Function()? current,
    void Function(Map<String, dynamic>)? onComicMetadata,
  }) async {
    final metadataRead = info(source);
    late final Map<String, dynamic> metadata;
    try {
      metadata = await metadataRead.timeout(const Duration(seconds: 12));
    } finally {
      // Metadata preparation has no cancellable native group of its own.
      // A UI timeout must not release physical admission while it still runs.
      await metadataRead.then<void>((_) {}, onError: (Object _) {});
    }
    if (current?.call() == false) throw StateError("Search cancelled");
    final action = aggregateVideoSourceAction(metadata);
    if (action == null) {
      onComicMetadata?.call(metadata);
      return null;
    }
    final payload = asJsonMap(action['payload']);
    final capabilities = ApiVideoCapabilities.fromJson(
      asJsonMap(payload['capabilities']),
    );
    if (payload['nativeSearch'] != true || !capabilities.canSearch) {
      throw const AggregateSourceEntryRequired(
        AggregateSourceNotice.unsupported,
      );
    }
    if (action['type'] == 'openVideoCatalog' ||
        capabilities.browserCatalog ||
        capabilities.search == 'website') {
      throw const AggregateSourceEntryRequired(AggregateSourceNotice.inSource);
    }
    final home = apiVideoHttps(payload['url']);
    final function = RegExp(
      r'^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*$',
    );
    final paths = [
      for (final key in ['catalogFnPath', 'detailFnPath', 'playbackFnPath'])
        (payload[key] is String ? (payload[key] as String).trim() : ''),
    ];
    if (!const {1, 2}.contains(payload['protocol']) ||
        home == null ||
        (home.hasPort && home.port != 443) ||
        paths.any((p) => p.length > 120 || !function.hasMatch(p))) {
      throw const FormatException('Invalid video search contract');
    }
    Future<Map<String, dynamic>>? pluginRead;
    final repo = ApiVideoRepository(
      source: source,
      home: home,
      catalogFn: paths[0],
      detailFn: paths[1],
      playbackFn: paths[2],
      capabilities: capabilities,
      pluginCall: (path, args) {
        if (current?.call() == false) throw StateError('Search cancelled');
        final read = call != null
            ? call!(source, path, args)
            : callUnifiedComicPlugin(
                pluginId: source,
                fnPath: path,
                core: args,
                taskGroupKey: taskGroupKey,
                notifyUnauthorized: false,
              );
        pluginRead = read;
        return read;
      },
    );
    final keyword = query.trim();
    return (page, cursor) async {
      try {
        return await repo.page(query: keyword, page: page, cursor: cursor);
      } finally {
        // Preview reads are serial. The repository's timeout may complete
        // before the underlying plugin call has released its physical slot.
        await pluginRead?.then<void>((_) {}, onError: (Object _) {});
        pluginRead = null;
      }
    };
  }
}
