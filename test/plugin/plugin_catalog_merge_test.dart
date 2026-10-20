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

  test('keeps official entries when the personal catalog is unavailable', () {
    const official = '[{"manifest":{"uuid":"official"}}]';
    expect(mergeCloudPluginCatalogPayloads(official, null), official);
    expect(mergeCloudPluginCatalogPayloads(official, '<html>'), official);
  });
}
