import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/plugin_store/models/cloud_plugin_item.dart';
import 'package:zephyr/plugin/utils/plugin_catalog_merge.dart';
import 'package:zephyr/plugin/utils/plugin_cloud_download_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'first offline opening includes all seven published plugins and iKun icon',
    () async {
      SharedPreferences.setMockInitialValues({});
      final entries = decodeCloudPluginCatalog(
        await readCloudPluginCatalogFallback(),
      )!;
      expect(entries.map(cloudPluginUuid).toSet(), {
        ...managedPluginUuids,
        'ccc2fe17-c0a8-4fd8-a596-835772686404',
        'b27083a4-a643-462a-8204-e6f42c19a5b9',
      });
      expect(entries, hasLength(7));
      final ikun = entries.singleWhere(
        (entry) => entry['manifest']['name'] == 'iKun 资源',
      )['manifest'];
      final icon = ikun['iconUrl'] as String;
      expect(icon, startsWith('data:image/png;base64,'));
      expect(base64Decode(icon.split(',').last).take(8), [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ]);
    },
  );

  test('corrupt cache cannot suppress bundled entries', () async {
    SharedPreferences.setMockInitialValues({
      'plugin_store.catalog.v2': '<html>',
    });
    expect(
      decodeCloudPluginCatalog(await readCloudPluginCatalogFallback()),
      hasLength(7),
    );
  });

  test('cache retains other plugins and a newer managed version', () async {
    SharedPreferences.setMockInitialValues({
      'plugin_store.catalog.v2': jsonEncode([
        {
          'repo': 'kl5212840-lang/Breeze-plugins',
          'manifest': {
            'uuid': 'f5387e66-9c58-4b8f-beb7-22a939f79e5d',
            'version': '9.0.0',
          },
        },
        {
          'manifest': {'uuid': 'official'},
        },
      ]),
    });
    final entries = decodeCloudPluginCatalog(
      await readCloudPluginCatalogFallback(),
    )!;
    expect(entries, hasLength(8));
    expect(
      entries.singleWhere(
        (entry) =>
            cloudPluginUuid(entry) == 'f5387e66-9c58-4b8f-beb7-22a939f79e5d',
      )['manifest']['version'],
      '9.0.0',
    );
    expect(cloudPluginUuid(entries.last), 'official');
  });

  test(
    'offline startup respects a previously refreshed empty personal list',
    () async {
      SharedPreferences.setMockInitialValues({
        'plugin_store.catalog.sources.v1': jsonEncode({
          'official': [
            {
              'manifest': {'uuid': 'official'},
            },
          ],
          'personal': [],
          'personalVersioned': true,
        }),
        'plugin_store.catalog.v2': jsonEncode([
          {
            'repo': personalPluginCatalogRepository,
            'manifest': {'uuid': 'removed'},
          },
        ]),
      });
      final entries = decodeCloudPluginCatalog(
        await readCloudPluginCatalogFallback(),
      )!;
      expect(entries.map(cloudPluginUuid), ['official']);
    },
  );

  test('cached legacy rows expose reinstall before catalog refresh', () async {
    const uuid = 'f5387e66-9c58-4b8f-beb7-22a939f79e5d';
    SharedPreferences.setMockInitialValues({});
    final initial = decodeCloudPluginCatalog(
      await readCloudPluginCatalogFallback(),
    )!;
    final installed = initial.singleWhere(
      (entry) => cloudPluginUuid(entry) == uuid,
    );
    SharedPreferences.setMockInitialValues({
      'plugin_store.catalog.sources.v1': jsonEncode({
        'official': [
          {
            'manifest': {'uuid': 'official'},
          },
        ],
        'personal': [
          {
            'repo': personalPluginCatalogRepository,
            'manifest': {
              'uuid': uuid,
              'version': installed['manifest']['version'],
              'updateUrl': 'https://fixture.invalid/legacy',
            },
          },
        ],
        'personalVersioned': false,
      }),
    });
    final entries = decodeCloudPluginCatalog(
      await readCloudPluginCatalogFallback(),
    )!;
    final item = CloudPluginItem.fromJson(
      (entries.singleWhere((entry) => cloudPluginUuid(entry) == uuid) as Map)
          .cast<String, dynamic>(),
    );
    expect(item.manifest.name, installed['manifest']['name']);
    expect(item.canReinstallFromCloud(null), isTrue);
    expect(item.formalRelease, isNull);
    expect(entries.map(cloudPluginUuid), contains('official'));
  });
}
