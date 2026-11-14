import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/plugin/utils/plugin_catalog_merge.dart';

CloudPluginCatalogSnapshot _legacy(String combined) =>
    CloudPluginCatalogSnapshot.fromLegacyCache(
      combined: combined,
      bundled: '[]',
    );

List<String> _ids(CloudPluginCatalogSnapshot snapshot) =>
    (jsonDecode(snapshot.payload) as List).map(cloudPluginUuid).toList();

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

  test(
    'only a unique live first-party entry carries migration authority',
    () async {
      const uuid = 'e9f18928-3ba8-4d86-a12e-b53a62f47933';
      final manifest = {
        'uuid': uuid,
        'version': '0.1.2',
        'updateUrl':
            'https://raw.githubusercontent.com/$personalPluginCatalogRepository/main/updates/v1/bika.json',
        'releaseSeries': 1,
        'scriptSha256': 'a' * 64,
        'migrationFrom': [
          {'version': '0.1.11', 'scriptSha256': 'b' * 64},
        ],
      };
      final formal = {
        'repo': personalPluginCatalogRepository,
        'manifest': manifest,
      };
      final newer = {
        'repo': personalPluginCatalogRepository,
        'manifest': {...manifest, 'version': '0.1.11'},
      };
      final live = await loadCloudPluginCatalog(
        official: () async => jsonEncode([newer]),
        personal: () async => jsonEncode([formal]),
        fallback: const CloudPluginCatalogSnapshot(),
      );
      expect(live.entries.single.formalRelease?.version, '0.1.2');
      expect(live.entries.single.json, formal);
      final cached = CloudPluginCatalogSnapshot.fromCacheJson(
        live.toCacheJson(),
      )!;
      expect(cached.entries.single.formalRelease, isNull);

      final forwarded = await loadCloudPluginCatalog(
        official: () async => jsonEncode([formal]),
        personal: () async => null,
        legacyPersonal: () async => jsonEncode([formal]),
        fallback: const CloudPluginCatalogSnapshot(),
      );
      expect(forwarded.entries.single.formalRelease, isNull);

      final duplicate = await loadCloudPluginCatalog(
        official: () async => null,
        personal: () async => jsonEncode([formal, formal]),
        fallback: const CloudPluginCatalogSnapshot(),
      );
      expect(duplicate.entries.single.formalRelease, isNull);
    },
  );

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
      fallback: _legacy('[{"manifest":{"uuid":"saved"}}]'),
    );
    expect(_ids(result), ['personal', 'saved']);
  });

  test(
    'HTML personal response keeps valid official data and saved managed plugins',
    () async {
      const id = 'f5387e66-9c58-4b8f-beb7-22a939f79e5d';
      final snapshot = await loadCloudPluginCatalog(
        official: () async =>
            '[{"manifest":{"uuid":"official","version":"2"}}]',
        personal: () async => '<html>blocked</html>',
        fallback: _legacy(
          '[{"manifest":{"uuid":"$id","version":"0.1.1"}},'
          '{"manifest":{"uuid":"official","version":"1"}}]',
        ),
      );
      final result = jsonDecode(snapshot.payload) as List;
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
          personal: () async => '[{"manifest":{}}]',
          fallback: _legacy('[{"manifest":{"uuid":"saved"}}]'),
        ),
        throwsStateError,
      );
    },
  );

  test('timeout cannot discard another completed source', () async {
    final result = await loadCloudPluginCatalog(
      official: () => Future<String?>.delayed(const Duration(seconds: 1)),
      personal: () async => '[{"manifest":{"uuid":"personal"}}]',
      fallback: const CloudPluginCatalogSnapshot(),
      timeout: const Duration(milliseconds: 10),
    );
    expect(_ids(result), ['personal']);
  });

  test(
    'new personal UUIDs survive partial failure and cache restart',
    () async {
      const privateCatalogue = '[{"manifest":{"uuid":"new-source"}}]';
      final initial = await loadCloudPluginCatalog(
        official: () async => '[{"manifest":{"uuid":"official-before"}}]',
        personal: () async => privateCatalogue,
        fallback: const CloudPluginCatalogSnapshot(),
      );
      final restored = CloudPluginCatalogSnapshot.fromCacheJson(
        initial.toCacheJson(),
      )!;
      final refresh = await loadCloudPluginCatalog(
        official: () async => '[{"manifest":{"uuid":"official-after"}}]',
        personal: () async => '<html>gateway</html>',
        fallback: restored,
      );
      expect(_ids(refresh), ['new-source', 'official-after']);
    },
  );

  test(
    'old combined cache preserves a newly introduced personal entry',
    () async {
      final refresh = await loadCloudPluginCatalog(
        official: () async => '[{"manifest":{"uuid":"official-after"}}]',
        personal: () async => null,
        fallback: _legacy(
          '[{"repo":"$personalPluginCatalogRepository","manifest":{"uuid":"new"}},'
          '{"repo":"another/source","manifest":{"uuid":"official-before"}}]',
        ),
      );
      expect(_ids(refresh), ['new', 'official-after']);
    },
  );

  test(
    'authoritative refresh replaces each source without resurrecting entries',
    () async {
      final cached = await loadCloudPluginCatalog(
        official: () async => '[{"manifest":{"uuid":"official"}}]',
        personal: () async => '[{"manifest":{"uuid":"removed"}}]',
        fallback: const CloudPluginCatalogSnapshot(),
      );
      final result = await loadCloudPluginCatalog(
        official: () async => null,
        personal: () async => '[]',
        legacyPersonal: () async => throw StateError('unexpected legacy fetch'),
        fallback: cached,
      );
      expect(result.personalVersioned, isTrue);
      expect(_ids(result), ['official']);
      final afterFailure = await loadCloudPluginCatalog(
        official: () async => '[{"manifest":{"uuid":"official"}}]',
        personal: () async => null,
        legacyPersonal: () async => '[{"manifest":{"uuid":"removed"}}]',
        fallback: CloudPluginCatalogSnapshot.fromCacheJson(
          result.toCacheJson(),
        )!,
      );
      expect(_ids(afterFailure), ['official']);
    },
  );

  test(
    'legacy root bootstraps only until a versioned index succeeds',
    () async {
      var legacyRequests = 0;
      Future<String> loadLegacy() async {
        legacyRequests++;
        return '[{"manifest":{"uuid":"legacy"}}]';
      }

      final first = await loadCloudPluginCatalog(
        official: () async => null,
        personal: () async => '<html>not found</html>',
        legacyPersonal: loadLegacy,
        fallback: const CloudPluginCatalogSnapshot(),
      );
      expect(_ids(first), ['legacy']);
      expect(first.personalVersioned, isFalse);
      final canonical = await loadCloudPluginCatalog(
        official: () async => null,
        personal: () async => '[{"manifest":{"uuid":"new"}}]',
        legacyPersonal: loadLegacy,
        fallback: first,
      );
      expect(_ids(canonical), ['new']);
      expect(canonical.personalVersioned, isTrue);
      expect(legacyRequests, 1);
    },
  );

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
