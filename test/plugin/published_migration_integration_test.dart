import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/plugin_store/widgets/cloud_plugin_card.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/plugin_store/models/cloud_plugin_item.dart';
import 'package:zephyr/plugin/plugin_cloud_update_service.dart';
import 'package:zephyr/plugin/plugin_install_service.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/plugin/utils/plugin_cloud_download_utils.dart';
import 'package:zephyr/plugin/utils/plugin_release_policy.dart';
import 'package:zephyr/src/rust/api/http.dart' as http;
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/src/rust/qjs.dart';

import '../test_helper.dart';

const _id = '1e600cff-8ebe-4517-8aa4-6678aec46424';
const _legacy =
    'module.exports={getInfo(){return {uuid:"$_id",version:"0.11.4"}}};';
const _formal =
    'module.exports={getInfo(){return {uuid:"$_id",version:"0.1.0",releaseSeries:1}}};';
const _channel = 'https://fixture.invalid/updates/v1/hanime.json';
Map<String, dynamic> _info(String version, {int series = 0}) => {
  'uuid': _id,
  'version': version,
  'releaseSeries': series,
  'updateUrl': _channel,
  'npmName': '',
  'name': 'Published fixture',
};
Map<String, dynamic> _manifest() => {
  ..._info('0.1.0', series: 1),
  'scriptSha256': PluginReleasePolicy.scriptDigest(_formal),
  'migrationFrom': [
    {
      'version': '0.11.4',
      'scriptSha256': PluginReleasePolicy.scriptDigest(_legacy),
    },
  ],
};
Map<String, dynamic> _item(Map<String, dynamic> info) => {
  'repo': 'kl5212840-lang/Breeze-plugins',
  'manifest': info,
};

class _Client implements http.HttpClient {
  _Client(this.api);
  final _Api api;
  @override
  Future<http.FetchResponse> fetch({
    required String url,
    http.FetchInit? init,
  }) => api.respond(url);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected HTTP method ${invocation.memberName}');
}

/// Exercises real catalog/download/install/update/database paths. Only the
/// Rust HTTP and JS execution boundary is replaced; it cannot reach a network.
class _Api extends RustLibApi {
  Map<String, dynamic> manifest = _manifest();
  Map<String, dynamic> actualInfo = _info('0.1.0', series: 1);
  String script = _formal;
  int assetReads = 0;
  int getInfoReads = 0;
  final runtimes = <String, String>{};
  Future<void> Function()? beforeAsset;
  Future<void> Function()? beforeInfo;
  bool catalogUnavailable = false;
  void reset() {
    manifest = _manifest();
    actualInfo = _info('0.1.0', series: 1);
    script = _formal;
    assetReads = 0;
    getInfoReads = 0;
    beforeAsset = null;
    beforeInfo = null;
    catalogUnavailable = false;
    runtimes.clear();
  }

  Future<http.FetchResponse> respond(String url) async {
    final Object body;
    if (url.contains('catalog/v1/plugins_data.json')) {
      if (catalogUnavailable) throw StateError('offline catalog');
      body = jsonEncode([_item(manifest)]);
    } else if (url.contains('plugin-list') ||
        url.contains('plugins_data.json')) {
      body = jsonEncode([
        {
          'repo': 'fixture/other',
          'manifest': {'uuid': 'other', 'version': '1.0.0'},
        },
      ]);
    } else if (url.endsWith('/updates/v1/hanime.json')) {
      body = jsonEncode({
        ...manifest,
        'tag_name': 'v${manifest['version']}',
        'assets': [
          {
            'name': 'fixture.cjs',
            'browser_download_url': 'https://fixture.invalid/fixture.cjs',
          },
        ],
      });
    } else if (url.endsWith('/fixture.cjs')) {
      assetReads++;
      await beforeAsset?.call();
      body = script;
    } else {
      throw StateError('Unexpected network URL $url');
    }
    return http.FetchResponse(
      status: 200,
      statusText: 'OK',
      ok: true,
      headers: const {},
      body: Uint8List.fromList(utf8.encode(body as String)),
      url: url,
      redirected: false,
    );
  }

  @override
  http.HttpClient crateApiHttpHttpClientCreate({
    http.HttpClientOptions? options,
  }) => _Client(this);
  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;
  @override
  Future<void> crateApiQjsBuildQjsRuntime({
    required QjsRuntimeBuildRequest request,
  }) async {
    runtimes[request.runtimeName] = request.bundle?.bundleJs ?? '';
  }

  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode(runtimes[runtimeName] ?? script);
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
    Object reply;
    if (fnPath == 'getInfo') {
      getInfoReads++;
      await beforeInfo?.call();
      reply = actualInfo;
    } else if (fnPath == 'init') {
      reply = {
        'data': {'ok': true},
      };
    } else {
      throw StateError('Unexpected JS operation $fnPath');
    }
    return Uint8List.fromList(utf8.encode(jsonEncode(reply)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected native method ${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Api api;
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    api = _Api();
    RustLib.initMock(api: api);
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    objectbox.pluginInfoBox.removeAll();
    objectbox.pluginConfigBox.removeAll();
    TestObjectBoxHelper.cleanComicFolderBoxes();
    await PluginRegistryService.I.init();
    api.reset();
  });
  Future<void> seed({
    String id = _id,
    String version = '0.11.4',
    String script = _legacy,
    int series = 0,
    bool enabled = false,
    bool debug = false,
  }) async {
    objectbox.pluginConfigBox.removeAll();
    TestObjectBoxHelper.cleanComicFolderBoxes();
    objectbox.pluginInfoBox.removeAll();
    await PluginRegistryService.I.refreshFromDb();
    final now = DateTime.utc(2026, 10, 26);
    await PluginRegistryService.I.upsert(
      PluginInfo(
        uuid: id,
        version: version,
        originScript: script,
        insertedAt: now,
        updatedAt: now,
        isEnabled: enabled,
        isDeleted: false,
        lastLoadSuccess: true,
        sortOrder: 7,
        debug: debug,
        getInfoJson: jsonEncode({
          ..._info(version, series: series),
          'uuid': id,
        }),
      ),
    );
    objectbox.pluginConfigBox.put(
      PluginConfig(name: _id, config: '{"preference":"preserve"}'),
    );
    objectbox.unifiedFavoriteBox.put(createTestFavorite('$_id-favorite'));
    objectbox.unifiedHistoryBox.put(createTestHistory('$_id-history'));
  }

  PluginInfo saved() => objectbox.pluginInfoBox.getAll().single;
  void expectDataPreserved() {
    expect(
      objectbox.pluginConfigBox.getAll().single.config,
      '{"preference":"preserve"}',
    );
    expect(
      objectbox.unifiedFavoriteBox.getAll().single.uniqueKey,
      '$_id-favorite',
    );
    expect(
      objectbox.unifiedHistoryBox.getAll().single.uniqueKey,
      '$_id-history',
    );
  }

  test(
    'silent migration keeps identity, settings, favorites, history, order and enabled state; repeats are no-op',
    () async {
      await seed();
      final oldId = saved().id;
      final inserted = saved().insertedAt;
      await PluginCloudUpdateService.I.silentUpdateFromCloud();
      expect(saved().id, oldId);
      expect(saved().version, '0.1.0');
      expect(saved().originScript, _formal);
      expect(saved().sortOrder, 7);
      expect(saved().isEnabled, isFalse);
      expect(saved().insertedAt, inserted);
      expectDataPreserved();
      expect(api.assetReads, 1);
      await PluginCloudUpdateService.I.silentUpdateFromCloud();
      expect(api.assetReads, 1);
    },
  );
  test(
    'manual sync discovers formal migration from old channel; same-series patches use self channel',
    () async {
      await seed();
      expect(
        await PluginCloudUpdateService.I.syncPluginFromSelfChannel(_id),
        isTrue,
      );
      api.script = '$_formal\n// public patch';
      api.actualInfo = _info('0.1.1', series: 1);
      api.manifest = {
        ...api.actualInfo,
        'scriptSha256': PluginReleasePolicy.scriptDigest(api.script),
      };
      expect(
        await PluginCloudUpdateService.I.syncPluginFromSelfChannel(_id),
        isTrue,
      );
      expect(saved().version, '0.1.1');
      expectDataPreserved();
    },
  );
  test('store update accepts version reset and keeps plugin data', () async {
    await seed();
    final oldId = saved().id;
    await PluginInstallService.I.installFromCloud(
      CloudPluginItem.fromJson(_item(api.manifest)),
    );
    expect(saved().id, oldId);
    expect(saved().version, '0.1.0');
    expectDataPreserved();
    await Future<void>.delayed(Duration.zero);
  });
  test(
    'ordinary legacy updates without migration metadata still work',
    () async {
      await seed(id: 'ordinary-plugin');
      api.script = 'legacy public patch';
      api.actualInfo = {..._info('0.11.5'), 'uuid': 'ordinary-plugin'};
      api.manifest = api.actualInfo;
      await PluginCloudUpdateService.I.silentUpdateFromCloud();
      expect(saved().version, '0.11.5');
      expectDataPreserved();
    },
  );
  test(
    'unpublished higher, edited same-version, and debug installs are not silently replaced',
    () async {
      for (final input in [
        (version: '0.11.5', script: _legacy, debug: false),
        (version: '0.11.4', script: '$_legacy\n// local edit', debug: false),
        (version: '0.11.4', script: _legacy, debug: true),
      ]) {
        await seed(
          version: input.version,
          script: input.script,
          debug: input.debug,
        );
        await PluginCloudUpdateService.I.silentUpdateFromCloud();
        expect(saved().version, input.version);
        expect(saved().originScript, input.script);
      }
      expect(api.assetReads, 0);
    },
  );
  test(
    'invalid file digest is rejected before JS evaluation or database changes',
    () async {
      await seed();
      api.script = '$_formal\n// corrupted';
      await PluginCloudUpdateService.I.silentUpdateFromCloud();
      expect(saved().originScript, _legacy);
      expect(api.getInfoReads, 0);
      expectDataPreserved();
    },
  );
  test(
    'wrong UUID, version or release series cannot replace installed plugin',
    () async {
      for (final info in [
        {..._info('0.1.0', series: 1), 'uuid': 'wrong'},
        _info('0.2.0', series: 1),
        _info('0.1.0'),
      ]) {
        await seed();
        api.actualInfo = info;
        await PluginCloudUpdateService.I.silentUpdateFromCloud();
        expect(saved().originScript, _legacy);
        expectDataPreserved();
      }
    },
  );
  test(
    'delete or replacement while update download is pending wins over updater',
    () async {
      await seed();
      api.beforeAsset = () async {
        objectbox.pluginInfoBox.removeAll();
        await PluginRegistryService.I.refreshFromDb();
      };
      await PluginCloudUpdateService.I.silentUpdateFromCloud();
      expect(objectbox.pluginInfoBox.getAll(), isEmpty);
      await seed();
      api.beforeAsset = () async {
        final item = saved();
        item.originScript = 'developer replacement';
        await PluginRegistryService.I.upsert(item);
      };
      await PluginCloudUpdateService.I.silentUpdateFromCloud();
      expect(saved().originScript, 'developer replacement');
    },
  );
  test(
    'store install cannot resurrect a deleted plugin during getInfo',
    () async {
      await seed();
      api.beforeInfo = () async {
        objectbox.pluginInfoBox.removeAll();
        await PluginRegistryService.I.refreshFromDb();
      };
      await expectLater(
        PluginInstallService.I.installFromCloud(
          CloudPluginItem.fromJson(_item(api.manifest)),
        ),
        throwsStateError,
      );
      expect(objectbox.pluginInfoBox.getAll(), isEmpty);
    },
  );
  test(
    'new install verifies formal metadata; stale cached legacy catalog cannot hide formal series',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'plugin_store.catalog.v2',
        jsonEncode([_item(_info('0.11.4'))]),
      );
      final fallback =
          jsonDecode(await readCloudPluginCatalogFallback()) as List;
      final info =
          (fallback.firstWhere((x) => x['manifest']['uuid'] == _id)
              as Map)['manifest'];
      expect(info['releaseSeries'], 1);
      expect(info['version'], '0.1.0');
      await PluginInstallService.I.installFromCloud(
        CloudPluginItem.fromJson(_item(api.manifest)),
      );
      expect(saved().version, '0.1.0');
      expect(saved().isEnabled, isTrue);
      await Future<void>.delayed(Duration.zero);
    },
  );
  testWidgets(
    'store offers Update for recognized public version reset, but preserves development installs',
    (tester) async {
      await seed();
      var installs = 0;
      Future<void> show() => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CloudPluginCard(
              item: CloudPluginItem.fromJson(_item(api.manifest)),
              installing: false,
              onOpenHome: (_) {},
              onInstall: () {
                installs++;
              },
            ),
          ),
        ),
      );
      await show();
      expect(find.text(t.plugin.downloadUpdate), findsOneWidget);
      await tester.tap(find.text(t.plugin.downloadUpdate));
      expect(installs, 1);
      await seed(version: '0.11.5', script: 'unpublished build');
      await show();
      expect(find.text(t.plugin.downloadUpdate), findsNothing);
      expect(find.text(t.plugin.localVersionNewer), findsOneWidget);
    },
  );
}
