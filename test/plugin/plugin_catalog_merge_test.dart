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
}
