import 'package:zephyr/page/video/video_page_route.dart';
import 'dart:convert';
import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/comic_list/models/comic_list_scene.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/page/video/native_video_catalog_page.dart';
import 'package:zephyr/page/video/video_search_filters.dart';
import 'package:zephyr/page/video/video_search_history.dart';
import 'package:zephyr/page/video/video_search_page.dart';
import 'package:zephyr/page/video/video_site_browser.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/api_video_repository.dart';

import 'package:zephyr/page/discover/view/plugin_function_dialog.dart';

/// Discover 页插件动作路由。
///
/// 把插件返回的 action 协议转换为具体页面跳转，
/// 与 UI 解耦，方便集中维护。
class DiscoverRouter {
  DiscoverRouter._();

  /// Native video search is opt-in. Never route it through comic search.
  static Map<String, dynamic>? videoSearchAction(Map<String, dynamic> action) {
    final payload = asJsonMap(action['payload']);
    if (!const {
          'openVideoCatalog',
          'openVideoLibrary',
        }.contains(action['type']) ||
        payload['nativeSearch'] != true) {
      return null;
    }
    return {
      ...action,
      'payload': {...payload, 'openSearch': true},
    };
  }

  static Future<void> route(
    BuildContext context, {
    required Map<String, dynamic> action,
    required String currentFrom,
  }) async {
    final type = action['type']?.toString() ?? '';

    if (type == 'none' || type.isEmpty) {
      return;
    }

    switch (type) {
      case 'openSearch':
        await _openSearch(context, asJsonMap(action['payload']));
      case 'openWeb':
        await _openWeb(context, asJsonMap(action['payload']));
      case 'openVideoCatalog':
        await _openVideoCatalog(context, asJsonMap(action['payload']));
      case 'openVideoLibrary':
        await _openVideoLibrary(context, asJsonMap(action['payload']));
      case 'openPluginFunction':
        await _openPluginFunction(
          context,
          asJsonMap(action['payload']),
          currentFrom: currentFrom,
        );
      case 'openCloudFavorite':
        await _openCloudFavorite(
          context,
          asJsonMap(action['payload']),
          currentFrom: currentFrom,
        );
      case 'openComicList':
        await _openComicList(context, asJsonMap(action['payload']));
      case 'openComicInfo':
        await _openComicInfo(context, asJsonMap(action['payload']));
    }
  }

  /// 为需要插件来源的动作自动补全 source。
  static Map<String, dynamic> attachSource(
    Map<String, dynamic> action,
    String from,
  ) {
    final type = action['type']?.toString().trim() ?? '';
    if (type != 'openPluginFunction' &&
        type != 'openCloudFavorite' &&
        type != 'openSearch' &&
        type != 'openVideoCatalog' &&
        type != 'openVideoLibrary' &&
        type != 'openComicList' &&
        type != 'openComicInfo') {
      return action;
    }

    final payload = Map<String, dynamic>.from(asJsonMap(action['payload']));
    payload['source'] = from;

    if (type == 'openComicList') {
      final scene = Map<String, dynamic>.from(asJsonMap(payload['scene']));
      scene['source'] = from;
      payload['scene'] = scene;
    }

    return Map<String, dynamic>.from(action)..['payload'] = payload;
  }

  static Future<void> _openSearch(
    BuildContext context,
    Map<String, dynamic> payload,
  ) async {
    final source = _sourceFromString(payload['source']?.toString());
    final extern = _normalizeOpenSearchExtern(payload);
    final keywordFromPayload = payload['keyword']?.toString() ?? '';
    final keywordFromExtern = extern['keyword']?.toString() ?? '';
    final keyword = keywordFromPayload.isNotEmpty
        ? keywordFromPayload
        : keywordFromExtern;

    final searchStates = SearchStates.initial().copyWith(
      from: source,
      searchKeyword: keyword,
      pluginExtern: extern,
    );

    if (!context.mounted) {
      return;
    }
    context.pushRoute(
      SearchResultRoute(
        searchEvent: SearchEvent().copyWith(searchStates: searchStates),
      ),
    );
  }

  static Future<void> _openWeb(
    BuildContext context,
    Map<String, dynamic> payload,
  ) async {
    final title = payload['title']?.toString() ?? '';
    final url = payload['url']?.toString() ?? '';
    if (url.isEmpty) {
      return;
    }

    if (!context.mounted) {
      return;
    }
    final navigation = asJsonMap(payload['navigation']);
    context.pushRoute(
      WebViewRoute(
        info: [title, url, if (navigation.isNotEmpty) jsonEncode(navigation)],
      ),
    );
  }

  static Future<void> _openVideoCatalog(
    BuildContext context,
    Map<String, dynamic> payload,
  ) async {
    final source = _sourceFromString(payload['source']?.toString());
    final homeUrl = Uri.tryParse(payload['url']?.toString() ?? '');
    final selectors = asJsonMap(
      payload['selectors'],
    ).map((key, value) => MapEntry(key, value.toString()));
    const requiredSelectors = [
      'row',
      'rowTitle',
      'rowCards',
      'cards',
      'cardLink',
      'cardTitle',
      'cardImage',
      'cardSubtitle',
      'cardDuration',
      'detailTitle',
      'detailCover',
      'detailDescription',
      'detailTags',
      'episodes',
      'related',
      'video',
    ];
    if (source.isEmpty ||
        homeUrl == null ||
        homeUrl.scheme != 'https' ||
        homeUrl.host.isEmpty ||
        homeUrl.userInfo.isNotEmpty ||
        (homeUrl.hasPort && homeUrl.port != 443) ||
        requiredSelectors.any(
          (key) =>
              selectors[key]?.trim().isNotEmpty != true ||
              selectors[key]!.length > 300,
        )) {
      return;
    }
    String path(String name) => payload[name]?.toString().trim() ?? '';
    if (path('catalogFnPath').isEmpty ||
        path('detailFnPath').isEmpty ||
        path('playbackFnPath').isEmpty ||
        !context.mounted) {
      return;
    }
    final categories = <NativeCatalogCategory>[];
    for (final item in asJsonList(payload['categories']).take(12)) {
      final entry = asJsonMap(item);
      final title = entry['title']?.toString().trim() ?? '';
      final url = Uri.tryParse(entry['url']?.toString() ?? '');
      if (title.isEmpty ||
          title.length > 30 ||
          url == null ||
          url.scheme != 'https' ||
          url.host != homeUrl.host ||
          url.userInfo.isNotEmpty ||
          (url.hasPort && url.port != 443) ||
          (url.path != '/' && url.path != '/search')) {
        continue;
      }
      categories.add(NativeCatalogCategory(title: title, url: url));
    }
    final tabs = <NativeCatalogTab>[];
    for (final item in asJsonList(payload['tabs']).take(4)) {
      final entry = asJsonMap(item);
      final id = entry['id']?.toString() ?? '';
      final title = entry['title']?.toString().trim() ?? '';
      final mode = entry['mode']?.toString() ?? '';
      final url = Uri.tryParse(entry['url']?.toString() ?? '');
      if (!{'recommend', 'ranking', 'subscriptions', 'me'}.contains(id) ||
          title.isEmpty ||
          title.length > 12 ||
          !{'catalog', 'website', 'account'}.contains(mode) ||
          url == null ||
          url.scheme != 'https' ||
          url.host != homeUrl.host ||
          url.userInfo.isNotEmpty ||
          (url.hasPort && url.port != 443) ||
          (mode == 'catalog' &&
              url.path != '/' &&
              url.path != '/search' &&
              !(payload['nativeSubscriptions'] == true &&
                  id == 'subscriptions' &&
                  url.path == '/subscriptions'))) {
        continue;
      }
      tabs.add(NativeCatalogTab(id: id, title: title, url: url, mode: mode));
    }
    final schema = asJsonMap(payload['searchFilters']).isEmpty
        ? null
        : VideoFilterSchema.fromWire(asJsonMap(payload['searchFilters']));
    Uri? initialUrl;
    if (payload['openSearch'] == true) {
      if (payload['nativeSearch'] != true) return;
      final result = await Navigator.of(context, rootNavigator: true)
          .push<VideoSearchFilters>(
            videoPageRoute(
              builder: (_) => VideoSearchPage(
                source: source,
                initial: const VideoSearchFilters(),
                authorEnabled: schema != null,
              ),
            ),
          );
      if (result == null || !context.mounted) return;
      initialUrl = result.toUri(homeUrl);
      unawaited(
        VideoSearchHistory.add(source, result.query).catchError((Object _) {
          if (context.mounted) showErrorToast(t.videoSearch.historyWriteFailed);
        }),
      );
    }
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push<void>(
      videoPageRoute(
        builder: (_) => NativeVideoCatalogPage(
          source: source,
          title: payload['title']?.toString() ?? 'Video',
          homeUrl: homeUrl,
          initialUrl: initialUrl,
          catalogFnPath: path('catalogFnPath'),
          detailFnPath: path('detailFnPath'),
          playbackFnPath: path('playbackFnPath'),
          nativeAccount: payload['nativeAccount'] == true,
          nativeSubscriptions: payload['nativeSubscriptions'] == true,
          nativeAuth: payload['nativeAuth'] == true,
          nativeSiteActions: payload['nativeSiteActions'] == true,
          externalAuthenticationEntries: [
            for (final raw in asJsonList(
              payload['externalAuthenticationEntries'],
            ).take(4))
              if (Uri.tryParse(raw.toString()) case final Uri rawEntry)
                if (videoSiteExternalAuthenticationEntry(homeUrl, rawEntry)
                    case final Uri entry)
                  entry,
          ],
          searchFilters: schema,
          selectors: selectors,
          categories: categories,
          tabs: tabs,
        ),
      ),
    );
  }

  static Future<void> _openVideoLibrary(
    BuildContext context,
    Map<String, dynamic> payload,
  ) async {
    final source = _sourceFromString(payload['source']?.toString());
    final home = Uri.tryParse(payload['url']?.toString() ?? '');
    String path(String key) => payload[key]?.toString().trim() ?? '';
    final function = RegExp(
      r'^[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*$',
    );
    if (payload['protocol'] != 1 ||
        source.isEmpty ||
        home == null ||
        home.scheme != 'https' ||
        home.host.isEmpty ||
        home.userInfo.isNotEmpty ||
        (home.hasPort && home.port != 443) ||
        ['catalogFnPath', 'detailFnPath', 'playbackFnPath'].any(
          (key) => path(key).length > 120 || !function.hasMatch(path(key)),
        )) {
      return;
    }
    var query = '';
    if (payload['openSearch'] == true) {
      if (payload['nativeSearch'] != true) return;
      final result = await Navigator.of(context, rootNavigator: true)
          .push<VideoSearchFilters>(
            videoPageRoute(
              builder: (_) => VideoSearchPage(
                source: source,
                initial: const VideoSearchFilters(),
                authorEnabled: false,
                hint: t.videoLibrary.searchHint,
              ),
            ),
          );
      if (result == null || !context.mounted) return;
      query = result.query;
      unawaited(
        VideoSearchHistory.add(source, query).catchError((Object _) {}),
      );
    }
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push<void>(
      videoPageRoute(
        builder: (_) => ApiVideoLibraryPage(
          repository: ApiVideoRepository(
            source: source,
            home: home,
            catalogFn: path('catalogFnPath'),
            detailFn: path('detailFnPath'),
            playbackFn: path('playbackFnPath'),
            batchDetailFn: function.hasMatch(path('batchDetailFnPath'))
                ? path('batchDetailFnPath')
                : null,
          ),
          title: payload['title']?.toString() ?? 'Video',
          initialQuery: query,
        ),
      ),
    );
  }

  static Future<void> _openPluginFunction(
    BuildContext context,
    Map<String, dynamic> payload, {
    required String currentFrom,
  }) async {
    final source = _sourceFromString(payload['source']?.toString());
    if (source.isEmpty) {
      showErrorToast(t.error.missingPluginSource(action: t.oldHome.function));
      return;
    }

    final functionId = payload['id']?.toString().trim() ?? '';
    if (functionId.isEmpty) {
      return;
    }
    final title = payload['title']?.toString().trim() ?? t.oldHome.function;
    final presentation = payload['presentation']?.toString().trim() ?? 'page';

    Future<void> onAction(Map<String, dynamic> action) => route(
      context,
      action: attachSource(action, source),
      currentFrom: currentFrom,
    );

    if (presentation != 'dialog') {
      if (!context.mounted) {
        return;
      }
      await context.pushRoute(
        PluginFunctionRoute(
          from: source,
          functionId: functionId,
          title: title,
          onAction: onAction,
        ),
      );
      return;
    }

    if (!context.mounted) {
      return;
    }
    final mediaSize = MediaQuery.sizeOf(context);
    final dialogWidth = (mediaSize.width * 0.9).clamp(280.0, 560.0).toDouble();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => PluginFunctionDialog(
        from: source,
        functionId: functionId,
        title: title,
        onAction: onAction,
        onLogin: () {
          if (context.mounted) {
            context.pushRoute(LoginRoute(from: source));
          }
        },
        dialogWidth: dialogWidth,
      ),
    );
  }

  static Future<void> _openCloudFavorite(
    BuildContext context,
    Map<String, dynamic> payload, {
    required String currentFrom,
  }) async {
    final parsed = _sourceFromString(payload['source']?.toString());
    final source = parsed.isEmpty ? currentFrom : parsed;
    if (source.isEmpty) {
      showErrorToast(
        t.error.missingPluginSource(action: t.oldHome.cloudFavorite),
      );
      return;
    }

    final title = payload['title']?.toString();

    if (!context.mounted) {
      return;
    }
    await context.pushRoute(
      ComicListRoute(
        title: title ?? t.oldHome.cloudFavorite,
        sceneSource: source,
        sceneBundleFnPath: 'getCloudFavoriteSceneBundle',
        sceneBundleFnPathFallback: 'get_cloud_favorite_scene_bundle',
      ),
    );
  }

  static Future<void> _openComicList(
    BuildContext context,
    Map<String, dynamic> payload,
  ) async {
    final scene = ComicListScene.fromMap(asJsonMap(payload['scene']));

    if (!context.mounted) {
      return;
    }
    await context.pushRoute(ComicListRoute(scene: scene, title: scene.title));
  }

  static Future<void> _openComicInfo(
    BuildContext context,
    Map<String, dynamic> payload,
  ) async {
    final comicId = payload['comicId']?.toString().trim() ?? '';
    if (comicId.isEmpty) {
      return;
    }

    final source = _sourceFromString(payload['source']?.toString());
    if (source.isEmpty) {
      return;
    }

    if (!context.mounted) {
      return;
    }
    context.pushRoute(
      ComicInfoRoute(
        comicId: comicId,
        from: source,
        type: ComicEntryType.normal,
      ),
    );
  }

  static Map<String, dynamic> _normalizeOpenSearchExtern(
    Map<String, dynamic> payload,
  ) {
    final extern = Map<String, dynamic>.from(asJsonMap(payload['extern']));
    for (final entry in payload.entries) {
      final key = entry.key.toString();
      if (key == 'source' || key == 'extern' || extern.containsKey(key)) {
        continue;
      }
      final value = entry.value;
      if (value == null) {
        continue;
      }
      if (value is String && value.trim().isEmpty) {
        continue;
      }
      extern[key] = value;
    }

    return extern;
  }

  static String _sourceFromString(String? source) {
    return (source ?? '').trim();
  }
}
