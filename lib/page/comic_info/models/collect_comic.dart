import 'dart:convert';
import 'package:zephyr/network/http/plugin/unified_plugin_envelope.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/page/comic_list/cubit/jm_collection_snapshots.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/page/comic_info/models/plugin_action_login.dart';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/comic_info/models/favorite_workflow.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/page/bookshelf/service/comic_link_service.dart';
import 'package:zephyr/util/json/json_sanitize.dart';
import 'package:zephyr/util/path_util.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/breeze_switch.dart';

UnifiedComicFavorite? _findLocalFavorite(String key) {
  final query = objectbox.unifiedFavoriteBox
      .query(UnifiedComicFavorite_.uniqueKey.equals(key))
      .build();
  try {
    return query.findFirst();
  } finally {
    query.close();
  }
}

Future<bool> isLocalComicCollected({
  required String from,
  required String comicId,
}) async {
  final key = '${from.trim()}:$comicId';
  final favorite = _findLocalFavorite(key);
  if (favorite == null || favorite.deleted) return false;
  if (_repairedFavoriteCover(favorite) == null) return true;
  return objectbox.store.runInTransaction(TxMode.write, () {
    final current = _findLocalFavorite(key);
    if (current == null || current.deleted) return false;
    if (_repairedFavoriteCover(current) case final cover?) {
      // A cache path repair carries no change to the user's favorite intent.
      current.cover = cover;
      objectbox.unifiedFavoriteBox.put(current);
    }
    return true;
  });
}

/// Apply the confirmed intent even if another page or sync has already
/// changed this favorite. Store the item and its links in one transaction.
Future<({bool collected, bool changed})> setLocalComicFavorite({
  required String from,
  required NormalComicAllInfo normalInfo,
  required bool collected,
}) async {
  final comicInfo = normalInfo.comicInfo;
  final pluginId = from.trim();
  final key = '$pluginId:${comicInfo.id}';
  return objectbox.store.runInTransaction(TxMode.write, () {
    final now = DateTime.now().toUtc();
    if (!collected) {
      final query = objectbox.unifiedFavoriteBox
          .query(UnifiedComicFavorite_.comicId.equals(comicInfo.id))
          .build();
      final records = <UnifiedComicFavorite>[];
      try {
        records.addAll(
          query.find().where((row) => row.source.trim() == pluginId),
        );
      } finally {
        query.close();
      }
      final existing = _findLocalFavorite(key);
      if (existing != null && !records.any((row) => row.id == existing.id)) {
        records.add(existing);
      }
      final live = records.where((row) => !row.deleted).toList();
      for (final row in live) {
        row
          ..deleted = true
          ..updatedAt = now;
      }
      if (live.isNotEmpty) objectbox.unifiedFavoriteBox.putMany(live);
      for (final storedKey in {key, ...records.map((row) => row.uniqueKey)}) {
        ComicLinkService.removeComicFromAll(
          storedKey,
          ComicFolderType.favorite,
        );
      }
      return (collected: false, changed: live.isNotEmpty);
    }
    final existing = _findLocalFavorite(key);
    final wasCollected = existing != null && !existing.deleted;
    if (wasCollected) return (collected: true, changed: false);

    objectbox.unifiedFavoriteBox.put(
      UnifiedComicFavorite(
        id: existing?.id ?? 0,
        uniqueKey: key,
        source: pluginId,
        comicId: comicInfo.id,
        title: comicInfo.title,
        description: comicInfo.description,
        cover: jsonEncode(_comicImageToMap(comicInfo.cover)),
        creator: jsonEncode(_creatorToMap(comicInfo.creator)),
        titleMeta: jsonEncode(
          comicInfo.titleMeta.map(_titleMetaToMap).toList(),
        ),
        metadata: jsonEncode(comicInfo.metadata.map(_metadataToMap).toList()),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        deleted: false,
        schemaVersion: 2,
      ),
    );
    ComicLinkService.addComic(key, null, ComicFolderType.favorite);
    return (collected: true, changed: true);
  });
}

Map<String, dynamic> _comicImageToMap(ComicImage image) {
  return sanitizeDynamic({
    'id': image.id,
    'url': image.url,
    'name': image.name,
    'path': _resolveImagePath(
      id: image.id,
      url: image.url,
      rawPath: image.path,
    ),
    'extern': image.extern,
  });
}

String? _repairedFavoriteCover(UnifiedComicFavorite favorite) {
  final coverRaw = favorite.cover.trim();
  if (coverRaw.isEmpty) {
    return null;
  }

  Map<String, dynamic> coverMap;
  try {
    final decoded = jsonDecode(coverRaw);
    if (decoded is! Map) {
      return null;
    }
    coverMap = Map<String, dynamic>.from(decoded);
  } catch (_) {
    return null;
  }

  final currentPath = coverMap['path']?.toString().trim() ?? '';
  if (currentPath.isNotEmpty) {
    return null;
  }

  final repairedPath = _resolveImagePath(
    id: coverMap['id']?.toString() ?? favorite.comicId,
    url: coverMap['url']?.toString() ?? '',
    rawPath: currentPath,
  );
  if (repairedPath.isEmpty) {
    return null;
  }

  coverMap['path'] = repairedPath;
  return jsonEncode(sanitizeDynamic(coverMap));
}

String _resolveImagePath({
  required String id,
  required String url,
  required String rawPath,
}) {
  final path = rawPath.trim();
  if (path.isNotEmpty) {
    return path;
  }

  final safeId = sanitizePathSegment(id.trim().isEmpty ? 'cover' : id);
  final extension = extractImageExtension(url);
  return '$safeId.$extension';
}

Map<String, dynamic> _creatorToMap(Creator creator) {
  return sanitizeDynamic({
    'id': creator.id,
    'name': creator.name,
    'avatar': _comicImageToMap(creator.avatar),
    'onTap': creator.onTap,
    'extern': creator.extern,
  });
}

Map<String, dynamic> _titleMetaToMap(ComicInfoActionItem item) {
  return sanitizeDynamic({
    'name': item.name,
    'onTap': item.onTap,
    'onLongPress': item.onLongPress,
    'extern': item.extern,
  });
}

Map<String, dynamic> _metadataToMap(ComicInfoMetadata item) {
  return sanitizeDynamic({
    'name': item.name,
    'type': item.type,
    'value': item.value
        .map(
          (entry) => sanitizeDynamic({
            'name': entry.name,
            'onTap': entry.onTap,
            'onLongPress': entry.onLongPress,
            'extern': entry.extern,
          }),
        )
        .toList(),
  });
}

Future<bool> toggleCloudComicFavorite({
  required BuildContext context,
  required String from,
  String? pluginId,
  required String comicId,
  required bool currentStatus,
  NormalComicAllInfo? snapshotInfo,
  bool legacyAllowCollected = true,
  String legacyAllowCollectedReason = '',
  String? collectionTargetId,
  String? collectionTargetName,
}) async {
  final result = await executeCloudFavoriteWorkflow(
    context: context,
    from: from,
    pluginId: pluginId,
    comicId: comicId,
    action: currentStatus
        ? ((collectionTargetId?.trim().isNotEmpty ?? false) ||
                  (collectionTargetName?.trim().isNotEmpty ?? false)
              ? FavoriteWorkflowAction.removeFromTarget
              : FavoriteWorkflowAction.removeAll)
        : FavoriteWorkflowAction.add,
    currentStatus: currentStatus,
    snapshotInfo: snapshotInfo,
    legacyAllowCollected: legacyAllowCollected,
    legacyAllowCollectedReason: legacyAllowCollectedReason,
    collectionTargetId: collectionTargetId,
    collectionTargetName: collectionTargetName,
  );
  if (result.status != FavoriteWorkflowStatus.completed) {
    throw FavoriteWorkflowIncompleteException(result);
  }
  final favorited = result.favorited;
  if (favorited is! bool) {
    throw StateError(t.comicInfo.pluginInvalidFavorited);
  }
  return favorited;
}

typedef FavoriteWorkflowPluginCall =
    Future<Map<String, dynamic>> Function({
      required String pluginId,
      required String fnPath,
      required Map<String, dynamic> core,
      required Map<String, dynamic> extern,
    });

Future<Map<String, dynamic>> _callFavoriteWorkflowPlugin({
  required String pluginId,
  required String fnPath,
  required Map<String, dynamic> core,
  required Map<String, dynamic> extern,
}) => callUnifiedComicPlugin(
  pluginId: pluginId,
  fnPath: fnPath,
  core: core,
  extern: extern,
  // The originating action owns its sign-in prompt; keep the source underneath.
  notifyUnauthorized: false,
);

UnifiedComicListItem _collectionSnapshotItem(
  String source,
  NormalComicAllInfo info,
) {
  final comic = info.comicInfo;
  final metadata = [
    for (final m in comic.metadata)
      UnifiedComicMetadata(
        type: m.type,
        name: m.name,
        value: m.value.map((v) => v.name).toList(),
      ),
  ];
  final missing = info.extern['fieldsMissing'];
  if (missing is List &&
      !missing.contains('tags') &&
      !metadata.any((m) => m.type == 'tags' || m.type == 'tag')) {
    metadata.add(const UnifiedComicMetadata(type: 'tags', name: '', value: []));
  }
  return UnifiedComicListItem(
    source: source,
    id: comic.id,
    title: comic.title,
    subtitle: '',
    finished: false,
    likesCount: info.totalLikes,
    viewsCount: info.totalViews,
    updatedAt: DateTime.now().toUtc().toIso8601String(),
    cover: UnifiedComicCover(
      id: comic.cover.id,
      url: comic.cover.url,
      path: comic.cover.path,
      extern: const {},
    ),
    metadata: metadata,
    raw: {'description': comic.description},
    extern: const {},
  );
}

class _CloudFavoriteAction {
  const _CloudFavoriteAction(this.intent, this.future);
  final String intent;
  final Future<FavoriteWorkflowExecutionResult> future;
}

final _cloudFavoriteActions = <String, _CloudFavoriteAction>{};
int _cloudFavoriteOperationSerial = 0;

Future<FavoriteWorkflowExecutionResult> executeCloudFavoriteWorkflow({
  required BuildContext context,
  required String from,
  String? pluginId,
  required String comicId,
  required FavoriteWorkflowAction action,
  required bool currentStatus,
  NormalComicAllInfo? snapshotInfo,
  bool legacyAllowCollected = true,
  String legacyAllowCollectedReason = '',
  String? collectionTargetId,
  String? collectionTargetName,
  FavoriteWorkflowPluginCall? invokePlugin,
}) {
  final source = (pluginId?.trim().isNotEmpty ?? false)
      ? pluginId!.trim()
      : from.trim();
  final generation = pluginSessionWriteFence.generation(source);
  final key = '$source:$generation:$comicId';
  final intent = jsonEncode([
    action.wireName,
    collectionTargetId,
    collectionTargetName,
  ]);
  final pending = _cloudFavoriteActions[key];
  // Repeated taps join the same write. A distinct explicit intent waits for the
  // preceding result and uses its confirmed status, never a stale button value.
  if (pending?.intent == intent) return pending!.future;
  Future<FavoriteWorkflowExecutionResult> run() async {
    var status = currentStatus;
    if (pending != null) {
      final previous = await pending.future;
      if (previous.status != FavoriteWorkflowStatus.completed) return previous;
      status = previous.favorited ?? status;
    }
    if (!context.mounted ||
        generation != pluginSessionWriteFence.generation(source) ||
        pluginSessionWriteFence.isChanging(source)) {
      return const FavoriteWorkflowExecutionResult(
        status: FavoriteWorkflowStatus.cancelled,
      );
    }
    return _executeCloudFavoriteWorkflow(
      context: context,
      from: from,
      pluginId: source,
      comicId: comicId,
      action: action,
      currentStatus: status,
      snapshotInfo: snapshotInfo,
      legacyAllowCollected: legacyAllowCollected,
      legacyAllowCollectedReason: legacyAllowCollectedReason,
      collectionTargetId: collectionTargetId,
      collectionTargetName: collectionTargetName,
      invokePlugin: invokePlugin,
    );
  }

  final task = run();
  final entry = _CloudFavoriteAction(intent, task);
  _cloudFavoriteActions[key] = entry;
  void release() {
    if (identical(_cloudFavoriteActions[key], entry))
      _cloudFavoriteActions.remove(key);
  }

  // Observe both terminal paths without creating an unhandled error Future.
  task.then<void>(
    (_) => release(),
    onError: (Object _, StackTrace __) => release(),
  );
  return task;
}

Future<FavoriteWorkflowExecutionResult> _executeCloudFavoriteWorkflow({
  required BuildContext context,
  required String from,
  String? pluginId,
  required String comicId,
  required FavoriteWorkflowAction action,
  required bool currentStatus,
  NormalComicAllInfo? snapshotInfo,
  bool legacyAllowCollected = true,
  String legacyAllowCollectedReason = '',
  String? collectionTargetId,
  String? collectionTargetName,
  FavoriteWorkflowPluginCall? invokePlugin,
}) async {
  final resolvedPluginId = (pluginId?.trim().isNotEmpty ?? false)
      ? pluginId!.trim()
      : from.trim();
  final targetId = collectionTargetId?.trim() ?? '';
  final targetFolder = targetId.isEmpty ? null : targetId;
  final snapshots = JmCollectionSnapshots.instance;
  final account = snapshots.accountScope(resolvedPluginId);
  final generation = pluginSessionWriteFence.generation(resolvedPluginId);
  final operation = ++_cloudFavoriteOperationSerial;
  var commitStep = 0;
  String? recorded;
  var snapshotStatus = currentStatus;
  Future<void> record(
    bool next,
    bool _,
    String? movedToFolder, {
    String? addedToFolder,
  }) async {
    final identity = '$next|${movedToFolder ?? ''}|${addedToFolder ?? ''}';
    if (account == null || recorded == identity) return;
    recorded = identity;
    try {
      await snapshots.mutate(
        source: resolvedPluginId,
        account: account,
        generation: generation,
        id: comicId,
        operationId: '$operation:${++commitStep}',
        favorited: next,
        previouslyFavorited: snapshotStatus,
        item: snapshotInfo == null
            ? null
            : _collectionSnapshotItem(resolvedPluginId, snapshotInfo),
        movedToFolder: movedToFolder,
        addedToFolder: addedToFolder,
        removedFromFolder: action == FavoriteWorkflowAction.removeFromTarget
            ? collectionTargetId
            : null,
      );
      snapshotStatus = next;
    } catch (_) {
      /* A local cache failure cannot undo the confirmed site action. */
    }
  }

  try {
    final result = await _runFavoriteWorkflow(
      context: context,
      invokePlugin: invokePlugin ?? _callFavoriteWorkflowPlugin,
      pluginId: resolvedPluginId,
      comicId: comicId,
      action: action,
      currentStatus: currentStatus,
      collectionTargetId: collectionTargetId,
      collectionTargetName: collectionTargetName,
      onCommitted: (next) => record(
        next,
        currentStatus,
        action == FavoriteWorkflowAction.move ? targetFolder : null,
        addedToFolder: action == FavoriteWorkflowAction.add
            ? targetFolder
            : null,
      ),
    );
    return result;
  } catch (error) {
    if (error is FavoriteWorkflowIncompleteException &&
        error.result.committed &&
        error.result.favorited is bool) {
      await record(
        error.result.favorited!,
        currentStatus,
        action == FavoriteWorkflowAction.move ? targetFolder : null,
        addedToFolder: action == FavoriteWorkflowAction.add
            ? targetFolder
            : null,
      );
    }
    if (error is PluginLoginRequiredException ||
        !_isMissingFavoriteWorkflowFunction(error)) {
      rethrow;
    }
    if (!legacyAllowCollected ||
        (action != FavoriteWorkflowAction.add &&
            action != FavoriteWorkflowAction.removeAll)) {
      throw FavoriteWorkflowUnsupportedException(legacyAllowCollectedReason);
    }
    return _runLegacyFavoriteWorkflow(
      context: context,
      pluginId: resolvedPluginId,
      comicId: comicId,
      action: action,
      currentStatus: currentStatus,
      recordSnapshot: record,
    );
  }
}

Future<FavoriteWorkflowExecutionResult> _runFavoriteWorkflow({
  required BuildContext context,
  required FavoriteWorkflowPluginCall invokePlugin,
  required String pluginId,
  required String comicId,
  required FavoriteWorkflowAction action,
  required bool currentStatus,
  required Future<void> Function(bool) onCommitted,
  String? collectionTargetId,
  String? collectionTargetName,
}) async {
  final target = <String, dynamic>{};
  if (collectionTargetId?.trim().isNotEmpty ?? false) {
    target['id'] = collectionTargetId!.trim();
  }
  if (collectionTargetName?.trim().isNotEmpty ?? false) {
    target['name'] = collectionTargetName!.trim();
  }

  var response = await invokePlugin(
    pluginId: pluginId,
    fnPath: 'startFavoriteAction',
    core: {
      'comicId': comicId,
      'action': action.wireName,
      'currentFavorite': currentStatus,
      if (target.isNotEmpty) 'context': {'target': target},
    },
    extern: const <String, dynamic>{},
  );

  for (var step = 0; step < 16; step++) {
    final result = FavoriteWorkflowResult.fromJson(response);
    // A confirmed no-op (already absent on the site) also supersedes a stale
    // local snapshot. Preserve committed=false: no write was performed.
    if ((result.committed ||
            result.status == FavoriteWorkflowStatus.completed) &&
        result.favorited is bool) {
      await onCommitted(result.favorited!);
    }
    switch (result.status) {
      case FavoriteWorkflowStatus.completed:
        return _toExecutionResult(result);
      case FavoriteWorkflowStatus.partial:
      case FavoriteWorkflowStatus.failed:
      case FavoriteWorkflowStatus.cancelled:
        final executionResult = _toExecutionResult(result);
        if (result.status == FavoriteWorkflowStatus.failed) {
          // Some plugins return a caught unauthorized envelope as failed.message.
          // Preserve that explicit type rather than guessing from human text.
          if (!result.committed) {
            final login = pluginActionLoginRequirement(
              result.message,
              pluginId: pluginId,
            );
            if (login != null) throw login;
          }
          final message = result.message?.trim() ?? '';
          throw StateError(
            message.isNotEmpty ? message : t.error.executionFailed,
          );
        }
        throw FavoriteWorkflowIncompleteException(executionResult);
      case FavoriteWorkflowStatus.awaitingInput:
        final token = result.continuationToken?.trim() ?? '';
        final input = result.input;
        if (token.isEmpty || input == null) {
          throw StateError('收藏工作流等待交互时缺少 continuationToken 或 input');
        }
        if (!context.mounted) {
          throw const FavoriteWorkflowIncompleteException(
            FavoriteWorkflowExecutionResult(
              status: FavoriteWorkflowStatus.cancelled,
              message: '页面已关闭，收藏操作已取消',
            ),
          );
        }
        final userInput = await showFavoriteWorkflowInput(context, input);
        response = await invokePlugin(
          pluginId: pluginId,
          fnPath: 'continueFavoriteAction',
          core: {
            'comicId': comicId,
            'action': action.wireName,
            'continuationToken': token,
            'input': userInput ?? const <String, dynamic>{'cancelled': true},
          },
          extern: const <String, dynamic>{},
        );
    }
  }

  throw StateError('收藏工作流超过最大交互步骤');
}

FavoriteWorkflowExecutionResult _toExecutionResult(
  FavoriteWorkflowResult result,
) {
  return FavoriteWorkflowExecutionResult(
    status: result.status,
    favorited: result.favorited,
    committed: result.committed,
    message: result.message,
  );
}

Future<FavoriteWorkflowExecutionResult> _runLegacyFavoriteWorkflow({
  required BuildContext context,
  required String pluginId,
  required String comicId,
  required FavoriteWorkflowAction action,
  required bool currentStatus,
  required Future<void> Function(
    bool next,
    bool previous,
    String? movedToFolder,
  )
  recordSnapshot,
}) async {
  final data = await _callFavoriteWorkflowPlugin(
    pluginId: pluginId,
    fnPath: 'toggleFavorite',
    core: {'comicId': comicId, 'currentFavorite': currentStatus},
    extern: const <String, dynamic>{},
  );
  final favorited = data['favorited'];
  if (favorited is! bool) {
    throw StateError(t.comicInfo.pluginInvalidFavorited);
  }

  await recordSnapshot(favorited, currentStatus, null);
  final nextStep = data['nextStep']?.toString() ?? 'none';
  if (action != FavoriteWorkflowAction.add ||
      !favorited ||
      nextStep != 'selectFolder' ||
      !context.mounted) {
    return FavoriteWorkflowExecutionResult(
      status: FavoriteWorkflowStatus.completed,
      favorited: favorited,
      committed: true,
    );
  }

  final folders = await _listCloudFavoriteFolders(pluginId);
  if (!context.mounted || folders.isEmpty) {
    return FavoriteWorkflowExecutionResult(
      status: FavoriteWorkflowStatus.completed,
      favorited: favorited,
      committed: true,
    );
  }

  final selectedFolder = await _showFolderSelectionDialog(context, folders);
  if (selectedFolder == null || !context.mounted) {
    return FavoriteWorkflowExecutionResult(
      status: FavoriteWorkflowStatus.completed,
      favorited: favorited,
      committed: true,
    );
  }

  await _moveCloudFavoriteToFolder(
    from: pluginId,
    comicId: comicId,
    folder: selectedFolder,
  );
  await recordSnapshot(favorited, favorited, selectedFolder.id);
  showSuccessToast(t.comicInfo.addedToFolder(name: selectedFolder.name));
  return FavoriteWorkflowExecutionResult(
    status: FavoriteWorkflowStatus.completed,
    favorited: favorited,
    committed: true,
  );
}

bool _isMissingFavoriteWorkflowFunction(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('startfavoriteaction') &&
      (message.contains('not a function') ||
          message.contains('function path not found') ||
          message.contains('missing function') ||
          message.contains('undefined'));
}

Future<Map<String, dynamic>?> showFavoriteWorkflowInput(
  BuildContext context,
  FavoriteWorkflowInput input,
) {
  return switch (input.type) {
    'select' => _showFavoriteWorkflowSelect(context, input),
    'text' => _showFavoriteWorkflowText(context, input),
    'confirm' => _showFavoriteWorkflowConfirm(context, input),
    'form' => _showFavoriteWorkflowForm(context, input),
    _ => throw StateError('不支持的收藏工作流交互类型：${input.type}'),
  };
}

Future<Map<String, dynamic>?> _showFavoriteWorkflowSelect(
  BuildContext context,
  FavoriteWorkflowInput input,
) async {
  final selected = input.options
      .where((option) => option.selected)
      .map((option) => option.id)
      .toSet();
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _FavoriteWorkflowInputControllers(
      builder: (dialogContext, controllers) {
        final createController = controllers.putIfAbsent(
          'create',
          TextEditingController.new,
        );
        return StatefulBuilder(
          builder: (ctx, setState) {
            final createdName = createController.text.trim();
            final canConfirm =
                !input.required ||
                selected.isNotEmpty ||
                createdName.isNotEmpty;
            return AlertDialog(
              title: Text(input.title ?? t.comicInfo.addToCustomFolder),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.6,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (input.description?.isNotEmpty ?? false)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(input.description!),
                        ),
                      if (input.options.isNotEmpty)
                        input.isMultiple
                            ? Column(
                                children: input.options.map((option) {
                                  return CheckboxListTile(
                                    value: selected.contains(option.id),
                                    title: Text(option.label),
                                    subtitle: option.description == null
                                        ? null
                                        : Text(option.description!),
                                    contentPadding: EdgeInsets.zero,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          selected.add(option.id);
                                        } else {
                                          selected.remove(option.id);
                                        }
                                        createController.clear();
                                      });
                                    },
                                  );
                                }).toList(),
                              )
                            : RadioGroup<String>(
                                groupValue: selected.isEmpty
                                    ? null
                                    : selected.first,
                                onChanged: (value) {
                                  setState(() {
                                    selected
                                      ..clear()
                                      ..add(value!);
                                    createController.clear();
                                  });
                                },
                                child: Column(
                                  children: input.options.map((option) {
                                    return RadioListTile<String>(
                                      value: option.id,
                                      title: Text(option.label),
                                      subtitle: option.description == null
                                          ? null
                                          : Text(option.description!),
                                      contentPadding: EdgeInsets.zero,
                                    );
                                  }).toList(),
                                ),
                              ),
                      if (input.allowCreate) ...[
                        if (input.options.isNotEmpty) const Divider(),
                        TextField(
                          controller: createController,
                          decoration: InputDecoration(
                            labelText: input.createField?.label ?? '新建收藏夹',
                            hintText: input.createField?.placeholder,
                          ),
                          onChanged: (_) {
                            setState(() {
                              selected.clear();
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(t.common.cancel),
                ),
                FilledButton(
                  onPressed: canConfirm
                      ? () {
                          final value = input.isMultiple
                              ? selected.toList()
                              : selected.isEmpty
                              ? null
                              : selected.first;
                          Navigator.pop(dialogContext, {
                            if (input.key?.isNotEmpty ?? false)
                              'key': input.key,
                            'value': value,
                            if (createdName.isNotEmpty) 'created': createdName,
                          });
                        }
                      : null,
                  child: Text(t.common.confirm),
                ),
              ],
            );
          },
        );
      },
    ),
  );
  return result;
}

Future<Map<String, dynamic>?> _showFavoriteWorkflowText(
  BuildContext context,
  FavoriteWorkflowInput input,
) async {
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _FavoriteWorkflowInputControllers(
      builder: (dialogContext, controllers) {
        final controller = controllers.putIfAbsent(
          'text',
          TextEditingController.new,
        );
        return StatefulBuilder(
          builder: (ctx, setState) {
            final canConfirm =
                !input.required || controller.text.trim().isNotEmpty;
            return AlertDialog(
              title: Text(input.title ?? ''),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(hintText: input.description),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (canConfirm) {
                    Navigator.pop(dialogContext, {
                      if (input.key?.isNotEmpty ?? false) 'key': input.key,
                      'value': controller.text,
                    });
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(t.common.cancel),
                ),
                FilledButton(
                  onPressed: canConfirm
                      ? () => Navigator.pop(dialogContext, {
                          if (input.key?.isNotEmpty ?? false) 'key': input.key,
                          'value': controller.text,
                        })
                      : null,
                  child: Text(t.common.confirm),
                ),
              ],
            );
          },
        );
      },
    ),
  );
  return result;
}

Future<Map<String, dynamic>?> _showFavoriteWorkflowConfirm(
  BuildContext context,
  FavoriteWorkflowInput input,
) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(input.title ?? t.common.confirm),
        content: input.description == null ? null : Text(input.description!),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t.common.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, {
              if (input.key?.isNotEmpty ?? false) 'key': input.key,
              'value': true,
            }),
            child: Text(t.common.confirm),
          ),
        ],
      );
    },
  );
}

Future<Map<String, dynamic>?> _showFavoriteWorkflowForm(
  BuildContext context,
  FavoriteWorkflowInput input,
) async {
  final values = <String, dynamic>{};
  for (final field in input.fields) {
    if (field.defaultValue != null) {
      values[field.key] = field.defaultValue;
    } else if (field.type == 'switch' || field.type == 'confirm') {
      values[field.key] = false;
    } else if (field.type == 'multiChoice') {
      values[field.key] = <String>[];
    }
  }

  bool isValid() {
    for (final field in input.fields.where((field) => field.required)) {
      final value = values[field.key];
      if (value == null ||
          value is String && value.trim().isEmpty ||
          value is List && value.isEmpty ||
          (field.type == 'switch' || field.type == 'confirm') &&
              value != true) {
        return false;
      }
    }
    return true;
  }

  Widget buildField(
    FavoriteWorkflowField field,
    void Function(void Function()) setState,
    Map<String, TextEditingController> controllers,
  ) {
    switch (field.type) {
      case 'switch':
      case 'confirm':
        return BreezeSwitchListTile(
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(field.label),
            subtitle: field.description == null
                ? null
                : Text(field.description!),
            value: values[field.key] == true,
            onChanged: (value) => setState(() => values[field.key] = value),
          ),
        );
      case 'choice':
        return RadioGroup<String>(
          groupValue: values[field.key]?.toString(),
          onChanged: (value) => setState(() => values[field.key] = value),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(field.label),
              if (field.description != null) Text(field.description!),
              ...field.options.map(
                (option) => RadioListTile<String>(
                  value: option.id,
                  title: Text(option.label),
                  subtitle: option.description == null
                      ? null
                      : Text(option.description!),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        );
      case 'multiChoice':
        final selected =
            (values[field.key] as List?)?.cast<String>() ?? <String>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(field.label),
            if (field.description != null) Text(field.description!),
            ...field.options.map(
              (option) => CheckboxListTile(
                value: selected.contains(option.id),
                title: Text(option.label),
                subtitle: option.description == null
                    ? null
                    : Text(option.description!),
                contentPadding: EdgeInsets.zero,
                onChanged: (value) => setState(() {
                  if (value == true) {
                    selected.add(option.id);
                  } else {
                    selected.remove(option.id);
                  }
                  values[field.key] = selected;
                }),
              ),
            ),
          ],
        );
      case 'text':
      case 'password':
      case 'number':
      default:
        final controller = controllers.putIfAbsent(
          field.key,
          () =>
              TextEditingController(text: field.defaultValue?.toString() ?? ''),
        );
        return TextField(
          controller: controller,
          obscureText: field.type == 'password',
          keyboardType: field.type == 'number'
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.placeholder,
          ),
          onChanged: (value) => setState(() => values[field.key] = value),
        );
    }
  }

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _FavoriteWorkflowInputControllers(
      builder: (dialogContext, controllers) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text(input.title ?? t.common.confirm),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.65,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (input.description != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(input.description!),
                          ),
                        ),
                      ...input.fields.map(
                        (field) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: buildField(field, setState, controllers),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(t.common.cancel),
                ),
                FilledButton(
                  onPressed: isValid()
                      ? () => Navigator.pop(dialogContext, {
                          'values': Map<String, dynamic>.from(values),
                        })
                      : null,
                  child: Text(t.common.confirm),
                ),
              ],
            );
          },
        );
      },
    ),
  );
  return result;
}

// A popped route remains mounted while its reverse transition runs. Keep text
// controllers with the dialog subtree, rather than the completed route Future.
class _FavoriteWorkflowInputControllers extends StatefulWidget {
  const _FavoriteWorkflowInputControllers({required this.builder});

  final Widget Function(BuildContext, Map<String, TextEditingController>)
  builder;

  @override
  State<_FavoriteWorkflowInputControllers> createState() =>
      _FavoriteWorkflowInputControllersState();
}

class _FavoriteWorkflowInputControllersState
    extends State<_FavoriteWorkflowInputControllers> {
  final _controllers = <String, TextEditingController>{};

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controllers);
}

Future<List<_FavoriteFolder>> _listCloudFavoriteFolders(String from) async {
  final data = await callUnifiedComicPlugin(
    from: from,
    fnPath: 'listFavoriteFolders',
    core: const <String, dynamic>{},
    extern: const <String, dynamic>{},
  );
  final items = data['items'];
  if (items is! List) {
    return const <_FavoriteFolder>[];
  }
  return items
      .whereType<Map>()
      .map((item) => _FavoriteFolder.fromJson(Map<String, dynamic>.from(item)))
      .where((item) => item.id.isNotEmpty)
      .toList();
}

Future<void> _moveCloudFavoriteToFolder({
  required String from,
  required String comicId,
  required _FavoriteFolder folder,
}) async {
  final result = await callUnifiedComicPlugin(
    from: from,
    fnPath: 'moveFavoriteToFolder',
    core: {
      'comicId': comicId,
      'folderId': folder.id,
      'folderName': folder.name,
    },
    extern: const <String, dynamic>{},
  );
  requireSuccessfulPluginEnvelope(result);
  if (from == PluginAccountAuthenticationService.jm &&
      result['ok'] != true &&
      asJsonMap(result['data'])['ok'] != true) {
    throw StateError(t.error.operationFailed);
  }
}

Future<_FavoriteFolder?> _showFolderSelectionDialog(
  BuildContext context,
  List<_FavoriteFolder> folders,
) {
  _FavoriteFolder? selected;
  return showDialog<_FavoriteFolder>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text(t.comicInfo.addToCustomFolder),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * 0.5,
              ),
              child: SizedBox(
                width: double.maxFinite,
                child: RadioGroup<String>(
                  groupValue: selected?.id,
                  onChanged: (value) {
                    setState(() {
                      final selectedIndex = folders.indexWhere(
                        (item) => item.id == value,
                      );
                      selected = selectedIndex >= 0
                          ? folders[selectedIndex]
                          : null;
                    });
                  },
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: folders.length,
                    itemBuilder: (itemCtx, index) {
                      final folder = folders[index];
                      return RadioListTile<String>(
                        title: Text(folder.name),
                        subtitle: Text('ID: ${folder.id}'),
                        value: folder.id,
                      );
                    },
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(t.comicInfo.skipAdd),
              ),
              ElevatedButton(
                onPressed: selected == null
                    ? null
                    : () => Navigator.pop(dialogContext, selected),
                child: Text(t.comicInfo.confirmAdd),
              ),
            ],
          );
        },
      );
    },
  );
}

class _FavoriteFolder {
  const _FavoriteFolder({required this.id, required this.name});

  final String id;
  final String name;

  factory _FavoriteFolder.fromJson(Map<String, dynamic> json) {
    return _FavoriteFolder(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}
