import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:objectbox/objectbox.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/plugin/qjs_network_route.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/plugin/plugin_install_service.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/service/download/download_task_repository.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/plugin_account_data_clear.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/src/rust/qjs.dart';

import '../test_helper.dart';

const _source = 'dynamic-local-lifecycle-source';

class _Api extends RustLibApi {
  final runtimes = <String, QjsRuntimeBuildRequest>{};
  final calls = <String>[];
  bool failBuild = false;
  Completer<void>? dropStarted, dropGate;

  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => runtimes.containsKey(name);
  @override
  Future<void> crateApiQjsBuildQjsRuntime({
    required QjsRuntimeBuildRequest request,
  }) async {
    if (failBuild && canonicalQjsSource(request.runtimeName) == _source)
      throw StateError('fixture runtime build failure');
    runtimes[request.runtimeName] = request;
  }

  @override
  Future<bool> crateApiQjsQjsDropRuntime({required String runtimeName}) async {
    if (canonicalQjsSource(runtimeName) == _source) {
      if (dropStarted?.isCompleted == false) dropStarted!.complete();
      await dropGate?.future;
    }
    return runtimes.remove(runtimeName) != null;
  }

  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode(runtimes[runtimeName]?.bundle?.bundleName);
  @override
  Future<Uint8List> crateApiQjsQjsTaskCall({
    required String runtimeName,
    required String taskGroupKey,
    required bool isOnce,
    String? bundleJs,
    String? bundleUrl,
    required String fnPath,
    required String argsJson,
  }) async {
    calls.add('$runtimeName:$fnPath');
    return Uint8List.fromList(
      utf8.encode(
        fnPath == 'getInfo' ? '{"uuid":"$_source","version":"2"}' : '{}',
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected native call: ${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final registry = PluginRegistryService.I;
  final local = LocalPluginInstallationState.instance;
  late _Api api;
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    api = _Api();
    RustLib.initMock(api: api);
    await registry.init();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await local.reload();
    objectbox.pluginInfoBox.removeAll();
    objectbox.pluginConfigBox.removeAll();
    objectbox.downloadTaskBox.removeAll();
    objectbox.comicFollowBox.removeAll();
    TestObjectBoxHelper.cleanComicFolderBoxes();
    api.runtimes.clear();
    api.calls.clear();
    api.failBuild = false;
    api.dropStarted = api.dropGate = null;
    final now = DateTime.utc(2026);
    await registry.upsert(
      PluginInfo(
        uuid: _source,
        version: '1',
        originScript: 'retained fixture bundle',
        insertedAt: now,
        updatedAt: now,
        isEnabled: true,
        isDeleted: false,
        lastLoadSuccess: true,
        debug: false,
      ),
    );
    objectbox.pluginConfigBox.put(
      PluginConfig(
        name: _source,
        config: '{"account":"fixture","setting":true}',
      ),
    );
    api.runtimes[_source] = const QjsRuntimeBuildRequest(
      runtimeName: _source,
      injectFilesystem: false,
    );
  });

  Future<void> reinstall({bool initialize = false}) => PluginInstallService.I
      .savePluginByScript(
        'new fixture bundle',
        sourceLabel: 'offline fixture',
        expectedUuid: _source,
        allowReplaceExisting: true,
        initialize: initialize,
      )
      .then((_) {});

  test(
    'ordinary removal keeps records, source settings and exact downloaded bytes',
    () async {
      final file = File('${TestObjectBoxHelper.tempPath}/retained-image.jpg');
      await file.writeAsBytes([1, 2, 3, 4]);
      final favorite = createTestFavorite('$_source:comic')..source = _source;
      final history = createTestHistory('$_source:comic')..source = _source;
      final download = createTestDownload(
        '$_source:comic',
        storageRoot: file.parent.path,
      )..source = _source;
      objectbox.unifiedFavoriteBox.put(favorite);
      objectbox.unifiedHistoryBox.put(history);
      objectbox.unifiedDownloadBox.put(download);
      final now = DateTime.utc(2026);
      objectbox.comicFollowBox.put(
        ComicFollow(
          uniqueKey: '$_source:comic',
          source: _source,
          comicId: 'comic',
          title: 'fixture',
          description: '',
          cover: '',
          creator: '',
          titleMeta: '',
          metadata: '',
          lastChapterCount: 1,
          detectedChapterCount: 2,
          hasUpdate: true,
          updateTime: now,
          deleted: false,
          createdAt: now,
          updatedAt: now,
          schemaVersion: 1,
        ),
      );
      final task = DownloadTask()
        ..comicId = 'comic'
        ..comicName = 'fixture'
        ..taskInfo = DownloadTaskJson(
          from: _source,
          comicId: 'comic',
          comicName: 'fixture',
          chapterRef: const DownloadChapterTaskRef(chapterId: 'chapter'),
          imagePaths: [file.path],
          completedImages: 1,
          totalImages: 2,
        );
      objectbox.downloadTaskBox.put(task);
      final pluginBefore = objectbox.pluginInfoBox.getAll().single.toJson();
      final configBefore = objectbox.pluginConfigBox.getAll().single.toJson();
      // Compare durable before/after values: ObjectBox stores millisecond UTC
      // instants and reads local DateTimes, independent of the caller objects.
      final dataBefore = [
        objectbox.unifiedFavoriteBox.get(favorite.id)!.toJson(),
        objectbox.unifiedHistoryBox.get(history.id)!.toJson(),
        objectbox.unifiedDownloadBox.get(download.id)!.toJson(),
        objectbox.comicFollowBox.getAll().single.toJson(),
      ];
      await registry.deletePlugin(_source);
      expect(local.isRemoved(_source), isTrue);
      expect(registry.getByUuid(_source)!.isDeleted, isTrue);
      expect(registry.activePlugins(), isEmpty);
      expect(api.runtimes.containsKey(_source), isFalse);
      expect(objectbox.pluginInfoBox.getAll().single.toJson(), pluginBefore);
      expect(objectbox.pluginConfigBox.getAll().single.toJson(), configBefore);
      expect([
        objectbox.unifiedFavoriteBox.getAll().single.toJson(),
        objectbox.unifiedHistoryBox.getAll().single.toJson(),
        objectbox.unifiedDownloadBox.getAll().single.toJson(),
        objectbox.comicFollowBox.getAll().single.toJson(),
      ], dataBefore);
      final paused = objectbox.downloadTaskBox.get(task.id)!;
      expect(paused.isCompleted, isFalse);
      expect(paused.isDownloading, isFalse);
      expect(paused.taskInfo!.stateCode, 'paused');
      expect(paused.taskInfo!.imagePaths, [file.path]);
      expect(paused.taskInfo!.completedImages, 1);
      expect(await file.readAsBytes(), [1, 2, 3, 4]);
      // Paused records can be cleared independently without deleting their files.
      await const DownloadTaskRepository().removeRecords([task.id]);
      expect(objectbox.downloadTaskBox.get(task.id), isNull);
      expect(await file.readAsBytes(), [1, 2, 3, 4]);
      await file.delete();
    },
  );

  test(
    'export keeps active plugin and configuration despite device-only removal',
    () async {
      await registry.deletePlugin(_source);
      final plan = await prepareSettingsArchiveImport(
        null,
        state: const GlobalSettingState(),
        includeAll: true,
      );
      final rows = plan.compatibilityPayload['pluginInfos'] as List;
      expect(rows.single['uuid'], _source);
      expect(rows.single['isDeleted'], isFalse);
      expect(rows.single['originScript'], 'retained fixture bundle');
      expect(plan.compatibilityPayload['pluginConfigs'], isNotEmpty);
      expect(
        jsonEncode(plan.compatibilityPayload),
        isNot(contains(LocalPluginInstallationState.storageKey)),
      );
    },
  );

  test(
    'ordinary sync refresh cannot reinstall a locally removed source',
    () async {
      await registry.deletePlugin(_source);
      final incoming = objectbox.pluginInfoBox.getAll().single
        ..version = 'remote-newer'
        ..updatedAt = DateTime.utc(2099);
      objectbox.pluginInfoBox.put(incoming);
      await registry.reconcileAfterExternalSync();
      expect(registry.getByUuid(_source)!.version, 'remote-newer');
      expect(registry.getByUuid(_source)!.isDeleted, isTrue);
      expect(registry.activePlugins(), isEmpty);
      expect(api.runtimes.containsKey(_source), isFalse);
      expect(api.calls.where((call) => call == '$_source:init'), isEmpty);
    },
  );

  test(
    'successful explicit install clears removal but keeps personal-data exclusions',
    () async {
      await registry.deletePlugin(_source);
      await local.setDataExclusions(_source, {
        PluginDataScope.records,
      }, beforeWrite: (_) async {});
      final epoch = local.installationEpoch(_source);
      await reinstall();
      expect(local.isRemoved(_source), isFalse);
      expect(local.isDataExcluded(_source, PluginDataScope.records), isTrue);
      expect(local.installationEpoch(_source), epoch + 1);
      expect(registry.getByUuid(_source)!.isDeleted, isFalse);
      expect(registry.getByUuid(_source)!.isEnabled, isTrue);
      expect(
        objectbox.pluginConfigBox.getAll().single.config,
        '{"account":"fixture","setting":true}',
      );
    },
  );

  test(
    'failed explicit install preserves removal, raw plugin and account settings',
    () async {
      await registry.deletePlugin(_source);
      final pluginBefore = objectbox.pluginInfoBox.getAll().single.toJson();
      final configsBefore = objectbox.pluginConfigBox
          .getAll()
          .map((row) => row.toJson())
          .toList();
      final prefs = await SharedPreferences.getInstance();
      final markerBefore = prefs.getString(
        LocalPluginInstallationState.storageKey,
      );
      api.failBuild = true;
      await expectLater(reinstall(initialize: true), throwsStateError);
      expect(local.isRemoved(_source), isTrue);
      expect(local.isInstalling(_source), isFalse);
      expect(objectbox.pluginInfoBox.getAll().single.toJson(), pluginBefore);
      expect(
        objectbox.pluginConfigBox.getAll().map((row) => row.toJson()).toList(),
        configsBefore,
      );
      expect(
        prefs.getString(LocalPluginInstallationState.storageKey),
        markerBefore,
      );
      expect(registry.getByUuid(_source)!.isDeleted, isTrue);
    },
  );

  test(
    'reinstall does not undo a separately confirmed personal-data deletion',
    () async {
      await registry.deletePlugin(_source);
      final epoch = await local.setDataExclusions(_source, {
        PluginDataScope.records,
        PluginDataScope.accountSettings,
      }, beforeWrite: (_) async {});
      final clear = preparePluginAccountDataClear(
        _source,
        cloudDelete: true,
        expectedEpoch: epoch,
      );
      objectbox.store.runInTransaction(TxMode.write, clear.persistDatabase);
      final deletedFavorite = createTestFavorite(
        '$_source:deleted-comic',
        deleted: true,
      )..source = _source;
      objectbox.unifiedFavoriteBox.put(deletedFavorite);
      final favoriteBefore = objectbox.unifiedFavoriteBox
          .get(deletedFavorite.id)!
          .toJson();
      final configBefore = objectbox.pluginConfigBox.getAll().single.config;
      await reinstall();
      expect(local.isRemoved(_source), isFalse);
      expect(
        local.isDataExcluded(_source, PluginDataScope.accountSettings),
        isTrue,
      );
      expect(objectbox.pluginConfigBox.getAll().single.config, configBefore);
      final config = jsonDecode(configBefore) as Map<String, dynamic>;
      expect(config.containsKey('account'), isFalse);
      expect(
        (config['__breezeSyncFields'] as Map)['account']['deleted'],
        isTrue,
      );
      expect(
        objectbox.unifiedFavoriteBox.getAll().single.toJson(),
        favoriteBefore,
      );
    },
  );

  test(
    'remove finishing after explicit install starts cannot publish an old removal',
    () async {
      api.dropStarted = Completer<void>();
      api.dropGate = Completer<void>();
      final removal = registry.deletePlugin(_source);
      final rejectedRemoval = expectLater(
        removal,
        throwsA(isA<PluginLifecycleChanged>()),
      );
      await api.dropStarted!.future.timeout(const Duration(seconds: 3));
      final installing = reinstall();
      expect(local.isInstalling(_source), isTrue);
      api.dropGate!.complete();
      await rejectedRemoval;
      await installing;
      expect(local.isRemoved(_source), isFalse);
      expect(registry.getByUuid(_source)!.isDeleted, isFalse);
      expect(objectbox.pluginInfoBox.getAll().single.version, '2');
    },
  );

  test(
    'confirmation from an old installation cannot remove a successful reinstall',
    () async {
      final confirmedEpoch = local.installationEpoch(_source);
      await reinstall();
      await expectLater(
        registry.deletePlugin(
          _source,
          expectedInstallationEpoch: confirmedEpoch,
        ),
        throwsA(isA<PluginLifecycleChanged>()),
      );
      expect(local.isRemoved(_source), isFalse);
      expect(registry.getByUuid(_source)!.isDeleted, isFalse);
    },
  );
}
