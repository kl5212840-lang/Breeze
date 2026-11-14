import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/sync_service.dart'
    show runExclusiveStorageOperation;
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/discover/cubit/discover_cubit.dart';
import 'package:zephyr/plugin/plugin_install_service.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/src/rust/qjs.dart';

import '../test_helper.dart';

const _uuid = 'info-publication-test';

Uint8List _info(String version) => Uint8List.fromList(
  utf8.encode(jsonEncode({'uuid': _uuid, 'version': version})),
);

class _Api extends RustLibApi {
  final runtimes = <String, QjsRuntimeBuildRequest>{};
  final pendingInfos = <Completer<Uint8List>>[];
  final calls = <String>[];
  Completer<void>? dropGate;
  Completer<void>? dropStarted;

  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => runtimes.containsKey(name);

  @override
  Future<void> crateApiQjsBuildQjsRuntime({
    required QjsRuntimeBuildRequest request,
  }) async {
    runtimes[request.runtimeName] = request;
  }

  @override
  Future<bool> crateApiQjsQjsDropRuntime({required String runtimeName}) async {
    dropStarted?.complete();
    await dropGate?.future;
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
    if (runtimeName == 'global') return _info('new');
    if (fnPath != 'getInfo') return Uint8List.fromList(utf8.encode('{}'));
    final pending = Completer<Uint8List>();
    pendingInfos.add(pending);
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected native call: ${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = PluginRegistryService.I;
  late _Api api;

  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    api = _Api();
    RustLib.initMock(api: api);
    await service.init();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  Future<void> put(String version, {bool enabled = true}) async {
    final existing = objectbox.pluginInfoBox.getAll().firstOrNull;
    final now = DateTime.utc(2026);
    await service.upsert(
      PluginInfo(
        id: existing?.id ?? 0,
        uuid: _uuid,
        version: version,
        originScript: '$version bundle',
        insertedAt: now,
        updatedAt: now,
        isEnabled: enabled,
        isDeleted: false,
        lastLoadSuccess: false,
        debug: false,
        getInfoJson: '',
      ),
    );
  }

  Future<void> flush() async {
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() async {
    objectbox.pluginInfoBox.removeAll();
    api.pendingInfos.clear();
    api.calls.clear();
    api.runtimes.clear();
    api.dropGate = null;
    api.dropStarted = null;
    await service.refreshFromDb();
    await put('old');
    await flush();
  });

  for (final oldFails in [false, true]) {
    test(
      'replacement ignores late old ${oldFails ? 'error' : 'success'}',
      () async {
        final cubit = DiscoverCubit();
        await flush();
        expect(api.pendingInfos, hasLength(1));
        await put('new');
        await flush();
        // New bundle starts while the previous runtime call is still pending.
        expect(api.pendingInfos, hasLength(2));
        api.pendingInfos[1].complete(_info('new'));
        await flush();
        if (oldFails) {
          api.pendingInfos[0].completeError(StateError('runtime已关闭'));
        } else {
          api.pendingInfos[0].complete(_info('old'));
        }
        await flush();
        expect(cubit.state.infoStates[_uuid]!.data!['version'], 'new');
        expect(cubit.state.infoStates[_uuid]!.error, isNull);
        expect(service.getCachedPluginInfo(_uuid)!['version'], 'new');
        expect(
          jsonDecode(service.readPersistedGetInfoJson(_uuid))['version'],
          'new',
        );
        await cubit.close();
      },
    );
  }

  test('old completion cannot finish a new pending load', () async {
    final cubit = DiscoverCubit();
    await flush();
    await put('new');
    await flush();
    api.pendingInfos[0].complete(_info('old'));
    await flush();
    expect(cubit.state.infoStates[_uuid]!.loading, isTrue);
    expect(service.readPersistedGetInfoJson(_uuid), isEmpty);
    api.pendingInfos[1].complete(_info('new'));
    await flush();
    expect(cubit.state.infoStates[_uuid]!.data!['version'], 'new');
    await cubit.close();
  });

  test(
    'same-bundle explicit retry owns its result and remains retryable',
    () async {
      final cubit = DiscoverCubit();
      await flush();
      final retry = cubit.retryLoadInfo(_uuid);
      await flush();
      expect(api.pendingInfos, hasLength(2));
      api.pendingInfos[0].completeError(StateError('superseded call'));
      await flush();
      expect(cubit.state.infoStates[_uuid]?.error, isNull);
      api.pendingInfos[1].completeError(StateError('current failure'));
      await retry;
      expect(cubit.state.infoStates[_uuid]!.error, contains('current failure'));
      final secondRetry = cubit.retryLoadInfo(_uuid);
      await flush();
      api.pendingInfos[2].complete(_info('recovered'));
      await secondRetry;
      expect(cubit.state.infoStates[_uuid]!.error, isNull);
      expect(cubit.state.infoStates[_uuid]!.data!['version'], 'recovered');
      await cubit.close();
    },
  );

  for (final enabled in [false, true]) {
    test('enabled change preserves displayed metadata ($enabled)', () async {
      await put('old', enabled: !enabled);
      final cubit = DiscoverCubit();
      await flush();
      api.pendingInfos.single.complete(_info('displayed title'));
      await flush();
      final displayed = cubit.state.infoStates[_uuid]!;
      final changes = <DiscoverState>[];
      final subscription = cubit.stream.listen(changes.add);
      final callsBefore = api.calls.length;
      await service.setEnabled(_uuid, enabled, initialize: false);
      await flush();
      expect(cubit.state.plugins[_uuid]!.isEnabled, enabled);
      expect(cubit.state.infoStates[_uuid], same(displayed));
      expect(api.calls.length, callsBefore);
      expect(changes, isNotEmpty);
      for (final change in changes) {
        expect(change.infoStates[_uuid], same(displayed));
        expect(change.infoStates[_uuid]!.loading, isFalse);
      }
      await subscription.cancel();
      await cubit.close();
    });
  }

  test('enabled change replaces a pending load with no metadata', () async {
    final cubit = DiscoverCubit();
    await flush();
    expect(api.pendingInfos, hasLength(1));
    await service.setEnabled(_uuid, false, initialize: false);
    await flush();
    expect(api.pendingInfos, hasLength(2));
    expect(cubit.state.infoStates[_uuid]!.loading, isTrue);
    api.pendingInfos[0].completeError(StateError('runtime已关闭'));
    await flush();
    expect(cubit.state.infoStates[_uuid]!.loading, isTrue);
    expect(cubit.state.infoStates[_uuid]!.error, isNull);
    api.pendingInfos[1].complete(_info('current metadata'));
    await flush();
    expect(cubit.state.infoStates[_uuid]!.loading, isFalse);
    expect(cubit.state.infoStates[_uuid]!.data!['version'], 'current metadata');
    expect(cubit.state.plugins[_uuid]!.isEnabled, isFalse);
    expect(api.calls.where((call) => call.endsWith(':init')), isEmpty);
    await cubit.close();
  });

  test(
    'sync disable pauses only its source before dropping the runtime',
    () async {
      final previous = service.snapshot;
      final disabled = objectbox.pluginInfoBox.getAll().single
        ..isEnabled = false;
      objectbox.pluginInfoBox.put(disabled);
      const chapter = DownloadTaskJson(
        from: _uuid,
        comicId: 'work',
        comicName: 'Work',
        chapterRef: DownloadChapterTaskRef(chapterId: 'chapter'),
        imagePaths: ['checkpoint.png'],
      );
      final taskId = objectbox.downloadTaskBox.put(
        DownloadTask()..taskInfo = chapter,
      );
      final otherId = objectbox.downloadTaskBox.put(
        DownloadTask()..taskInfo = chapter.copyWith(from: 'other-source'),
      );
      api.runtimes[_uuid] = const QjsRuntimeBuildRequest(
        runtimeName: _uuid,
        injectFilesystem: false,
      );
      final dropGate = api.dropGate = Completer<void>();
      final dropStarted = api.dropStarted = Completer<void>();
      final reconcile = runExclusiveStorageOperation(
        () => service.reconcileAfterExternalSync(previousSnapshot: previous),
      );
      try {
        await dropStarted.future.timeout(const Duration(seconds: 3));
        final paused = objectbox.downloadTaskBox.get(taskId)!;
        expect(paused.isCompleted, isFalse);
        expect(paused.taskInfo!.stateCode, 'paused');
        expect(paused.taskInfo!.phaseCode, 'pluginDisabled');
        expect(paused.taskInfo!.imagePaths, chapter.imagePaths);
        expect(
          objectbox.downloadTaskBox.get(otherId)!.taskInfo!.stateCode,
          'queued',
        );
      } finally {
        dropGate.complete();
        await reconcile.timeout(const Duration(seconds: 3));
        objectbox.downloadTaskBox.removeMany([taskId, otherId]);
      }
    },
  );

  for (final changedField in ['originScript', 'version', 'debug', 'debugUrl']) {
    test(
      'registry rejects stale metadata after $changedField changes',
      () async {
        final pending = service.fetchPluginInfo(
          uuid: _uuid,
          runtimeName: _uuid,
        );
        await flush();
        final replacement = objectbox.pluginInfoBox.getAll().single;
        switch (changedField) {
          case 'originScript':
            replacement.originScript = 'replacement script';
          case 'version':
            replacement.version = 'replacement version';
          case 'debug':
            replacement.debug = true;
          case 'debugUrl':
            replacement.debugUrl = 'https://example.invalid/new.cjs';
        }
        replacement.getInfoJson = '{"version":"replacement"}';
        await service.upsert(replacement);
        api.pendingInfos.single.complete(_info('stale'));
        await pending;
        expect(service.getCachedPluginInfo(_uuid)!['version'], 'replacement');
        expect(
          jsonDecode(service.readPersistedGetInfoJson(_uuid))['version'],
          'replacement',
        );
        expect(service.getByUuid(_uuid)!.lastLoadSuccess, isFalse);
      },
    );
  }

  test('closed Discover does not receive an outstanding error', () async {
    final cubit = DiscoverCubit();
    await flush();
    await cubit.close();
    api.pendingInfos.single.completeError(StateError('runtime已关闭'));
    await flush();
    expect(cubit.isClosed, isTrue);
  });

  test('held replacement freezes only its uuid from the first await', () async {
    api.runtimes[_uuid] = const QjsRuntimeBuildRequest(
      runtimeName: _uuid,
      injectFilesystem: false,
    );
    api.dropGate = Completer<void>();
    api.dropStarted = Completer<void>();
    final publications = <Map<String, PluginRuntimeState>>[];
    final subscription = service.stream.listen(publications.add);
    final replacement = objectbox.pluginInfoBox.getAll().single
      ..version = 'new'
      ..originScript = 'new bundle';
    final installing = service.upsertAndSetEnabled(
      replacement,
      initialize: false,
    );
    // The upsert has already run, but even its first microtask boundary cannot
    // expose the replacement to another plugin's stream listener.
    expect(service.getByUuid(_uuid)!.version, 'new');
    expect(service.snapshot[_uuid]!.version, 'old');
    await api.dropStarted!.future;
    await flush();
    expect(publications, isEmpty);
    final now = DateTime.utc(2026);
    await service.upsert(
      PluginInfo(
        uuid: 'unrelated-plugin',
        version: 'other',
        originScript: 'other bundle',
        insertedAt: now,
        updatedAt: now,
        isEnabled: false,
        isDeleted: false,
        lastLoadSuccess: false,
        debug: false,
      ),
    );
    await service.updateLoadResult('unrelated-plugin', success: true);
    await flush();
    expect(publications, hasLength(2));
    expect(service.snapshot['unrelated-plugin']!.lastLoadSuccess, isTrue);
    expect(publications.last['unrelated-plugin']!.lastLoadSuccess, isTrue);
    for (final published in publications) {
      expect(published[_uuid]!.version, 'old');
    }
    expect(service.snapshot[_uuid]!.version, 'old');
    api.dropGate!.complete();
    await installing;
    await flush();
    expect(service.snapshot[_uuid]!.version, 'new');
    expect(
      publications.where((item) => item[_uuid]!.version == 'new'),
      hasLength(1),
    );
    expect(api.calls, isEmpty);
    await subscription.cancel();
  });

  for (final enabled in [false, true]) {
    test('maintenance publishes only after drop settles ($enabled)', () async {
      await put('old', enabled: enabled);
      await flush();
      api.runtimes[_uuid] = const QjsRuntimeBuildRequest(
        runtimeName: _uuid,
        injectFilesystem: false,
      );
      api.dropGate = Completer<void>();
      api.dropStarted = Completer<void>();
      final publications = <Map<String, PluginRuntimeState>>[];
      final subscription = service.stream.listen(publications.add);
      final install = PluginInstallService.I.savePluginByScript(
        'new bundle',
        sourceLabel: 'publication test',
        allowReplaceExisting: true,
        expectedUuid: _uuid,
        initialize: false,
      );
      await api.dropStarted!.future;
      await flush();
      expect(publications, isEmpty);
      expect(api.runtimes.containsKey(_uuid), isTrue);
      api.dropGate!.complete();
      await install;
      await flush();
      expect(publications, hasLength(1));
      expect(publications.single[_uuid]!.version, 'new');
      expect(publications.single[_uuid]!.isEnabled, enabled);
      expect(api.runtimes.containsKey(_uuid), isFalse);
      expect(api.calls, ['global:getInfo']);
      await subscription.cancel();
    });
  }
}
