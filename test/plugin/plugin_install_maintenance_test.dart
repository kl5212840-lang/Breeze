import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart';
import 'package:zephyr/network/sync/sync_service.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/plugin/plugin_install_service.dart';
import 'package:zephyr/plugin/plugin_host_compatibility.dart';
import 'package:zephyr/page/plugin_store/cubit/plugin_store_cubit.dart';
import 'package:zephyr/page/plugin_store/models/cloud_plugin_item.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/network/http/plugin/qjs_network_route.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/plugin/plugin_cloud_update_service.dart';
import 'package:zephyr/plugin/utils/plugin_catalog_merge.dart';
import 'package:zephyr/plugin/utils/published_plugin_artifact.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/comic_follow/comic_follow_chapter_reader.dart';
import 'package:zephyr/src/rust/api/http.dart' as rust_http;
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/src/rust/qjs.dart';

import '../test_helper.dart';

const _uuid = 'maintenance-install-test';
const _releaseUrl = 'https://fixture.invalid/releases/latest';
const _assetUrl = 'https://fixture.invalid/update.cjs';
const _managedUuid = 'e9f18928-3ba8-4d86-a12e-b53a62f47933';
const _firstPartyRoot =
    'https://raw.githubusercontent.com/$personalPluginCatalogRepository/main';
const _formalCatalog = '$_firstPartyRoot/catalog/v1/plugins_data.json';
const _formalIndex = '$_firstPartyRoot/updates/v1/bika.json';
const _formalAsset =
    'https://github.com/$personalPluginCatalogRepository/releases/download/plugins-fixture/Bika-v0.1.2.cjs';
const _legacySource = 'previous publicly distributed bundle';
const _formalSource = 'official versioned bundle';

class _HttpClient implements rust_http.HttpClient {
  _HttpClient(this.request);
  final Future<String> Function(String) request;

  @override
  Future<rust_http.FetchResponse> fetch({
    required String url,
    rust_http.FetchInit? init,
  }) async => rust_http.FetchResponse(
    status: 200,
    statusText: 'OK',
    ok: true,
    headers: const {},
    body: Uint8List.fromList(utf8.encode(await request(url))),
    url: url,
    redirected: false,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Api extends RustLibApi {
  final runtimes = <String, QjsRuntimeBuildRequest>{};
  final calls = <String>[];
  final dropped = <String>[];
  bool failBuild = false;
  Map<String, dynamic>? getInfoOverride;
  Map<String, dynamic>? detailOverride;
  final detailCalls = <Map<String, dynamic>>[];
  final initGates = <String, Completer<Uint8List>>{};
  Future<Uint8List> Function()? oldBundleInfo;
  late Future<String> Function(String) request;

  @override
  rust_http.HttpClient crateApiHttpHttpClientCreate({
    rust_http.HttpClientOptions? options,
  }) => _HttpClient(request);

  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => runtimes.containsKey(name);

  @override
  Future<void> crateApiQjsBuildQjsRuntime({
    required QjsRuntimeBuildRequest request,
  }) async {
    if (failBuild && canonicalQjsSource(request.runtimeName) == _uuid) {
      throw StateError('fixture build failure');
    }
    runtimes[request.runtimeName] = request;
  }

  @override
  Future<bool> crateApiQjsQjsDropRuntime({required String runtimeName}) async {
    dropped.add(runtimeName);
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
    if (fnPath == 'getComicDetail' && detailOverride != null) {
      detailCalls.add(jsonDecode(argsJson) as Map<String, dynamic>);
      return Uint8List.fromList(utf8.encode(jsonEncode(detailOverride)));
    }
    if (fnPath == 'init' && initGates.containsKey(runtimeName)) {
      return initGates[runtimeName]!.future;
    }
    if (fnPath == 'getInfo' &&
        bundleJs == 'old bundle' &&
        oldBundleInfo != null) {
      return oldBundleInfo!();
    }
    return Uint8List.fromList(
      utf8.encode(
        fnPath == 'getInfo'
            ? jsonEncode(getInfoOverride ?? {'uuid': _uuid, 'version': '0.1.4'})
            : '{}',
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected native call: ${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Api api;
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    api = _Api();
    RustLib.initMock(api: api);
    await PluginRegistryService.I.init();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  Future<void> seed({required bool enabled, bool debug = false}) async {
    objectbox.pluginInfoBox.removeAll();
    objectbox.pluginConfigBox.removeAll();
    final now = DateTime.utc(2026);
    await PluginRegistryService.I.upsert(
      PluginInfo(
        uuid: _uuid,
        version: '0.1.3',
        originScript: 'old bundle',
        insertedAt: now,
        updatedAt: now,
        isEnabled: enabled,
        isDeleted: false,
        lastLoadSuccess: true,
        sortOrder: 7,
        debug: debug,
        debugUrl: 'https://example.invalid/debug.cjs',
      ),
    );
    objectbox.pluginConfigBox.put(
      PluginConfig(name: _uuid, config: '{"fixture":"unchanged"}'),
    );
    api.failBuild = false;
    api.getInfoOverride = null;
    api.detailOverride = null;
    api.detailCalls.clear();
    api.oldBundleInfo = null;
    api.request = (url) async => throw StateError('Unexpected HTTP URL: $url');
    PluginHostCompatibilityNotices.instance.takePending();
    await dropQjsRuntimesForPlugin(_uuid);
    api.calls.clear();
    api.dropped.clear();
    api.initGates.clear();
    api.runtimes[_uuid] = const QjsRuntimeBuildRequest(
      runtimeName: _uuid,
      injectFilesystem: false,
    );
  }

  Future<void> update({bool initialize = true}) async {
    await PluginInstallService.I.savePluginByScript(
      'new bundle',
      sourceLabel: 'test fixture',
      expectedUuid: _uuid,
      allowReplaceExisting: true,
      initialize: initialize,
    );
  }

  void serveUpdateAsset(FutureOr<String> Function() download) {
    api.request = (url) async {
      if (url == _releaseUrl) {
        return jsonEncode({
          'tag_name': '0.1.4',
          'assets': [
            {'name': 'update.cjs', 'browser_download_url': _assetUrl},
          ],
        });
      }
      expect(url, _assetUrl);
      return download();
    };
  }

  CloudPluginItem catalogItem() => CloudPluginItem.fromJson({
    'repo': 'fixture/source',
    'manifest': {'uuid': _uuid, 'version': '0.1.4', 'updateUrl': _releaseUrl},
  });

  for (final enabled in [false, true]) {
    test(
      'maintenance preserves state/config and invalidates runtime ($enabled)',
      () async {
        await seed(enabled: enabled, debug: true);
        final configBefore = objectbox.pluginConfigBox.getAll().single.toJson();
        await update(initialize: false);
        final saved = objectbox.pluginInfoBox.getAll().single;
        expect(saved.version, '0.1.4');
        expect(saved.originScript, 'new bundle');
        expect(saved.isEnabled, enabled);
        expect(saved.debug, isTrue);
        expect(saved.debugUrl, 'https://example.invalid/debug.cjs');
        expect(saved.sortOrder, 7);
        expect(saved.insertedAt.toUtc(), DateTime.utc(2026));
        expect(
          objectbox.pluginConfigBox.getAll().single.toJson(),
          configBefore,
        );
        expect(api.calls, ['global:getInfo']);
        expect(api.dropped, contains(_uuid));
        expect(api.runtimes.containsKey(_uuid), isFalse);
      },
    );
  }

  test(
    'ordinary update keeps a disabled plugin disabled without init',
    () async {
      await seed(enabled: false);
      await update();
      expect(PluginRegistryService.I.getByUuid(_uuid)!.isEnabled, isFalse);
      expect(api.calls, ['global:getInfo']);
    },
  );

  test('default enabled update still initializes immediately', () async {
    await seed(enabled: true);
    await update();
    await Future<void>.delayed(Duration.zero);
    expect(PluginRegistryService.I.getByUuid(_uuid)!.isEnabled, isTrue);
    expect(api.calls.any((call) => call.endsWith(':init')), isTrue);
  });

  test(
    'self-channel download cannot replace a later reinstall of the same bundle',
    () async {
      await seed(enabled: false);
      final registry = PluginRegistryService.I;
      final initial = objectbox.pluginInfoBox.getAll().single
        ..getInfoJson = jsonEncode({'updateUrl': _releaseUrl});
      await registry.upsert(initial);

      final downloadStarted = Completer<void>();
      final download = Completer<String>();
      serveUpdateAsset(() {
        downloadStarted.complete();
        return download.future;
      });

      final sync = PluginCloudUpdateService.I.syncPluginFromSelfChannel(_uuid);
      final rejected = expectLater(
        sync,
        throwsA(isA<PluginLifecycleChanged>()),
      );
      await downloadStarted.future.timeout(const Duration(seconds: 3));
      await registry.deletePlugin(_uuid);
      api.getInfoOverride = {
        'uuid': _uuid,
        'version': '0.1.3',
        'updateUrl': _releaseUrl,
      };
      await PluginInstallService.I.savePluginByScript(
        'old bundle',
        sourceLabel: 'fixture reinstall',
        expectedUuid: _uuid,
        allowReplaceExisting: true,
        initialize: false,
      );
      api.getInfoOverride = null;
      download.complete('stale update bundle');
      await rejected;

      final saved = objectbox.pluginInfoBox.getAll().single;
      expect(saved.version, '0.1.3');
      expect(saved.originScript, 'old bundle');
      expect(registry.isLocallyRemoved(_uuid), isFalse);
      expect(jsonDecode(saved.getInfoJson)['updateUrl'], _releaseUrl);
    },
  );

  test('old self-channel metadata cannot write over a newer bundle', () async {
    await seed(enabled: false);
    final readingStarted = Completer<void>();
    final oldInfo = Completer<Uint8List>();
    api.oldBundleInfo = () {
      readingStarted.complete();
      return oldInfo.future;
    };
    final sync = PluginCloudUpdateService.I.syncPluginFromSelfChannel(_uuid);
    final rejected = expectLater(sync, throwsA(isA<PluginLifecycleChanged>()));
    await readingStarted.future.timeout(const Duration(seconds: 3));
    await update(initialize: false);
    oldInfo.complete(
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'uuid': _uuid,
            'version': '0.1.3',
            'updateUrl': _releaseUrl,
          }),
        ),
      ),
    );
    await rejected;

    final saved = objectbox.pluginInfoBox.getAll().single;
    expect(saved.originScript, 'new bundle');
    expect(jsonDecode(saved.getInfoJson)['version'], '0.1.4');
    expect(jsonDecode(saved.getInfoJson).containsKey('updateUrl'), isFalse);
  });

  test(
    'cloud store rejects a downloaded UUID different from the selected listing',
    () async {
      await seed(enabled: false);
      final before = objectbox.pluginInfoBox.getAll().single.toJson();
      serveUpdateAsset(() => 'different source bundle');
      api.getInfoOverride = {'uuid': 'different-source', 'version': '0.1.4'};

      await expectLater(
        PluginInstallService.I.installFromCloud(catalogItem()),
        throwsStateError,
      );

      expect(objectbox.pluginInfoBox.getAll().single.toJson(), before);
    },
  );

  test(
    'catalog install keeps the old plugin when the advertised version differs',
    () async {
      await seed(enabled: false);
      final before = objectbox.pluginInfoBox.getAll().single.toJson();
      serveUpdateAsset(() => 'different version bundle');
      api.getInfoOverride = {'uuid': _uuid, 'version': '0.1.5'};

      await expectLater(
        PluginInstallService.I.installFromCloud(catalogItem()),
        throwsStateError,
      );
      expect(objectbox.pluginInfoBox.getAll().single.toJson(), before);
    },
  );

  test(
    'catalog checksum is verified before executing a downloaded script',
    () async {
      await seed(enabled: false);
      final before = objectbox.pluginInfoBox.getAll().single.toJson();
      serveUpdateAsset(() => 'wrong asset');
      final item = CloudPluginItem.fromJson({
        'repo': 'fixture/source',
        'manifest': {
          'uuid': _uuid,
          'version': '0.1.4',
          'updateUrl': _releaseUrl,
          'scriptSha256': sha256
              .convert(utf8.encode('published asset'))
              .toString(),
        },
      });
      await expectLater(
        PluginInstallService.I.installFromCloud(item),
        throwsStateError,
      );
      expect(api.calls, isEmpty);
      expect(objectbox.pluginInfoBox.getAll().single.toJson(), before);
    },
  );

  test(
    'a self-update index checksum also protects the installed bundle',
    () async {
      await seed(enabled: false);
      final installed = objectbox.pluginInfoBox.getAll().single
        ..getInfoJson = jsonEncode({'updateUrl': _releaseUrl});
      await PluginRegistryService.I.upsert(installed);
      final before = objectbox.pluginInfoBox.getAll().single.toJson();
      api.request = (url) async {
        if (url == _releaseUrl) {
          return jsonEncode({
            'tag_name': 'v0.1.4',
            'scriptSha256': sha256
                .convert(utf8.encode('verified bundle'))
                .toString(),
            'assets': [
              {'name': 'update.cjs', 'browser_download_url': _assetUrl},
            ],
          });
        }
        expect(url, _assetUrl);
        return 'changed payload';
      };
      await expectLater(
        PluginCloudUpdateService.I.syncPluginFromSelfChannel(_uuid),
        throwsStateError,
      );
      expect(api.calls, isEmpty);
      expect(objectbox.pluginInfoBox.getAll().single.toJson(), before);
    },
  );

  test(
    'manual install rechecks the original bundle in the storage queue',
    () async {
      await seed(enabled: false);
      final registry = PluginRegistryService.I;
      final entered = Completer<void>();
      final release = Completer<void>();
      final competingUpdate = runExclusiveStorageOperation(() async {
        entered.complete();
        await release.future;
        final next = objectbox.pluginInfoBox.getAll().single
          ..version = '0.1.5'
          ..originScript = 'newer queued bundle';
        await registry.upsertAndSetEnabled(next, initialize: false);
      });
      await entered.future;
      final pending = PluginInstallService.I.savePluginByScript(
        '0.1.4 bundle',
        sourceLabel: 'local replacement',
        expectedUuid: _uuid,
        allowReplaceExisting: true,
        initialize: false,
      );
      final rejected = expectLater(
        pending,
        throwsA(isA<PluginLifecycleChanged>()),
      );
      try {
        // Complete candidate inspection while the competing writer owns the queue.
        await Future<void>.delayed(Duration.zero);
        expect(api.calls, contains('global:getInfo'));
      } finally {
        release.complete();
      }
      await competingUpdate;
      await rejected;
      expect(registry.getByUuid(_uuid)?.originScript, 'newer queued bundle');

      // A new explicit file update is allowed to roll back the settled version.
      await PluginInstallService.I.installFromLocalBytes(
        utf8.encode('intentional 0.1.4 rollback'),
        fileName: 'plugin.cjs',
        expectedUuid: _uuid,
        allowReplaceExisting: true,
      );
      expect(registry.getByUuid(_uuid)?.version, '0.1.4');
      expect(
        registry.getByUuid(_uuid)?.originScript,
        'intentional 0.1.4 rollback',
      );
    },
  );

  test(
    'a new catalog UUID installs and follows through its declared contract',
    () async {
      await seed(enabled: false);
      const source = '2fa52435-3d4e-4651-a8e6-62eb59855db3';
      const bundle =
          'module.exports={getInfo:()=>({uuid:"$source",version:"1.0.0",breezeExperience:{comicFollow:1}})}';
      api.getInfoOverride = {
        'uuid': source,
        'version': '1.0.0',
        'breezeExperience': {'comicFollow': 1},
      };
      api.detailOverride = {
        'data': {
          'normal': {
            'comicInfo': {'id': 'sample'},
            'extern': {
              'comicFollow': {
                'chapterCount': 2,
                'latestChapterId': 'chapter-two',
                'latestChapterTitle': 'Second chapter',
              },
            },
          },
        },
      };
      final catalog = [
        {
          'repo': 'kl5212840-lang/Breeze-plugins',
          'manifest': {
            'uuid': source,
            'name': 'Future comic source',
            'version': '1.0.0',
            'updateUrl': _releaseUrl,
            'scriptSha256': sha256.convert(utf8.encode(bundle)).toString(),
          },
        },
      ];
      api.request = (url) async {
        if (url.endsWith('/catalog/v1/plugins_data.json'))
          return jsonEncode(catalog);
        if (url.endsWith('/plugins_data.json') || url.endsWith('/plugin-list'))
          return '[]';
        if (url == _releaseUrl) {
          return jsonEncode({
            'tag_name': 'v1.0.0',
            'assets': [
              {'name': 'future.cjs', 'browser_download_url': _assetUrl},
            ],
          });
        }
        expect(url, _assetUrl);
        return bundle;
      };
      final store = PluginStoreCubit();
      addTearDown(store.close);
      await store.loadCloudPlugins();
      final item = store.state.cloudPlugins.singleWhere(
        (item) => item.manifest.uuid == source,
      );
      await PluginInstallService.I.installFromCloud(item);
      expect(PluginRegistryService.I.getByUuid(source)?.version, '1.0.0');
      final time = DateTime.utc(2026, 11, 12);
      final result = await ComicFollowChapterReader().detect(
        ComicFollow(
          uniqueKey: '$source:sample',
          source: source,
          comicId: 'sample',
          title: 'Tracked sample',
          description: '',
          cover: '',
          creator: '',
          titleMeta: '',
          metadata: '',
          lastChapterCount: 1,
          detectedChapterCount: 1,
          hasUpdate: false,
          updateTime: time,
          deleted: false,
          createdAt: time,
          updatedAt: time,
          schemaVersion: 1,
        ),
      );
      expect(result?.chapterCount, 2);
      expect(result?.latestChapterTitle, 'Second chapter');
      expect(api.detailCalls.single, {
        'comicId': 'sample',
        'extern': {'comicFollow': true},
      });
    },
  );

  for (final entry in ['cloud store', 'known source URL']) {
    test(
      '$entry download cannot overwrite a newer self-channel update',
      () async {
        await seed(enabled: false);
        final registry = PluginRegistryService.I;
        const selfRelease = 'https://fixture.invalid/self-release';
        const selfAsset = 'https://fixture.invalid/self-update.cjs';
        final installed = objectbox.pluginInfoBox.getAll().single
          ..getInfoJson = jsonEncode({'updateUrl': selfRelease});
        await registry.upsert(installed);
        final epoch = LocalPluginInstallationState.instance.installationEpoch(
          _uuid,
        );
        final account = objectbox.pluginConfigBox.getAll().single.toJson();
        final started = Completer<void>();
        final staleAsset = Completer<String>();
        String release(String version, String url) => jsonEncode({
          'tag_name': version,
          'assets': [
            {'name': 'update.cjs', 'browser_download_url': url},
          ],
        });
        api.request = (url) async {
          if (url == _releaseUrl) return release('0.1.4', _assetUrl);
          if (url == selfRelease) return release('0.1.5', selfAsset);
          if (url == selfAsset) return 'newer self-channel bundle';
          expect(url, _assetUrl);
          started.complete();
          return staleAsset.future;
        };
        final pending = entry == 'cloud store'
            ? PluginInstallService.I.installFromCloud(catalogItem())
            : PluginInstallService.I.installFromNetworkUrl(
                _assetUrl,
                expectedUuid: _uuid,
                allowReplaceExisting: true,
              );
        final rejected = expectLater(
          pending,
          throwsA(isA<PluginLifecycleChanged>()),
        );
        await started.future.timeout(const Duration(seconds: 3));
        api.getInfoOverride = {'uuid': _uuid, 'version': '0.1.5'};
        expect(
          await PluginCloudUpdateService.I.syncPluginFromSelfChannel(_uuid),
          isTrue,
        );
        expect(
          LocalPluginInstallationState.instance.installationEpoch(_uuid),
          epoch,
          reason: 'self-channel update replaces the bundle in place',
        );
        api.getInfoOverride = null;
        staleAsset.complete('stale catalog bundle');
        await rejected;

        final saved = objectbox.pluginInfoBox.getAll().single;
        expect(saved.originScript, 'newer self-channel bundle');
        expect(saved.version, '0.1.5');
        expect(saved.isEnabled, isFalse);
        expect(objectbox.pluginConfigBox.getAll().single.toJson(), account);
      },
    );

    test('$entry download cannot reverse a later removal', () async {
      await seed(enabled: false);
      final registry = PluginRegistryService.I;
      final downloadStarted = Completer<void>();
      final download = Completer<String>();
      serveUpdateAsset(() {
        downloadStarted.complete();
        return download.future;
      });
      final install = entry == 'cloud store'
          ? PluginInstallService.I.installFromCloud(catalogItem())
          : PluginInstallService.I.installFromNetworkUrl(
              _assetUrl,
              expectedUuid: _uuid,
              allowReplaceExisting: true,
            );
      final rejected = expectLater(
        install,
        throwsA(isA<PluginLifecycleChanged>()),
      );
      await downloadStarted.future.timeout(const Duration(seconds: 3));
      await registry.deletePlugin(_uuid);
      download.complete('stale update bundle');

      try {
        await rejected;
        expect(registry.isLocallyRemoved(_uuid), isTrue);
        expect(
          objectbox.pluginInfoBox.getAll().single.originScript,
          'old bundle',
        );
        expect(api.calls, isEmpty);
        if (entry == 'cloud store') {
          serveUpdateAsset(() => 'new reinstall bundle');
          await PluginInstallService.I.installFromCloud(catalogItem());
          expect(registry.isLocallyRemoved(_uuid), isFalse);
          expect(
            objectbox.pluginInfoBox.getAll().single.originScript,
            'new reinstall bundle',
          );
        }
      } finally {
        await LocalPluginInstallationState.instance
            .completeExplicitInstallation(_uuid);
        await registry.refreshFromDb();
      }
    });
  }

  test(
    'arbitrary URL discovers the script UUID and rejects a duplicate',
    () async {
      await seed(enabled: false);
      const discovered = 'new-source-from-url';
      serveUpdateAsset(() => 'new arbitrary source bundle');
      api.getInfoOverride = {'uuid': discovered, 'version': '0.1.4'};
      await PluginInstallService.I.installFromNetworkUrl(_assetUrl);
      expect(PluginRegistryService.I.getByUuid(discovered)?.version, '0.1.4');

      await expectLater(
        PluginInstallService.I.installFromNetworkUrl(_assetUrl),
        throwsStateError,
      );
    },
  );

  test('maintenance rejects an unexpected identity before writing', () async {
    await seed(enabled: true);
    final before = objectbox.pluginInfoBox.getAll().single.toJson();
    await expectLater(
      PluginInstallService.I.savePluginByScript(
        'new bundle',
        sourceLabel: 'test fixture',
        expectedUuid: 'different-plugin',
        allowReplaceExisting: true,
        initialize: false,
      ),
      throwsStateError,
    );
    expect(objectbox.pluginInfoBox.getAll().single.toJson(), before);
    expect(api.dropped, isEmpty);
  });

  test(
    'unsupported getInfo candidate keeps old script, state, runtime and account config',
    () async {
      await seed(enabled: true);
      final before = objectbox.pluginInfoBox.getAll().single.toJson();
      final config = objectbox.pluginConfigBox.getAll().single.toJson();
      api.getInfoOverride = {
        'uuid': _uuid,
        'version': '0.2.0',
        'name': 'Future plugin',
        'function': [
          {
            'action': {
              'type': 'openVideoLibrary',
              'payload': {'protocol': 3},
            },
          },
        ],
      };
      await expectLater(
        update(),
        throwsA(isA<PluginHostCompatibilityException>()),
      );
      expect(objectbox.pluginInfoBox.getAll().single.toJson(), before);
      expect(objectbox.pluginConfigBox.getAll().single.toJson(), config);
      expect(api.calls, ['global:getInfo']);
      expect(api.dropped, isEmpty);
      expect(
        PluginHostCompatibilityNotices.instance.takePending().single.name,
        'Future plugin',
      );
    },
  );

  test(
    'unsupported declared cloud requirement refuses before download or candidate script evaluation',
    () async {
      await seed(enabled: true);
      final before = objectbox.pluginInfoBox.getAll().single.toJson();
      final item = CloudPluginItem.fromJson({
        'repo': 'fixture/source',
        'manifest': {
          'uuid': _uuid,
          'version': '0.2.0',
          'updateUrl': 'https://example.invalid/plugin.json',
          'requirements': {'version': 2, 'capabilities': {}},
        },
      });
      await expectLater(
        PluginInstallService.I.installFromCloud(item),
        throwsA(isA<PluginHostCompatibilityException>()),
      );
      expect(api.calls, isEmpty);
      expect(api.dropped, isEmpty);
      expect(objectbox.pluginInfoBox.getAll().single.toJson(), before);
    },
  );

  test('maintenance defers init until normal use of the new script', () async {
    await seed(enabled: true);
    await update(initialize: false);
    expect(api.calls, ['global:getInfo']);
    await ensureQjsRuntimeReady(pluginId: _uuid);
    expect(api.calls.any((call) => call.endsWith(':init')), isTrue);
    expect(
      api.runtimes.values.where(
        (request) =>
            canonicalQjsSource(request.runtimeName) == _uuid &&
            request.bundle?.bundleJs == 'new bundle',
      ),
      isNotEmpty,
    );
  });

  Future<void> flush() async {
    for (var i = 0; i < 12; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test(
    'replacement rejects a late old VM config write and retains account fields',
    () async {
      await seed(enabled: true);
      final oldRuntime = await ensureQjsRuntimeReady(
        pluginId: _uuid,
        initialize: false,
      );
      savePluginConfigValueSync(_uuid, 'account', 'saved-account');
      savePluginConfigValueSync(_uuid, 'token', 'saved-token');
      final lateWrite = Completer<void>();
      final oldPromise = lateWrite.future.then(
        (_) => onSavePluginConfig(oldRuntime, 'token', '"stale-token"'),
      );
      await update();
      await flush();
      final rejected = expectLater(
        oldPromise,
        throwsA(isA<PluginSessionChanged>()),
      );
      lateWrite.complete();
      await rejected;
      expect(
        loadPluginConfigValue(_uuid, 'account', fallback: ''),
        'saved-account',
      );
      expect(
        loadPluginConfigValue(_uuid, 'token', fallback: ''),
        'saved-token',
      );
      final currentRuntime = await ensureQjsRuntimeReady(
        pluginId: _uuid,
        initialize: false,
      );
      expect(currentRuntime, isNot(oldRuntime));
      onSavePluginConfig(currentRuntime, 'token', '"current-token"');
      expect(
        loadPluginConfigValue(_uuid, 'token', fallback: ''),
        'current-token',
      );
      final generation = pluginSessionWriteFence.generation(_uuid);
      expect(
        await ensureQjsRuntimeReady(pluginId: _uuid, initialize: false),
        currentRuntime,
      );
      savePluginConfigValueSync(_uuid, 'preference', true);
      expect(pluginSessionWriteFence.generation(_uuid), generation);
    },
  );

  test(
    'ordinary shared update rolls back script and config on preparation failure',
    () async {
      await seed(enabled: true);
      final beforeInfo = objectbox.pluginInfoBox.getAll().single.toJson();
      final beforeConfig = objectbox.pluginConfigBox.getAll().single.toJson();
      final replacement = objectbox.pluginInfoBox.getAll().single
        ..version = 'broken'
        ..originScript = 'broken bundle';
      api.failBuild = true;
      await expectLater(
        PluginRegistryService.I.upsertAndSetEnabled(replacement),
        throwsStateError,
      );
      api.failBuild = false;
      expect(objectbox.pluginInfoBox.getAll().single.toJson(), beforeInfo);
      expect(objectbox.pluginConfigBox.getAll().single.toJson(), beforeConfig);
      expect(
        PluginRegistryService.I.snapshot[_uuid]!.originScript,
        'old bundle',
      );
    },
  );

  for (final oldFails in [false, true]) {
    test(
      'retired init cannot overwrite replacement status (failure=$oldFails)',
      () async {
        await seed(enabled: true);
        final registry = PluginRegistryService.I;
        final old = registry.getByUuid(_uuid)!;
        final runtime = await ensureQjsRuntimeReady(
          pluginId: _uuid,
          initialize: false,
        );
        final gate = Completer<Uint8List>();
        api.initGates[runtime] = gate;
        await registry.runPluginInitIfNeeded(old, runtimeName: _uuid);
        await flush();
        expect(api.calls, contains('$runtime:init'));
        await update(initialize: false);
        await registry.updateLoadResult(_uuid, success: oldFails);
        if (oldFails) {
          gate.completeError(StateError('old init failed'));
        } else {
          gate.complete(Uint8List.fromList(utf8.encode('{}')));
        }
        await flush();
        final current = registry.getByUuid(_uuid)!;
        expect(current.version, '0.1.4');
        expect(current.lastLoadSuccess, oldFails);
        expect(current.lastLoadError, isNull);
      },
    );
  }

  test(
    'shared registry compatibility rejection leaves source VM and account config untouched',
    () async {
      await seed(enabled: true);
      final beforeInfo = objectbox.pluginInfoBox.getAll().single.toJson();
      final beforeConfig = objectbox.pluginConfigBox.getAll().single.toJson();
      final beforeRuntime = api.runtimes[_uuid];
      final beforeGeneration = pluginSessionWriteFence.generation(_uuid);
      final replacement = objectbox.pluginInfoBox.getAll().single
        ..version = 'future'
        ..originScript = 'future bundle'
        ..getInfoJson = jsonEncode({
          'requirements': {
            'version': 1,
            'capabilities': {'videoLibraryProtocol': 3},
          },
        });
      await expectLater(
        PluginRegistryService.I.upsertAndSetEnabled(replacement),
        throwsA(isA<PluginHostCompatibilityException>()),
      );
      expect(objectbox.pluginInfoBox.getAll().single.toJson(), beforeInfo);
      expect(objectbox.pluginConfigBox.getAll().single.toJson(), beforeConfig);
      expect(api.runtimes[_uuid], same(beforeRuntime));
      expect(pluginSessionWriteFence.generation(_uuid), beforeGeneration);
      expect(api.calls, isEmpty);
      expect(api.dropped, isEmpty);
    },
  );

  test(
    'local script compatibility rejection retains installed script and config',
    () async {
      await seed(enabled: true);
      final beforeInfo = objectbox.pluginInfoBox.getAll().single.toJson();
      final beforeConfig = objectbox.pluginConfigBox.getAll().single.toJson();
      final beforeGeneration = pluginSessionWriteFence.generation(_uuid);
      api.getInfoOverride = {
        'uuid': _uuid,
        'version': 'future',
        'requirements': {
          'version': 1,
          'capabilities': {'videoLibraryProtocol': 3},
        },
      };
      await expectLater(
        update(),
        throwsA(isA<PluginHostCompatibilityException>()),
      );
      expect(objectbox.pluginInfoBox.getAll().single.toJson(), beforeInfo);
      expect(objectbox.pluginConfigBox.getAll().single.toJson(), beforeConfig);
      expect(pluginSessionWriteFence.generation(_uuid), beforeGeneration);
      expect(api.calls, ['global:getInfo']);
      expect(api.dropped, isEmpty);
      expect(api.runtimes[_uuid], isNotNull);
    },
  );

  test(
    'cloud manifest compatibility rejection stops before download or VM work',
    () async {
      await seed(enabled: true);
      final beforeInfo = objectbox.pluginInfoBox.getAll().single.toJson();
      final beforeConfig = objectbox.pluginConfigBox.getAll().single.toJson();
      final item = CloudPluginItem.fromJson({
        'repo': 'fixture/source',
        'manifest': {
          'uuid': _uuid,
          'version': 'future',
          'updateUrl': 'https://example.invalid/future.json',
          'requirements': {
            'version': 1,
            'capabilities': {'videoLibraryProtocol': 3},
          },
        },
      });
      await expectLater(
        PluginInstallService.I.installFromCloud(item, expectedUuid: _uuid),
        throwsA(isA<PluginHostCompatibilityException>()),
      );
      expect(objectbox.pluginInfoBox.getAll().single.toJson(), beforeInfo);
      expect(objectbox.pluginConfigBox.getAll().single.toJson(), beforeConfig);
      expect(api.calls, isEmpty);
      expect(api.dropped, isEmpty);
    },
  );

  test(
    'explicit reinstall stamps a new installation after a future deletion',
    () async {
      await seed(enabled: false);
      final deleted = objectbox.pluginInfoBox.getAll().single;
      final deletionClock = DateTime.utc(2099);
      final previousInstallation = DateTime.utc(2100);
      deleted
        ..isDeleted = true
        ..isEnabled = false
        ..originScript = ''
        ..insertedAt = previousInstallation
        ..deletedAt = deletionClock
        ..updatedAt = deletionClock;
      await PluginRegistryService.I.upsert(deleted);
      objectbox.pluginConfigBox.removeAll();
      await update(initialize: false);
      final saved = objectbox.pluginInfoBox.getAll().single;
      expect(saved.isDeleted, isFalse);
      expect(saved.deletedAt, isNull);
      expect(saved.insertedAt.isAfter(deletionClock), isTrue);
      expect(saved.insertedAt.isAfter(previousInstallation), isTrue);
      expect(saved.updatedAt.isBefore(saved.insertedAt), isFalse);
      expect(
        PluginRegistryService.I.getByUuid(_uuid)!.insertedAt,
        saved.insertedAt,
      );
      expect(api.calls, ['global:getInfo']);
    },
  );

  group('first-party release migration', () {
    Map<String, dynamic> metadata(String oldVersion) => {
      'uuid': _managedUuid,
      'releaseSeries': 1,
      'scriptSha256': publishedPluginScriptSha256(_formalSource),
      'migrationFrom': [
        {
          'version': oldVersion,
          'scriptSha256': publishedPluginScriptSha256(_legacySource),
        },
      ],
    };

    Map<String, dynamic> catalog(String oldVersion) => {
      'repo': personalPluginCatalogRepository,
      'manifest': {
        ...metadata(oldVersion),
        'version': '0.1.2',
        'updateUrl': _formalIndex,
      },
    };

    Future<void> seedManaged({
      String version = '0.1.11',
      String script = _legacySource,
    }) async {
      SharedPreferences.setMockInitialValues({});
      await LocalPluginInstallationState.instance.reload();
      await seed(enabled: false);
      objectbox.pluginInfoBox.removeAll();
      objectbox.pluginConfigBox.removeAll();
      final now = DateTime.utc(2026);
      await PluginRegistryService.I.upsert(
        PluginInfo(
          uuid: _managedUuid,
          version: version,
          originScript: script,
          insertedAt: now,
          updatedAt: now,
          isEnabled: false,
          isDeleted: false,
          lastLoadSuccess: true,
          sortOrder: 8,
          debug: false,
        ),
      );
      objectbox.pluginConfigBox.put(
        PluginConfig(name: _managedUuid, config: '{"account":"saved"}'),
      );
      await PluginRegistryService.I.refreshFromDb();
      api.getInfoOverride = {
        'uuid': _managedUuid,
        'version': '0.1.2',
        'updateUrl': _formalIndex,
        'releaseSeries': 1,
      };
    }

    List<String> serveMigration({
      String oldVersion = '0.1.11',
      Map<String, dynamic> indexOverrides = const {},
      FutureOr<String> Function()? asset,
    }) {
      final requests = <String>[];
      api.request = (url) async {
        requests.add(url);
        if (url == _formalCatalog) return jsonEncode([catalog(oldVersion)]);
        if (url == _formalIndex) {
          return jsonEncode({
            ...metadata(oldVersion),
            'tag_name': 'v0.1.2',
            'assets': [
              {'name': 'Bika-v0.1.2.cjs', 'browser_download_url': _formalAsset},
            ],
            ...indexOverrides,
          });
        }
        if (url.endsWith(_formalAsset)) {
          return asset == null ? _formalSource : await asset();
        }
        return '[{"manifest":{"uuid":"upstream"}}]';
      };
      return requests;
    }

    Future<CloudPluginItem> readStoreItem() async {
      final store = PluginStoreCubit();
      try {
        await store.loadCloudPlugins();
        return store.state.cloudPlugins.singleWhere(
          (item) => item.manifest.uuid == _managedUuid,
        );
      } finally {
        await store.close();
      }
    }

    test(
      'store replaces an exact higher-numbered old bundle and keeps state',
      () async {
        await seedManaged(script: '\n$_legacySource\n');
        final requests = serveMigration();
        final before = objectbox.pluginInfoBox.getAll().single;
        final config = objectbox.pluginConfigBox.getAll().single.toJson();
        expect(
          await PluginInstallService.I.installFromCloud(await readStoreItem()),
          '更新成功',
        );
        final after = objectbox.pluginInfoBox.getAll().single;
        expect(after.id, before.id);
        expect(after.originScript, _formalSource);
        expect(after.version, '0.1.2');
        expect(after.isEnabled, isFalse);
        expect(after.sortOrder, before.sortOrder);
        expect(after.insertedAt, before.insertedAt);
        expect(objectbox.pluginConfigBox.getAll().single.toJson(), config);
        expect(requests.where((url) => url == _formalIndex), hasLength(1));
      },
    );

    test(
      'explicit cloud reinstall replaces unlisted internal bytes in place',
      () async {
        await seedManaged(version: '0.3.22', script: 'internal build');
        serveMigration();
        final item = await readStoreItem();
        final before = objectbox.pluginInfoBox.getAll().single;
        final config = objectbox.pluginConfigBox.getAll().single.toJson();

        await expectLater(
          PluginInstallService.I.installFromCloud(item),
          throwsStateError,
        );
        await expectLater(
          PluginInstallService.I.installFromCloud(
            CloudPluginItem.fromJson(catalog('0.1.11')),
            reinstall: true,
          ),
          throwsStateError,
        );
        serveMigration(indexOverrides: {'uuid': 'wrong-source'});
        await expectLater(
          PluginInstallService.I.installFromCloud(item, reinstall: true),
          throwsStateError,
        );
        expect(
          objectbox.pluginInfoBox.getAll().single.originScript,
          'internal build',
        );

        serveMigration();
        expect(
          await PluginInstallService.I.installFromCloud(item, reinstall: true),
          '更新成功',
        );
        final after = objectbox.pluginInfoBox.getAll().single;
        expect(after.originScript, _formalSource);
        expect(after.version, '0.1.2');
        expect(after.id, before.id);
        expect(after.insertedAt, before.insertedAt);
        expect(after.sortOrder, before.sortOrder);
        expect(after.isEnabled, isFalse);
        expect(objectbox.pluginConfigBox.getAll().single.toJson(), config);
      },
    );

    test('silent update migrates distinct same-version bytes once', () async {
      await seedManaged(version: '0.1.2');
      final requests = serveMigration(oldVersion: '0.1.2');
      final epoch = LocalPluginInstallationState.instance.installationEpoch(
        _managedUuid,
      );
      await PluginCloudUpdateService.I.silentUpdateFromCloud();
      await PluginCloudUpdateService.I.silentUpdateFromCloud();
      expect(
        objectbox.pluginInfoBox.getAll().single.originScript,
        _formalSource,
      );
      expect(
        LocalPluginInstallationState.instance.installationEpoch(_managedUuid),
        epoch,
      );
      expect(requests.where((url) => url == _formalIndex), hasLength(1));
    });

    test(
      'an independent index alone cannot authorize a self-channel downgrade',
      () async {
        await seedManaged();
        final installed = objectbox.pluginInfoBox.getAll().single
          ..getInfoJson = jsonEncode({'updateUrl': _formalIndex});
        await PluginRegistryService.I.upsert(installed);
        final requests = serveMigration();
        expect(
          await PluginCloudUpdateService.I.syncPluginFromSelfChannel(
            _managedUuid,
          ),
          isFalse,
        );
        expect(requests, [_formalIndex]);
        expect(api.calls, isEmpty);
        expect(
          objectbox.pluginInfoBox.getAll().single.originScript,
          _legacySource,
        );
      },
    );

    test(
      'wrong legacy bytes and locally forged catalog cannot allow downgrade',
      () async {
        await seedManaged(script: 'different locally modified bundle');
        final requests = serveMigration();
        final item = await readStoreItem();
        await expectLater(
          PluginInstallService.I.installFromCloud(item),
          throwsStateError,
        );
        await PluginCloudUpdateService.I.silentUpdateFromCloud();
        expect(requests, isNot(contains(_formalIndex)));
        expect(api.calls, isEmpty);

        await seedManaged();
        final forged = CloudPluginItem.fromJson(catalog('0.1.11'));
        await expectLater(
          PluginInstallService.I.installFromCloud(forged),
          throwsStateError,
        );
        expect(api.calls, isEmpty);
        expect(
          objectbox.pluginInfoBox.getAll().single.originScript,
          _legacySource,
        );
      },
    );

    test(
      'index and downloaded bytes must agree before the new script can run',
      () async {
        await seedManaged();
        final before = objectbox.pluginInfoBox.getAll().single.toJson();
        final requests = serveMigration(indexOverrides: {'migrationFrom': []});
        await expectLater(
          PluginInstallService.I.installFromCloud(await readStoreItem()),
          throwsStateError,
        );
        expect(requests.where((url) => url.endsWith(_formalAsset)), isEmpty);

        serveMigration(asset: () => 'wrong formal bundle');
        await expectLater(
          PluginInstallService.I.installFromCloud(await readStoreItem()),
          throwsStateError,
        );
        expect(api.calls, isEmpty);
        expect(objectbox.pluginInfoBox.getAll().single.toJson(), before);
      },
    );

    test(
      'late migration cannot overwrite a replacement committed during download',
      () async {
        await seedManaged();
        final downloading = Completer<void>();
        final asset = Completer<String>();
        serveMigration(
          asset: () {
            downloading.complete();
            return asset.future;
          },
        );
        final install = PluginInstallService.I.installFromCloud(
          await readStoreItem(),
        );
        final rejected = expectLater(
          install,
          throwsA(isA<PluginLifecycleChanged>()),
        );
        try {
          await downloading.future.timeout(const Duration(seconds: 3));
          final replacement = objectbox.pluginInfoBox.getAll().single
            ..version = '0.1.12'
            ..originScript = 'replacement bundle';
          await PluginRegistryService.I.upsertAndSetEnabled(
            replacement,
            initialize: false,
          );
        } finally {
          asset.complete(_formalSource);
        }
        await rejected;
        expect(
          objectbox.pluginInfoBox.getAll().single.originScript,
          'replacement bundle',
        );
      },
    );

    test(
      'legacy and upstream fallback cannot replace an installed formal release',
      () async {
        await seedManaged();
        serveMigration();
        await PluginCloudUpdateService.I.silentUpdateFromCloud();
        SharedPreferences.setMockInitialValues({});
        final legacy = {
          'repo': personalPluginCatalogRepository,
          'manifest': {
            'uuid': _managedUuid,
            'version': '0.1.12',
            'updateUrl': _releaseUrl,
          },
        };
        final requests = <String>[];
        api.request = (url) async {
          requests.add(url);
          if (url == _formalCatalog) return '<html>unavailable</html>';
          return jsonEncode([legacy]);
        };
        await PluginCloudUpdateService.I.silentUpdateFromCloud();
        await expectLater(
          PluginInstallService.I.installFromCloud(
            CloudPluginItem.fromJson(legacy),
          ),
          throwsStateError,
        );
        expect(requests, isNot(contains(_releaseUrl)));
        expect(
          objectbox.pluginInfoBox.getAll().single.originScript,
          _formalSource,
        );
      },
    );
  });
}
