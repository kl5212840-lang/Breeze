import 'dart:convert';

import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/bookshelf/service/comic_link_service.dart';
import 'package:zephyr/page/bookshelf/service/video_bookshelf_index.dart';
import 'package:zephyr/util/text/public_search_text.dart';
import 'package:zephyr/util/json/shelf_metadata_fields.dart';

import 'package:zephyr/widgets/comic_entry/models/unified_comic_list_item_mapper.dart';
import 'package:zephyr/widgets/comic_simplify_entry/comic_simplify_entry_info.dart';

export 'package:zephyr/util/json/shelf_metadata_fields.dart'
    show shelfFacetFieldsFromMetadata;

Set<String> _explicitValues(String value) => value
    .split(RegExp(r'[/,，、;；|]'))
    .map((v) => v.trim())
    .where((v) => v.isNotEmpty)
    .toSet();
String _search(Iterable<String> parts) =>
    normalizePublicSearchText(parts.join(' '));

ShelfFacetEntry shelfFacetEntryFromVideo(VideoBookshelfRow row) {
  final item = row.item;
  final fields =
      <String, Set<String>>{
        'tags': _explicitValues(item.genres),
        'category': {item.typeName.trim()},
        'year': _explicitValues(item.year),
        'area': _explicitValues(item.area),
        'language': _explicitValues(item.language),
        'quality': {...?row.facetFields['quality']},
        'author': _explicitValues(item.writers),
      }..removeWhere((_, values) {
        values.remove('');
        return values.isEmpty;
      });
  return ShelfFacetEntry(
    key: row.key,
    source: row.source.trim(),
    searchText: _search([
      item.title,
      item.description,
      item.alternateTitle,
      item.actors,
      item.directors,
      item.writers,
      ...fields.values.expand((v) => v),
    ]),
    folders: row.folderIds.isEmpty ? const {'__unfiled'} : {...row.folderIds},
    fields: fields,
  );
}

class ComicShelfFacetIndex {
  const ComicShelfFacetIndex({
    required this.entries,
    required this.comics,
    required this.folderLabels,
    this.sortTimes = const {},
    this.recordKeys = const {},
    this.storedMemberships = const {},
  });
  final List<ShelfFacetEntry> entries;
  final Map<String, ComicSimplifyEntryInfo> comics;
  final Map<String, String> folderLabels;
  final Map<String, DateTime> sortTimes;

  /// Canonical display identity -> original persisted record identities.
  final Map<String, Set<String>> recordKeys;

  /// Canonical identity -> original link identity -> actual directory paths.
  final Map<String, Map<String, Set<String>>> storedMemberships;
}

Set<String> comicFacetRecordKeys(ComicShelfFacetIndex index, String key) =>
    index.recordKeys[key] ?? {key};

Map<String, Map<String, Set<String>>> comicFacetStoredPathsInScope(
  ComicShelfFacetIndex index,
  ShelfFacetSelection selection, {
  required String currentFolder,
}) => {
  for (final entry in index.entries)
    entry.key: {
      for (final stored
          in (index.storedMemberships[entry.key] ?? {entry.key: entry.folders})
              .entries)
        stored.key: {
          for (final path in stored.value)
            if (shelfFacetMatches(
              entry.copyWith(folders: {path}),
              selection.copyWith(values: const {}),
              currentFolder: currentFolder,
            ))
              path,
        },
    },
};

void copyComicFromFacetIndex(
  String key,
  Set<String> targets, {
  required ComicShelfFacetIndex snapshot,
  required ComicFolderType type,
}) {
  if (!snapshot.comics.containsKey(key)) return;
  ComicLinkService.copyComicLinks(
    comicFacetRecordKeys(snapshot, key),
    targets,
    type,
  );
}

void moveComicFromFacetScope(
  String key,
  ShelfFacetSelection selection,
  Set<String> targets, {
  required String currentFolder,
  required ComicShelfFacetIndex snapshot,
  required ComicFolderType type,
}) {
  if (targets.isEmpty) return;
  final storedPaths = comicFacetStoredPathsInScope(
    snapshot,
    selection,
    currentFolder: currentFolder,
  )[key];
  if (storedPaths == null) return;
  for (final stored in storedPaths.entries) {
    ComicLinkService.moveComicLinks(stored.key, stored.value, targets, type);
  }
}

/// Preserve memberships outside the chosen folder scope during move/removal.
Map<String, Set<String>> comicFacetPathsInScope(
  ComicShelfFacetIndex index,
  ShelfFacetSelection selection, {
  required String currentFolder,
}) => {
  for (final entry in index.entries)
    entry.key: {
      for (final path in entry.folders)
        if (shelfFacetMatches(
          entry.copyWith(folders: {path}),
          selection.copyWith(values: const {}),
          currentFolder: currentFolder,
        ))
          path,
    },
};

void removeComicFromFacetScope(
  String key,
  ShelfFacetSelection selection, {
  required String currentFolder,
  ComicShelfFacetIndex? snapshot,
  ComicFolderType type = ComicFolderType.favorite,
}) {
  final index = snapshot ?? loadComicShelfFacetIndex(type: type);
  final storedPaths = comicFacetStoredPathsInScope(
    index,
    selection,
    currentFolder: currentFolder,
  )[key];
  if (storedPaths == null ||
      storedPaths.values.every((paths) => paths.isEmpty)) {
    return;
  }
  if (selection.scope == ShelfFacetScope.all) {
    for (final storedKey in {
      ...comicFacetRecordKeys(index, key),
      ...storedPaths.keys,
    }) {
      ComicLinkService.removeComicFromAll(storedKey, type);
    }
  } else {
    for (final stored in storedPaths.entries) {
      if (stored.value.isEmpty) {
        continue;
      }
      if (ComicLinkService.linksOfComic(stored.key, type).isEmpty) {
        ComicLinkService.removeComicFromAll(stored.key, type);
      } else {
        for (final path in stored.value) {
          ComicLinkService.removeComic(
            stored.key,
            path.isEmpty ? null : path,
            type,
          );
        }
      }
    }
  }
}

/// Build a read-only, source-namespaced snapshot; each work is counted once even
/// when multiple links point to it. Folder identities are sync IDs, never names.
ComicShelfFacetIndex comicShelfFacetIndexFromSnapshot({
  List<UnifiedComicFavorite> favorites = const [],
  List<UnifiedComicHistory> histories = const [],
  List<UnifiedComicDownload> downloads = const [],
  ComicFolderType type = ComicFolderType.favorite,
  required List<ComicFolder> folders,
  required List<ComicLink> links,
}) {
  final byId = {
    for (final f in folders)
      if (f.typeData == type.name && f.deletedAt == null && f.syncId.isNotEmpty)
        f.syncId: f,
  };
  final removedFolderIds = {
    for (final folder in folders)
      if (folder.typeData == type.name && folder.deletedAt != null)
        folder.syncId,
  };
  final paths = <String, String?>{};
  String? pathFor(String id, Set<String> visited) {
    if (paths.containsKey(id)) return paths[id];
    final folder = byId[id];
    if (folder == null || !visited.add(id)) return null;
    final name = folder.name.trim();
    if (name.isEmpty || name.contains('/')) return paths[id] = null;
    final parent = folder.parentSyncId;
    final prefix = parent == null || parent.isEmpty
        ? ''
        : pathFor(parent, visited);
    return paths[id] = prefix == null ? null : '$prefix/$name';
  }

  for (final id in byId.keys) {
    pathFor(id, {});
  }
  final folderLabels = <String, String>{
    '': t.common.root,
    for (final path in paths.values.whereType<String>()) path: path,
  };
  final candidates = switch (type) {
    ComicFolderType.favorite => [
      for (final row in favorites)
        _ComicFacetRow(
          uniqueKey: row.uniqueKey,
          source: row.source,
          comicId: row.comicId,
          title: row.title,
          description: row.description,
          creator: row.creator,
          titleMeta: row.titleMeta,
          metadata: row.metadata,
          updatedAt: row.updatedAt,
          sortTime: row.createdAt,
          deleted: row.deleted,
          info: unifiedComicFromUnifiedFavorite(row).toSimplifyEntryInfo(),
        ),
    ],
    ComicFolderType.history => [
      for (final row in histories)
        _ComicFacetRow(
          uniqueKey: row.uniqueKey,
          source: row.source,
          comicId: row.comicId,
          title: row.title,
          description: row.description,
          creator: row.creator,
          titleMeta: row.titleMeta,
          metadata: row.metadata,
          updatedAt: row.updatedAt,
          sortTime: row.updatedAt,
          deleted: row.deleted,
          info: unifiedComicFromUnifiedHistory(row).toSimplifyEntryInfo(),
        ),
    ],
    ComicFolderType.download => [
      for (final row in downloads)
        _ComicFacetRow(
          uniqueKey: row.uniqueKey,
          source: row.source,
          comicId: row.comicId,
          title: row.title,
          description: row.description,
          creator: row.creator,
          titleMeta: row.titleMeta,
          metadata: row.metadata,
          updatedAt: row.updatedAt,
          sortTime: row.downloadedAt,
          deleted: row.deleted,
          info: unifiedComicFromUnifiedDownload(row).toSimplifyEntryInfo(),
        ),
    ],
  };
  final rows = <String, _ComicFacetRow>{};
  final recordKeys = <String, Set<String>>{};
  final aliases = <String, String>{};
  for (final favorite in candidates.where((f) => !f.deleted)) {
    final source = favorite.source.trim();
    if (source.isEmpty || favorite.comicId.isEmpty) continue;
    final key = '$source:${favorite.comicId}';
    recordKeys.putIfAbsent(key, () => <String>{}).add(favorite.uniqueKey);
    aliases[favorite.uniqueKey] = key;
    aliases[key] = key;
    if (rows[key] == null || favorite.updatedAt.isAfter(rows[key]!.updatedAt)) {
      rows[key] = favorite;
    }
  }
  final memberships = <String, Set<String>>{};
  final storedMemberships = <String, Map<String, Set<String>>>{};
  final removedMemberships = <String>{};
  for (final link in links) {
    if (link.typeData != type.name) continue;
    final key = aliases[link.comicUniqueKey];
    if (key == null) continue;
    if (link.deletedAt != null ||
        removedFolderIds.contains(link.folderSyncId)) {
      removedMemberships.add(key);
      continue;
    }
    final id = link.folderSyncId;
    final path = id == null || id.isEmpty ? '' : paths[id];
    if (path != null) {
      memberships.putIfAbsent(key, () => <String>{}).add(path);
      storedMemberships
          .putIfAbsent(key, () => <String, Set<String>>{})
          .putIfAbsent(link.comicUniqueKey, () => <String>{})
          .add(path);
    }
  }
  final comics = <String, ComicSimplifyEntryInfo>{};
  final entries = <ShelfFacetEntry>[];
  for (final row in rows.entries) {
    // Legacy favorites without a link can appear at root. An explicitly
    // removed or unreachable membership must never become that fallback.
    if ((type == ComicFolderType.download ||
            type == ComicFolderType.favorite &&
                removedMemberships.contains(row.key)) &&
        memberships[row.key]?.isNotEmpty != true) {
      continue;
    }
    final favorite = row.value;
    final fields = shelfFacetFieldsFromMetadata(favorite.metadata);
    String creator = '';
    try {
      final value = jsonDecode(favorite.creator);
      if (value is Map && value['name'] is String) {
        creator = value['name'] as String;
      }
    } catch (_) {}
    comics[row.key] = favorite.info;
    entries.add(
      ShelfFacetEntry(
        key: row.key,
        source: favorite.source.trim(),
        searchText: _search([
          favorite.comicId,
          favorite.title,
          favorite.description,
          creator,
          favorite.titleMeta,
          ...fields.values.expand((v) => v),
        ]),
        folders:
            type != ComicFolderType.history &&
                memberships[row.key]?.isNotEmpty == true
            ? memberships[row.key]!
            : const {''},
        fields: fields,
      ),
    );
  }
  return ComicShelfFacetIndex(
    entries: List.unmodifiable(entries),
    comics: Map.unmodifiable(comics),
    folderLabels: type == ComicFolderType.history
        ? const {}
        : Map.unmodifiable(folderLabels),
    recordKeys: Map.unmodifiable({
      for (final row in recordKeys.entries)
        row.key: Set<String>.unmodifiable(row.value),
    }),
    storedMemberships: Map.unmodifiable({
      for (final row in rows.entries)
        row.key: Map<String, Set<String>>.unmodifiable({
          for (final stored
              in (storedMemberships[row.key] ??
                      {
                        for (final key in recordKeys[row.key]!) key: {''},
                      })
                  .entries)
            stored.key: Set<String>.unmodifiable(stored.value),
        }),
    }),
    sortTimes: Map.unmodifiable({
      for (final row in rows.entries) row.key: row.value.sortTime,
    }),
  );
}

ComicShelfFacetIndex loadComicShelfFacetIndex({required ComicFolderType type}) {
  final folderQuery = objectbox.comicFolderBox
      .query(ComicFolder_.typeData.equals(type.name))
      .build();
  final linkQuery = objectbox.comicLinkBox
      .query(ComicLink_.typeData.equals(type.name))
      .build();
  try {
    return comicShelfFacetIndexFromSnapshot(
      type: type,
      favorites: type == ComicFolderType.favorite
          ? objectbox.unifiedFavoriteBox.getAll()
          : const [],
      histories: type == ComicFolderType.history
          ? objectbox.unifiedHistoryBox.getAll()
          : const [],
      downloads: type == ComicFolderType.download
          ? objectbox.unifiedDownloadBox.getAll()
          : const [],
      folders: folderQuery.find(),
      links: linkQuery.find(),
    );
  } finally {
    folderQuery.close();
    linkQuery.close();
  }
}

/// Public fields projected from each mode's own persisted record, never another
/// shelf's copy of the work. Unknown plugin metadata stays absent.
class _ComicFacetRow {
  const _ComicFacetRow({
    required this.uniqueKey,
    required this.source,
    required this.comicId,
    required this.title,
    required this.description,
    required this.creator,
    required this.titleMeta,
    required this.metadata,
    required this.updatedAt,
    required this.sortTime,
    required this.deleted,
    required this.info,
  });
  final String uniqueKey,
      source,
      comicId,
      title,
      description,
      creator,
      titleMeta,
      metadata;
  final DateTime updatedAt, sortTime;
  final bool deleted;
  final ComicSimplifyEntryInfo info;
}
