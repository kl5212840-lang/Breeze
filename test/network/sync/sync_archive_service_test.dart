import 'package:zephyr/network/sync/plugin_config_merge.dart';
import 'sync_installed_fixture.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/navigation_bar.dart'
    show automaticSyncStartNotification;
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/appearance_image_sync.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/network/sync/sync_archive_context.dart';
import 'package:zephyr/network/sync/sync_archive_service.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/network/sync/sync_failure.dart';
import 'package:zephyr/network/sync/video_library_sync.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';
import 'package:zephyr/page/video/video_account_credentials.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/service/reader/comic_chapter_reading_progress.dart';

import '../../test_helper.dart';

Future<List<int>> _identity(List<int> bytes) async => bytes;
const _codecs = SyncArchiveCodecs(
  comic: ComicSyncCodec(encode: _identity, decode: _identity),
  settings: SettingsSyncCodec(encode: _identity, decode: _identity),
  video: VideoLibrarySyncCodec(encode: _identity, decode: _identity),
);
const _identityKey = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
String _digest(Object? data) =>
    sha256.convert(utf8.encode(jsonEncode(data))).toString();

class _RejectSettingsMetadataOnce extends InMemorySharedPreferencesStore {
  _RejectSettingsMetadataOnce(super.data) : super.withData();

  bool rejected = false;

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (!rejected && key == 'flutter.sync.settings.block.meta.v3') {
      rejected = true;
      return false;
    }
    return super.setValue(type, key, value);
  }
}

class _HeldSettingsMetadata extends InMemorySharedPreferencesStore {
  _HeldSettingsMetadata(super.data) : super.withData();

  final started = Completer<void>();
  final result = Completer<bool>();

  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (!started.isCompleted && key == 'flutter.sync.settings.block.meta.v3') {
      started.complete();
      if (!await result.future) return false;
    }
    return super.setValue(type, key, value);
  }
}

/// Both versions share one fake server. Raw listing deliberately exposes both
/// directories, so these public tests exercise the production archive boundary.
class _Server {
  final files = <String, List<int>>{};
  final mutations = <String>[];
  bool Function(String path)? failWrite;
  void Function(String path)? beforeWrite;
  void Function(String path)? beforeRead;

  final contexts = <SyncArchiveContext>[];
  SyncArchiveAdapters adapters() => SyncArchiveAdapters.forTransports((scope) {
    contexts.add(scope);
    return _Transport(this, scope);
  }, identity: _identityKey);

  String path(bool legacy, String name) =>
      '${legacy ? SyncArchiveContext.legacyRoot : SyncArchiveContext.currentRoot}/$name';
  void payload(
    bool legacy,
    String kind,
    Map<String, dynamic> data, {
    int stamp = 1,
  }) {
    final bytes = utf8.encode(jsonEncode(data));
    files[path(legacy, '${kind}_$stamp.bin')] = bytes;
    files[path(legacy, '$kind.md5')] = utf8.encode(
      ComicSyncCore.calculateMd5(bytes),
    );
  }

  Map<String, dynamic> active(bool legacy, String kind) {
    final md5 = utf8.decode(files[path(legacy, '$kind.md5')]!);
    final bytes = files.entries
        .singleWhere(
          (entry) =>
              entry.key.startsWith(path(legacy, '${kind}_')) &&
              ComicSyncCore.calculateMd5(entry.value) == md5,
        )
        .value;
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
  }

  void video(
    bool legacy,
    VideoLibrarySnapshot snapshot, {
    PortablePreferencesSnapshot? preferences,
  }) {
    final raw = snapshot.toJson();
    final portable = preferences?.toJson();
    files[path(
      legacy,
      'video_library_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.bin',
    )] = utf8.encode(
      jsonEncode({
        'format': 'BreezeVideoLibrary',
        'version': 1,
        'snapshot': raw,
        'sha256': _digest(raw),
        if (portable != null) ...{
          'portable': portable,
          'portableSha256': _digest(portable),
        },
      }),
    );
  }

  Map<String, String> saved({bool? legacy}) => {
    for (final file in files.entries)
      if (legacy == null || file.key.startsWith(path(legacy, '')))
        file.key: base64Encode(file.value),
  };
}

class _Transport implements ComicSyncRemoteAdapter {
  _Transport(this.server, this.scope);
  final _Server server;
  final SyncArchiveContext scope;
  String path(String name) => name.contains('/') ? name : '${scope.root}/$name';
  @override
  Future<void> testConnection() async {}
  @override
  Future<void> ensureRemoteReady() async {}
  @override
  Future<List<String>> listRemoteDataFiles() async =>
      server.files.keys.toList();
  @override
  Future<List<int>> downloadRemoteFile(String name) async {
    server.beforeRead?.call(path(name));
    return List.of(server.files[path(name)] ?? (throw StateError('404')));
  }

  @override
  Future<String> downloadRemoteMd5() async =>
      utf8.decode(server.files[path('comic.md5')] ?? []);
  @override
  Future<void> uploadRemoteMd5(String md5) =>
      uploadRemoteFile('comic.md5', utf8.encode(md5));
  @override
  Future<void> uploadRemoteFile(
    String name,
    List<int> bytes, {
    String contentType = 'application/octet-stream',
  }) async {
    if (scope.readOnly) throw const LegacyArchiveReadOnly();
    final target = path(name);
    server.beforeWrite?.call(target);
    if (server.failWrite?.call(target) == true)
      throw StateError('synthetic unavailable');
    server.mutations.add('put:$target');
    server.files[target] = List.of(bytes);
  }

  @override
  Future<void> deleteRemoteFiles(List<String> names) async {
    if (scope.readOnly) throw const LegacyArchiveReadOnly();
    for (final name in names) {
      server.mutations.add('delete:${path(name)}');
      server.files.remove(path(name));
    }
  }
}

Map<String, dynamic> _comic(
  String key, {
  bool deleted = false,
  int year = 2020,
}) => {
  'version': 'v1',
  'favorites': [
    (createTestFavorite(
      key,
      deleted: deleted,
      updatedAt: DateTime.utc(year),
    )..metadata = '[{"futurePluginField":"opaque"}]').toJson()..remove('id'),
  ],
};
GlobalSettingState _state({
  bool compatibility = false,
  bool settings = false,
  bool plugins = false,
}) => GlobalSettingState(
  syncSetting: SyncSettingState(
    legacyCompatibilityEnabled: compatibility,
    syncSettings: settings,
    syncPlugins: plugins,
  ),
);
void _saveState(GlobalSettingState state) {
  final user = objectbox.userSettingBox.get(1)!;
  user.globalSetting = state;
  objectbox.userSettingBox.put(user);
}

const _reviewAppearanceKeys = {'locale', 'localeFollowsSystem', 'eInkSetting'};
Map<String, dynamic> _reviewPortableValues(GlobalSettingState state) {
  final json = state.toJson();
  return {
    for (final key in [
      ..._reviewAppearanceKeys,
      'oldPageRollbackEnabled',
      'autoFollowOnCollect',
      'videoDownloadConcurrency',
      'downloadWifiOnly',
      'downloadCompletionNotice',
      'clickCoverToStartReading',
      'bookshelfSetting',
      'backPressExitEnabled',
      'cloudFavoritePreferred',
      'leftHandModeEnabled',
      'chineseConvertMode',
    ])
      key: json[key],
    'eInkSetting': Map<String, dynamic>.from(json['eInkSetting'] as Map)
      ..remove('detectionHandled'),
  };
}

GlobalSettingState _reviewLocalState(GlobalSettingState state) =>
    state.copyWith(
      locale: const Locale('en', 'US'),
      localeFollowsSystem: false,
      oldPageRollbackEnabled: false,
      autoFollowOnCollect: true,
      videoDownloadConcurrency: 3,
      downloadWifiOnly: true,
      downloadCompletionNotice: 'episode',
      clickCoverToStartReading: true,
      bookshelfSetting: const BookshelfSettingState(
        homePageIndex: 1,
        rememberFavoriteSort: true,
        favoriteSort: 'da',
      ),
      backPressExitEnabled: true,
      cloudFavoritePreferred: true,
      leftHandModeEnabled: true,
      chineseConvertMode: ChineseConvertMode.traditional,
      eInkSetting: const EInkSettingState(
        enabled: true,
        detectionHandled: true,
      ),
    );

// Matches the shipped serializer in 0242d5f7 and the schema-v2 writers used
// by collect_comic/reader_history_service and migration_v1_to_v2. All values
// are synthetic; private JSON is deliberately opaque to the archive layer.
Map<String, dynamic> _shippedComic({bool oldReadMode = false}) => {
  'version': 'v1',
  'favorites': [
    (createTestFavorite('shipped:favorite', updatedAt: DateTime.utc(2024))
          ..schemaVersion = 2
          ..metadata = '[{"type":"plugin-field","value":{"opaque":[1,2]}}]')
        .toJson()
      ..remove('id'),
  ],
  'histories': [
    (createTestHistory(
      'shipped:history',
      updatedAt: DateTime.utc(2024),
    )..schemaVersion = 2).toJson()..remove('id'),
  ],
  'follows': [],
  'folders': [],
  'links': [],
  'readPreferences': oldReadMode
      ? [
          {
            'uniqueKey': 'shipped:history',
            'source': 'test',
            'comicId': 'shipped:history',
            'readMode': 2,
            'updatedAt': DateTime.utc(2024).toIso8601String(),
            'deleted': false,
          },
        ]
      : [],
};

Map<String, dynamic> _shippedSettings() {
  final global =
      jsonDecode(
            jsonEncode(
              const GlobalSettingState(
                dynamicColor: false,
                syncSetting: SyncSettingState(
                  webdavSetting: WebDavSettingState(
                    host: 'https://synthetic.invalid',
                    password: 'SYNTHETIC_OLD_TRANSPORT',
                  ),
                ),
              ).toJson(),
            ),
          )
          as Map<String, dynamic>;
  (global['syncSetting'] as Map).remove('legacyCompatibilityEnabled');
  for (final key in ['customExportPath', 'appLockSetting', 'cacheSetting']) {
    global.remove(key);
  }
  final plugins = {
    'pluginConfigs': [
      {
        'name': 'shipped-plugin',
        'config':
            '{"account.fixture":{"opaque":"synthetic"},"future-private":{"x":[1,2]}}',
      },
    ],
    'pluginInfos': <dynamic>[],
  };
  final time = DateTime.utc(2035).millisecondsSinceEpoch;
  return {
    'version': 'v1',
    'schemaVersion': 'v2',
    'syncTime': time,
    'globalSetting': global,
    ...plugins,
    'blocks': {
      'appearance': {
        'updatedAt': time,
        'data': {
          for (final key in [
            'dynamicColor',
            'themeMode',
            'isAMOLED',
            'seedColor',
            'locale',
            'welcomePageNum',
          ])
            key: global[key],
        },
      },
      'library': {
        'updatedAt': time,
        'data': {
          for (final key in [
            'maskedKeywords',
            'comicChoice',
            'disableBika',
            'updateAccelerate',
            'retryDownloadUntilSuccess',
            'searchHistory',
          ])
            key: global[key],
        },
      },
      'reader': {'updatedAt': time, 'data': global['readSetting']},
      'video': {
        'updatedAt': time,
        'data': {'version': 1, 'values': VideoPlaybackPreferences.defaults},
      },
      'plugins': {'updatedAt': time, 'data': plugins},
    },
  };
}

// These compatibility fixtures exercise the retained merge algorithm. Public
// automatic/manual entrypoint policy is covered separately below.
Future<SyncRunResult> _mergeSync(
  GlobalSettingState state, {
  SyncArchiveAdapters? archives,
  SyncArchiveCodecs codecs = const SyncArchiveCodecs(),
  SyncArchiveHooks? hooks,
}) => runExclusiveStorageOperation(
  () => runArchiveSync(
    state: state,
    direction: SyncDirection.merge,
    archives: archives,
    codecs: codecs,
    hooks: hooks,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late SyncArchiveHooks hooks;
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TestObjectBoxHelper.cleanComicFolderBoxes();
    objectbox.comicFollowBox.removeAll();
    objectbox.comicReadPreferenceBox.removeAll();
    objectbox.pluginConfigBox.removeAll();
    objectbox.pluginInfoBox.removeAll();
    await installSyncPlugins([
      'test',
      'fixture',
      'shipped-plugin',
      'local-plugin',
    ]);
    _saveState(_state());
    temporary = await Directory.systemTemp.createTemp(
      'breeze_archive_fixture_',
    );
    hooks = SyncArchiveHooks(recoveryDirectory: temporary);
  });
  tearDown(() async {
    await temporary.delete(recursive: true);
  });

  test(
    'records-only sync transfers chapter history without admitting an uninstalled source',
    () async {
      final server = _Server();
      final path = server.path(
        false,
        'chapter_progress_v1_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.bin',
      );
      server.files[path] = ChapterProgressArchive({
        ('fixture', 'chapter-work', 'one'): (
          at: 10,
          progress: (pageIndex: 5, pageCount: 5, completed: true),
        ),
        ('fixture', 'chapter-work', 'two'): (
          at: 11,
          progress: (pageIndex: 2, pageCount: 5, completed: false),
        ),
        ('not-installed', 'chapter-work', 'two'): (
          at: 11,
          progress: (pageIndex: 3, pageCount: 5, completed: false),
        ),
      }).encode();
      await autoSync(
        _state(),
        archives: server.adapters(),
        hooks: hooks,
        codecs: _codecs,
      );
      final store = ComicChapterReadingProgress.instance;
      expect(
        store.lookup('fixture', 'chapter-work', ['one'])?.completed,
        isTrue,
      );
      expect(store.lookup('fixture', 'chapter-work', ['two'])?.pageIndex, 2);
      expect(store.lookup('not-installed', 'chapter-work', ['two']), isNull);
      expect(server.files[path], isNotNull);
      expect(
        server.files.keys.where(
          (path) => path.contains('chapter_progress_v1_'),
        ),
        hasLength(2),
      );
    },
  );

  test(
    'restore from an unused cloud archive reports no backup without writing',
    () async {
      final server = _Server();
      final state = _state();
      _saveState(state);
      objectbox.unifiedFavoriteBox.put(createTestFavorite('local-only'));
      await expectLater(
        runArchiveSync(
          state: state,
          direction: SyncDirection.restore,
          archives: server.adapters(),
          codecs: _codecs,
        ),
        throwsA(isA<NoCloudBackup>()),
      );
      expect(server.mutations, isEmpty);
      expect(objectbox.unifiedFavoriteBox.getAll(), hasLength(1));
    },
  );

  test(
    'current settings restore rolls back playback when metadata fails',
    () async {
      final state = _state(settings: true).copyWith(dynamicColor: true);
      _saveState(state);
      await VideoPlaybackPreferences.save('defaultSpeed', 1.25);
      final previous = SharedPreferencesStorePlatform.instance;
      final backend = _RejectSettingsMetadataOnce(await previous.getAll());
      SharedPreferencesStorePlatform.instance = backend;
      addTearDown(() => SharedPreferencesStorePlatform.instance = previous);
      final payload = _shippedSettings();
      final video = (payload['blocks'] as Map)['video'] as Map;
      (video['data'] as Map)['values'] = {
        ...VideoPlaybackPreferences.defaults,
        'defaultSpeed': 1.5,
      };
      final server = _Server()..payload(false, 'settings', payload);

      await expectLater(
        downloadSettingsData(
          server.adapters().current,
          state: state,
          codec: _codecs.settings,
        ),
        throwsA(isA<StateError>()),
      );
      expect(backend.rejected, isTrue);
      expect(objectbox.userSettingBox.get(1)!.globalSetting, state);
      expect((await VideoPlaybackPreferences.read()).defaultSpeed, 1.25);
      expect(server.mutations, isEmpty);
    },
  );

  for (final (field, value, commit) in [
    ('cover', true, false),
    ('defaultSpeed', 1.5, false),
    ('cover', true, true),
  ]) {
    test(
      'playback edit waits for local settings restore: $field commit=$commit',
      () async {
        final state = _state(settings: true).copyWith(dynamicColor: true);
        _saveState(state);
        await VideoPlaybackPreferences.save('defaultSpeed', 1.25);
        final previous = SharedPreferencesStorePlatform.instance;
        final backend = _HeldSettingsMetadata(await previous.getAll());
        SharedPreferencesStorePlatform.instance = backend;
        addTearDown(() => SharedPreferencesStorePlatform.instance = previous);
        final payload = _shippedSettings();
        final video = (payload['blocks'] as Map)['video'] as Map;
        (video['data'] as Map)['values'] = {
          ...VideoPlaybackPreferences.defaults,
          'defaultSpeed': 1.5,
          'controlsStyle': 'breeze',
        };
        final server = _Server()..payload(false, 'settings', payload);
        final restore = downloadSettingsData(
          server.adapters().current,
          state: state,
          codec: _codecs.settings,
        );
        final outcome = commit
            ? restore
            : expectLater(restore, throwsA(isA<StateError>()));
        await backend.started.future;
        var saveSettled = false;
        final save = VideoPlaybackPreferences.save(field, value).then((_) {
          saveSettled = true;
        });
        late bool settledDuringRestore;
        late String visibleStyleDuringRestore;
        try {
          // A single event turn drains the in-memory preference write if
          // it is not waiting for the still-blocked restore.
          await Future<void>.delayed(Duration.zero);
          settledDuringRestore = saveSettled;
          visibleStyleDuringRestore =
              VideoPlaybackPreferences.interfaceStyle.value;
        } finally {
          backend.result.complete(commit);
        }
        await outcome;
        await save;
        final playback = await VideoPlaybackPreferences.read();
        expect(
          playback.defaultSpeed,
          commit || field == 'defaultSpeed' ? 1.5 : 1.25,
        );
        expect(playback.cover, field == 'cover');
        expect(settledDuringRestore, isFalse);
        expect(visibleStyleDuringRestore, 'system');
        expect(playback.controlsStyle, commit ? 'breeze' : 'system');
        expect(
          objectbox.userSettingBox.get(1)!.globalSetting.dynamicColor,
          !commit,
        );
        expect(server.mutations, isEmpty);
      },
    );
  }

  for (final notification in ['enabled', 'disabled', 'inactive', 'future']) {
    test(
      'automatic start notice follows preflight exactly once: $notification',
      () async {
        final notices = <ToastEvent>[];
        final subscription = eventBus.on<ToastEvent>().listen(notices.add);
        addTearDown(subscription.cancel);
        final server = _Server();
        if (notification == 'future') {
          final future = _shippedSettings()..['schemaVersion'] = 'future';
          server.payload(false, 'settings', future);
        }
        final operation = autoSync(
          _state(),
          archives: server.adapters(),
          codecs: _codecs,
          hooks: SyncArchiveHooks(
            recoveryDirectory: hooks.recoveryDirectory,
            appearanceImages: hooks.appearanceImages,
            onStarted: automaticSyncStartNotification(
              canNotify: () =>
                  notification != 'disabled' && notification != 'inactive',
            ),
          ),
        );
        if (notification == 'future') {
          await expectLater(
            operation,
            throwsA(isA<SyncCompatibilityException>()),
          );
          expect(server.mutations, isEmpty);
        } else {
          await operation;
        }
        await Future<void>.delayed(Duration.zero);
        final starts = notices.where(
          (event) =>
              event.type == ToastType.info &&
              event.message == t.settings.syncWorking,
        );
        expect(starts, hasLength(notification == 'enabled' ? 1 : 0));
      },
    );
  }

  test(
    'unreadable committed comic snapshot is never treated as empty',
    () async {
      final state = _state();
      final server = _Server()
        ..payload(
          false,
          'comic',
          _comic('test:removed', deleted: true, year: 2021),
        );
      objectbox.unifiedFavoriteBox.putMany([
        createTestFavorite('test:removed', updatedAt: DateTime.utc(2020)),
        createTestFavorite('test:local-only', updatedAt: DateTime.utc(2020)),
      ]);
      final before = server.saved();
      final active = server.path(false, 'comic_1.bin');
      var reads = 0;
      server.beforeRead = (path) {
        // Both preflights read successfully. The active snapshot then becomes
        // temporarily unreadable at the final record-channel selection.
        if (path == active && ++reads >= 3) {
          throw const SocketException('fixture transient failure');
        }
      };

      Future<SyncRunResult> sync() => autoSync(
        state,
        archives: server.adapters(),
        codecs: _codecs,
        hooks: hooks,
      );

      await expectLater(sync(), throwsA(isA<SyncCompatibilityException>()));
      expect(reads, 3);
      expect(server.mutations, isEmpty);
      expect(server.saved(), before);
      final activeLocal = objectbox.unifiedFavoriteBox.getAll().singleWhere(
        (row) => row.uniqueKey == 'test:removed',
      );
      expect(activeLocal.deleted, isFalse);

      server.beforeRead = null;
      expect((await sync()).newArchiveSynced, isTrue);
      final published = server.active(false, 'comic')['favorites'] as List;
      expect(
        {for (final row in published) row['uniqueKey']: row['deleted']},
        {'test:local-only': false, 'test:removed': true},
      );
    },
  );

  for (final merge in [false, true]) {
    test(
      'comic publication preserves occupied filenames when digest fails: merge=$merge',
      () async {
        objectbox.unifiedFavoriteBox.put(createTestFavorite('test:local'));
        final stamp = DateTime.now().millisecondsSinceEpoch;
        final committed = _comic('test:committed');
        final server = _Server()
          ..payload(false, 'comic', committed, stamp: stamp + 30000);
        // Cover the publication clock range for the duration of the fixture.
        // No assumption about the exact millisecond of the async upload.
        final occupied = {
          for (var offset = 0; offset < 30000; offset++)
            server.path(
              false,
              ComicSyncCore.buildComicDataFileName(stamp + offset),
            ),
        };
        for (final path in occupied) {
          server.files[path] = const [1];
        }
        final digestPath = server.path(false, 'comic.md5');
        final digest = server.files[digestPath]!.toList();
        server.failWrite = (path) => path == digestPath;
        final adapter = server.adapters().current;
        await expectLater(
          merge
              ? runComicSync(adapter, codec: _codecs.comic)
              : uploadComicData(adapter, codec: _codecs.comic),
          throwsStateError,
        );
        final dataWrite = server.mutations.single.substring('put:'.length);
        expect(occupied.contains(dataWrite), isFalse, reason: dataWrite);
        expect(server.files[digestPath], digest);
        expect(server.active(false, 'comic'), committed);
      },
    );
  }

  test('comic cleanup keeps the active snapshot if its read fails', () async {
    objectbox.unifiedFavoriteBox.put(createTestFavorite('test:kept'));
    final server = _Server()
      ..payload(false, 'comic', ComicSyncCore.captureData());
    for (var stamp = 2; stamp <= 5; stamp++) {
      server.files[server.path(false, 'comic_$stamp.bin')] = [stamp];
    }
    final active = server.path(false, 'comic_1.bin');
    final bytes = List<int>.of(server.files[active]!);
    final digest = utf8.encode(ComicSyncCore.calculateMd5(bytes));
    var reads = 0;
    server.beforeRead = (path) {
      if (path == active && ++reads >= 3) {
        throw const SocketException('fixture transient failure');
      }
    };

    expect(
      (await autoSync(
        _state(),
        archives: server.adapters(),
        codecs: _codecs,
        hooks: hooks,
      )).newArchiveSynced,
      isTrue,
    );
    expect(reads, 3);
    expect(server.files[active], bytes);
    expect(server.files[server.path(false, 'comic.md5')], digest);
    expect(server.mutations, isNot(contains('delete:$active')));
  });

  test(
    'settings cleanup keeps the active snapshot if its read fails',
    () async {
      final state = _state(settings: true);
      _saveState(state);
      final server = _Server();
      final digest = server.path(false, 'settings.md5');
      String? publishedPath;
      var committed = false;
      var failedReads = 0;
      server.beforeWrite = (path) {
        final timestamp = ComicSyncCore.extractSettingsTimestampFromRemotePath(
          path,
        );
        if (timestamp != null) publishedPath = path;
        if (path == digest) {
          final stamp = ComicSyncCore.extractSettingsTimestampFromRemotePath(
            publishedPath!,
          )!;
          for (var i = 1; i <= 4; i++) {
            server.files[server.path(false, 'settings_${stamp + i}.bin')] = [i];
          }
          committed = true;
        }
      };
      server.beforeRead = (path) {
        if (committed && path == publishedPath) {
          failedReads++;
          throw const SocketException('fixture transient failure');
        }
      };

      expect(
        (await manualUploadToCloud(
          state: state,
          archives: server.adapters(),
          codecs: _codecs,
          hooks: hooks,
        )).newArchiveSynced,
        isTrue,
      );
      expect(failedReads, 1);
      final active = server.files[publishedPath];
      expect(active, isNotNull);
      expect(
        utf8.decode(server.files[digest]!),
        ComicSyncCore.calculateMd5(active!),
      );
      expect(server.mutations, isNot(contains('delete:$publishedPath')));
    },
  );

  test(
    'failed settings digest write leaves the previous same-clock snapshot active',
    () async {
      const semanticTime = 9000000000000;
      final original = _shippedSettings()..['syncTime'] = semanticTime;
      for (final block in (original['blocks'] as Map).values) {
        (block as Map)['updatedAt'] = semanticTime;
      }
      final state = _state(settings: true).copyWith(
        dynamicColor:
            !((original['globalSetting'] as Map)['dynamicColor'] as bool),
      );
      _saveState(state);
      final server = _Server()
        ..payload(false, 'settings', original, stamp: semanticTime);
      final oldPath = server.path(false, 'settings_$semanticTime.bin');
      final digestPath = server.path(false, 'settings.md5');
      final oldBytes = List<int>.of(server.files[oldPath]!);
      final oldDigest = List<int>.of(server.files[digestPath]!);
      server.failWrite = (path) => path == digestPath;
      String? publishedPath;
      server.beforeWrite = (path) {
        if (ComicSyncCore.extractSettingsTimestampFromRemotePath(path) !=
            null) {
          publishedPath = path;
        }
      };
      Future<SyncRunResult> upload() => manualUploadToCloud(
        state: state,
        archives: server.adapters(),
        codecs: _codecs,
        hooks: hooks,
      );

      await expectLater(upload(), throwsStateError);
      expect(server.files[oldPath], oldBytes);
      expect(server.files[digestPath], oldDigest);
      expect(server.active(false, 'settings'), original);

      server.failWrite = null;
      expect((await upload()).newArchiveSynced, isTrue);
      expect(publishedPath, isNot(oldPath));
      final activeBytes = server.files[publishedPath]!;
      expect(
        utf8.decode(server.files[digestPath]!),
        ComicSyncCore.calculateMd5(activeBytes),
      );
      final active = jsonDecode(utf8.decode(activeBytes)) as Map;
      expect(active['syncTime'], semanticTime);
      expect(
        (active['globalSetting'] as Map)['dynamicColor'],
        state.dynamicColor,
      );
    },
  );

  for (final problem in [
    'missing digest',
    'unmatched digest',
    'empty digest file',
    'invalid bin',
  ]) {
    test('automatic sync refuses a comic archive with $problem', () async {
      final server = _Server()..payload(false, 'comic', _comic('test:cloud'));
      final digest = server.path(false, 'comic.md5');
      final bin = server.path(false, 'comic_1.bin');
      if (problem == 'missing digest') {
        server.files.remove(digest);
      } else if (problem == 'unmatched digest') {
        server.files[digest] = utf8.encode('not-the-payload-digest');
      } else if (problem == 'empty digest file') {
        server.files.remove(bin);
        server.files[digest] = [];
      } else {
        final invalid = utf8.encode('invalid comic JSON');
        server.files[bin] = invalid;
        server.files[digest] = utf8.encode(ComicSyncCore.calculateMd5(invalid));
      }
      final before = server.saved();
      await expectLater(
        autoSync(
          _state(),
          archives: server.adapters(),
          codecs: _codecs,
          hooks: hooks,
        ),
        throwsA(
          problem == 'invalid bin'
              ? isA<FormatException>()
              : isA<SyncCompatibilityException>(),
        ),
      );
      expect(server.mutations, isEmpty);
      expect(server.saved(), before);
      expect(objectbox.unifiedFavoriteBox.getAll(), isEmpty);
    });
  }

  test(
    'gallery cancellation precedes every domain write and legacy import',
    () async {
      final server = _Server()..payload(true, 'comic', _comic('cancelled-old'));
      final records = <String, LocalAppearanceSyncRecord>{};
      for (var i = 0; i < 8; i++) {
        final bytes = Uint8List.fromList(
          img.encodeJpg(
            img.Image(width: 2, height: 2)..setPixelRgb(0, 0, i * 30, 0, 0),
          ),
        );
        final digest = sha256.convert(bytes).toString();
        final key = 'collection-cover:$digest';
        records[key] = LocalAppearanceSyncRecord(
          key: key,
          digest: digest,
          size: bytes.length,
          modifiedAt: 2,
          deleted: false,
        );
        server.files[server.path(false, 'appearance_resource_$digest.bin')] =
            bytes;
      }
      expect(records, hasLength(8));
      final manifest = utf8.encode(
        jsonEncode(AppearanceSyncManifest(records).toJson()),
      );
      server.files[server.path(
            false,
            'appearance_${List.filled(32, 'a').join()}_${sha256.convert(manifest)}.bin',
          )] =
          manifest;
      final images = LocalAppearanceImages(
        rootDirectory: Directory('${temporary.path}/images'),
      );
      final state = _state(settings: true, plugins: true);
      _saveState(state);
      final beforeCloud = server.saved();
      final beforeLocal = objectbox.unifiedFavoriteBox
          .getAll()
          .map((e) => e.toJson())
          .toList();
      final beforeSetting = objectbox.userSettingBox.get(1)!.globalSetting;
      var prompted = false;
      try {
        await expectLater(
          runArchiveSync(
            state: state,
            archives: server.adapters(),
            codecs: _codecs,
            hooks: SyncArchiveHooks(
              recoveryDirectory: temporary,
              appearanceImages: images,
            ),
            resolveGalleryConflict: (conflict) async {
              prompted = true;
              expect(conflict.candidates, hasLength(8));
              expect(server.mutations, isEmpty);
              return null;
            },
          ),
          throwsA(isA<AppearanceGalleryResolutionCancelled>()),
        );
        expect(prompted, isTrue);
        expect(server.mutations, isEmpty);
        expect(server.saved(), beforeCloud);
        expect(
          objectbox.unifiedFavoriteBox.getAll().map((e) => e.toJson()).toList(),
          beforeLocal,
        );
        expect(objectbox.userSettingBox.get(1)!.globalSetting, beforeSetting);
        expect(images.paths.value, isEmpty);
      } finally {
        images.paths.dispose();
      }
    },
  );

  test(
    'one sync automatically accepts shipped schema2 old data and only writes the new archive',
    () async {
      final server = _Server()
        ..payload(true, 'comic', _shippedComic(oldReadMode: true));
      final old = server.saved(legacy: true);
      objectbox.unifiedFavoriteBox.put(
        createTestFavorite('local:kept')..schemaVersion = 2,
      );
      final result = await _mergeSync(
        _state(),
        archives: server.adapters(),
        codecs: _codecs,
        hooks: hooks,
      );
      expect(result.newArchiveSynced, isTrue);
      expect(result.legacyArchiveImported, isTrue);
      expect(server.saved(legacy: true), old);
      expect(
        server.mutations.every(
          (e) => e.contains('${SyncArchiveContext.currentRoot}/'),
        ),
        isTrue,
      );
      expect(
        server.contexts.where((e) => e.legacy).every((e) => e.readOnly),
        isTrue,
      );
      expect(
        objectbox.unifiedFavoriteBox.getAll().map((e) => e.uniqueKey).toSet(),
        {'shipped:favorite', 'local:kept'},
      );
      expect(objectbox.unifiedHistoryBox.getAll().single.schemaVersion, 2);
      expect(
        objectbox.comicReadPreferenceBox.getAll(),
        isEmpty,
        reason: 'Per-book reader settings follow the selected settings scope.',
      );
      expect(
        (server.active(false, 'comic')['favorites'] as List).cast<Map>().every(
          (e) => e['schemaVersion'] == 2,
        ),
        isTrue,
      );
    },
  );

  test(
    'an existing new main archive merges old and local records while keeping its newer deletion',
    () async {
      final server = _Server()..payload(true, 'comic', _shippedComic());
      final main = _comic('shipped:favorite', deleted: true, year: 2040);
      (main['favorites'] as List).add(
        createTestFavorite('new:kept').toJson()..remove('id'),
      );
      server.payload(false, 'comic', main);
      final old = server.saved(legacy: true);
      objectbox.unifiedFavoriteBox.put(createTestFavorite('local:kept'));
      await _mergeSync(
        _state(),
        archives: server.adapters(),
        codecs: _codecs,
        hooks: hooks,
      );
      final rows = objectbox.unifiedFavoriteBox.getAll();
      expect(rows.map((e) => e.uniqueKey).toSet(), {
        'shipped:favorite',
        'new:kept',
        'local:kept',
      });
      expect(
        rows.singleWhere((e) => e.uniqueKey == 'shipped:favorite').deleted,
        isTrue,
      );
      expect(server.saved(legacy: true), old);
      expect(
        ((server.active(false, 'comic')['favorites'] as List)
            .cast<Map>()
            .singleWhere(
              (e) => e['uniqueKey'] == 'shipped:favorite',
            ))['deleted'],
        isTrue,
      );
    },
  );

  test(
    'unchanged legacy input is idempotent across repeated sync and cannot revive a local deletion',
    () async {
      final payload = _shippedComic();
      payload['folders'] = [
        ComicFolder(
          syncId: '',
          uniqueKey: '/Old|favorite',
          name: 'Old',
          typeData: 'favorite',
          versionVectorJson: '{}',
          createdAt: 1,
          updatedAt: 1,
        ).toJson()..remove('id'),
      ];
      final server = _Server()..payload(true, 'comic', payload);
      final archives = server.adapters();
      await _mergeSync(
        _state(),
        archives: archives,
        codecs: _codecs,
        hooks: hooks,
      );
      final originalFolder = objectbox.comicFolderBox.getAll().single.toJson()
        ..remove('id');
      final row = objectbox.unifiedFavoriteBox.getAll().single;
      row.deleted = true;
      row.updatedAt = DateTime.utc(2040);
      objectbox.unifiedFavoriteBox.put(row);
      final expected = ComicSyncCore.captureData();
      final old = server.saved(legacy: true);
      for (var i = 0; i < 3; i++) {
        final result = await _mergeSync(
          _state(),
          archives: archives,
          codecs: _codecs,
          hooks: hooks,
        );
        expect(result.newArchiveSynced, isTrue);
        expect(result.legacyArchiveImported, isFalse);
        expect(ComicSyncCore.captureData(), expected);
        expect(
          objectbox.comicFolderBox.getAll().single.toJson()..remove('id'),
          originalFolder,
        );
        expect(server.saved(legacy: true), old);
      }
    },
  );

  test(
    'reinstall revisits unchanged legacy input skipped while its source was absent',
    () async {
      final server = _Server()..payload(true, 'comic', _shippedComic());
      final old = server.saved(legacy: true);
      final archives = server.adapters();
      await installSyncPlugins(['fixture', 'shipped-plugin', 'local-plugin']);
      objectbox.unifiedFavoriteBox.put(createTestFavorite('local:retained'));
      await _mergeSync(
        _state(),
        archives: archives,
        codecs: _codecs,
        hooks: hooks,
      );
      expect(objectbox.unifiedFavoriteBox.getAll().map((e) => e.uniqueKey), [
        'local:retained',
      ]);
      expect((server.active(false, 'comic')['favorites'] as List), isEmpty);
      expect(server.saved(legacy: true), old);

      await installSyncPlugins([
        'test',
        'fixture',
        'shipped-plugin',
        'local-plugin',
      ]);
      await _mergeSync(
        _state(),
        archives: archives,
        codecs: _codecs,
        hooks: hooks,
      );
      expect(
        objectbox.unifiedFavoriteBox.getAll().map((e) => e.uniqueKey).toSet(),
        {'local:retained', 'shipped:favorite'},
      );
      expect(server.saved(legacy: true), old);
    },
  );

  test(
    'a delayed changed old archive is accepted on the next sync without replaying stale deleted records',
    () async {
      final server = _Server()..payload(true, 'comic', _shippedComic());
      final archives = server.adapters();
      await _mergeSync(
        _state(),
        archives: archives,
        codecs: _codecs,
        hooks: hooks,
      );
      final row = objectbox.unifiedFavoriteBox.getAll().single;
      row.deleted = true;
      row.updatedAt = DateTime.utc(2040);
      objectbox.unifiedFavoriteBox.put(row);
      await _mergeSync(
        _state(),
        archives: archives,
        codecs: _codecs,
        hooks: hooks,
      );
      final late = _shippedComic();
      (late['favorites'] as List).add(
        (createTestFavorite(
          'old:late',
          updatedAt: DateTime.utc(2030),
        )..schemaVersion = 2).toJson()..remove('id'),
      );
      server.payload(true, 'comic', late, stamp: 2);
      final old = server.saved(legacy: true);
      final result = await _mergeSync(
        _state(),
        archives: archives,
        codecs: _codecs,
        hooks: hooks,
      );
      expect(result.legacyArchiveImported, isTrue);
      final rows = objectbox.unifiedFavoriteBox.getAll();
      expect(
        rows.singleWhere((e) => e.uniqueKey == 'shipped:favorite').deleted,
        isTrue,
      );
      expect(
        rows.singleWhere((e) => e.uniqueKey == 'old:late').deleted,
        isFalse,
      );
      expect(server.saved(legacy: true), old);
      expect(
        (server.active(false, 'comic')['favorites'] as List)
            .cast<Map>()
            .map((e) => e['uniqueKey'])
            .toSet(),
        {'shipped:favorite', 'old:late'},
      );
    },
  );

  for (final settings in [false, true]) {
    for (final plugins in [false, true]) {
      test(
        'unified sync respects settings=$settings plugins=$plugins with the real old full serializer',
        () async {
          final state = _state(settings: settings, plugins: plugins);
          _saveState(state);
          final server = _Server()
            ..payload(true, 'comic', _shippedComic())
            ..payload(true, 'settings', _shippedSettings());
          final old = server.saved(legacy: true);
          final result = await _mergeSync(
            state,
            archives: server.adapters(),
            codecs: _codecs,
            hooks: hooks,
          );
          expect(result.newArchiveSynced, isTrue);
          expect(
            objectbox.userSettingBox.get(1)!.globalSetting.dynamicColor,
            !settings,
          );
          final configs = objectbox.pluginConfigBox.getAll();
          expect(
            configs.map((e) => e.name).toList(),
            plugins ? ['shipped-plugin'] : isEmpty,
          );
          if (plugins)
            expect(configs.single.config, contains('future-private'));
          expect(server.saved(legacy: true), old);
          if (settings || plugins) {
            expect(
              jsonEncode(server.active(false, 'settings')),
              isNot(contains('SYNTHETIC_OLD_TRANSPORT')),
            );
          } else {
            expect(
              server.files.keys.where(
                (e) => e.startsWith(server.path(false, 'settings_')),
              ),
              isEmpty,
            );
          }
        },
      );
    }
  }

  test(
    'enabling a sync choice later accepts that old input even when its head did not change',
    () async {
      final server = _Server()..payload(true, 'settings', _shippedSettings());
      final archives = server.adapters();
      await _mergeSync(
        _state(),
        archives: archives,
        codecs: _codecs,
        hooks: hooks,
      );
      expect(objectbox.pluginConfigBox.getAll(), isEmpty);
      expect(
        objectbox.userSettingBox.get(1)!.globalSetting.dynamicColor,
        isTrue,
      );
      final enabled = _state(settings: true, plugins: true);
      _saveState(enabled);
      await _mergeSync(
        enabled,
        archives: archives,
        codecs: _codecs,
        hooks: hooks,
      );
      expect(
        objectbox.userSettingBox.get(1)!.globalSetting.dynamicColor,
        isFalse,
      );
      expect(
        objectbox.pluginConfigBox.getAll().single.config,
        contains('future-private'),
      );
      expect(
        server.mutations.every(
          (e) => e.contains('${SyncArchiveContext.currentRoot}/'),
        ),
        isTrue,
      );
    },
  );

  test(
    'plugins-only sync uploads no excluded local app settings even in compatibility fields',
    () async {
      const marker = 'SYNTHETIC_LOCAL_APP_ONLY';
      final state = _state(plugins: true).copyWith(maskedKeywords: [marker]);
      _saveState(state);
      objectbox.pluginConfigBox.put(
        PluginConfig(
          name: 'local-plugin',
          config: '{"public.preference":"selected"}',
        ),
      );
      final server = _Server();
      await _mergeSync(
        state,
        archives: server.adapters(),
        codecs: _codecs,
        hooks: hooks,
      );
      final payload = server.active(false, 'settings');
      expect(payload['globalSetting'], isEmpty);
      expect((payload['blocks'] as Map).keys, ['plugins']);
      expect(
        utf8.decode(
          server.files.entries
              .singleWhere(
                (e) =>
                    e.key.startsWith(server.path(false, 'settings_')) &&
                    ComicSyncCore.calculateMd5(e.value) ==
                        utf8.decode(
                          server.files[server.path(false, 'settings.md5')]!,
                        ),
              )
              .value,
        ),
        isNot(contains(marker)),
      );
      expect((payload['pluginConfigs'] as List).single['name'], 'local-plugin');
    },
  );

  test(
    'plugins-only sync retains existing cloud setting blocks without leaking local settings',
    () async {
      const marker = 'SYNTHETIC_LOCAL_APP_ONLY';
      final state = _state(plugins: true).copyWith(maskedKeywords: [marker]);
      _saveState(state);
      final remote = _shippedSettings();
      final server = _Server()..payload(false, 'settings', remote);
      objectbox.pluginConfigBox.put(
        PluginConfig(
          name: 'local-plugin',
          config: '{"public.preference":"selected"}',
        ),
      );
      await _mergeSync(
        state,
        archives: server.adapters(),
        codecs: _codecs,
        hooks: hooks,
      );
      final payload = server.active(false, 'settings');
      for (final block in ['appearance', 'library', 'reader', 'video']) {
        expect(
          (payload['blocks'] as Map)[block],
          (remote['blocks'] as Map)[block],
        );
      }
      expect(jsonEncode(payload), isNot(contains(marker)));
      expect(objectbox.userSettingBox.get(1)!.globalSetting.maskedKeywords, [
        marker,
      ]);
      expect(
        objectbox.userSettingBox.get(1)!.globalSetting.dynamicColor,
        isTrue,
      );
      expect(
        (payload['pluginConfigs'] as List).map((e) => e['name']),
        containsAll(['local-plugin', 'shipped-plugin']),
      );
    },
  );

  test(
    'an unrelated old config edit cannot revive saved login deleted after its first import',
    () async {
      final home = Uri.https('example.test');
      const source = 'shipped-plugin';
      final credentials = {
        'version': 1,
        'origin': home.origin,
        'account': 'synthetic-account',
        'password': 'synthetic-password',
        'updatedAt': 1,
        'deleted': false,
      };
      Map<String, dynamic> oldSettings(int year, String preference) {
        final data = {
          'pluginInfos': <dynamic>[],
          'pluginConfigs': [
            {
              'name': source,
              'config': jsonEncode({
                VideoAccountCredentials.key: credentials,
                'public.preference': preference,
              }),
            },
          ],
        };
        final stamp = DateTime.utc(year).millisecondsSinceEpoch;
        return {
          'version': 'v1',
          'schemaVersion': 'v2',
          'syncTime': stamp,
          'globalSetting': <String, dynamic>{},
          ...data,
          'blocks': {
            'plugins': {'updatedAt': stamp, 'data': data},
          },
        };
      }

      final state = _state(plugins: true);
      _saveState(state);
      final server = _Server()
        ..payload(true, 'settings', oldSettings(2020, 'old'));
      final archives = server.adapters();
      await _mergeSync(
        state,
        archives: archives,
        codecs: _codecs,
        hooks: hooks,
      );
      expect(VideoAccountCredentials.load(source, home), isNotNull);
      await VideoAccountCredentials.clear(source, home);
      expect(VideoAccountCredentials.load(source, home), isNull);
      server.payload(true, 'settings', oldSettings(2035, 'changed'));
      final old = server.saved(legacy: true);
      await _mergeSync(
        state,
        archives: archives,
        codecs: _codecs,
        hooks: hooks,
      );
      expect(
        VideoAccountCredentials.load(source, home),
        isNull,
        reason: 'An unchanged old credential value is not a new account edit.',
      );
      final local =
          jsonDecode(
                objectbox.pluginConfigBox
                    .getAll()
                    .singleWhere((c) => c.name == source)
                    .config,
              )
              as Map;
      expect(local['public.preference'], 'changed');
      expect(server.saved(legacy: true), old);
    },
  );

  test(
    'retry after comic commit and later video upload failure preserves merged rows and deletions',
    () async {
      final server = _Server()
        ..payload(false, 'comic', _comic('cloud:kept'))
        ..payload(true, 'comic', _comic('old:removed'));
      final old = server.saved(legacy: true);
      objectbox.unifiedFavoriteBox.put(createTestFavorite('local:kept'));
      await VideoLibraryStore.shared.setFavorite(
        'fixture',
        ApiVideoItem(
          id: 'retry-video',
          title: 'Fixture',
          detailUrl: Uri.https('example.test', '/video'),
        ),
        true,
      );
      server.failWrite = (path) =>
          path.startsWith(server.path(false, 'video_library_'));
      final archives = server.adapters();
      await expectLater(
        _mergeSync(_state(), archives: archives, codecs: _codecs, hooks: hooks),
        throwsStateError,
      );
      expect(
        (server.active(false, 'comic')['favorites'] as List).map(
          (e) => e['uniqueKey'],
        ),
        containsAll(['cloud:kept', 'local:kept', 'old:removed']),
      );
      final removed =
          objectbox.unifiedFavoriteBox.getAll().singleWhere(
              (e) => e.uniqueKey == 'old:removed',
            )
            ..deleted = true
            ..updatedAt = DateTime.utc(2040);
      objectbox.unifiedFavoriteBox.put(removed);
      server.failWrite = null;
      await _mergeSync(
        _state(),
        archives: archives,
        codecs: _codecs,
        hooks: hooks,
      );
      final committed = server.active(false, 'comic');
      await _mergeSync(
        _state(),
        archives: archives,
        codecs: _codecs,
        hooks: hooks,
      );
      expect(server.active(false, 'comic'), committed);
      final favorites = objectbox.unifiedFavoriteBox.getAll();
      expect(favorites.map((e) => e.uniqueKey).toSet(), {
        'cloud:kept',
        'local:kept',
        'old:removed',
      });
      expect(
        favorites.singleWhere((e) => e.uniqueKey == 'old:removed').deleted,
        isTrue,
      );
      expect(server.saved(legacy: true), old);
    },
  );

  for (final compatibility in [false, true]) {
    test(
      'obsolete compatibility flag=$compatibility neither blocks sync nor enables old writes',
      () async {
        final state = _state(compatibility: compatibility);
        _saveState(state);
        final server = _Server()..payload(true, 'comic', _shippedComic());
        final old = server.saved(legacy: true);
        final result = await _mergeSync(
          state,
          archives: server.adapters(),
          codecs: _codecs,
          hooks: hooks,
        );
        expect(result.newArchiveSynced, isTrue);
        expect(server.saved(legacy: true), old);
        expect(
          server.mutations.every(
            (e) => e.contains('${SyncArchiveContext.currentRoot}/'),
          ),
          isTrue,
        );
      },
    );
  }

  for (final failure in [
    'old-schema',
    'old-field',
    'old-settings',
    'new-schema',
  ]) {
    test(
      'future $failure stops the whole unified sync before local changes or any remote write',
      () async {
        final oldComic = _shippedComic();
        final server = _Server();
        if (failure == 'old-schema')
          ((oldComic['histories'] as List).single as Map)['schemaVersion'] = 3;
        if (failure == 'old-field')
          ((oldComic['favorites'] as List).single
                  as Map)['future-unknown-field'] =
              true;
        server.payload(true, 'comic', oldComic);
        if (failure == 'old-settings')
          server.payload(true, 'settings', {'version': 'v99'});
        if (failure == 'new-schema')
          server.payload(false, 'comic', {'version': 'v99'});
        final state = _state(settings: true, plugins: true);
        _saveState(state);
        objectbox.unifiedFavoriteBox.put(
          createTestFavorite('local:kept')..schemaVersion = 2,
        );
        final local = ComicSyncCore.captureData();
        final before = server.saved();
        final prefs = await SharedPreferences.getInstance();
        final beforePrefs = {
          for (final key in prefs.getKeys()) key: prefs.get(key),
        };
        await expectLater(
          _mergeSync(
            state,
            archives: server.adapters(),
            codecs: _codecs,
            hooks: hooks,
          ),
          throwsA(isA<SyncCompatibilityException>()),
        );
        expect(ComicSyncCore.captureData(), local);
        expect(objectbox.userSettingBox.get(1)!.globalSetting, state);
        expect({
          for (final key in prefs.getKeys()) key: prefs.get(key),
        }, beforePrefs);
        expect(server.saved(), before);
        expect(server.mutations, isEmpty);
      },
    );
  }

  test(
    'legacy transport is always read-only and denies every mutation',
    () async {
      final server = _Server();
      final reader = server.adapters().legacyReader;
      await reader.ensureRemoteReady();
      await expectLater(
        Future.sync(() => reader.uploadRemoteMd5('x')),
        throwsA(isA<LegacyArchiveReadOnly>()),
      );
      await expectLater(
        Future.sync(() => reader.uploadRemoteFile('comic_1.bin', [1])),
        throwsA(isA<LegacyArchiveReadOnly>()),
      );
      await expectLater(
        Future.sync(() => reader.deleteRemoteFiles(['comic_1.bin'])),
        throwsA(isA<LegacyArchiveReadOnly>()),
      );
      expect(server.mutations, isEmpty);
    },
  );

  test(
    'old import commit failure rolls back local data before the main archive is written',
    () async {
      final item = ApiVideoItem(
        id: 'local',
        title: 'Local',
        detailUrl: Uri.https('example.test', '/local'),
      );
      await VideoLibraryStore.shared.setFavorite('fixture', item, true);
      final video = (await VideoLibraryStore.shared.read()).toJson();
      final server = _Server()..payload(true, 'comic', _shippedComic());
      server.video(true, VideoLibrarySnapshot());
      final old = server.saved();
      await expectLater(
        _mergeSync(
          _state(),
          archives: server.adapters(),
          codecs: _codecs,
          hooks: SyncArchiveHooks(
            recoveryDirectory: temporary,
            beforeDatabaseCommit: () => throw StateError('synthetic failure'),
          ),
        ),
        throwsA(isA<ArchiveRestoreFailed>()),
      );
      expect(objectbox.unifiedFavoriteBox.getAll(), isEmpty);
      expect((await VideoLibraryStore.shared.read()).toJson(), video);
      expect(server.saved(), old);
      expect(server.mutations, isEmpty);
      expect(await temporary.list().toList(), isEmpty);
    },
  );

  test(
    'interrupted legacy import retries after preferences are written but database commit is absent',
    () async {
      final server = _Server()..payload(true, 'comic', _shippedComic());
      final prefs = await SharedPreferences.getInstance();
      final checkpoint = File('${temporary.path}/$_identityKey.json');
      late String interruptedFile;
      late Map<String, Object> interruptedPrefs;
      await expectLater(
        _mergeSync(
          _state(),
          archives: server.adapters(),
          codecs: _codecs,
          hooks: SyncArchiveHooks(
            recoveryDirectory: temporary,
            beforeDatabaseCommit: () {
              // Capture what would survive a process kill at this boundary.
              interruptedFile = checkpoint.readAsStringSync();
              interruptedPrefs = {
                for (final key in prefs.getKeys()) key: prefs.get(key)!,
              };
              throw StateError('leave the database transaction uncommitted');
            },
          ),
        ),
        throwsA(isA<ArchiveRestoreFailed>()),
      );
      expect(objectbox.unifiedFavoriteBox.getAll(), isEmpty);
      expect(server.mutations, isEmpty);
      // The exception path rolled back in memory; restore just the disk state
      // at the cut while keeping the real ObjectBox transaction uncommitted.
      SharedPreferences.setMockInitialValues(interruptedPrefs);
      await checkpoint.writeAsString(interruptedFile);
      final retry = await _mergeSync(
        _state(),
        archives: server.adapters(),
        codecs: _codecs,
        hooks: hooks,
      );
      expect(retry.legacyArchiveImported, isTrue);
      expect(objectbox.unifiedFavoriteBox.getAll(), hasLength(1));
      expect(await checkpoint.exists(), isFalse);
    },
  );

  test(
    'interrupted legacy import keeps preferences when its database commit survived',
    () async {
      final server = _Server()..payload(true, 'comic', _shippedComic());
      final checkpoint = File('${temporary.path}/$_identityKey.json');
      late String prepared;
      final imported = await _mergeSync(
        _state(),
        archives: server.adapters(),
        codecs: _codecs,
        hooks: SyncArchiveHooks(
          recoveryDirectory: temporary,
          beforeDatabaseCommit: () => prepared = checkpoint.readAsStringSync(),
        ),
      );
      expect(imported.legacyArchiveImported, isTrue);
      expect(objectbox.unifiedFavoriteBox.getAll(), hasLength(1));

      // Restore the on-disk checkpoint and the commit proof that would remain
      // after ObjectBox committed but before the checkpoint was finalized.
      final token = (jsonDecode(prepared) as Map)['operationToken'] as String;
      final commits = objectbox.store.box<LocalStorageCommit>();
      expect(commits.getAll(), isEmpty);
      commits.put(LocalStorageCommit(operationToken: token));
      await checkpoint.writeAsString(prepared);
      final retry = await _mergeSync(
        _state(),
        archives: server.adapters(),
        codecs: _codecs,
        hooks: hooks,
      );
      expect(retry.legacyArchiveImported, isFalse);
      expect(objectbox.unifiedFavoriteBox.getAll(), hasLength(1));
      expect(await checkpoint.exists(), isFalse);
      expect(commits.getAll(), isEmpty);
    },
  );

  test(
    'known old video update preserves local new-only fields and metric evidence',
    () async {
      final local = ApiVideoItem(
        id: 'video',
        title: 'Local',
        detailUrl: Uri.https('example.test', '/video'),
        containCover: true,
        sourceViews: 15,
        sourceViewsAreClicks: true,
        sourceRating: 8.5,
        sourceRatingCount: 2,
        sourceRatingCountConsistent: false,
      );
      await VideoLibraryStore.shared.setFavorite('fixture', local, true);
      final before = await VideoLibraryStore.shared.read();
      final key = before.favorites.keys.single;
      final raw =
          jsonDecode(jsonEncode(before.toJson())) as Map<String, dynamic>;
      final row = (raw['favorites'] as Map)[key] as Map;
      row['clock'] = (row['clock'] as int) + 100;
      row['device'] = 'old-device';
      final item = ((row['data'] as Map)['item'] as Map);
      item['title'] = 'Old-device update';
      item.remove('containCover');
      item['sourceViews'] = 99;
      item.remove('sourceViewsKind');
      item['sourceRating'] = 4.5;
      item['sourceRatingCount'] = 8;
      item.remove('sourceRatingCountConsistent');
      final server = _Server()..video(true, VideoLibrarySnapshot.fromJson(raw));
      final old = server.saved(legacy: true);
      await _mergeSync(
        _state(),
        archives: server.adapters(),
        codecs: _codecs,
        hooks: hooks,
      );
      final saved = (await VideoLibraryStore.shared.read()).favorites[key]!;
      expect((saved.data['item'] as Map)['title'], 'Old-device update');
      expect((saved.data['item'] as Map)['containCover'], isTrue);
      expect(saved.data['item'], containsPair('sourceViews', 15));
      expect(saved.data['item'], containsPair('sourceViewsKind', 'clicks'));
      expect(saved.data['item'], containsPair('sourceRating', 8.5));
      expect(saved.data['item'], containsPair('sourceRatingCount', 2));
      expect(saved.data['item'], containsPair('sourceRatingCountConsistent', false));
      expect(server.saved(legacy: true), old);
    },
  );

  test(
    'legacy cloud merge preserves a favorite deleted during local apply',
    () async {
      final store = VideoLibraryStore.shared;
      final item = ApiVideoItem(
        id: 'removed',
        title: 'Removed',
        detailUrl: Uri.https('example.test', '/removed'),
      );
      await store.setFavorite('fixture', item, true);
      final server = _Server()
        ..video(
          true,
          await store.read(),
          preferences: PortablePreferencesSnapshot(),
        );
      Future<void>? deletion;
      void deleteOnPreferenceApply() {
        deletion ??= store.setFavorite('fixture', item, false);
      }

      PortablePreferences.changes.addListener(deleteOnPreferenceApply);
      try {
        await _mergeSync(
          _state(),
          archives: server.adapters(),
          codecs: _codecs,
          hooks: hooks,
        );
        expect(deletion, isNotNull);
        await deletion;
        expect((await store.read()).contains('fixture', item.id), isFalse);
      } finally {
        PortablePreferences.changes.removeListener(deleteOnPreferenceApply);
      }
    },
  );

  test(
    'unrelated files do not count as archives and valid old data is still accepted',
    () async {
      final server = _Server();
      server.files[server.path(false, '.DS_Store')] = [1];
      server.files[server.path(true, 'notes.txt')] = [2];
      var status = await readArchiveStatus(
        _state(),
        archives: server.adapters(),
      );
      expect(status.hasCurrentData, isFalse);
      expect(status.hasLegacyData, isFalse);
      server.payload(true, 'comic', _shippedComic());
      status = await readArchiveStatus(_state(), archives: server.adapters());
      expect(status.hasCurrentData, isFalse);
      expect(status.hasLegacyData, isTrue);
      final old = server.saved(legacy: true);
      expect(
        (await _mergeSync(
          _state(),
          archives: server.adapters(),
          codecs: _codecs,
          hooks: hooks,
        )).newArchiveSynced,
        isTrue,
      );
      expect(server.saved(legacy: true), old);
    },
  );

  test(
    'old candidates without a committed MD5 are rejected without applying them',
    () async {
      final server = _Server()..payload(true, 'settings', _shippedSettings());
      server.files.remove(server.path(true, 'settings.md5'));
      final old = server.saved();
      await expectLater(
        _mergeSync(
          _state(),
          archives: server.adapters(),
          codecs: _codecs,
          hooks: hooks,
        ),
        throwsA(isA<SyncCompatibilityException>()),
      );
      expect(objectbox.unifiedFavoriteBox.getAll(), isEmpty);
      expect(server.saved(), old);
      expect(server.mutations, isEmpty);
    },
  );

  for (final direction in [SyncDirection.upload, SyncDirection.restore]) {
    for (final settingsEnabled in [false, true]) {
      test(
        'behavior and bookshelf follow $direction only when settings=$settingsEnabled',
        () async {
          final state = _reviewLocalState(_state(settings: settingsEnabled));
          _saveState(state);
          final cloudValues = _reviewPortableValues(const GlobalSettingState());
          final server = _Server()
            ..payload(false, 'settings', {
              'version': 'v1',
              'schemaVersion': 'v2',
              'syncTime': DateTime.utc(2040).millisecondsSinceEpoch,
              'blocks': {
                'appearance': {
                  'updatedAt': DateTime.utc(2040).millisecondsSinceEpoch,
                  'data': {
                    for (final key in _reviewAppearanceKeys)
                      key: cloudValues[key],
                  },
                },
                'library': {
                  'updatedAt': DateTime.utc(2040).millisecondsSinceEpoch,
                  'data': {
                    for (final entry in cloudValues.entries)
                      if (!_reviewAppearanceKeys.contains(entry.key))
                        entry.key: entry.value,
                  },
                },
              },
            });
          final cloudBefore = server.saved();
          if (direction == SyncDirection.upload) {
            await manualUploadToCloud(
              state: state,
              archives: server.adapters(),
              codecs: _codecs,
              hooks: hooks,
            );
          } else {
            await manualDownloadFromCloud(
              state: state,
              archives: server.adapters(),
              codecs: _codecs,
              hooks: hooks,
            );
          }
          final restored = objectbox.userSettingBox.get(1)!.globalSetting;
          final expectedLocal =
              settingsEnabled && direction == SyncDirection.restore
              ? cloudValues
              : _reviewPortableValues(state);
          final actual = _reviewPortableValues(restored);
          expect(restored.eInkSetting.detectionHandled, isTrue);
          for (final key in cloudValues.keys) {
            expect(actual[key], expectedLocal[key], reason: key);
          }
          if (settingsEnabled && direction == SyncDirection.upload) {
            final uploaded = server.active(false, 'settings');
            for (final key in cloudValues.keys) {
              final name = _reviewAppearanceKeys.contains(key)
                  ? 'appearance'
                  : 'library';
              final block =
                  ((uploaded['blocks'] as Map)[name] as Map)['data'] as Map;
              expect(block[key], expectedLocal[key], reason: key);
              expect(
                (uploaded['globalSetting'] as Map)[key],
                expectedLocal[key],
              );
            }
          } else {
            expect(
              Map.fromEntries(
                server.saved().entries.where(
                  (e) => e.key.contains('/settings'),
                ),
              ),
              cloudBefore,
            );
          }
        },
      );
    }
  }

  for (final followsSystem in [false, true]) {
    test(
      'restore keeps language and follows-system paired: $followsSystem',
      () async {
        final state = _state(settings: true).copyWith(
          locale: const Locale('zh', 'CN'),
          localeFollowsSystem: !followsSystem,
        );
        _saveState(state);
        final cloud = state
            .copyWith(
              locale: const Locale('en', 'US'),
              localeFollowsSystem: followsSystem,
            )
            .toJson();
        final server = _Server()
          ..payload(false, 'settings', {
            'version': 'v1',
            'schemaVersion': 'v2',
            'syncTime': 1,
            'blocks': {
              'appearance': {
                'updatedAt': 1,
                'data': {
                  'locale': cloud['locale'],
                  'localeFollowsSystem': followsSystem,
                },
              },
            },
          });
        await manualDownloadFromCloud(
          state: state,
          archives: server.adapters(),
          codecs: _codecs,
          hooks: hooks,
        );
        final restored = objectbox.userSettingBox.get(1)!.globalSetting;
        expect(restored.locale, const Locale('en', 'US'));
        expect(restored.localeFollowsSystem, followsSystem);
      },
    );
  }

  for (final settingsEnabled in [false, true]) {
    test(
      'old cloud startup index maps to current tabs only in selected settings scope: $settingsEnabled',
      () async {
        final state = _state(
          settings: settingsEnabled,
        ).copyWith(welcomePageNum: 13);
        _saveState(state);
        final server = _Server()
          ..payload(false, 'settings', {
            'version': 'v1',
            'schemaVersion': 'v2',
            'syncTime': 10,
            'blocks': {
              'appearance': {
                'updatedAt': 10,
                'data': {'welcomePageNum': 2},
              },
              'library': {
                'updatedAt': 10,
                'data': {'oldPageRollbackEnabled': true},
              },
            },
          });
        await manualDownloadFromCloud(
          state: state,
          archives: server.adapters(),
          codecs: _codecs,
          hooks: hooks,
        );
        final restored = objectbox.userSettingBox.get(1)!.globalSetting;
        expect(restored.oldPageRollbackEnabled, isFalse);
        expect(restored.welcomePageNum, settingsEnabled ? 11 : 13);
      },
    );
  }

  test(
    'full capture canonicalizes a directly constructed legacy navigation state',
    () async {
      final state = _state(
        settings: false,
      ).copyWith(oldPageRollbackEnabled: true, welcomePageNum: 2);
      final payload = await captureFullCloudSettings(state);
      final global = payload['globalSetting'] as Map;
      expect(global['oldPageRollbackEnabled'], isFalse);
      expect(global['welcomePageNum'], 11);
      expect(
        ((payload['blocks'] as Map)['library'] as Map)['data'],
        containsPair('oldPageRollbackEnabled', false),
      );
      expect(
        ((payload['blocks'] as Map)['appearance'] as Map)['data'],
        containsPair('welcomePageNum', 11),
      );
      expect(
        state.oldPageRollbackEnabled,
        isTrue,
        reason: 'capture must not mutate its caller',
      );
    },
  );

  test(
    'full replacement captures behavior and bookshelf with daily settings off',
    () async {
      final state = _reviewLocalState(_state(settings: false, plugins: false));
      _saveState(state);
      final payload = await captureFullCloudSettings(state);
      final values = _reviewPortableValues(state);
      for (final key in values.keys) {
        final name = _reviewAppearanceKeys.contains(key)
            ? 'appearance'
            : 'library';
        final block = ((payload['blocks'] as Map)[name] as Map)['data'] as Map;
        expect(block[key], values[key], reason: key);
        expect((payload['globalSetting'] as Map)[key], values[key]);
      }
    },
  );

  test(
    'manual upload keeps local choices even with a newer cloud and merges unique records',
    () async {
      final state = _state(
        settings: true,
        plugins: true,
      ).copyWith(dynamicColor: true);
      _saveState(state);
      objectbox.pluginConfigBox.put(
        PluginConfig(
          name: 'local-plugin',
          config: '{"choice":"local","onlyLocal":"kept"}',
        ),
      );
      objectbox.unifiedFavoriteBox.put(createTestFavorite('local:unique'));
      final cloudSettings = _shippedSettings();
      final pluginData = {
        'pluginConfigs': [
          {
            'name': 'local-plugin',
            'config': '{"choice":"cloud","cloudOptional":"kept"}',
          },
        ],
        'pluginInfos': <dynamic>[],
      };
      (cloudSettings['blocks'] as Map)['plugins'] = {
        'updatedAt': DateTime.utc(2040).millisecondsSinceEpoch,
        'data': pluginData,
      };
      final server = _Server()
        ..payload(false, 'settings', cloudSettings)
        ..payload(false, 'comic', _comic('cloud:unique'));
      await manualUploadToCloud(
        state: state,
        archives: server.adapters(),
        codecs: _codecs,
        hooks: hooks,
      );
      expect(
        objectbox.userSettingBox.get(1)!.globalSetting.dynamicColor,
        isTrue,
      );
      expect(
        jsonDecode(objectbox.pluginConfigBox.getAll().single.config)['choice'],
        'local',
      );
      final settings = server.active(false, 'settings');
      expect((settings['globalSetting'] as Map)['dynamicColor'], isTrue);
      final config = (settings['pluginConfigs'] as List)
          .cast<Map>()
          .singleWhere((r) => r['name'] == 'local-plugin');
      expect(jsonDecode(config['config'] as String)['choice'], 'local');
      expect(
        objectbox.unifiedFavoriteBox.getAll().map((r) => r.uniqueKey).toSet(),
        {'local:unique', 'cloud:unique'},
      );
      expect(
        (server.active(false, 'comic')['favorites'] as List)
            .map((r) => r['uniqueKey'])
            .toSet(),
        {'local:unique', 'cloud:unique'},
      );
    },
  );

  test(
    'manual restore uses cloud choices with newer local clocks and preserves missing fields and device settings',
    () async {
      final state = _state(settings: true, plugins: true).copyWith(
        dynamicColor: true,
        maskedKeywords: ['local-optional'],
        customExportPath: '/synthetic/local-only',
        syncSetting: _state(settings: true, plugins: true).syncSetting.copyWith(
          settingsSyncTime: DateTime.utc(2040).millisecondsSinceEpoch,
        ),
      );
      _saveState(state);
      objectbox.pluginConfigBox.put(
        PluginConfig(
          name: 'local-plugin',
          config: '{"choice":"local","onlyLocal":"kept"}',
        ),
      );
      final server = _Server()
        ..payload(false, 'settings', {
          'version': 'v1',
          'schemaVersion': 'v2',
          'syncTime': 10,
          'blocks': {
            'appearance': {
              'updatedAt': 10,
              'data': {'dynamicColor': false},
            },
            'plugins': {
              'updatedAt': 10,
              'data': {
                'pluginConfigs': [
                  {'name': 'local-plugin', 'config': '{"choice":"cloud"}'},
                ],
                'pluginInfos': <dynamic>[],
              },
            },
          },
        });
      final before = server.saved();
      await manualDownloadFromCloud(
        state: state,
        archives: server.adapters(),
        codecs: _codecs,
        hooks: hooks,
      );
      final restored = objectbox.userSettingBox.get(1)!.globalSetting;
      expect(restored.dynamicColor, isFalse);
      expect(restored.maskedKeywords, ['local-optional']);
      expect(restored.customExportPath, '/synthetic/local-only');
      expect(restored.syncSetting, state.syncSetting);
      final config = jsonDecode(
        objectbox.pluginConfigBox.getAll().single.config,
      );
      expect(config['choice'], 'cloud');
      expect(config['onlyLocal'], 'kept');
      expect(
        Map.fromEntries(
          server.saved().entries.where((e) => e.key.contains('/settings')),
        ),
        Map.fromEntries(
          before.entries.where((e) => e.key.contains('/settings')),
        ),
      );
    },
  );

  test(
    'automatic sync exchanges records only across current and legacy archives even with every switch enabled',
    () async {
      final state = _reviewLocalState(_state(settings: true, plugins: true));
      _saveState(state);
      objectbox.pluginConfigBox.put(
        PluginConfig(name: 'local-plugin', config: '{"choice":"local"}'),
      );
      objectbox.comicReadPreferenceBox.put(
        ComicReadPreference(
          uniqueKey: 'local:reader',
          source: 'test',
          comicId: 'local:reader',
          overridesJson: '{"readMode":1}',
          updatedAt: DateTime.utc(2020),
        ),
      );
      final cloudSettings = _shippedSettings();
      final cloudValues = _reviewPortableValues(const GlobalSettingState());
      for (final entry in cloudValues.entries) {
        final name = _reviewAppearanceKeys.contains(entry.key)
            ? 'appearance'
            : 'library';
        (((cloudSettings['blocks'] as Map)[name] as Map)['data']
                as Map)[entry.key] =
            entry.value;
      }
      final server = _Server()
        ..payload(true, 'settings', cloudSettings)
        ..payload(true, 'comic', _shippedComic(oldReadMode: true))
        ..payload(false, 'settings', cloudSettings)
        ..payload(false, 'comic', _comic('current:record'));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('breeze.collection-cover.style.v1', 'glass');
      final settings = Map.fromEntries(
        server.saved().entries.where((e) => e.key.contains('/settings')),
      );
      await autoSync(
        state,
        archives: server.adapters(),
        codecs: _codecs,
        hooks: hooks,
      );
      expect(
        objectbox.userSettingBox.get(1)!.globalSetting.dynamicColor,
        isTrue,
      );
      final after = objectbox.userSettingBox.get(1)!.globalSetting;
      expect(_reviewPortableValues(after), _reviewPortableValues(state));
      expect(after.eInkSetting.detectionHandled, isTrue);
      expect(
        objectbox.pluginConfigBox.getAll().single.config,
        '{"choice":"local"}',
      );
      expect(
        objectbox.comicReadPreferenceBox.getAll().single.uniqueKey,
        'local:reader',
      );
      expect(prefs.getString('breeze.collection-cover.style.v1'), 'glass');
      expect(
        Map.fromEntries(
          server.saved().entries.where((e) => e.key.contains('/settings')),
        ),
        settings,
      );
      expect(
        (server.active(false, 'comic')['readPreferences'] as List),
        isEmpty,
      );
      expect(server.mutations.any((e) => e.contains('/appearance_')), isFalse);
      expect(
        objectbox.unifiedFavoriteBox.getAll().map((r) => r.uniqueKey).toSet(),
        {'shipped:favorite', 'current:record'},
      );
    },
  );

  test(
    'fresh-journal style follows upload then restore rather than revision clocks',
    () async {
      final state = _state(settings: true);
      _saveState(state);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('breeze.collection-cover.style.v1', 'glass');
      final server = _Server();
      await manualUploadToCloud(
        state: state,
        archives: server.adapters(),
        codecs: _codecs,
        hooks: hooks,
      );
      expect(prefs.getString('breeze.collection-cover.style.v1'), 'glass');
      final portable = await VideoLibrarySync.readArchive(
        server.adapters().current,
        codec: _codecs.video,
      );
      expect(
        portable.preferences.entries.values.singleWhere(
          (r) => r['key'] == 'breeze.collection-cover.style.v1',
        )['value'],
        'glass',
      );
      // Simulate a brand new device: no local portable/settings revision journal.
      SharedPreferences.setMockInitialValues({
        'breeze.collection-cover.style.v1': 'mosaic',
      });
      _saveState(
        state.copyWith(
          syncSetting: state.syncSetting.copyWith(
            settingsSyncTime: DateTime.utc(2040).millisecondsSinceEpoch,
          ),
        ),
      );
      await manualDownloadFromCloud(
        state: state,
        archives: server.adapters(),
        codecs: _codecs,
        hooks: hooks,
      );
      expect(
        (await SharedPreferences.getInstance()).getString(
          'breeze.collection-cover.style.v1',
        ),
        'glass',
      );
    },
  );

  test(
    'upload metadata commit preserves edits made while network writes are pending',
    () async {
      final state = _state(settings: true).copyWith(dynamicColor: false);
      _saveState(state);
      final server = _Server();
      var edited = false;
      server.beforeWrite = (path) {
        if (edited || !path.contains('/settings_')) return;
        edited = true;
        final latest = objectbox.userSettingBox.get(1)!.globalSetting;
        _saveState(
          latest.copyWith(
            dynamicColor: true,
            maskedKeywords: ['during-upload'],
          ),
        );
      };
      await manualUploadToCloud(
        state: state,
        archives: server.adapters(),
        codecs: _codecs,
        hooks: hooks,
      );
      expect(edited, isTrue);
      final latest = objectbox.userSettingBox.get(1)!.globalSetting;
      expect(latest.dynamicColor, isTrue);
      expect(latest.maskedKeywords, ['during-upload']);
    },
  );

  test(
    'restore commits selected fields against latest state and retains an intervening local setting edit',
    () async {
      final state = _state(settings: true).copyWith(dynamicColor: true);
      _saveState(state);
      final server = _Server()
        ..payload(false, 'settings', {
          'version': 'v1',
          'schemaVersion': 'v2',
          'syncTime': 20,
          'blocks': {
            'appearance': {
              'updatedAt': 20,
              'data': {'dynamicColor': false},
            },
          },
        });
      var reads = 0;
      server.beforeRead = (path) {
        if (!path.contains('/settings_')) return;
        reads++;
        // The first read belongs to round preflight. The second is the actual
        // directed channel read, after its local baseline has been captured.
        if (reads == 2) {
          final current = objectbox.userSettingBox.get(1)!.globalSetting;
          _saveState(current.copyWith(maskedKeywords: ['during-read']));
        }
      };
      await manualDownloadFromCloud(
        state: state,
        archives: server.adapters(),
        codecs: _codecs,
        hooks: hooks,
      );
      final restored = objectbox.userSettingBox.get(1)!.globalSetting;
      expect(restored.dynamicColor, isFalse);
      expect(restored.maskedKeywords, ['during-read']);
    },
  );

  for (final direction in [SyncDirection.upload, SyncDirection.restore]) {
    test(
      'per-book reader preference follows $direction while records still merge',
      () async {
        final state = _state(settings: true);
        _saveState(state);
        objectbox.comicReadPreferenceBox.put(
          ComicReadPreference(
            uniqueKey: 'shipped:history',
            source: 'test',
            comicId: 'shipped:history',
            overridesJson: '{"readMode":1}',
            updatedAt: DateTime.utc(2040),
          ),
        );
        final server = _Server()
          ..payload(false, 'comic', _shippedComic(oldReadMode: true));
        if (direction == SyncDirection.upload) {
          await manualUploadToCloud(
            state: state,
            archives: server.adapters(),
            codecs: _codecs,
            hooks: hooks,
          );
        } else {
          await manualDownloadFromCloud(
            state: state,
            archives: server.adapters(),
            codecs: _codecs,
            hooks: hooks,
          );
        }
        final local = objectbox.comicReadPreferenceBox.getAll().single;
        expect(
          jsonDecode(local.overridesJson)['readMode'],
          direction == SyncDirection.upload ? 1 : 2,
        );
        final cloud =
            (server.active(false, 'comic')['readPreferences'] as List).single
                as Map;
        expect(
          jsonDecode(cloud['overridesJson'] as String)['readMode'],
          direction == SyncDirection.upload ? 1 : 2,
        );
        expect(
          objectbox.unifiedFavoriteBox.getAll().single.uniqueKey,
          'shipped:favorite',
        );
      },
    );
  }

  for (final columns in [3, 4]) {
    test(
      'plugin nickname and $columns-column format survive upload and restore',
      () async {
        final state = _state(settings: false, plugins: true);
        _saveState(state);
        objectbox.pluginConfigBox.put(
          PluginConfig(
            name: 'local-plugin',
            config: jsonEncode({
              'ui.displayName': '我的图源',
              'ui.categoryGridColumns': columns,
              'account.credentials': {
                'account': 'fixture',
                'password': 'synthetic',
              },
            }),
          ),
        );
        final server = _Server();
        await manualUploadToCloud(
          state: state,
          archives: server.adapters(),
          codecs: _codecs,
          hooks: hooks,
        );
        final row = objectbox.pluginConfigBox.getAll().single;
        row.config = jsonEncode({
          'ui.displayName': '本机另一备注',
          'ui.categoryGridColumns': 3,
        });
        objectbox.pluginConfigBox.put(row);
        await manualDownloadFromCloud(
          state: state,
          archives: server.adapters(),
          codecs: _codecs,
          hooks: hooks,
        );
        final restored = objectbox.pluginConfigBox.getAll().single;
        final config = jsonDecode(restored.config) as Map;
        expect(restored.name, 'local-plugin');
        expect(config['ui.displayName'], '我的图源');
        expect(config['ui.categoryGridColumns'], columns);
        expect(config['account.credentials'], {
          'account': 'fixture',
          'password': 'synthetic',
        });
      },
    );
  }

  test(
    'manual restore applies plugin enabled/order preferences without downgrading the installed executable',
    () async {
      final state = _state(plugins: true);
      _saveState(state);
      final existing = objectbox.pluginInfoBox.getAll().singleWhere(
        (p) => p.uuid == 'local-plugin',
      );
      existing.isEnabled = false;
      existing.sortOrder = 5;
      existing.updatedAt = DateTime.utc(2040);
      objectbox.pluginInfoBox.put(existing);
      final remoteInfo = {
        ...existing.toJson(),
        'isEnabled': true,
        'sortOrder': 1,
        'version': 'old-cloud-version',
        'originScript': 'older-cloud-script',
        'updatedAt': DateTime.utc(2020).toIso8601String(),
      }..remove('id');
      final server = _Server()
        ..payload(false, 'settings', {
          'version': 'v1',
          'schemaVersion': 'v2',
          'syncTime': 10,
          'blocks': {
            'plugins': {
              'updatedAt': 10,
              'data': {
                'pluginConfigs': <dynamic>[],
                'pluginInfos': [remoteInfo],
              },
            },
          },
        });
      await manualDownloadFromCloud(
        state: state,
        archives: server.adapters(),
        codecs: _codecs,
        hooks: hooks,
      );
      final restored = objectbox.pluginInfoBox.getAll().singleWhere(
        (p) => p.uuid == 'local-plugin',
      );
      expect(restored.isEnabled, isTrue);
      expect(restored.sortOrder, 1);
      expect(restored.version, existing.version);
      expect(restored.originScript, existing.originScript);
    },
  );
  test(
    'actual automatic round backs up accounts without importing or publishing unrelated settings',
    () async {
      final state = _state(settings: true, plugins: true);
      _saveState(state);
      final local = updatePluginConfigField(
        updatePluginConfigField(
          {},
          'public.preference',
          'local-only',
          nowMs: 100,
        ),
        'account.credentials',
        {'account': 'new-synthetic-account', 'password': 'synthetic-password'},
        nowMs: 20,
      );
      final remote = updatePluginConfigField(
        updatePluginConfigField(
          {},
          'public.preference',
          'cloud-kept',
          nowMs: 10,
        ),
        'account.credentials',
        {
          'account': 'old-synthetic-account',
          'password': 'old-synthetic-password',
        },
        nowMs: 10,
      );
      final configuration = PluginConfig(
        name: 'local-plugin',
        config: jsonEncode(local),
      );
      objectbox.pluginConfigBox.put(configuration);
      final cloud = _shippedSettings();
      final pluginData =
          ((cloud['blocks'] as Map)['plugins'] as Map)['data'] as Map;
      (pluginData['pluginConfigs'] as List).add({
        'name': 'local-plugin',
        'config': jsonEncode(remote),
      });
      final originalAppearance = jsonEncode(
        (cloud['blocks'] as Map)['appearance'],
      );
      final originalPluginInfo = jsonEncode(pluginData['pluginInfos']);
      final server = _Server()..payload(false, 'settings', cloud);
      await autoSync(
        state,
        archives: server.adapters(),
        codecs: _codecs,
        hooks: hooks,
      );
      final uploaded = server.active(false, 'settings');
      final uploadedPlugins =
          ((uploaded['blocks'] as Map)['plugins'] as Map)['data'] as Map;
      final uploadedConfiguration = jsonDecode(
        (uploadedPlugins['pluginConfigs'] as List).singleWhere(
              (row) => row['name'] == 'local-plugin',
            )['config']
            as String,
      );
      expect(
        uploadedConfiguration['account.credentials']['account'],
        'new-synthetic-account',
      );
      expect(uploadedConfiguration['public.preference'], 'cloud-kept');
      expect(jsonEncode(uploadedPlugins['pluginInfos']), originalPluginInfo);
      expect(
        jsonEncode((uploaded['blocks'] as Map)['appearance']),
        originalAppearance,
      );
      expect(
        objectbox.pluginConfigBox.get(configuration.id)!.config,
        jsonEncode(local),
      );
      expect(
        objectbox.userSettingBox.get(1)!.globalSetting.dynamicColor,
        state.dynamicColor,
      );
      final savedSettings = Map.fromEntries(
        server.saved().entries.where((e) => e.key.contains('/settings')),
      );
      final disabled = state.copyWith(
        syncSetting: state.syncSetting.copyWith(syncPlugins: false),
      );
      _saveState(disabled);
      configuration.config = jsonEncode(
        updatePluginConfigField(local, 'account.credentials', {
          'account': 'disabled-local',
        }, nowMs: 30),
      );
      objectbox.pluginConfigBox.put(configuration);
      await autoSync(
        disabled,
        archives: server.adapters(),
        codecs: _codecs,
        hooks: hooks,
      );
      expect(
        Map.fromEntries(
          server.saved().entries.where((e) => e.key.contains('/settings')),
        ),
        savedSettings,
      );
    },
  );
}
