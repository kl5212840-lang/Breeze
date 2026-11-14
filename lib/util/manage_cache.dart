import 'package:zephyr/page/video/video_personal_snapshot_store.dart';
import 'package:zephyr/page/comic_list/cubit/jm_collection_snapshots.dart';
import 'package:zephyr/service/temporary_data_cache.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/util/get_path.dart';
import 'package:zephyr/service/cache_workspace_guard.dart';
import 'package:zephyr/service/source_image_cache_store.dart';
import 'package:zephyr/src/rust/api/simple.dart';

bool shouldCleanCacheOnStartup(GlobalSettingState state, int measuredBytes) {
  final cache = state.cacheSetting;
  final limit = cache.cacheSizeLimit > 0 ? cache.cacheSizeLimit : 1073741824;
  return cache.autoCleanCache && measuredBytes >= limit;
}

SourceImageCacheStore _imageCache(String cachePath, {String? source}) {
  final sources = source == null
      ? objectbox.pluginInfoBox.getAll().map((plugin) => plugin.uuid.trim())
      : [source.trim()];
  return SourceImageCacheStore(
    root: cachePath,
    sourceSegments: sources
        .where((source) => source.isNotEmpty)
        .map((source) => encodePath(path: source)),
  );
}

/// Count only image partitions whose source identity is known. Workspace and
/// unclassified caches are intentionally neither measured nor removed.
Future<int> imageCacheSize(String cachePath, {String? source}) =>
    _imageCache(cachePath, source: source).sizeBytes();

Future<void> manageCacheSize(BuildContext context) async {
  if (!context.mounted) return;
  final cubit = context.read<GlobalSettingCubit>();
  // Older builds deferred cleanup with this flag. The current startup always
  // measures the actual image cache before taking action.
  if (cubit.state.needCleanCache) {
    cubit.updateState((state) => state.copyWith(needCleanCache: false));
  }
  if (!cubit.state.cacheSetting.autoCleanCache) return;
  try {
    final images = _imageCache(await getCachePath());
    final bytes = await images.sizeBytes();
    if (!context.mounted || !shouldCleanCacheOnStartup(cubit.state, bytes)) {
      return;
    }
    await CacheWorkspaceGuard.clear(() async {
      if (context.mounted && shouldCleanCacheOnStartup(cubit.state, bytes)) {
        await images.clear();
      }
    });
  } catch (error, stack) {
    logger.w(
      'Startup image cache cleanup deferred',
      error: error,
      stackTrace: stack,
    );
  }
}

Future<void> clearCache(String cachePath, {String? source}) =>
    CacheWorkspaceGuard.clear(() async {
      try {
        // Even a mistaken caller cannot turn this entry into download/file
        // cleanup. The source partition lives only under the platform cache.
        if (!p.equals(
          p.absolute(cachePath),
          p.absolute(await getCachePath()),
        )) {
          throw const CacheCleanupFailed();
        }
        if (source != null && source.trim().isEmpty) {
          throw const CacheCleanupFailed();
        }
        await _imageCache(cachePath, source: source).clear();
        TemporaryDataCaches.clear(source: source);
        await VideoPersonalSnapshotStore.clearDisk(source: source);
        await JmCollectionSnapshots.instance.clearDisk(source: source);
        logger.d('Reloadable image cache cleared.');
      } catch (_) {
        throw const CacheCleanupFailed();
      }
    });
