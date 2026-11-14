// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'dart:async' as _i50;

import 'package:auto_route/auto_route.dart' as _i48;
import 'package:collection/collection.dart' as _i54;
import 'package:flutter/foundation.dart' as _i56;
import 'package:flutter/rendering.dart' as _i52;
import 'package:material_ui/material_ui.dart' as _i49;
import 'package:zephyr/cubit/string_select.dart' as _i58;
import 'package:zephyr/debug/coreml_upscale_debug_page.dart' as _i15;
import 'package:zephyr/debug/qjs_runtime_debug_page.dart' as _i34;
import 'package:zephyr/debug/show_color.dart' as _i39;
import 'package:zephyr/page/about/view/about_page.dart' as _i1;
import 'package:zephyr/page/app_bootstrap_page.dart' as _i3;
import 'package:zephyr/page/bookshelf/view/bookshelf_page.dart' as _i5;
import 'package:zephyr/page/change_log_page.dart' as _i8;
import 'package:zephyr/page/comic_follow/view/comic_follow_page.dart' as _i9;
import 'package:zephyr/page/comic_info/view/comic_info.dart' as _i10;
import 'package:zephyr/page/comic_list/models/comic_list_scene.dart' as _i55;
import 'package:zephyr/page/comic_list/view/comic_list_page.dart' as _i11;
import 'package:zephyr/page/comic_read/type/chapter_extern.dart' as _i57;
import 'package:zephyr/page/comic_read/view/comic_read.dart' as _i12;
import 'package:zephyr/page/comments/cubit/cubit.dart' as _i59;
import 'package:zephyr/page/comments/view/comments.dart' as _i13;
import 'package:zephyr/page/comments/view/plugin_comments_scaffold.dart'
    as _i29;
import 'package:zephyr/page/discover/view/discover_page.dart' as _i18;
import 'package:zephyr/page/download/download_center_page.dart' as _i19;
import 'package:zephyr/page/font_setting/view/font_setting_page.dart' as _i21;
import 'package:zephyr/page/login_page.dart' as _i24;
import 'package:zephyr/page/more/view/more.dart' as _i25;
import 'package:zephyr/page/navigation_bar.dart' as _i26;
import 'package:zephyr/page/old_page/old_home/old_home_page.dart' as _i27;
import 'package:zephyr/page/old_page/old_ranking/old_ranking_page.dart' as _i28;
import 'package:zephyr/page/plugin_function/view/plugin_function_page.dart'
    as _i31;
import 'package:zephyr/page/plugin_settings/view/plugin_detail_page.dart'
    as _i30;
import 'package:zephyr/page/plugin_settings/view/plugin_settings_page.dart'
    as _i32;
import 'package:zephyr/page/plugin_settings/widgets/plugin_settings_content.dart'
    as _i60;
import 'package:zephyr/page/plugin_store/view/plugin_store_page.dart' as _i33;
import 'package:zephyr/page/search/cubit/search_cubit.dart' as _i62;
import 'package:zephyr/page/search/view/search_page.dart' as _i37;
import 'package:zephyr/page/search_aggregate/view/search_aggregate_result_page.dart'
    as _i36;
import 'package:zephyr/page/search_result/bloc/search_bloc.dart' as _i61;
import 'package:zephyr/page/search_result/search_result.dart' as _i63;
import 'package:zephyr/page/search_result/view/search_result_page.dart' as _i38;
import 'package:zephyr/page/setting/bookshelf/bookshelf_setting_page.dart'
    as _i6;
import 'package:zephyr/page/setting/cache/cache_setting_page.dart' as _i7;
import 'package:zephyr/page/setting/data_backup/data_backup_page.dart' as _i16;
import 'package:zephyr/page/setting/global/app_behavior_setting_page.dart'
    as _i2;
import 'package:zephyr/page/setting/global/appearance_setting_page.dart' as _i4;
import 'package:zephyr/page/setting/global/content_network_setting_page.dart'
    as _i14;
import 'package:zephyr/page/setting/global/debug_setting_page.dart' as _i17;
import 'package:zephyr/page/setting/global/eink_setting_page.dart' as _i20;
import 'package:zephyr/page/setting/global/global_setting.dart' as _i23;
import 'package:zephyr/page/setting/global/storage_setting_page.dart' as _i42;
import 'package:zephyr/page/setting/global/switch_style_setting_page.dart'
    as _i43;
import 'package:zephyr/page/setting/global/sync_setting_page.dart' as _i44;
import 'package:zephyr/page/setting/real_sr/real_sr_setting_page.dart' as _i35;
import 'package:zephyr/page/source_shell/models/source_shell_section.dart'
    as _i65;
import 'package:zephyr/page/source_shell/source_native_controls.dart' as _i64;
import 'package:zephyr/page/source_shell/source_settings_hub.dart' as _i40;
import 'package:zephyr/page/source_shell/view/source_shell_page.dart' as _i41;
import 'package:zephyr/page/theme_color/view/theme_color_page.dart' as _i45;
import 'package:zephyr/page/webdav_sync/view/webdav_sync_page.dart' as _i46;
import 'package:zephyr/page/webview_page.dart' as _i47;
import 'package:zephyr/service/update/json/github_release_json.dart' as _i51;
import 'package:zephyr/type/enum.dart' as _i53;
import 'package:zephyr/widgets/full_screen_image_view.dart' as _i22;

/// generated route for
/// [_i1.AboutPage]
class AboutRoute extends _i48.PageRouteInfo<AboutRouteArgs> {
  AboutRoute({
    _i49.Key? key,
    _i50.Future<List<Map<String, dynamic>>> Function()? contributorLoader,
    List<_i48.PageRouteInfo>? children,
  }) : super(
         AboutRoute.name,
         args: AboutRouteArgs(key: key, contributorLoader: contributorLoader),
         initialChildren: children,
       );

  static const String name = 'AboutRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<AboutRouteArgs>(
        orElse: () => const AboutRouteArgs(),
      );
      return _i1.AboutPage(
        key: args.key,
        contributorLoader: args.contributorLoader,
      );
    },
  );
}

class AboutRouteArgs {
  const AboutRouteArgs({this.key, this.contributorLoader});

  final _i49.Key? key;

  final _i50.Future<List<Map<String, dynamic>>> Function()? contributorLoader;

  @override
  String toString() {
    return 'AboutRouteArgs{key: $key, contributorLoader: $contributorLoader}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AboutRouteArgs) return false;
    return key == other.key;
  }

  @override
  int get hashCode => key.hashCode;
}

/// generated route for
/// [_i2.AppBehaviorSettingPage]
class AppBehaviorSettingRoute extends _i48.PageRouteInfo<void> {
  const AppBehaviorSettingRoute({List<_i48.PageRouteInfo>? children})
    : super(AppBehaviorSettingRoute.name, initialChildren: children);

  static const String name = 'AppBehaviorSettingRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i2.AppBehaviorSettingPage();
    },
  );
}

/// generated route for
/// [_i3.AppBootstrapPage]
class AppBootstrapRoute extends _i48.PageRouteInfo<void> {
  const AppBootstrapRoute({List<_i48.PageRouteInfo>? children})
    : super(AppBootstrapRoute.name, initialChildren: children);

  static const String name = 'AppBootstrapRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i3.AppBootstrapPage();
    },
  );
}

/// generated route for
/// [_i4.AppearanceSettingPage]
class AppearanceSettingRoute extends _i48.PageRouteInfo<void> {
  const AppearanceSettingRoute({List<_i48.PageRouteInfo>? children})
    : super(AppearanceSettingRoute.name, initialChildren: children);

  static const String name = 'AppearanceSettingRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i4.AppearanceSettingPage();
    },
  );
}

/// generated route for
/// [_i5.BookshelfPage]
class BookshelfRoute extends _i48.PageRouteInfo<void> {
  const BookshelfRoute({List<_i48.PageRouteInfo>? children})
    : super(BookshelfRoute.name, initialChildren: children);

  static const String name = 'BookshelfRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i5.BookshelfPage();
    },
  );
}

/// generated route for
/// [_i6.BookshelfSettingPage]
class BookshelfSettingRoute extends _i48.PageRouteInfo<void> {
  const BookshelfSettingRoute({List<_i48.PageRouteInfo>? children})
    : super(BookshelfSettingRoute.name, initialChildren: children);

  static const String name = 'BookshelfSettingRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i6.BookshelfSettingPage();
    },
  );
}

/// generated route for
/// [_i7.CacheSettingPage]
class CacheSettingRoute extends _i48.PageRouteInfo<CacheSettingRouteArgs> {
  CacheSettingRoute({
    _i49.Key? key,
    String? source,
    String? sourceName,
    List<_i48.PageRouteInfo>? children,
  }) : super(
         CacheSettingRoute.name,
         args: CacheSettingRouteArgs(
           key: key,
           source: source,
           sourceName: sourceName,
         ),
         initialChildren: children,
       );

  static const String name = 'CacheSettingRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<CacheSettingRouteArgs>(
        orElse: () => const CacheSettingRouteArgs(),
      );
      return _i7.CacheSettingPage(
        key: args.key,
        source: args.source,
        sourceName: args.sourceName,
      );
    },
  );
}

class CacheSettingRouteArgs {
  const CacheSettingRouteArgs({this.key, this.source, this.sourceName});

  final _i49.Key? key;

  final String? source;

  final String? sourceName;

  @override
  String toString() {
    return 'CacheSettingRouteArgs{key: $key, source: $source, sourceName: $sourceName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CacheSettingRouteArgs) return false;
    return key == other.key &&
        source == other.source &&
        sourceName == other.sourceName;
  }

  @override
  int get hashCode => key.hashCode ^ source.hashCode ^ sourceName.hashCode;
}

/// generated route for
/// [_i8.ChangelogPage]
class ChangelogRoute extends _i48.PageRouteInfo<ChangelogRouteArgs> {
  ChangelogRoute({
    _i49.Key? key,
    _i50.Future<List<_i51.GithubReleaseJson>> Function(bool, int)?
    releaseLoader,
    List<_i48.PageRouteInfo>? children,
  }) : super(
         ChangelogRoute.name,
         args: ChangelogRouteArgs(key: key, releaseLoader: releaseLoader),
         initialChildren: children,
       );

  static const String name = 'ChangelogRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ChangelogRouteArgs>(
        orElse: () => const ChangelogRouteArgs(),
      );
      return _i8.ChangelogPage(
        key: args.key,
        releaseLoader: args.releaseLoader,
      );
    },
  );
}

class ChangelogRouteArgs {
  const ChangelogRouteArgs({this.key, this.releaseLoader});

  final _i49.Key? key;

  final _i50.Future<List<_i51.GithubReleaseJson>> Function(bool, int)?
  releaseLoader;

  @override
  String toString() {
    return 'ChangelogRouteArgs{key: $key, releaseLoader: $releaseLoader}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ChangelogRouteArgs) return false;
    return key == other.key;
  }

  @override
  int get hashCode => key.hashCode;
}

/// generated route for
/// [_i9.ComicFollowPage]
class ComicFollowRoute extends _i48.PageRouteInfo<ComicFollowRouteArgs> {
  ComicFollowRoute({
    _i49.Key? key,
    bool embedded = false,
    bool active = true,
    List<_i48.PageRouteInfo>? children,
  }) : super(
         ComicFollowRoute.name,
         args: ComicFollowRouteArgs(
           key: key,
           embedded: embedded,
           active: active,
         ),
         initialChildren: children,
       );

  static const String name = 'ComicFollowRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ComicFollowRouteArgs>(
        orElse: () => const ComicFollowRouteArgs(),
      );
      return _i9.ComicFollowPage(
        key: args.key,
        embedded: args.embedded,
        active: args.active,
      );
    },
  );
}

class ComicFollowRouteArgs {
  const ComicFollowRouteArgs({
    this.key,
    this.embedded = false,
    this.active = true,
  });

  final _i49.Key? key;

  final bool embedded;

  final bool active;

  @override
  String toString() {
    return 'ComicFollowRouteArgs{key: $key, embedded: $embedded, active: $active}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ComicFollowRouteArgs) return false;
    return key == other.key &&
        embedded == other.embedded &&
        active == other.active;
  }

  @override
  int get hashCode => key.hashCode ^ embedded.hashCode ^ active.hashCode;
}

/// generated route for
/// [_i10.ComicInfoPage]
class ComicInfoRoute extends _i48.PageRouteInfo<ComicInfoRouteArgs> {
  ComicInfoRoute({
    _i52.Key? key,
    required String comicId,
    required String from,
    required _i53.ComicEntryType type,
    Map<String, dynamic>? extern,
    String? collectionTargetId,
    String? collectionTargetName,
    List<_i48.PageRouteInfo>? children,
  }) : super(
         ComicInfoRoute.name,
         args: ComicInfoRouteArgs(
           key: key,
           comicId: comicId,
           from: from,
           type: type,
           extern: extern,
           collectionTargetId: collectionTargetId,
           collectionTargetName: collectionTargetName,
         ),
         initialChildren: children,
       );

  static const String name = 'ComicInfoRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ComicInfoRouteArgs>();
      return _i10.ComicInfoPage(
        key: args.key,
        comicId: args.comicId,
        from: args.from,
        type: args.type,
        extern: args.extern,
        collectionTargetId: args.collectionTargetId,
        collectionTargetName: args.collectionTargetName,
      );
    },
  );
}

class ComicInfoRouteArgs {
  const ComicInfoRouteArgs({
    this.key,
    required this.comicId,
    required this.from,
    required this.type,
    this.extern,
    this.collectionTargetId,
    this.collectionTargetName,
  });

  final _i52.Key? key;

  final String comicId;

  final String from;

  final _i53.ComicEntryType type;

  final Map<String, dynamic>? extern;

  final String? collectionTargetId;

  final String? collectionTargetName;

  @override
  String toString() {
    return 'ComicInfoRouteArgs{key: $key, comicId: $comicId, from: $from, type: $type, extern: $extern, collectionTargetId: $collectionTargetId, collectionTargetName: $collectionTargetName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ComicInfoRouteArgs) return false;
    return key == other.key &&
        comicId == other.comicId &&
        from == other.from &&
        type == other.type &&
        const _i54.MapEquality<String, dynamic>().equals(
          extern,
          other.extern,
        ) &&
        collectionTargetId == other.collectionTargetId &&
        collectionTargetName == other.collectionTargetName;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      comicId.hashCode ^
      from.hashCode ^
      type.hashCode ^
      const _i54.MapEquality<String, dynamic>().hash(extern) ^
      collectionTargetId.hashCode ^
      collectionTargetName.hashCode;
}

/// generated route for
/// [_i11.ComicListPage]
class ComicListRoute extends _i48.PageRouteInfo<ComicListRouteArgs> {
  ComicListRoute({
    _i49.Key? key,
    String? title,
    _i55.ComicListScene? scene,
    String? sceneSource,
    String? sceneBundleFnPath,
    String? sceneBundleFnPathFallback,
    bool embedded = false,
    bool jmCollection = false,
    List<_i48.PageRouteInfo>? children,
  }) : super(
         ComicListRoute.name,
         args: ComicListRouteArgs(
           key: key,
           title: title,
           scene: scene,
           sceneSource: sceneSource,
           sceneBundleFnPath: sceneBundleFnPath,
           sceneBundleFnPathFallback: sceneBundleFnPathFallback,
           embedded: embedded,
           jmCollection: jmCollection,
         ),
         initialChildren: children,
       );

  static const String name = 'ComicListRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ComicListRouteArgs>(
        orElse: () => const ComicListRouteArgs(),
      );
      return _i11.ComicListPage(
        key: args.key,
        title: args.title,
        scene: args.scene,
        sceneSource: args.sceneSource,
        sceneBundleFnPath: args.sceneBundleFnPath,
        sceneBundleFnPathFallback: args.sceneBundleFnPathFallback,
        embedded: args.embedded,
        jmCollection: args.jmCollection,
      );
    },
  );
}

class ComicListRouteArgs {
  const ComicListRouteArgs({
    this.key,
    this.title,
    this.scene,
    this.sceneSource,
    this.sceneBundleFnPath,
    this.sceneBundleFnPathFallback,
    this.embedded = false,
    this.jmCollection = false,
  });

  final _i49.Key? key;

  final String? title;

  final _i55.ComicListScene? scene;

  final String? sceneSource;

  final String? sceneBundleFnPath;

  final String? sceneBundleFnPathFallback;

  final bool embedded;

  final bool jmCollection;

  @override
  String toString() {
    return 'ComicListRouteArgs{key: $key, title: $title, scene: $scene, sceneSource: $sceneSource, sceneBundleFnPath: $sceneBundleFnPath, sceneBundleFnPathFallback: $sceneBundleFnPathFallback, embedded: $embedded, jmCollection: $jmCollection}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ComicListRouteArgs) return false;
    return key == other.key &&
        title == other.title &&
        scene == other.scene &&
        sceneSource == other.sceneSource &&
        sceneBundleFnPath == other.sceneBundleFnPath &&
        sceneBundleFnPathFallback == other.sceneBundleFnPathFallback &&
        embedded == other.embedded &&
        jmCollection == other.jmCollection;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      title.hashCode ^
      scene.hashCode ^
      sceneSource.hashCode ^
      sceneBundleFnPath.hashCode ^
      sceneBundleFnPathFallback.hashCode ^
      embedded.hashCode ^
      jmCollection.hashCode;
}

/// generated route for
/// [_i12.ComicReadPage]
class ComicReadRoute extends _i48.PageRouteInfo<ComicReadRouteArgs> {
  ComicReadRoute({
    _i56.Key? key,
    required String comicId,
    required int order,
    String chapterId = '',
    String requestId = '',
    String storageChapterId = '',
    String logicalKey = '',
    _i57.ChapterExtern chapterExtern = const {},
    required int epsNumber,
    required String from,
    required _i58.StringSelectCubit stringSelectCubit,
    required _i53.ComicEntryType type,
    required dynamic comicInfo,
    List<_i48.PageRouteInfo>? children,
  }) : super(
         ComicReadRoute.name,
         args: ComicReadRouteArgs(
           key: key,
           comicId: comicId,
           order: order,
           chapterId: chapterId,
           requestId: requestId,
           storageChapterId: storageChapterId,
           logicalKey: logicalKey,
           chapterExtern: chapterExtern,
           epsNumber: epsNumber,
           from: from,
           stringSelectCubit: stringSelectCubit,
           type: type,
           comicInfo: comicInfo,
         ),
         initialChildren: children,
       );

  static const String name = 'ComicReadRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<ComicReadRouteArgs>();
      return _i12.ComicReadPage(
        key: args.key,
        comicId: args.comicId,
        order: args.order,
        chapterId: args.chapterId,
        requestId: args.requestId,
        storageChapterId: args.storageChapterId,
        logicalKey: args.logicalKey,
        chapterExtern: args.chapterExtern,
        epsNumber: args.epsNumber,
        from: args.from,
        stringSelectCubit: args.stringSelectCubit,
        type: args.type,
        comicInfo: args.comicInfo,
      );
    },
  );
}

class ComicReadRouteArgs {
  const ComicReadRouteArgs({
    this.key,
    required this.comicId,
    required this.order,
    this.chapterId = '',
    this.requestId = '',
    this.storageChapterId = '',
    this.logicalKey = '',
    this.chapterExtern = const {},
    required this.epsNumber,
    required this.from,
    required this.stringSelectCubit,
    required this.type,
    required this.comicInfo,
  });

  final _i56.Key? key;

  final String comicId;

  final int order;

  final String chapterId;

  final String requestId;

  final String storageChapterId;

  final String logicalKey;

  final _i57.ChapterExtern chapterExtern;

  final int epsNumber;

  final String from;

  final _i58.StringSelectCubit stringSelectCubit;

  final _i53.ComicEntryType type;

  final dynamic comicInfo;

  @override
  String toString() {
    return 'ComicReadRouteArgs{key: $key, comicId: $comicId, order: $order, chapterId: $chapterId, requestId: $requestId, storageChapterId: $storageChapterId, logicalKey: $logicalKey, chapterExtern: $chapterExtern, epsNumber: $epsNumber, from: $from, stringSelectCubit: $stringSelectCubit, type: $type, comicInfo: $comicInfo}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ComicReadRouteArgs) return false;
    return key == other.key &&
        comicId == other.comicId &&
        order == other.order &&
        chapterId == other.chapterId &&
        requestId == other.requestId &&
        storageChapterId == other.storageChapterId &&
        logicalKey == other.logicalKey &&
        chapterExtern == other.chapterExtern &&
        epsNumber == other.epsNumber &&
        from == other.from &&
        stringSelectCubit == other.stringSelectCubit &&
        type == other.type &&
        comicInfo == other.comicInfo;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      comicId.hashCode ^
      order.hashCode ^
      chapterId.hashCode ^
      requestId.hashCode ^
      storageChapterId.hashCode ^
      logicalKey.hashCode ^
      chapterExtern.hashCode ^
      epsNumber.hashCode ^
      from.hashCode ^
      stringSelectCubit.hashCode ^
      type.hashCode ^
      comicInfo.hashCode;
}

/// generated route for
/// [_i13.CommentsPage]
class CommentsRoute extends _i48.PageRouteInfo<CommentsRouteArgs> {
  CommentsRoute({
    _i49.Key? key,
    required String comicId,
    required String comicTitle,
    List<_i48.PageRouteInfo>? children,
  }) : super(
         CommentsRoute.name,
         args: CommentsRouteArgs(
           key: key,
           comicId: comicId,
           comicTitle: comicTitle,
         ),
         initialChildren: children,
       );

  static const String name = 'CommentsRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<CommentsRouteArgs>();
      return _i13.CommentsPage(
        key: args.key,
        comicId: args.comicId,
        comicTitle: args.comicTitle,
      );
    },
  );
}

class CommentsRouteArgs {
  const CommentsRouteArgs({
    this.key,
    required this.comicId,
    required this.comicTitle,
  });

  final _i49.Key? key;

  final String comicId;

  final String comicTitle;

  @override
  String toString() {
    return 'CommentsRouteArgs{key: $key, comicId: $comicId, comicTitle: $comicTitle}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! CommentsRouteArgs) return false;
    return key == other.key &&
        comicId == other.comicId &&
        comicTitle == other.comicTitle;
  }

  @override
  int get hashCode => key.hashCode ^ comicId.hashCode ^ comicTitle.hashCode;
}

/// generated route for
/// [_i14.ContentNetworkSettingPage]
class ContentNetworkSettingRoute extends _i48.PageRouteInfo<void> {
  const ContentNetworkSettingRoute({List<_i48.PageRouteInfo>? children})
    : super(ContentNetworkSettingRoute.name, initialChildren: children);

  static const String name = 'ContentNetworkSettingRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i14.ContentNetworkSettingPage();
    },
  );
}

/// generated route for
/// [_i15.CoreMLUpscaleDebugPage]
class CoreMLUpscaleDebugRoute extends _i48.PageRouteInfo<void> {
  const CoreMLUpscaleDebugRoute({List<_i48.PageRouteInfo>? children})
    : super(CoreMLUpscaleDebugRoute.name, initialChildren: children);

  static const String name = 'CoreMLUpscaleDebugRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i15.CoreMLUpscaleDebugPage();
    },
  );
}

/// generated route for
/// [_i16.DataBackupPage]
class DataBackupRoute extends _i48.PageRouteInfo<DataBackupRouteArgs> {
  DataBackupRoute({
    _i49.Key? key,
    _i16.DataBackupActions actions = const _i16.DataBackupActions(),
    List<_i48.PageRouteInfo>? children,
  }) : super(
         DataBackupRoute.name,
         args: DataBackupRouteArgs(key: key, actions: actions),
         initialChildren: children,
       );

  static const String name = 'DataBackupRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<DataBackupRouteArgs>(
        orElse: () => const DataBackupRouteArgs(),
      );
      return _i16.DataBackupPage(key: args.key, actions: args.actions);
    },
  );
}

class DataBackupRouteArgs {
  const DataBackupRouteArgs({
    this.key,
    this.actions = const _i16.DataBackupActions(),
  });

  final _i49.Key? key;

  final _i16.DataBackupActions actions;

  @override
  String toString() {
    return 'DataBackupRouteArgs{key: $key, actions: $actions}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DataBackupRouteArgs) return false;
    return key == other.key && actions == other.actions;
  }

  @override
  int get hashCode => key.hashCode ^ actions.hashCode;
}

/// generated route for
/// [_i17.DebugSettingPage]
class DebugSettingRoute extends _i48.PageRouteInfo<void> {
  const DebugSettingRoute({List<_i48.PageRouteInfo>? children})
    : super(DebugSettingRoute.name, initialChildren: children);

  static const String name = 'DebugSettingRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i17.DebugSettingPage();
    },
  );
}

/// generated route for
/// [_i18.DiscoverPage]
class DiscoverRoute extends _i48.PageRouteInfo<void> {
  const DiscoverRoute({List<_i48.PageRouteInfo>? children})
    : super(DiscoverRoute.name, initialChildren: children);

  static const String name = 'DiscoverRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i18.DiscoverPage();
    },
  );
}

/// generated route for
/// [_i19.DownloadCenterPage]
class DownloadCenterRoute extends _i48.PageRouteInfo<void> {
  const DownloadCenterRoute({List<_i48.PageRouteInfo>? children})
    : super(DownloadCenterRoute.name, initialChildren: children);

  static const String name = 'DownloadCenterRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i19.DownloadCenterPage();
    },
  );
}

/// generated route for
/// [_i20.EInkSettingPage]
class EInkSettingRoute extends _i48.PageRouteInfo<void> {
  const EInkSettingRoute({List<_i48.PageRouteInfo>? children})
    : super(EInkSettingRoute.name, initialChildren: children);

  static const String name = 'EInkSettingRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i20.EInkSettingPage();
    },
  );
}

/// generated route for
/// [_i21.FontSettingPage]
class FontSettingRoute extends _i48.PageRouteInfo<void> {
  const FontSettingRoute({List<_i48.PageRouteInfo>? children})
    : super(FontSettingRoute.name, initialChildren: children);

  static const String name = 'FontSettingRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i21.FontSettingPage();
    },
  );
}

/// generated route for
/// [_i22.FullScreenImagePage]
class FullRouteImageRoute extends _i48.PageRouteInfo<FullRouteImageRouteArgs> {
  FullRouteImageRoute({
    _i49.Key? key,
    required String imagePath,
    List<_i48.PageRouteInfo>? children,
  }) : super(
         FullRouteImageRoute.name,
         args: FullRouteImageRouteArgs(key: key, imagePath: imagePath),
         initialChildren: children,
       );

  static const String name = 'FullRouteImageRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<FullRouteImageRouteArgs>();
      return _i22.FullScreenImagePage(key: args.key, imagePath: args.imagePath);
    },
  );
}

class FullRouteImageRouteArgs {
  const FullRouteImageRouteArgs({this.key, required this.imagePath});

  final _i49.Key? key;

  final String imagePath;

  @override
  String toString() {
    return 'FullRouteImageRouteArgs{key: $key, imagePath: $imagePath}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! FullRouteImageRouteArgs) return false;
    return key == other.key && imagePath == other.imagePath;
  }

  @override
  int get hashCode => key.hashCode ^ imagePath.hashCode;
}

/// generated route for
/// [_i23.GlobalSettingPage]
class GlobalSettingRoute extends _i48.PageRouteInfo<void> {
  const GlobalSettingRoute({List<_i48.PageRouteInfo>? children})
    : super(GlobalSettingRoute.name, initialChildren: children);

  static const String name = 'GlobalSettingRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i23.GlobalSettingPage();
    },
  );
}

/// generated route for
/// [_i24.LoginPage]
class LoginRoute extends _i48.PageRouteInfo<LoginRouteArgs> {
  LoginRoute({_i49.Key? key, String? from, List<_i48.PageRouteInfo>? children})
    : super(
        LoginRoute.name,
        args: LoginRouteArgs(key: key, from: from),
        initialChildren: children,
      );

  static const String name = 'LoginRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<LoginRouteArgs>(
        orElse: () => const LoginRouteArgs(),
      );
      return _i24.LoginPage(key: args.key, from: args.from);
    },
  );
}

class LoginRouteArgs {
  const LoginRouteArgs({this.key, this.from});

  final _i49.Key? key;

  final String? from;

  @override
  String toString() {
    return 'LoginRouteArgs{key: $key, from: $from}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LoginRouteArgs) return false;
    return key == other.key && from == other.from;
  }

  @override
  int get hashCode => key.hashCode ^ from.hashCode;
}

/// generated route for
/// [_i25.MorePage]
class MoreRoute extends _i48.PageRouteInfo<void> {
  const MoreRoute({List<_i48.PageRouteInfo>? children})
    : super(MoreRoute.name, initialChildren: children);

  static const String name = 'MoreRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i25.MorePage();
    },
  );
}

/// generated route for
/// [_i26.NavigationBar]
class NavigationBar extends _i48.PageRouteInfo<void> {
  const NavigationBar({List<_i48.PageRouteInfo>? children})
    : super(NavigationBar.name, initialChildren: children);

  static const String name = 'NavigationBar';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i26.NavigationBar();
    },
  );
}

/// generated route for
/// [_i27.OldHomePage]
class OldHomeRoute extends _i48.PageRouteInfo<void> {
  const OldHomeRoute({List<_i48.PageRouteInfo>? children})
    : super(OldHomeRoute.name, initialChildren: children);

  static const String name = 'OldHomeRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i27.OldHomePage();
    },
  );
}

/// generated route for
/// [_i28.OldRankingPage]
class OldRankingRoute extends _i48.PageRouteInfo<void> {
  const OldRankingRoute({List<_i48.PageRouteInfo>? children})
    : super(OldRankingRoute.name, initialChildren: children);

  static const String name = 'OldRankingRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i28.OldRankingPage();
    },
  );
}

/// generated route for
/// [_i29.PluginCommentsScaffold]
class PluginCommentsScaffoldRoute
    extends _i48.PageRouteInfo<PluginCommentsScaffoldRouteArgs> {
  PluginCommentsScaffoldRoute({
    _i49.Key? key,
    required String from,
    required String comicId,
    required String comicTitle,
    _i59.CommentPluginCall? pluginCall,
    List<_i48.PageRouteInfo>? children,
  }) : super(
         PluginCommentsScaffoldRoute.name,
         args: PluginCommentsScaffoldRouteArgs(
           key: key,
           from: from,
           comicId: comicId,
           comicTitle: comicTitle,
           pluginCall: pluginCall,
         ),
         initialChildren: children,
       );

  static const String name = 'PluginCommentsScaffoldRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PluginCommentsScaffoldRouteArgs>();
      return _i29.PluginCommentsScaffold(
        key: args.key,
        from: args.from,
        comicId: args.comicId,
        comicTitle: args.comicTitle,
        pluginCall: args.pluginCall,
      );
    },
  );
}

class PluginCommentsScaffoldRouteArgs {
  const PluginCommentsScaffoldRouteArgs({
    this.key,
    required this.from,
    required this.comicId,
    required this.comicTitle,
    this.pluginCall,
  });

  final _i49.Key? key;

  final String from;

  final String comicId;

  final String comicTitle;

  final _i59.CommentPluginCall? pluginCall;

  @override
  String toString() {
    return 'PluginCommentsScaffoldRouteArgs{key: $key, from: $from, comicId: $comicId, comicTitle: $comicTitle, pluginCall: $pluginCall}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PluginCommentsScaffoldRouteArgs) return false;
    return key == other.key &&
        from == other.from &&
        comicId == other.comicId &&
        comicTitle == other.comicTitle &&
        pluginCall == other.pluginCall;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      from.hashCode ^
      comicId.hashCode ^
      comicTitle.hashCode ^
      pluginCall.hashCode;
}

/// generated route for
/// [_i30.PluginDetailPage]
class PluginDetailRoute extends _i48.PageRouteInfo<PluginDetailRouteArgs> {
  PluginDetailRoute({
    _i49.Key? key,
    required String from,
    required String pluginUuid,
    required String pluginDisplayName,
    List<_i48.PageRouteInfo>? children,
  }) : super(
         PluginDetailRoute.name,
         args: PluginDetailRouteArgs(
           key: key,
           from: from,
           pluginUuid: pluginUuid,
           pluginDisplayName: pluginDisplayName,
         ),
         initialChildren: children,
       );

  static const String name = 'PluginDetailRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PluginDetailRouteArgs>();
      return _i30.PluginDetailPage(
        key: args.key,
        from: args.from,
        pluginUuid: args.pluginUuid,
        pluginDisplayName: args.pluginDisplayName,
      );
    },
  );
}

class PluginDetailRouteArgs {
  const PluginDetailRouteArgs({
    this.key,
    required this.from,
    required this.pluginUuid,
    required this.pluginDisplayName,
  });

  final _i49.Key? key;

  final String from;

  final String pluginUuid;

  final String pluginDisplayName;

  @override
  String toString() {
    return 'PluginDetailRouteArgs{key: $key, from: $from, pluginUuid: $pluginUuid, pluginDisplayName: $pluginDisplayName}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PluginDetailRouteArgs) return false;
    return key == other.key &&
        from == other.from &&
        pluginUuid == other.pluginUuid &&
        pluginDisplayName == other.pluginDisplayName;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      from.hashCode ^
      pluginUuid.hashCode ^
      pluginDisplayName.hashCode;
}

/// generated route for
/// [_i31.PluginFunctionPage]
class PluginFunctionRoute extends _i48.PageRouteInfo<PluginFunctionRouteArgs> {
  PluginFunctionRoute({
    _i49.Key? key,
    required String from,
    required String functionId,
    required String title,
    required _i50.Future<void> Function(Map<String, dynamic>) onAction,
    List<_i48.PageRouteInfo>? children,
  }) : super(
         PluginFunctionRoute.name,
         args: PluginFunctionRouteArgs(
           key: key,
           from: from,
           functionId: functionId,
           title: title,
           onAction: onAction,
         ),
         initialChildren: children,
       );

  static const String name = 'PluginFunctionRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PluginFunctionRouteArgs>();
      return _i31.PluginFunctionPage(
        key: args.key,
        from: args.from,
        functionId: args.functionId,
        title: args.title,
        onAction: args.onAction,
      );
    },
  );
}

class PluginFunctionRouteArgs {
  const PluginFunctionRouteArgs({
    this.key,
    required this.from,
    required this.functionId,
    required this.title,
    required this.onAction,
  });

  final _i49.Key? key;

  final String from;

  final String functionId;

  final String title;

  final _i50.Future<void> Function(Map<String, dynamic>) onAction;

  @override
  String toString() {
    return 'PluginFunctionRouteArgs{key: $key, from: $from, functionId: $functionId, title: $title, onAction: $onAction}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PluginFunctionRouteArgs) return false;
    return key == other.key &&
        from == other.from &&
        functionId == other.functionId &&
        title == other.title;
  }

  @override
  int get hashCode =>
      key.hashCode ^ from.hashCode ^ functionId.hashCode ^ title.hashCode;
}

/// generated route for
/// [_i32.PluginSettingsPage]
class PluginSettingsRoute extends _i48.PageRouteInfo<PluginSettingsRouteArgs> {
  PluginSettingsRoute({
    _i49.Key? key,
    required String from,
    required String pluginUuid,
    required String pluginRuntimeName,
    required String pluginDisplayName,
    bool insideSource = false,
    _i60.PluginSettingsScope scope = _i60.PluginSettingsScope.all,
    List<_i48.PageRouteInfo>? children,
  }) : super(
         PluginSettingsRoute.name,
         args: PluginSettingsRouteArgs(
           key: key,
           from: from,
           pluginUuid: pluginUuid,
           pluginRuntimeName: pluginRuntimeName,
           pluginDisplayName: pluginDisplayName,
           insideSource: insideSource,
           scope: scope,
         ),
         initialChildren: children,
       );

  static const String name = 'PluginSettingsRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<PluginSettingsRouteArgs>();
      return _i32.PluginSettingsPage(
        key: args.key,
        from: args.from,
        pluginUuid: args.pluginUuid,
        pluginRuntimeName: args.pluginRuntimeName,
        pluginDisplayName: args.pluginDisplayName,
        insideSource: args.insideSource,
        scope: args.scope,
      );
    },
  );
}

class PluginSettingsRouteArgs {
  const PluginSettingsRouteArgs({
    this.key,
    required this.from,
    required this.pluginUuid,
    required this.pluginRuntimeName,
    required this.pluginDisplayName,
    this.insideSource = false,
    this.scope = _i60.PluginSettingsScope.all,
  });

  final _i49.Key? key;

  final String from;

  final String pluginUuid;

  final String pluginRuntimeName;

  final String pluginDisplayName;

  final bool insideSource;

  final _i60.PluginSettingsScope scope;

  @override
  String toString() {
    return 'PluginSettingsRouteArgs{key: $key, from: $from, pluginUuid: $pluginUuid, pluginRuntimeName: $pluginRuntimeName, pluginDisplayName: $pluginDisplayName, insideSource: $insideSource, scope: $scope}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PluginSettingsRouteArgs) return false;
    return key == other.key &&
        from == other.from &&
        pluginUuid == other.pluginUuid &&
        pluginRuntimeName == other.pluginRuntimeName &&
        pluginDisplayName == other.pluginDisplayName &&
        insideSource == other.insideSource &&
        scope == other.scope;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      from.hashCode ^
      pluginUuid.hashCode ^
      pluginRuntimeName.hashCode ^
      pluginDisplayName.hashCode ^
      insideSource.hashCode ^
      scope.hashCode;
}

/// generated route for
/// [_i33.PluginStorePage]
class PluginStoreRoute extends _i48.PageRouteInfo<void> {
  const PluginStoreRoute({List<_i48.PageRouteInfo>? children})
    : super(PluginStoreRoute.name, initialChildren: children);

  static const String name = 'PluginStoreRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i33.PluginStorePage();
    },
  );
}

/// generated route for
/// [_i34.QjsRuntimeDebugPage]
class QjsRuntimeDebugRoute extends _i48.PageRouteInfo<void> {
  const QjsRuntimeDebugRoute({List<_i48.PageRouteInfo>? children})
    : super(QjsRuntimeDebugRoute.name, initialChildren: children);

  static const String name = 'QjsRuntimeDebugRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i34.QjsRuntimeDebugPage();
    },
  );
}

/// generated route for
/// [_i35.RealSrSettingPage]
class RealSrSettingRoute extends _i48.PageRouteInfo<void> {
  const RealSrSettingRoute({List<_i48.PageRouteInfo>? children})
    : super(RealSrSettingRoute.name, initialChildren: children);

  static const String name = 'RealSrSettingRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i35.RealSrSettingPage();
    },
  );
}

/// generated route for
/// [_i36.SearchAggregateResultPage]
class SearchAggregateResultRoute
    extends _i48.PageRouteInfo<SearchAggregateResultRouteArgs> {
  SearchAggregateResultRoute({
    _i49.Key? key,
    required _i61.SearchEvent searchEvent,
    _i62.SearchCubit? searchCubit,
    Map<String, bool> selectedSources = const {},
    List<_i48.PageRouteInfo>? children,
  }) : super(
         SearchAggregateResultRoute.name,
         args: SearchAggregateResultRouteArgs(
           key: key,
           searchEvent: searchEvent,
           searchCubit: searchCubit,
           selectedSources: selectedSources,
         ),
         initialChildren: children,
       );

  static const String name = 'SearchAggregateResultRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SearchAggregateResultRouteArgs>();
      return _i48.WrappedRoute(
        child: _i36.SearchAggregateResultPage(
          key: args.key,
          searchEvent: args.searchEvent,
          searchCubit: args.searchCubit,
          selectedSources: args.selectedSources,
        ),
      );
    },
  );
}

class SearchAggregateResultRouteArgs {
  const SearchAggregateResultRouteArgs({
    this.key,
    required this.searchEvent,
    this.searchCubit,
    this.selectedSources = const {},
  });

  final _i49.Key? key;

  final _i61.SearchEvent searchEvent;

  final _i62.SearchCubit? searchCubit;

  final Map<String, bool> selectedSources;

  @override
  String toString() {
    return 'SearchAggregateResultRouteArgs{key: $key, searchEvent: $searchEvent, searchCubit: $searchCubit, selectedSources: $selectedSources}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SearchAggregateResultRouteArgs) return false;
    return key == other.key &&
        searchEvent == other.searchEvent &&
        searchCubit == other.searchCubit &&
        const _i54.MapEquality<String, bool>().equals(
          selectedSources,
          other.selectedSources,
        );
  }

  @override
  int get hashCode =>
      key.hashCode ^
      searchEvent.hashCode ^
      searchCubit.hashCode ^
      const _i54.MapEquality<String, bool>().hash(selectedSources);
}

/// generated route for
/// [_i37.SearchPage]
class SearchRoute extends _i48.PageRouteInfo<SearchRouteArgs> {
  SearchRoute({
    _i49.Key? key,
    required _i62.SearchStates searchState,
    bool aggregateMode = true,
    List<_i48.PageRouteInfo>? children,
  }) : super(
         SearchRoute.name,
         args: SearchRouteArgs(
           key: key,
           searchState: searchState,
           aggregateMode: aggregateMode,
         ),
         initialChildren: children,
       );

  static const String name = 'SearchRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SearchRouteArgs>();
      return _i37.SearchPage(
        key: args.key,
        searchState: args.searchState,
        aggregateMode: args.aggregateMode,
      );
    },
  );
}

class SearchRouteArgs {
  const SearchRouteArgs({
    this.key,
    required this.searchState,
    this.aggregateMode = true,
  });

  final _i49.Key? key;

  final _i62.SearchStates searchState;

  final bool aggregateMode;

  @override
  String toString() {
    return 'SearchRouteArgs{key: $key, searchState: $searchState, aggregateMode: $aggregateMode}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SearchRouteArgs) return false;
    return key == other.key &&
        searchState == other.searchState &&
        aggregateMode == other.aggregateMode;
  }

  @override
  int get hashCode =>
      key.hashCode ^ searchState.hashCode ^ aggregateMode.hashCode;
}

/// generated route for
/// [_i38.SearchResultPage]
class SearchResultRoute extends _i48.PageRouteInfo<SearchResultRouteArgs> {
  SearchResultRoute({
    _i49.Key? key,
    required _i63.SearchEvent searchEvent,
    _i62.SearchCubit? searchCubit,
    List<_i48.PageRouteInfo>? children,
  }) : super(
         SearchResultRoute.name,
         args: SearchResultRouteArgs(
           key: key,
           searchEvent: searchEvent,
           searchCubit: searchCubit,
         ),
         initialChildren: children,
       );

  static const String name = 'SearchResultRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SearchResultRouteArgs>();
      return _i48.WrappedRoute(
        child: _i38.SearchResultPage(
          key: args.key,
          searchEvent: args.searchEvent,
          searchCubit: args.searchCubit,
        ),
      );
    },
  );
}

class SearchResultRouteArgs {
  const SearchResultRouteArgs({
    this.key,
    required this.searchEvent,
    this.searchCubit,
  });

  final _i49.Key? key;

  final _i63.SearchEvent searchEvent;

  final _i62.SearchCubit? searchCubit;

  @override
  String toString() {
    return 'SearchResultRouteArgs{key: $key, searchEvent: $searchEvent, searchCubit: $searchCubit}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SearchResultRouteArgs) return false;
    return key == other.key &&
        searchEvent == other.searchEvent &&
        searchCubit == other.searchCubit;
  }

  @override
  int get hashCode =>
      key.hashCode ^ searchEvent.hashCode ^ searchCubit.hashCode;
}

/// generated route for
/// [_i39.ShowColorPage]
class ShowColorRoute extends _i48.PageRouteInfo<void> {
  const ShowColorRoute({List<_i48.PageRouteInfo>? children})
    : super(ShowColorRoute.name, initialChildren: children);

  static const String name = 'ShowColorRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i39.ShowColorPage();
    },
  );
}

/// generated route for
/// [_i40.SourceSettingsHub]
class SourceSettingsHubRoute
    extends _i48.PageRouteInfo<SourceSettingsHubRouteArgs> {
  SourceSettingsHubRoute({
    _i49.Key? key,
    List<_i64.SourceMenuAction> actions = const [],
    String source = '',
    List<_i48.PageRouteInfo>? children,
  }) : super(
         SourceSettingsHubRoute.name,
         args: SourceSettingsHubRouteArgs(
           key: key,
           actions: actions,
           source: source,
         ),
         initialChildren: children,
       );

  static const String name = 'SourceSettingsHubRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SourceSettingsHubRouteArgs>(
        orElse: () => const SourceSettingsHubRouteArgs(),
      );
      return _i40.SourceSettingsHub(
        key: args.key,
        actions: args.actions,
        source: args.source,
      );
    },
  );
}

class SourceSettingsHubRouteArgs {
  const SourceSettingsHubRouteArgs({
    this.key,
    this.actions = const [],
    this.source = '',
  });

  final _i49.Key? key;

  final List<_i64.SourceMenuAction> actions;

  final String source;

  @override
  String toString() {
    return 'SourceSettingsHubRouteArgs{key: $key, actions: $actions, source: $source}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SourceSettingsHubRouteArgs) return false;
    return key == other.key &&
        const _i54.ListEquality<_i64.SourceMenuAction>().equals(
          actions,
          other.actions,
        ) &&
        source == other.source;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      const _i54.ListEquality<_i64.SourceMenuAction>().hash(actions) ^
      source.hashCode;
}

/// generated route for
/// [_i41.SourceShellPage]
class SourceShellRoute extends _i48.PageRouteInfo<SourceShellRouteArgs> {
  SourceShellRoute({
    _i49.Key? key,
    required String source,
    required String sourceName,
    required List<_i65.SourceShellSection> sections,
    String initialSectionId = '',
    List<_i48.PageRouteInfo>? children,
  }) : super(
         SourceShellRoute.name,
         args: SourceShellRouteArgs(
           key: key,
           source: source,
           sourceName: sourceName,
           sections: sections,
           initialSectionId: initialSectionId,
         ),
         initialChildren: children,
       );

  static const String name = 'SourceShellRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SourceShellRouteArgs>();
      return _i41.SourceShellPage(
        key: args.key,
        source: args.source,
        sourceName: args.sourceName,
        sections: args.sections,
        initialSectionId: args.initialSectionId,
      );
    },
  );
}

class SourceShellRouteArgs {
  const SourceShellRouteArgs({
    this.key,
    required this.source,
    required this.sourceName,
    required this.sections,
    this.initialSectionId = '',
  });

  final _i49.Key? key;

  final String source;

  final String sourceName;

  final List<_i65.SourceShellSection> sections;

  final String initialSectionId;

  @override
  String toString() {
    return 'SourceShellRouteArgs{key: $key, source: $source, sourceName: $sourceName, sections: $sections, initialSectionId: $initialSectionId}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SourceShellRouteArgs) return false;
    return key == other.key &&
        source == other.source &&
        sourceName == other.sourceName &&
        const _i54.ListEquality<_i65.SourceShellSection>().equals(
          sections,
          other.sections,
        ) &&
        initialSectionId == other.initialSectionId;
  }

  @override
  int get hashCode =>
      key.hashCode ^
      source.hashCode ^
      sourceName.hashCode ^
      const _i54.ListEquality<_i65.SourceShellSection>().hash(sections) ^
      initialSectionId.hashCode;
}

/// generated route for
/// [_i42.StorageSettingPage]
class StorageSettingRoute extends _i48.PageRouteInfo<void> {
  const StorageSettingRoute({List<_i48.PageRouteInfo>? children})
    : super(StorageSettingRoute.name, initialChildren: children);

  static const String name = 'StorageSettingRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i42.StorageSettingPage();
    },
  );
}

/// generated route for
/// [_i43.SwitchStyleSettingPage]
class SwitchStyleSettingRoute extends _i48.PageRouteInfo<void> {
  const SwitchStyleSettingRoute({List<_i48.PageRouteInfo>? children})
    : super(SwitchStyleSettingRoute.name, initialChildren: children);

  static const String name = 'SwitchStyleSettingRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i43.SwitchStyleSettingPage();
    },
  );
}

/// generated route for
/// [_i44.SyncSettingPage]
class SyncSettingRoute extends _i48.PageRouteInfo<SyncSettingRouteArgs> {
  SyncSettingRoute({
    _i56.Key? key,
    _i44.SyncArchiveActions archiveActions = const _i44.SyncArchiveActions(),
    List<_i48.PageRouteInfo>? children,
  }) : super(
         SyncSettingRoute.name,
         args: SyncSettingRouteArgs(key: key, archiveActions: archiveActions),
         initialChildren: children,
       );

  static const String name = 'SyncSettingRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<SyncSettingRouteArgs>(
        orElse: () => const SyncSettingRouteArgs(),
      );
      return _i44.SyncSettingPage(
        key: args.key,
        archiveActions: args.archiveActions,
      );
    },
  );
}

class SyncSettingRouteArgs {
  const SyncSettingRouteArgs({
    this.key,
    this.archiveActions = const _i44.SyncArchiveActions(),
  });

  final _i56.Key? key;

  final _i44.SyncArchiveActions archiveActions;

  @override
  String toString() {
    return 'SyncSettingRouteArgs{key: $key, archiveActions: $archiveActions}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SyncSettingRouteArgs) return false;
    return key == other.key && archiveActions == other.archiveActions;
  }

  @override
  int get hashCode => key.hashCode ^ archiveActions.hashCode;
}

/// generated route for
/// [_i45.ThemeColorPage]
class ThemeColorRoute extends _i48.PageRouteInfo<void> {
  const ThemeColorRoute({List<_i48.PageRouteInfo>? children})
    : super(ThemeColorRoute.name, initialChildren: children);

  static const String name = 'ThemeColorRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i45.ThemeColorPage();
    },
  );
}

/// generated route for
/// [_i46.WebDavSyncPage]
class WebDavSyncRoute extends _i48.PageRouteInfo<void> {
  const WebDavSyncRoute({List<_i48.PageRouteInfo>? children})
    : super(WebDavSyncRoute.name, initialChildren: children);

  static const String name = 'WebDavSyncRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      return const _i46.WebDavSyncPage();
    },
  );
}

/// generated route for
/// [_i47.WebViewPage]
class WebViewRoute extends _i48.PageRouteInfo<WebViewRouteArgs> {
  WebViewRoute({
    _i49.Key? key,
    required List<String> info,
    List<_i48.PageRouteInfo>? children,
  }) : super(
         WebViewRoute.name,
         args: WebViewRouteArgs(key: key, info: info),
         initialChildren: children,
       );

  static const String name = 'WebViewRoute';

  static _i48.PageInfo page = _i48.PageInfo(
    name,
    builder: (data) {
      final args = data.argsAs<WebViewRouteArgs>();
      return _i47.WebViewPage(key: args.key, info: args.info);
    },
  );
}

class WebViewRouteArgs {
  const WebViewRouteArgs({this.key, required this.info});

  final _i49.Key? key;

  final List<String> info;

  @override
  String toString() {
    return 'WebViewRouteArgs{key: $key, info: $info}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! WebViewRouteArgs) return false;
    return key == other.key &&
        const _i54.ListEquality<String>().equals(info, other.info);
  }

  @override
  int get hashCode =>
      key.hashCode ^ const _i54.ListEquality<String>().hash(info);
}
