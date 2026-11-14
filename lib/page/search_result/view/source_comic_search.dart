import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/util/text/public_search_text.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

enum SourceComicSearchScope { all, title, tags, author }

String sourceComicSearchText(
  UnifiedComicListItem entry,
  SourceComicSearchScope scope,
) {
  final values = switch (scope) {
    SourceComicSearchScope.title => [entry.title],
    SourceComicSearchScope.tags => [
      for (final m in entry.metadata)
        if (m.type == 'tags' || m.type == 'tag') ...m.value,
    ],
    SourceComicSearchScope.author => [
      for (final m in entry.metadata)
        if (m.type == 'author') ...m.value,
    ],
    SourceComicSearchScope.all => [
      entry.title,
      entry.subtitle,
      if (entry.raw['description'] case final String description) description,
      for (final m in entry.metadata) ...m.value,
    ],
  };
  return normalizePublicSearchText(values.join(' '));
}

String _field(String type) => switch (type.trim().toLowerCase()) {
  'tag' => 'tags',
  'categories' => 'category',
  final value => value,
};

/// Fill absent public dimensions only. An explicitly supplied empty dimension
/// remains authoritative; names/IDs from another source are never candidates.
List<UnifiedComicListItem> mergeKnownSourceComicMetadata(
  List<UnifiedComicListItem> entries,
  Iterable<UnifiedComicListItem> known,
) {
  final byIdentity = <(String, String), List<UnifiedComicListItem>>{};
  for (final row in known) {
    byIdentity.putIfAbsent((row.source, row.id), () => []).add(row);
  }
  for (final candidates in byIdentity.values) {
    candidates.sort(
      (a, b) =>
          (DateTime.tryParse(b.updatedAt) ??
                  DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(
                DateTime.tryParse(a.updatedAt) ??
                    DateTime.fromMillisecondsSinceEpoch(0),
              ),
    );
  }
  return entries.map((entry) {
    final metadata = [...entry.metadata];
    final present = metadata.map((m) => _field(m.type)).toSet();
    final rawMetadata = entry.raw['metadata'];
    if (rawMetadata is List) {
      for (final m in rawMetadata.whereType<Map>()) {
        if (m['type'] is String && m['value'] is List)
          present.add(_field(m['type'] as String));
      }
    }
    for (final candidate
        in byIdentity[(entry.source, entry.id)] ??
            const <UnifiedComicListItem>[]) {
      final fields = <String, List<UnifiedComicMetadata>>{};
      for (final m in candidate.metadata) {
        final field = _field(m.type);
        if (const {
          'tags',
          'author',
          'category',
          'works',
          'actors',
          'year',
          'area',
          'language',
        }.contains(field)) {
          fields.putIfAbsent(field, () => []).add(m);
        }
      }
      final raw = candidate.raw['metadata'];
      if (raw is List) {
        for (final m in raw.whereType<Map>()) {
          if (m['type'] is String &&
              m['value'] is List &&
              (m['value'] as List).isEmpty) {
            final field = _field(m['type'] as String);
            if (const {'tags', 'author', 'category'}.contains(field))
              fields.putIfAbsent(field, () => []);
          }
        }
      }
      for (final group in fields.entries) {
        if (present.add(group.key)) {
          metadata.addAll(
            group.value.isEmpty
                ? [
                    UnifiedComicMetadata(
                      type: group.key,
                      name: '',
                      value: const [],
                    ),
                  ]
                : group.value,
          );
        }
      }
    }
    if (metadata.length == entry.metadata.length) return entry;
    return entry.copyWith(
      metadata: metadata,
      raw: {
        ...entry.raw,
        'metadata': [
          if (rawMetadata is List)
            ...rawMetadata.whereType<Map>().where(
              (m) => m['value'] is List && (m['value'] as List).isEmpty,
            ),
          ...metadata.map((m) => m.toJson()),
        ],
      },
    );
  }).toList();
}

/// The current source's existing local records are the only enrichment source.
/// No detail request, account session or other plugin is opened here.
List<UnifiedComicListItem> enrichSourceComicMetadata(
  List<UnifiedComicListItem> entries,
) {
  if (entries.isEmpty) return entries;
  final known = <UnifiedComicListItem>[];
  for (final source in entries.map((e) => e.source).toSet()) {
    final ids = entries
        .where((e) => e.source == source)
        .map((e) => e.id)
        .toSet()
        .toList();
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
      known.addAll(favorites.find().map(unifiedComicFromUnifiedFavorite));
      known.addAll(history.find().map(unifiedComicFromUnifiedHistory));
      known.addAll(downloads.find().map(unifiedComicFromUnifiedDownload));
    } finally {
      favorites.close();
      history.close();
      downloads.close();
    }
  }
  return mergeKnownSourceComicMetadata(entries, known);
}
