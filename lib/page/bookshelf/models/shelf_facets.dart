import 'package:freezed_annotation/freezed_annotation.dart';

part 'shelf_facets.freezed.dart';

const shelfFacetUnknown = '__breeze_unknown__';
const _shelfFacetValuePrefix = '__breeze_value__:';

/// Keep third-party values distinct from our missing-metadata marker, including
/// values that already begin with the escape prefix.
String shelfFacetEncodeValue(String value) =>
    value == shelfFacetUnknown || value.startsWith(_shelfFacetValuePrefix)
    ? '$_shelfFacetValuePrefix${Uri.encodeComponent(value)}'
    : value;

String shelfFacetDisplayValue(String value) {
  if (!value.startsWith(_shelfFacetValuePrefix)) return value;
  try {
    return Uri.decodeComponent(value.substring(_shelfFacetValuePrefix.length));
  } on FormatException {
    return value;
  }
}

const shelfFacetDimensions = [
  'tags',
  'category',
  'year',
  'area',
  'language',
  'author',
  'quality',
];

enum ShelfFacetScope { current, descendants, all }

@freezed
abstract class ShelfFacetEntry with _$ShelfFacetEntry {
  const factory ShelfFacetEntry({
    required String key,
    required String source,
    required String searchText,
    @Default({''}) Set<String> folders,
    @Default({}) Map<String, Set<String>> fields,
  }) = _ShelfFacetEntry;
}

@freezed
abstract class ShelfFacetSelection with _$ShelfFacetSelection {
  const ShelfFacetSelection._();
  const factory ShelfFacetSelection({
    @Default(ShelfFacetScope.current) ShelfFacetScope scope,
    @Default({}) Map<String, Set<String>> values,
    @Default(false) bool applied,
  }) = _ShelfFacetSelection;

  bool get isActive =>
      applied ||
      scope != ShelfFacetScope.current ||
      values.values.any((v) => v.isNotEmpty);
}

/// Folderless collections have no meaningful folder selection. Flat folder
/// collections still support current/all. At the root, descendants already
/// means all records.
ShelfFacetSelection shelfFacetSelectionForScope(
  ShelfFacetSelection selection, {
  required String? currentFolder,
  bool hierarchical = true,
}) => selection.copyWith(
  scope: switch ((currentFolder, selection.scope)) {
    (null, _) => ShelfFacetScope.current,
    ('', ShelfFacetScope.descendants) => ShelfFacetScope.all,
    (_, ShelfFacetScope.descendants) when !hierarchical =>
      ShelfFacetScope.current,
    (_, final scope) => scope,
  },
  values: {
    for (final entry in selection.values.entries) entry.key: {...entry.value},
  },
);

Set<String> _values(ShelfFacetEntry entry, String dimension) =>
    (entry.fields[dimension] ?? const <String>{})
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .map(shelfFacetEncodeValue)
        .toSet();

bool _inScope(ShelfFacetEntry entry, ShelfFacetScope scope, String? folder) {
  if (folder == null || scope == ShelfFacetScope.all) return true;
  if (scope == ShelfFacetScope.current) return entry.folders.contains(folder);
  return entry.folders.any(
    (path) => folder.isEmpty || path == folder || path.startsWith('$folder/'),
  );
}

bool shelfFacetMatches(
  ShelfFacetEntry entry,
  ShelfFacetSelection selection, {
  required String? currentFolder,
}) {
  if (!_inScope(entry, selection.scope, currentFolder)) return false;
  for (final dimension in shelfFacetDimensions) {
    final selected = selection.values[dimension] ?? const <String>{};
    if (selected.isEmpty) continue;
    final actual = _values(entry, dimension);
    if (actual.isEmpty
        ? !selected.contains(shelfFacetUnknown)
        : !actual.any(selected.contains)) {
      return false;
    }
  }
  return true;
}

/// Each count applies all other selected groups, so choices within one group are OR.
/// Candidate values and dimensions come only from the current snapshot/scope.
Map<String, Map<String, int>> shelfFacetOptions(
  List<ShelfFacetEntry> entries,
  ShelfFacetSelection selection, {
  required String? currentFolder,
}) {
  final scoped = entries
      .where((e) => _inScope(e, selection.scope, currentFolder))
      .toList();
  final result = <String, Map<String, int>>{};
  for (final dimension in shelfFacetDimensions) {
    final known = scoped.expand((e) => _values(e, dimension)).toSet();
    if (known.isEmpty) continue;
    if (scoped.any((e) => _values(e, dimension).isEmpty)) {
      known.add(shelfFacetUnknown);
    }
    final rest = selection.copyWith(
      values: Map<String, Set<String>>.from(selection.values)
        ..remove(dimension),
    );
    final matching = scoped.where(
      (e) => shelfFacetMatches(e, rest, currentFolder: currentFolder),
    );
    final counts = {for (final value in known) value: 0};
    for (final entry in matching) {
      final values = _values(entry, dimension);
      for (final value in values.isEmpty ? {shelfFacetUnknown} : values) {
        counts[value] = (counts[value] ?? 0) + 1;
      }
    }
    result[dimension] = counts;
  }
  return result;
}
