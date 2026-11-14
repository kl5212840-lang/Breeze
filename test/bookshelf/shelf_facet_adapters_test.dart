import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/object_box.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/bookshelf/service/shelf_facet_adapters.dart';
import 'package:zephyr/page/bookshelf/service/video_bookshelf_index.dart';
import 'package:zephyr/page/video/api_video_models.dart';

UnifiedComicFavorite _favorite(
  String source,
  String id, {
  String metadata = '',
  bool deleted = false,
}) => UnifiedComicFavorite(
  uniqueKey: '$source:$id',
  source: source,
  comicId: id,
  title: 'TITLE $id',
  description: 'Description',
  cover: '',
  creator: '{"name":"CREATOR"}',
  titleMeta: 'Seen',
  metadata: metadata,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  deleted: deleted,
  schemaVersion: 1,
);
ComicFolder _folder(String id, String name, {String? parent, int? deletedAt}) =>
    ComicFolder(
      syncId: id,
      parentSyncId: parent,
      uniqueKey: '${parent ?? ''}|$name|favorite',
      name: name,
      typeData: 'favorite',
      versionVectorJson: '{}',
      deletedAt: deletedAt,
      createdAt: 1,
      updatedAt: 1,
    );
ComicLink _link(
  String id,
  String comic, {
  String? folder,
  String type = 'favorite',
  int? deletedAt,
}) => ComicLink(
  uniqueKey: id,
  comicUniqueKey: comic,
  folderSyncId: folder,
  typeData: type,
  versionVectorJson: '{}',
  deletedAt: deletedAt,
  createdAt: 1,
  updatedAt: 1,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'favorite lookup cannot refile a work with only removed memberships',
    () {
      final index = comicShelfFacetIndexFromSnapshot(
        favorites: [
          _favorite('source', 'removed-link'),
          _favorite('source', 'removed-folder'),
          _favorite('source', 'legacy-unfiled'),
          _favorite('source', 'live-root'),
        ],
        folders: [_folder('gone', 'Gone', deletedAt: 2)],
        links: [
          _link('deleted', 'source:removed-link', deletedAt: 2),
          _link('orphan', 'source:removed-folder', folder: 'gone'),
          _link('root', 'source:live-root'),
        ],
      );
      expect(
        index.comics.keys,
        unorderedEquals(['source:legacy-unfiled', 'source:live-root']),
      );
    },
  );
  test(
    'third party video snapshots use explicit fields and retain unfiled identity',
    () {
      final item = ApiVideoItem(
        id: 'id',
        title: 'Title 2020 Japanese guessed',
        detailUrl: Uri.https('example.test', '/private/path'),
        genres: 'Action / Drama,Comedy',
        typeName: 'Series',
        year: '2024',
        area: 'Japan',
        language: 'Japanese',
        remarks: '2025 Korean',
      );
      final row = VideoBookshelfRow(
        key: 'stable',
        source: 'third-party',
        item: item,
        updatedAt: DateTime.utc(2026),
      );
      final entry = shelfFacetEntryFromVideo(row);
      expect(entry.fields, {
        'tags': {'Action', 'Drama', 'Comedy'},
        'category': {'Series'},
        'year': {'2024'},
        'area': {'Japan'},
        'language': {'Japanese'},
      });
      expect(entry.folders, {'__unfiled'});
      expect(entry.key, 'stable');
      expect(entry.source, 'third-party');
      expect(entry.searchText, isNot(contains('private/path')));
      expect(entry.fields.values.expand((v) => v), isNot(contains('2025')));
      final bare = shelfFacetEntryFromVideo(
        VideoBookshelfRow(
          key: 'bare',
          source: 'unregistered-source',
          item: ApiVideoItem(
            id: 'bare',
            title: '2024 动作',
            detailUrl: Uri.https('example.test', '/bare'),
            remarks: '日语',
          ),
          folderIds: const {'folder-id'},
          updatedAt: DateTime.utc(2026),
        ),
      );
      expect(bare.fields, isEmpty);
      expect(bare.folders, {'folder-id'});
    },
  );

  test(
    'shared metadata accepts only whitelisted types and scalar or name values',
    () {
      final fields = shelfFacetFieldsFromMetadata(
        jsonEncode([
          {
            'type': 'tags',
            'name': 'Tags',
            'value': [
              'A',
              1,
              {'name': 'B', 'url': 'secret'},
              {'id': 'not-a-label'},
              true,
              null,
            ],
          },
          {
            'type': 'category',
            'value': {'name': 'Category'},
          },
          {
            'type': 'year',
            'value': [2026],
          },
          {
            'type': 'author',
            'value': ['Author'],
          },
          {
            'type': 'area',
            'value': ['Area'],
          },
          {
            'type': 'language',
            'value': ['Language'],
          },
          {'type': 'cookie', 'value': 'secret'},
          {'type': 'url', 'value': 'https://secret'},
          {'type': 'private', 'value': 'secret'},
        ]),
      );
      expect(fields, {
        'tags': {'A', '1', 'B'},
        'category': {'Category'},
        'year': {'2026'},
        'author': {'Author'},
        'area': {'Area'},
        'language': {'Language'},
      });
      for (final broken in [
        '',
        '{bad',
        '{}',
        '[null,5,{"type":"tags","value":null}]',
      ]) {
        expect(shelfFacetFieldsFromMetadata(broken), isEmpty);
      }
    },
  );

  test('legacy and arbitrary-plugin category metadata share one facet', () {
    final index = comicShelfFacetIndexFromSnapshot(
      favorites: [
        _favorite(
          'unknown-marketplace-vendor',
          'same',
          metadata: jsonEncode([
            {
              'type': 'categories',
              'name': '分类',
              'value': [
                {
                  'name': 'Adventure',
                  'onTap': {'private': 'not indexed'},
                },
                {'name': 'Drama'},
              ],
            },
            {
              'type': 'category',
              'value': ['Adventure', 'Series'],
            },
            {
              'type': 'private',
              'value': ['Hidden'],
            },
          ]),
        ),
        _favorite(
          'other-vendor',
          'same',
          metadata: jsonEncode([
            {
              'type': 'categories',
              'value': [
                {'name': 'Comedy'},
              ],
            },
          ]),
        ),
      ],
      folders: [],
      links: [],
    );
    expect(
      index.entries
          .singleWhere((e) => e.source == 'unknown-marketplace-vendor')
          .fields,
      {
        'category': {'Adventure', 'Drama', 'Series'},
      },
    );
    final matching = index.entries.where(
      (entry) => shelfFacetMatches(
        entry,
        const ShelfFacetSelection(
          values: {
            'category': {'Drama'},
          },
        ),
        currentFolder: '',
      ),
    );
    expect(matching.map((e) => e.key), ['unknown-marketplace-vendor:same']);
    expect(
      shelfFacetOptions(
        index.entries,
        const ShelfFacetSelection(),
        currentFolder: '',
      )['category'],
      {'Adventure': 1, 'Drama': 1, 'Series': 1, 'Comedy': 1},
    );
  });

  group('isolated ObjectBox favorite index', () {
    late Directory directory;
    setUpAll(() async {
      directory = await Directory.systemTemp.createTemp('breeze_facets_');
      ObjectBox.resetForTests();
      objectbox = await ObjectBox.create(dbRootPath: directory.path);
    });
    tearDownAll(() async {
      objectbox.close();
      await directory.delete(recursive: true);
    });
    tearDown(() {
      objectbox.unifiedFavoriteBox.removeAll();
      objectbox.comicLinkBox.removeAll();
      objectbox.comicFolderBox.removeAll();
    });

    test(
      'source namespaces, duplicate links, paths and root fallback stay correct without writes',
      () {
        final metadata = jsonEncode([
          {
            'type': 'tags',
            'name': 'Tags',
            'value': [
              {'name': 'Adventure'},
            ],
          },
        ]);
        objectbox.unifiedFavoriteBox.putMany([
          _favorite('third-party', 'same', metadata: metadata),
          _favorite('other-source', 'same', metadata: '{bad'),
          _favorite('third-party', 'root'),
          _favorite('third-party', 'orphan'),
          _favorite('third-party', 'deleted', deleted: true),
        ]);
        objectbox.comicFolderBox.putMany([
          _folder('a', 'A'),
          _folder('b', 'B'),
          _folder('a-child', 'Same', parent: 'a'),
          _folder('b-child', 'Same', parent: 'b'),
          _folder('gone', 'Gone', deletedAt: 1),
          _folder('cycle', 'Cycle', parent: 'cycle'),
        ]);
        objectbox.comicLinkBox.putMany([
          _link('one', 'third-party:same', folder: 'a-child'),
          _link('duplicate', 'third-party:same', folder: 'a-child'),
          _link('two', 'third-party:same', folder: 'b-child'),
          _link('three', 'other-source:same', folder: 'a'),
          _link('deleted', 'third-party:root', folder: 'a', deletedAt: 1),
          _link('bad', 'third-party:orphan', folder: 'missing'),
          _link('cycle', 'third-party:orphan', folder: 'cycle'),
          _link('history', 'third-party:root', folder: 'a', type: 'history'),
        ]);
        final before = [
          objectbox.unifiedFavoriteBox.count(),
          objectbox.comicLinkBox.count(),
          objectbox.comicFolderBox.count(),
        ];
        final index = loadComicShelfFacetIndex(type: ComicFolderType.favorite);
        final entries = {for (final entry in index.entries) entry.key: entry};
        expect(entries.keys.toSet(), {
          'third-party:same',
          'other-source:same',
          'third-party:orphan',
        });
        expect(entries['third-party:same']!.folders, {'/A/Same', '/B/Same'});
        expect(entries['other-source:same']!.folders, {'/A'});
        expect(entries['third-party:root'], isNull);
        expect(entries['third-party:orphan']!.folders, {''});
        expect(index.folderLabels['/A/Same'], '/A/Same');
        expect(index.folderLabels.containsKey('/Gone'), isFalse);
        expect(index.folderLabels.keys, contains(''));
        expect(index.comics['third-party:same']!.id, 'same');
        expect(index.comics['third-party:same']!.source, 'third-party');
        expect(
          entries['third-party:same']!.searchText,
          contains('title same description creator seen adventure'),
        );
        expect(entries['other-source:same']!.fields, isEmpty);
        expect(
          index.entries
              .where(
                (e) => shelfFacetMatches(
                  e,
                  const ShelfFacetSelection(scope: ShelfFacetScope.descendants),
                  currentFolder: '/A',
                ),
              )
              .length,
          2,
        );
        expect([
          objectbox.unifiedFavoriteBox.count(),
          objectbox.comicLinkBox.count(),
          objectbox.comicFolderBox.count(),
        ], before);
        expect(
          loadComicShelfFacetIndex(type: ComicFolderType.history).entries,
          isEmpty,
        );
        expect(
          loadComicShelfFacetIndex(type: ComicFolderType.download).entries,
          isEmpty,
        );
      },
    );

    test(
      'explicit root and folder memberships coexist, trim source key and preserve stored link alias',
      () {
        objectbox.unifiedFavoriteBox.put(_favorite(' third-party ', 'id'));
        objectbox.comicFolderBox.put(_folder('folder', 'Folder'));
        objectbox.comicLinkBox.putMany([
          _link('root', ' third-party :id'),
          _link('folder', ' third-party :id', folder: 'folder'),
        ]);
        final index = loadComicShelfFacetIndex(type: ComicFolderType.favorite);
        final entry = index.entries.single;
        expect(entry.key, 'third-party:id');
        expect(entry.folders, {'', '/Folder'});
        expect(index.recordKeys[entry.key], {' third-party :id'});
        expect(index.storedMemberships[entry.key], {
          ' third-party :id': {'', '/Folder'},
        });
      },
    );
  });
}
