import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/plugin/utils/plugin_catalog_merge.dart';

void main() {
  test('places a separately identified personal plugin first', () {
    const official = '[{"manifest":{"uuid":"official"}}]';
    const personal = '[{"manifest":{"uuid":"personal"}}]';
    final merged =
        jsonDecode(mergeCloudPluginCatalogPayloads(official, personal))
            as List<dynamic>;
    expect(merged, hasLength(2));
    expect((merged[0] as Map)['manifest']['uuid'], 'personal');
    expect((merged[1] as Map)['manifest']['uuid'], 'official');
  });

  test('never replaces an official entry with the same UUID', () {
    const official = '[{"manifest":{"uuid":"official","version":"1"}}]';
    const personal = '[{"manifest":{"uuid":"official","version":"2"}}]';
    final merged =
        jsonDecode(mergeCloudPluginCatalogPayloads(official, personal))
            as List<dynamic>;
    expect(merged, hasLength(1));
    expect((merged.single as Map)['manifest']['version'], '1');
  });

  test(
    'personal 禁漫 update replaces only its matching original catalog entry',
    () {
      const jm = '6886291b-f524-441c-844b-c2efae9899a9';
      const official =
          '[{"manifest":{"uuid":"$jm","version":"0.2.1"}},'
          '{"manifest":{"uuid":"other","version":"1"}}]';
      const personal = '[{"manifest":{"uuid":"$jm","version":"0.3.0"}}]';
      final merged =
          jsonDecode(mergeCloudPluginCatalogPayloads(official, personal))
              as List<dynamic>;
      expect(merged, hasLength(2));
      expect((merged.first as Map)['manifest']['version'], '0.3.0');
      expect((merged.last as Map)['manifest']['uuid'], 'other');
    },
  );

  test('keeps official entries when the personal catalog is unavailable', () {
    const official = '[{"manifest":{"uuid":"official"}}]';
    expect(mergeCloudPluginCatalogPayloads(official, null), official);
    expect(mergeCloudPluginCatalogPayloads(official, '<html>'), official);
  });
  test('malformed official response does not hide personal plugins', () {
    const personal = '[{"manifest":{"uuid":"personal"}}]';
    expect(
      jsonDecode(mergeCloudPluginCatalogPayloads('<html>', personal)),
      jsonDecode(personal),
    );
  });

  test(
    'managed Copy entry overrides its official duplicate without downgrade',
    () {
      const id = 'b28da416-f2d4-4208-a85e-8b4c7c648e48';
      const old = '[{"manifest":{"uuid":"$id","version":"0.0.16"}}]';
      const newer = '[{"manifest":{"uuid":"$id","version":"0.0.17"}}]';
      expect(
        jsonDecode(mergeCloudPluginCatalogPayloads(old, newer)),
        jsonDecode(newer),
      );
      expect(
        jsonDecode(mergeCloudPluginCatalogPayloads(newer, old)),
        jsonDecode(newer),
      );
    },
  );

  test('official failure is isolated from successful personal fetch', () async {
    final result = await loadCloudPluginCatalog(
      official: () async => throw StateError('offline'),
      personal: () async => '[{"manifest":{"uuid":"personal"}}]',
      fallback: '[{"manifest":{"uuid":"saved"}}]',
    );
    expect((jsonDecode(result) as List).first['manifest']['uuid'], 'personal');
  });

  test(
    'HTML personal response keeps valid official data and saved managed plugins',
    () async {
      const id = 'f5387e66-9c58-4b8f-beb7-22a939f79e5d';
      final result =
          jsonDecode(
                await loadCloudPluginCatalog(
                  official: () async =>
                      '[{"manifest":{"uuid":"official","version":"2"}}]',
                  personal: () async => '<html>blocked</html>',
                  fallback:
                      '[{"manifest":{"uuid":"$id","version":"0.1.1"}},'
                      '{"manifest":{"uuid":"official","version":"1"}}]',
                ),
              )
              as List;
      expect(result, hasLength(2));
      expect(result.first['manifest']['uuid'], id);
      expect(result.last['manifest']['version'], '2');
    },
  );

  test(
    'both unavailable reports failure instead of saving empty success',
    () async {
      await expectLater(
        loadCloudPluginCatalog(
          official: () async => null,
          personal: () async => '[]',
          fallback: '[{"manifest":{"uuid":"saved"}}]',
        ),
        throwsStateError,
      );
    },
  );

  test('timeout cannot discard another completed source', () async {
    final result = await loadCloudPluginCatalog(
      official: () => Future<String?>.delayed(const Duration(seconds: 1)),
      personal: () async => '[{"manifest":{"uuid":"personal"}}]',
      fallback: '[]',
      timeout: const Duration(milliseconds: 10),
    );
    expect((jsonDecode(result) as List).single['manifest']['uuid'], 'personal');
  });
  test('managed fork takes priority over a higher numbered upstream channel', () {
    const id = 'b28da416-f2d4-4208-a85e-8b4c7c648e48';
    const official =
        '[{"repo":"upstream/copy","manifest":{"uuid":"$id","version":"2.0.0"}}]';
    const personal =
        '[{"repo":"owner/plugins","manifest":{"uuid":"$id","version":"0.1.1"}}]';
    final result =
        jsonDecode(mergeCloudPluginCatalogPayloads(official, personal)) as List;
    expect(result, hasLength(1));
    expect(result.single['repo'], 'owner/plugins');
    expect(result.single['manifest']['version'], '0.1.1');
  });
}
