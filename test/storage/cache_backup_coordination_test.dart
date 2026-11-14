import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/setting/cache/cache_setting_page.dart';
import 'package:zephyr/page/setting/data_backup/method.dart';
import 'package:zephyr/service/cache_workspace_guard.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/util/manage_cache.dart';
import 'package:zephyr/util/get_path.dart';
import 'package:zephyr/widgets/toast.dart';

import '../test_helper.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationCachePath() async => path;
  @override
  Future<String?> getTemporaryPath() async => path;
  @override
  Future<String?> getApplicationSupportPath() async =>
      p.join(p.dirname(path), 'support');
}

class _CacheApi extends RustLibApi {
  @override
  String crateApiSimpleEncodePath({required String path}) =>
      path == 'other-source-fixture' ? 'f_202' : 'f_101';
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _CannotDelete extends Fake implements File {
  @override
  String get path => '/synthetic-cache/private-fixture';
  @override
  Future<File> delete({bool recursive = false}) async =>
      throw const FileSystemException(
        'synthetic failure containing PRIVATE_MARKER',
      );
}

class _FailingCache extends Fake implements Directory {
  _FailingCache(this.path);
  @override
  final String path;
  @override
  Future<bool> exists() async => true;
  @override
  List<FileSystemEntity> listSync({
    bool recursive = false,
    bool followLinks = true,
  }) => [_CannotDelete()];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root, cache;
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: _CacheApi());
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('cache_backup_guard_');
    cache = await Directory(p.join(root.path, 'cache')).create();
    await Directory(p.join(cache.path, 'f_101')).create();
    await File(p.join(cache.path, 'f_101', 'image.tmp')).writeAsString('cached');
    final previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(cache.path);
    addTearDown(() => PathProviderPlatform.instance = previous);
    objectbox.pluginInfoBox.removeAll();
    objectbox.pluginInfoBox.put(PluginInfo(
      uuid: 'source-fixture', version: '1', originScript: '',
      insertedAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026),
      isEnabled: true, isDeleted: false, lastLoadSuccess: true, debug: false,
    ));
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  test('real cache helpers count exactly the removable source files and preserve persistent images', () async {
    Future<File> sentinel(String path, String value) async {
      final file = File(path);
      await file.parent.create(recursive: true);
      return file.writeAsString(value);
    }
    final files = await getFilePath();
    final downloads = await getDownloadPath();
    final protected = <File>[
      await sentinel(p.join(files, 'appearance-local', 'avatar.jpg'), 'custom avatar'),
      await sentinel(p.join(files, 'appearance-local', 'background.jpg'), 'custom background'),
      await sentinel(p.join(files, 'appearance-local', 'cover-protection.jpg'), 'protection image'),
      await sentinel(p.join(files, 'video-download-covers', 'work.png'), 'download poster'),
      await sentinel(p.join(downloads, 'video-v1', 'resource.mp4'), 'downloaded movie'),
      await sentinel(p.join(downloads, 'f_101', 'comic.jpg'), 'downloaded comic'),
      await sentinel(p.join(cache.path, 'backup-private-v1', 'archive'), 'backup workspace'),
      await sentinel(p.join(cache.path, 'breeze-video-staging', 'pending.mp4'), 'active download'),
      await sentinel(p.join(cache.path, 'f_999', 'unattributed'), 'unknown owner'),
    ];
    final image = await sentinel(p.join(cache.path, 'f_101', 'avatar.jpg'), 'remote avatar');
    final other = await sentinel(p.join(cache.path, 'f_202', 'poster.jpg'), 'other source');
    objectbox.pluginInfoBox.put(PluginInfo(
      uuid: 'other-source-fixture', version: '1', originScript: '',
      insertedAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026),
      isEnabled: true, isDeleted: false, lastLoadSuccess: true, debug: false,
    ));
    final sourceBytes = 6 + await image.length();
    final otherBytes = await other.length();
    expect(await imageCacheSize(await getCachePath(), source: 'source-fixture'), sourceBytes);
    expect(await imageCacheSize(await getCachePath()), sourceBytes + otherBytes);
    await clearCache(await getCachePath(), source: 'source-fixture');
    expect(await image.exists(), isFalse);
    expect(await other.exists(), isTrue);
    expect(await imageCacheSize(await getCachePath(), source: 'source-fixture'), 0);
    expect(await imageCacheSize(await getCachePath()), otherBytes);
    // Startup's automatic cleanup calls this same global helper after its
    // autoCleanCache/needCleanCache gate; no wider filesystem sweep is used.
    await clearCache(await getCachePath());
    expect(await other.exists(), isFalse);
    expect(await imageCacheSize(await getCachePath()), 0);
    for (final file in protected) {
      expect(await file.exists(), isTrue, reason: p.basename(file.path));
    }
  });

  test(
    'active backup prevents any cache deletion; release preserves sentry and independent data',
    () async {
      await Directory(p.join(cache.path, 'sentry')).create();
      await File(
        p.join(cache.path, 'sentry', 'pending-event'),
      ).writeAsString('keep');
      final downloads = await Directory(
        p.join(root.path, 'downloads'),
      ).create();
      final original = await File(
        p.join(downloads.path, 'page.jpg'),
      ).writeAsString('download');
      final backup = await File(
        p.join(root.path, 'saved.zip'),
      ).writeAsString('saved backup');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('account.fixture', 'synthetic credentials');
      final lease = CacheWorkspaceGuard.acquire();
      try {
        await expectLater(
          clearCache(cache.path),
          throwsA(isA<CacheWorkspaceBusy>()),
        );
        expect(
          await File(p.join(cache.path, 'f_101', 'image.tmp')).readAsString(),
          'cached',
        );
      } finally {
        lease.release();
        lease.release();
      }
      await clearCache(cache.path);
      expect(await File(p.join(cache.path, 'f_101', 'image.tmp')).exists(), isFalse);
      expect(
        await File(
          p.join(cache.path, 'sentry', 'pending-event'),
        ).readAsString(),
        'keep',
      );
      expect(await original.readAsString(), 'download');
      expect(await backup.readAsString(), 'saved backup');
      expect(prefs.getString('account.fixture'), 'synthetic credentials');
    },
  );

  test(
    'cleanup also prevents a new backup lease until its own operation ends',
    () async {
      final started = Completer<void>(), release = Completer<void>();
      final cleaning = CacheWorkspaceGuard.clear(() async {
        started.complete();
        await release.future;
      });
      await started.future;
      try {
        expect(CacheWorkspaceGuard.acquire, throwsA(isA<CacheWorkspaceBusy>()));
        await expectLater(
          clearCache(cache.path),
          throwsA(isA<CacheWorkspaceBusy>()),
        );
      } finally {
        release.complete();
        await cleaning;
      }
      final lease = CacheWorkspaceGuard.acquire();
      lease.release();
      await clearCache(cache.path);
    },
  );

  test(
    'failed staging releases its lease and an unsupported root is reported safely',
    () async {
      await expectLater(
        CacheWorkspaceGuard.withWorkspace<void>(() async {
          throw StateError('synthetic backup failure');
        }),
        throwsStateError,
      );
      await clearCache(cache.path);
      final failed = IOOverrides.runZoned(
        () => clearCache('/synthetic-cache'),
        createDirectory: (path) => _FailingCache(path),
      );
      await expectLater(
        failed,
        throwsA(
          isA<CacheCleanupFailed>().having(
            (error) => error.toString(),
            'safe message',
            t.cache.clearFailed,
          ),
        ),
      );
      final lease = CacheWorkspaceGuard.acquire();
      lease.release();
    },
  );

  test(
    'actual extracted import owns its staging until its asynchronous reads complete',
    () async {
      final extract = await Directory(
        p.join(cache.path, 'import', 'extract'),
      ).create(recursive: true);
      await File(
        p.join(extract.path, 'config.json'),
      ).writeAsString('{"includeDownloads":false}');
      await File(
        p.join(extract.path, 'objectbox.json'),
      ).writeAsString(objectbox.collectAllDataJson(removeIds: true));
      final importing = importExtractedBreezeData(extract.path, mode: BackupImportMode.restore);
      await expectLater(
        clearCache(cache.path),
        throwsA(isA<CacheWorkspaceBusy>()),
      );
      await importing.timeout(const Duration(seconds: 10));
      expect(await extract.exists(), isTrue);
      await clearCache(cache.path);
      expect(await extract.exists(), isTrue);
    },
  );

  testWidgets(
    'real cache page reports backup busy and never reports a successful clear',
    (tester) async {
      final previous = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _Paths(cache.path);
      addTearDown(() => PathProviderPlatform.instance = previous);
      final events = <ToastEvent>[];
      final subscription = eventBus.on<ToastEvent>().listen(events.add);
      addTearDown(subscription.cancel);
      final lease = CacheWorkspaceGuard.acquire();
      addTearDown(lease.release);
      await tester.pumpWidget(
        BlocProvider(
          create: (_) => GlobalSettingCubit(),
          child: const MaterialApp(home: CacheSettingPage()),
        ),
      );
      Future<void> wait(bool Function() ready) async {
        for (var i = 0; i < 100; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 20));
          if (ready()) return;
        }
        fail('cache page did not finish its bounded operation');
      }

      await wait(
        () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
      );
      await tester.tap(find.text(t.cache.clearCache));
      await wait(() => find.byType(AlertDialog).evaluate().isNotEmpty);
      expect(find.text(t.cache.clearCacheConfirm), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(t.cache.clear),
        ),
      );
      await wait(
        () => events.any((event) => event.message == t.cache.backupBusy),
      );
      expect(events.any((event) => event.message == t.cache.cleared), isFalse);
      expect(
        await tester.runAsync(
          () => File(p.join(cache.path, 'f_101', 'image.tmp')).exists(),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('global cache retries a failed size read and shows the limit only when enabled', (
    tester,
  ) async {
    final validPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(
      p.join(cache.path, 'f_101', 'image.tmp'),
    );
    addTearDown(() => PathProviderPlatform.instance = validPaths);
    final cubit = GlobalSettingCubit();
    addTearDown(cubit.close);
    cubit.updateCacheSetting((_) => const CacheSettingState());
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(home: CacheSettingPage()),
      ),
    );
    Future<void> waitFor(Finder finder) async {
      for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(finder, findsOneWidget);
    }

    final retry = find.byTooltip(t.cache.recalculate);
    await waitFor(find.text(t.cache.calculateFailed));
    expect(retry, findsOneWidget);
    expect(find.text(t.cache.browsingData), findsNothing);
    final auto = find.text(t.cache.autoClean);
    final limit = find.text(t.cache.sizeLimit);
    expect(find.text(t.cache.autoCleanSubtitle), findsOneWidget);
    expect(limit, findsNothing);

    PathProviderPlatform.instance = validPaths;
    await tester.tap(retry);
    await waitFor(find.text('6 B'));
    expect(retry, findsNothing);
    await tester.tap(auto);
    await tester.pumpAndSettle();
    expect(limit, findsOneWidget);
    expect(tester.getTopLeft(limit).dy, greaterThan(tester.getTopLeft(auto).dy));
    await tester.tap(limit);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 GB'));
    await tester.pumpAndSettle();
    expect(cubit.state.cacheSetting.cacheSizeLimit, 2147483648);
    await tester.tap(auto);
    await tester.pumpAndSettle();
    expect(limit, findsNothing);
    expect(cubit.state.cacheSetting.cacheSizeLimit, 2147483648);
    await tester.tap(auto);
    await tester.pumpAndSettle();
    expect(limit, findsOneWidget);
    expect(find.text('2 GB'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('auto clean defaults off and stale pending flags cannot bypass it', () async {
    expect(const CacheSettingState().autoCleanCache, isFalse);
    expect(CacheSettingState.fromJson({}).autoCleanCache, isFalse);
    expect(shouldCleanCacheOnStartup(const GlobalSettingState(needCleanCache: true), 2), isFalse);
    expect(shouldCleanCacheOnStartup(const GlobalSettingState(
      cacheSetting: CacheSettingState(autoCleanCache: true, cacheSizeLimit: 2),
    ), 2), isTrue);
    expect(shouldCleanCacheOnStartup(const GlobalSettingState(
      needCleanCache: true, cacheSetting: CacheSettingState(autoCleanCache: true, cacheSizeLimit: 3),
    ), 2), isFalse);
    final cubit = GlobalSettingCubit();
    addTearDown(cubit.close);
    cubit.updateState((state) => state.copyWith(
      needCleanCache: true, cacheSetting: const CacheSettingState(autoCleanCache: true),
    ));
    cubit.updateCacheSetting((state) => state.copyWith(autoCleanCache: false));
    expect(cubit.state.needCleanCache, isFalse);
    expect(shouldCleanCacheOnStartup(cubit.state, 2), isFalse);
  });

  testWidgets('disabled auto cleaning ignores even a one-byte limit and cancels pending cleanup', (tester) async {
    final cubit = GlobalSettingCubit();
    addTearDown(cubit.close);
    cubit.updateState((state) => state.copyWith(
      needCleanCache: true,
      cacheSetting: const CacheSettingState(autoCleanCache: false, cacheSizeLimit: 1),
    ));
    late BuildContext host;
    await tester.pumpWidget(BlocProvider.value(
      value: cubit,
      child: MaterialApp(home: Builder(builder: (context) {
        host = context;
        return const SizedBox.shrink();
      })),
    ));
    await manageCacheSize(host);
    expect(cubit.state.needCleanCache, isFalse);
    expect(await tester.runAsync(() => File(p.join(cache.path, 'f_101', 'image.tmp')).exists()), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('first startup above the current limit clears only known image cache', (tester) async {
    final cubit = GlobalSettingCubit();
    addTearDown(cubit.close);
    cubit.updateCacheSetting((state) => state.copyWith(autoCleanCache: true, cacheSizeLimit: 1));
    expect(cubit.state.needCleanCache, isFalse);
    late BuildContext host;
    await tester.pumpWidget(BlocProvider.value(value: cubit,
      child: MaterialApp(home: Builder(builder: (context) {
        host = context;
        return const SizedBox.shrink();
      })),
    ));
    await tester.runAsync(() async {
      final unclassified = File(p.join(cache.path, 'keep.tmp'));
      await unclassified.writeAsString('protected');
      await manageCacheSize(host);
      expect(await File(p.join(cache.path, 'f_101', 'image.tmp')).exists(), isFalse);
      expect(await unclassified.readAsString(), 'protected');
    });
    expect(cubit.state.needCleanCache, isFalse);
  });

  test('public cleanup rejects a download root even with a matching source partition', () async {
    final download = File(p.join(root.path, 'downloads', 'f_101', 'page'));
    await download.parent.create(recursive: true);
    await download.writeAsString('download');
    await expectLater(clearCache(download.parent.parent.path), throwsA(isA<CacheCleanupFailed>()));
    expect(await download.readAsString(), 'download');
  });

  testWidgets('source cache shows image size and updates it after confirmed clear', (tester) async {
    await tester.pumpWidget(BlocProvider(
      create: (_) => GlobalSettingCubit(),
      child: const MaterialApp(home: CacheSettingPage(source: 'source-fixture')),
    ));
    for (var i = 0; i < 100 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text(t.cache.sourceTitle), findsOneWidget);
    expect(find.text(t.cache.cacheSize), findsOneWidget);
    expect(find.text('6 B'), findsOneWidget);
    expect(find.text(t.cache.browsingData), findsNothing);
    expect(find.byTooltip(t.cache.recalculate), findsNothing);
    expect(find.text(t.cache.autoClean), findsNothing);
    expect(find.text(t.cache.sizeLimit), findsNothing);
    await tester.tap(find.text(t.cache.clearCache));
    await tester.pumpAndSettle();
    expect(find.text(t.cache.sourceClearConfirm), findsOneWidget);
    await tester.tap(find.text(t.common.cancel));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(() => File(p.join(cache.path, 'f_101', 'image.tmp')).exists()), isTrue);

    await tester.tap(find.text(t.cache.clearCache));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.cache.clear));
    for (var i = 0; i < 100 && find.text('0 B').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text('0 B'), findsOneWidget);
    expect(await tester.runAsync(() => File(p.join(cache.path, 'f_101', 'image.tmp')).exists()), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
