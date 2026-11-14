import 'dart:async';
import 'dart:convert';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/objectbox.g.dart';

String _field(Object? value) => switch (value) {
  'tag' => 'tags',
  'categories' => 'category',
  final String value => value,
  _ => '',
};
const _publicFields = {
  'tags',
  'author',
  'category',
  'works',
  'actors',
  'year',
  'area',
  'language',
};

class ComicPublicMetadataChange {
  const ComicPublicMetadataChange(this.source, this.recordKinds);
  final String source;
  final Set<String> recordKinds;
}

abstract final class ComicPublicMetadata {
  static final _changes = StreamController<ComicPublicMetadataChange>.broadcast(
    sync: true,
  );
  static Stream<ComicPublicMetadataChange> get changes => _changes.stream;

  /// Update public metadata only on existing live records. No timestamps,
  /// membership, download authority or reading position is changed.
  static void apply(
    String source,
    Map<String, List<Map<String, dynamic>>> byId, {
    Set<String> fieldsMissing = const {},
  }) {
    if (source.isEmpty || byId.isEmpty) return;
    final ids = byId.keys.toList();
    final kinds = <String>{};
    objectbox.store.runInTransaction(TxMode.write, () {
      final favorites = objectbox.unifiedFavoriteBox
          .query(
            UnifiedComicFavorite_.source
                .equals(source)
                .and(UnifiedComicFavorite_.comicId.oneOf(ids))
                .and(UnifiedComicFavorite_.deleted.equals(false)),
          )
          .build();
      final history = objectbox.unifiedHistoryBox
          .query(
            UnifiedComicHistory_.source
                .equals(source)
                .and(UnifiedComicHistory_.comicId.oneOf(ids))
                .and(UnifiedComicHistory_.deleted.equals(false)),
          )
          .build();
      final downloads = objectbox.unifiedDownloadBox
          .query(
            UnifiedComicDownload_.source
                .equals(source)
                .and(UnifiedComicDownload_.comicId.oneOf(ids))
                .and(UnifiedComicDownload_.deleted.equals(false)),
          )
          .build();
      try {
        for (final row in favorites.find()) {
          if (row.deleted) continue;
          final value = mergeComicPublicMetadata(
            row.metadata,
            byId[row.comicId]!,
            fieldsMissing: fieldsMissing,
          );
          if (value != row.metadata) {
            row.metadata = value;
            objectbox.unifiedFavoriteBox.put(row);
            kinds.add('favorite');
          }
        }
        for (final row in history.find()) {
          if (row.deleted) continue;
          final value = mergeComicPublicMetadata(
            row.metadata,
            byId[row.comicId]!,
            fieldsMissing: fieldsMissing,
          );
          if (value != row.metadata) {
            row.metadata = value;
            objectbox.unifiedHistoryBox.put(row);
            kinds.add('history');
          }
        }
        for (final row in downloads.find()) {
          if (row.deleted) continue;
          final value = mergeComicPublicMetadata(
            row.metadata,
            byId[row.comicId]!,
            fieldsMissing: fieldsMissing,
          );
          if (value != row.metadata) {
            row.metadata = value;
            objectbox.unifiedDownloadBox.put(row);
            kinds.add('download');
          }
        }
      } finally {
        favorites.close();
        history.close();
        downloads.close();
      }
    });
    if (kinds.isNotEmpty)
      _changes.add(ComicPublicMetadataChange(source, kinds));
  }
}

String mergeComicPublicMetadata(
  String previous,
  List<Map<String, dynamic>> incoming, {
  Set<String> fieldsMissing = const {},
}) {
  final missing = fieldsMissing.map(_field).toSet();
  final known = <String, List<Map<String, dynamic>>>{};
  for (final row in incoming) {
    final field = _field(row['type']);
    if (!_publicFields.contains(field) ||
        missing.contains(field) ||
        row['value'] is! List)
      continue;
    final values = <Object>[];
    for (final raw in row['value'] as List) {
      final value = raw is Map ? raw['name'] : raw;
      if ((value is String || value is num) &&
          value.toString().trim().isNotEmpty)
        values.add(value.toString().trim());
    }
    known.putIfAbsent(field, () => []).add({
      'type': field,
      'name': row['name'] is String ? row['name'] : '',
      'value': values,
    });
  }
  if (known.isEmpty) return previous;
  List<dynamic> old;
  try {
    final raw = jsonDecode(previous);
    old = raw is List ? raw : [];
  } catch (_) {
    old = [];
  }
  return jsonEncode([
    for (final row in old)
      if (row is! Map || !known.containsKey(_field(row['type']))) row,
    ...known.values.expand((rows) => rows),
  ]);
}
