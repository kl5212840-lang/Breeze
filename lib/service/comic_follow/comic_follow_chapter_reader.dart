import 'dart:async';

import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart'
    show normalizePluginId;
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/network/http/plugin/unified_plugin_envelope.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/comic_info/method/get_plugin_detail.dart'
    show sortChaptersByOrder;
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/comic_follow/comic_follow_check_failure.dart';
import 'package:zephyr/service/page_read_tasks.dart';
import 'package:zephyr/util/json/json_value.dart';

const _legacyJmSource = 'bf99008d-010b-4f17-ac7c-61a9b57dc3d9';

/// Optional, negotiated using the installed CJS getInfo, never a store claim.
bool supportsComicFollowV1(Map<String, dynamic>? pluginInfo) {
  final experience = asJsonMap(pluginInfo?['breezeExperience']);
  final declaration = experience.containsKey('comicFollow')
      ? experience['comicFollow']
      : asJsonMap(
          asJsonMap(pluginInfo?['data'])['breezeExperience'],
        )['comicFollow'];
  return declaration is int && declaration == 1;
}

class ComicFollowDetection {
  const ComicFollowDetection({
    required this.chapterCount,
    required this.latestChapterTitle,
    this.latestChapterId = '',
    this._chapterPositions = const {},
    this.failure,
  });

  const ComicFollowDetection.failed(ComicFollowCheckFailure reason)
    : this(chapterCount: null, latestChapterTitle: '', failure: reason);

  final int? chapterCount;
  final String latestChapterTitle;
  final String latestChapterId;
  final Map<String, int> _chapterPositions;
  final ComicFollowCheckFailure? failure;

  bool get hasOrderedChapters => _chapterPositions.isNotEmpty;

  /// A summary can identify the latest chapter but contains no read positions.
  int? positionOf(String chapterId) {
    final position = _chapterPositions[chapterId.trim()] ?? 0;
    return position > 0 ? position : null;
  }

  Set<String> get latestChapterIds => _chapterPositions.isEmpty
      ? {if (latestChapterId.isNotEmpty) latestChapterId}
      : {
          for (final entry in _chapterPositions.entries)
            if (entry.value == chapterCount) entry.key,
        };
}

typedef ComicFollowPluginRead =
    Future<Map<String, dynamic>> Function(
      String source,
      String comicId,
      Map<String, dynamic>? extern,
    );

/// Tracks public chapter metadata using the source's current runtime and
/// network rules. No account lookup, login UI, or detail-page writes.
class ComicFollowChapterReader {
  ComicFollowChapterReader({
    this._read,
    ComicFollowCheckFailure? Function(String source)? sourceFailure,
    Map<String, dynamic>? Function(String source)? pluginInfo,
    Future<void> Function(Duration)? delay,
    this._readBudget = const Duration(seconds: 25),
  }) : _sourceFailure = sourceFailure ?? _installedSourceFailure,
       _pluginInfo = pluginInfo ?? PluginRegistryService.I.getCachedPluginInfo,
       _delay = delay ?? Future<void>.delayed;

  final ComicFollowPluginRead? _read;
  final ComicFollowCheckFailure? Function(String source) _sourceFailure;
  final Map<String, dynamic>? Function(String source) _pluginInfo;
  final Future<void> Function(Duration) _delay;
  final Duration _readBudget;

  Future<Map<String, dynamic>> _request(
    String source,
    String comicId,
    Map<String, dynamic>? extern,
  ) {
    final read = _read;
    final tasks = read == null ? PageReadTasks() : null;
    final work = read != null
        ? read(source, comicId, extern)
        : tasks!.run(
            source,
            (group) => callUnifiedComicPlugin(
              from: source,
              fnPath: 'getComicDetail',
              core: {'comicId': comicId},
              extern: extern,
              notifyUnauthorized: false,
              taskGroupKey: group,
            ),
          );
    return work.timeout(
      _readBudget,
      onTimeout: () {
        // Cancel only this read. Its physical work still owns and clears the
        // group, even if it was preparing the runtime when the budget ran out.
        if (tasks != null) unawaited(tasks.cancel());
        throw const ComicFollowCheckException(ComicFollowCheckFailure.network);
      },
    );
  }

  static ComicFollowCheckFailure? _installedSourceFailure(String source) {
    final plugin = PluginRegistryService.I.getByUuid(source);
    if (plugin == null || plugin.isDeleted) {
      return ComicFollowCheckFailure.pluginMissing;
    }
    return plugin.isEnabled ? null : ComicFollowCheckFailure.pluginDisabled;
  }

  Future<ComicFollowDetection?> detect(
    ComicFollow follow, {
    bool Function()? canContinue,
  }) async {
    final source = normalizePluginId(follow.source);
    final comicId = follow.comicId.trim();
    for (var attempt = 0; ; attempt++) {
      if (canContinue?.call() == false) return null;
      final before = _sourceFailure(source);
      if (before != null) return ComicFollowDetection.failed(before);
      final useFollowContract = supportsComicFollowV1(_pluginInfo(source));
      try {
        final payload = await _request(
          source,
          comicId,
          useFollowContract ? const {'comicFollow': true} : null,
        );
        if (canContinue?.call() == false) return null;
        final after = _sourceFailure(source);
        if (after != null) return ComicFollowDetection.failed(after);
        final snapshot = _readSnapshot(
          payload,
          comicId,
          useFollowContract: useFollowContract,
        );
        if ((snapshot.chapterCount == 0 && follow.detectedChapterCount > 0) ||
            (source == _legacyJmSource &&
                follow.detectedChapterCount > 1 &&
                snapshot.chapterCount == 1 &&
                _looksLikeLegacyJmFallback(payload, comicId))) {
          // A formerly populated series cannot be cleared by an empty list
          // that might be a failed or partial read. Keep the last observation.
          return const ComicFollowDetection.failed(
            ComicFollowCheckFailure.invalidResponse,
          );
        }
        return snapshot;
      } catch (error) {
        if (canContinue?.call() == false) return null;
        final after = _sourceFailure(source);
        if (after != null) return ComicFollowDetection.failed(after);
        final failure = classifyComicFollowCheckFailure(error);
        if (attempt != 0 || !failure.retryable) {
          return ComicFollowDetection.failed(failure.reason);
        }
        await _delay(const Duration(milliseconds: 800));
      }
    }
  }

  static bool _looksLikeLegacyJmFallback(
    Map<String, dynamic> payload,
    String comicId,
  ) {
    final data = asJsonMap(payload['data']);
    final rawComic = asJsonMap(asJsonMap(data['raw'])['comicInfo']);
    final chapters = asJsonMap(data['normal'])['eps'];
    final series = rawComic['series'];
    if (series is! List ||
        series.isNotEmpty ||
        chapters is! List ||
        chapters.length != 1) {
      return false;
    }
    final chapter = asJsonMap(chapters.single);
    return chapter['id'] == comicId && chapter['order'] == 1;
  }

  static ComicFollowDetection _readSnapshot(
    Map<String, dynamic> payload,
    String comicId, {
    required bool useFollowContract,
  }) {
    void validate(Map<String, dynamic> map) {
      final failure = ComicFollowCheckException.fromPluginEnvelope(map);
      if (failure != null) throw failure;
      requireSuccessfulPluginEnvelope(map);
    }

    const invalid = FormatException('Invalid chapter snapshot');
    validate(payload);
    final data = asJsonMap(payload['data']);
    validate(data);
    final normal = asJsonMap(data.isEmpty ? payload['normal'] : data['normal']);
    validate(normal);
    final identity = asJsonMap(normal['comicInfo'])['id'];
    if (comicId.isEmpty || identity is! String || identity.trim() != comicId) {
      throw invalid;
    }
    final extern = asJsonMap(normal['extern']);
    if (useFollowContract && extern.containsKey('comicFollow')) {
      final summary = extern['comicFollow'];
      if (summary is! Map) throw invalid;
      final count = summary['chapterCount'];
      final title = summary['latestChapterTitle'];
      final latestId = summary['latestChapterId'];
      if (count is! int ||
          count < 0 ||
          title is! String ||
          latestId is! String ||
          (count > 0 && (latestId.trim().isEmpty || title.trim().isEmpty))) {
        throw invalid;
      }
      return ComicFollowDetection(
        chapterCount: count,
        latestChapterTitle: count == 0 ? '' : title,
        latestChapterId: count == 0 ? '' : latestId.trim(),
      );
    }

    // Compatibility for older Copy builds and other plugins. Only inspect the
    // chapter data, so an unrelated recommendation/cover field cannot poison
    // an otherwise usable chapter observation.
    final chapters = normal['eps'];
    final fieldsMissing = extern['fieldsMissing'];
    if (chapters is! List ||
        (fieldsMissing is List &&
            fieldsMissing.any(
              const {'eps', 'chapters', 'chapterList'}.contains,
            ))) {
      throw invalid;
    }
    final episodes = <({String id, String name, int order, Set<String> ids})>[];
    for (final chapter in chapters) {
      if (chapter is! Map ||
          chapter['id'] is! String ||
          (chapter['id'] as String).trim().isEmpty ||
          chapter['name'] is! String ||
          chapter['order'] is! int) {
        throw invalid;
      }
      final rawId = (chapter['id'] as String).trim();
      final logicalKey = chapter['logicalKey'];
      final requestId = chapter['requestId'];
      final id = logicalKey is String && logicalKey.trim().isNotEmpty
          ? logicalKey.trim()
          : rawId;
      episodes.add((
        id: id,
        name: chapter['name'] as String,
        order: chapter['order'] as int,
        ids: {
          id,
          rawId,
          if (requestId is String && requestId.trim().isNotEmpty)
            requestId.trim(),
        },
      ));
    }
    final ordered = sortChaptersByOrder(episodes, (episode) => episode.order);
    final positions = <String, int>{};
    for (var index = 0; index < ordered.length; index++) {
      for (final id in ordered[index].ids) {
        // Older histories can store an alias. Shared IDs are ambiguous.
        positions.update(id, (_) => 0, ifAbsent: () => index + 1);
      }
    }
    final latest = ordered.lastOrNull;
    return ComicFollowDetection(
      chapterCount: ordered.length,
      latestChapterTitle: latest?.name ?? '',
      latestChapterId: latest?.id ?? '',
      chapterPositions: positions,
    );
  }
}
