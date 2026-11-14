import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';

ShelfFacetEntry entry(
  String key, {
  Set<String> folders = const {''},
  Map<String, Set<String>> fields = const {},
}) => ShelfFacetEntry(
  key: key,
  source: 'fixture',
  searchText: key,
  folders: folders,
  fields: fields,
);

void main() {
  test(
    'reserved third-party metadata remains distinct from missing values',
    () {
      const reserved = shelfFacetUnknown;
      const prefix = '__breeze_value__:%FF';
      final rows = [
        entry('missing'),
        entry(
          'reserved',
          fields: {
            'tags': {reserved},
          },
        ),
        entry(
          'prefix',
          fields: {
            'tags': {prefix},
          },
        ),
      ];
      final real = shelfFacetEncodeValue(reserved);
      final escaped = shelfFacetEncodeValue(prefix);
      expect(real, isNot(shelfFacetUnknown));
      expect(shelfFacetDisplayValue(real), reserved);
      expect(shelfFacetDisplayValue(escaped), prefix);
      expect(shelfFacetDisplayValue(prefix), prefix);
      expect(
        shelfFacetOptions(
          rows,
          const ShelfFacetSelection(),
          currentFolder: '',
        )['tags'],
        {shelfFacetUnknown: 1, real: 1, escaped: 1},
      );
      for (final (value, expected) in [
        (shelfFacetUnknown, 'missing'),
        (real, 'reserved'),
        (escaped, 'prefix'),
      ]) {
        final selection = ShelfFacetSelection(
          values: {
            'tags': {value},
          },
        );
        expect(
          rows
              .where(
                (row) => shelfFacetMatches(row, selection, currentFolder: ''),
              )
              .map((row) => row.key),
          [expected],
        );
      }
    },
  );
  test(
    'folder scope observes path boundaries and video root includes all folders',
    () {
      final a = entry('a', folders: {'fiction'});
      final child = entry('child', folders: {'fiction/short'});
      final sibling = entry('sibling', folders: {'fictional'});
      const current = ShelfFacetSelection();
      const descendants = ShelfFacetSelection(
        scope: ShelfFacetScope.descendants,
      );
      expect(shelfFacetMatches(a, current, currentFolder: 'fiction'), isTrue);
      expect(
        shelfFacetMatches(child, current, currentFolder: 'fiction'),
        isFalse,
      );
      expect(
        shelfFacetMatches(child, descendants, currentFolder: 'fiction'),
        isTrue,
      );
      expect(
        shelfFacetMatches(sibling, descendants, currentFolder: 'fiction'),
        isFalse,
      );
      expect(shelfFacetMatches(child, current, currentFolder: null), isTrue);
      expect(shelfFacetMatches(child, current, currentFolder: ''), isFalse);
      expect(shelfFacetMatches(child, descendants, currentFolder: ''), isTrue);
      expect(
        shelfFacetMatches(
          entry('unfiled', folders: {'__unfiled'}),
          current,
          currentFolder: '__unfiled',
        ),
        isTrue,
      );
    },
  );

  test(
    'canonical comic paths keep root current and nested current distinct',
    () {
      final root = entry('root');
      final parent = entry('parent', folders: {'/父'});
      final child = entry('child', folders: {'/父/子'});
      const current = ShelfFacetSelection();
      const descendants = ShelfFacetSelection(
        scope: ShelfFacetScope.descendants,
      );
      expect(shelfFacetMatches(root, current, currentFolder: ''), isTrue);
      expect(shelfFacetMatches(child, current, currentFolder: ''), isFalse);
      expect(
        shelfFacetMatches(parent, current, currentFolder: '/父/子'),
        isFalse,
      );
      expect(shelfFacetMatches(child, current, currentFolder: '/父/子'), isTrue);
      expect(
        shelfFacetMatches(child, descendants, currentFolder: '/父'),
        isTrue,
      );
      expect(
        shelfFacetMatches(child, descendants, currentFolder: '/父/子2'),
        isFalse,
      );
    },
  );

  test('selections are OR within a dimension and AND across dimensions', () {
    final a = entry(
      'a',
      fields: {
        'tags': {'adventure', 'comedy'},
        'year': {'2026'},
      },
    );
    const or = ShelfFacetSelection(
      values: {
        'tags': {'drama', 'comedy'},
      },
    );
    expect(shelfFacetMatches(a, or, currentFolder: ''), isTrue);
    expect(
      shelfFacetMatches(
        a,
        or.copyWith(
          values: {
            ...or.values,
            'year': {'2025'},
          },
        ),
        currentFolder: '',
      ),
      isFalse,
    );
    expect(
      shelfFacetMatches(
        a,
        or.copyWith(scope: ShelfFacetScope.all),
        currentFolder: 'other',
      ),
      isTrue,
    );
    expect(const ShelfFacetSelection().isActive, isFalse);
    expect(const ShelfFacetSelection(applied: true).isActive, isTrue);
    expect(const ShelfFacetSelection(values: {'tags': {}}).isActive, isFalse);
    expect(or.isActive, isTrue);
    expect(
      const ShelfFacetSelection(scope: ShelfFacetScope.all).isActive,
      isTrue,
    );
  });

  test(
    'linked counts omit own group, count an entry once, and expose only real metadata',
    () {
      final entries = [
        entry(
          'a',
          fields: {
            'tags': {'A', 'B'},
            'author': {'X'},
          },
        ),
        entry(
          'b',
          fields: {
            'tags': {'B'},
            'author': {'Y'},
          },
        ),
        entry(
          'c',
          fields: {
            'author': {'X'},
          },
        ),
        entry(
          'd',
          folders: {'elsewhere'},
          fields: {
            'language': {'English'},
          },
        ),
      ];
      const selected = ShelfFacetSelection(
        values: {
          'tags': {'A'},
          'author': {'X'},
        },
      );
      final options = shelfFacetOptions(entries, selected, currentFolder: '');
      expect(options.keys, ['tags', 'author']);
      expect(options['tags'], {'A': 1, 'B': 1, shelfFacetUnknown: 1});
      expect(options['author'], {'X': 1, 'Y': 0});
      expect(
        shelfFacetOptions(
          [entry('empty')],
          const ShelfFacetSelection(),
          currentFolder: '',
        ),
        isEmpty,
      );
      expect(
        shelfFacetMatches(
          entries[2],
          const ShelfFacetSelection(
            values: {
              'tags': {shelfFacetUnknown},
            },
          ),
          currentFolder: '',
        ),
        isTrue,
      );
      expect(
        shelfFacetMatches(
          entries[0],
          const ShelfFacetSelection(
            values: {
              'tags': {shelfFacetUnknown},
            },
          ),
          currentFolder: '',
        ),
        isFalse,
      );
    },
  );

  test('snapshot collections and draft copies remain independent', () {
    const original = ShelfFacetSelection(
      values: {
        'tags': {'A'},
      },
    );
    final changed = original.copyWith(
      values: {
        'tags': {'B'},
      },
    );
    expect(original.values['tags'], {'A'});
    expect(changed.values['tags'], {'B'});
    expect(() => original.values['other'] = {'bad'}, throwsUnsupportedError);
  });

  test(
    'folderless and flat sheets cannot return an invisible folder scope',
    () {
      const selected = ShelfFacetSelection(
        scope: ShelfFacetScope.all,
        values: {
          'tags': {'A'},
        },
      );
      final folderless = shelfFacetSelectionForScope(
        selected,
        currentFolder: null,
        hierarchical: false,
      );
      expect(folderless.scope, ShelfFacetScope.current);
      expect(folderless.values, selected.values);
      expect(
        shelfFacetSelectionForScope(selected, currentFolder: '/A').scope,
        ShelfFacetScope.all,
      );
      expect(
        shelfFacetSelectionForScope(
          selected.copyWith(scope: ShelfFacetScope.descendants),
          currentFolder: '/A',
          hierarchical: false,
        ).scope,
        ShelfFacetScope.current,
      );
      expect(
        shelfFacetSelectionForScope(
          const ShelfFacetSelection(scope: ShelfFacetScope.all),
          currentFolder: null,
        ).isActive,
        isFalse,
      );
    },
  );
}
