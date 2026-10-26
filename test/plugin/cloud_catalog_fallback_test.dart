import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/plugin/utils/plugin_catalog_merge.dart';
import 'package:zephyr/plugin/utils/plugin_cloud_download_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'first offline opening includes all five managed plugins and iKun icon',
    () async {
      SharedPreferences.setMockInitialValues({});
      final entries = decodeCloudPluginCatalog(
        await readCloudPluginCatalogFallback(),
      )!;
      expect(entries.map(cloudPluginUuid).toSet(), managedPluginUuids);
      expect(entries, hasLength(5));
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
      hasLength(5),
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
    expect(entries, hasLength(6));
    expect(
      entries.singleWhere(
        (entry) =>
            cloudPluginUuid(entry) == 'f5387e66-9c58-4b8f-beb7-22a939f79e5d',
      )['manifest']['version'],
      '9.0.0',
    );
    expect(cloudPluginUuid(entries.last), 'official');
  });
}
