import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/plugin_store/models/cloud_plugin_item.dart';
import 'package:zephyr/plugin/models/cloud_plugin_manifest_internal.dart';
import 'package:zephyr/plugin/plugin_host_compatibility.dart';

Map<String, dynamic> video(int protocol) => {
  'uuid': 'fixture-plugin',
  'name': 'Fixture',
  'version': '0.1.7',
  'function': [
    {
      'action': {
        'type': 'openVideoLibrary',
        'payload': {'protocol': protocol},
      },
    },
  ],
};
Map<String, dynamic> requirement(Object? capabilities, {Object? version = 1}) =>
    {
      'uuid': 'fixture-plugin',
      'requirements': {'version': version, 'capabilities': capabilities},
    };

void main() {
  setUp(() => PluginHostCompatibilityNotices.instance.takePending());

  test(
    'legacy undeclared plugins keep prior behavior and no SemVer is guessed',
    () {
      expect(
        PluginHostCompatibility.checkInfo({'version': '99.0.0'}).supported,
        isTrue,
      );
      expect(PluginHostCompatibility.checkStoredInfo('').supported, isTrue);
      expect(
        PluginHostCompatibility.checkInfo({
          'function': [
            {
              'action': {'type': 'openVideoLibrary', 'payload': {}},
            },
          ],
        }).supported,
        isTrue,
      );
    },
  );

  test(
    'declared native video protocol 1 and 2 are supported, future protocol is refused',
    () {
      for (final protocol in [1, 2])
        expect(
          PluginHostCompatibility.checkInfo(video(protocol)).supported,
          isTrue,
        );
      expect(
        PluginHostCompatibility.checkInfo(video(3)).reasons,
        contains(PluginHostCompatibilityReason.videoLibraryProtocol),
      );
      expect(
        PluginHostCompatibility.checkInfo(
          video(2),
          capabilities: const PluginHostCapabilities(
            videoLibraryProtocols: {1},
          ),
        ).supported,
        isFalse,
      );
    },
  );

  test(
    'requirements use an explicit version and capability ABI, never app version',
    () {
      expect(
        PluginHostCompatibility.checkInfo(
          requirement({'videoLibraryProtocol': 2}),
        ).supported,
        isTrue,
      );
      for (final raw in [
        requirement({'videoLibraryProtocol': 3}),
        requirement({'futureBridge': 1}),
        requirement({'videoLibraryProtocol': '2'}),
        requirement({}, version: 2),
        requirement({}, version: '1'),
        requirement(null),
        {'requirements': null},
        {
          'requirements': {
            'version': 1,
            'capabilities': {},
            'minAppVersion': '3.0.37',
          },
        },
      ]) {
        expect(
          PluginHostCompatibility.checkInfo(raw).supported,
          isFalse,
          reason: raw.toString(),
        );
      }
    },
  );

  test('wrapped getInfo metadata cannot bypass either declaration', () {
    expect(
      PluginHostCompatibility.checkInfo({'data': video(3)}).supported,
      isFalse,
    );
    expect(
      PluginHostCompatibility.checkInfo({
        ...video(3),
        'data': video(2),
      }).supported,
      isFalse,
    );
    expect(
      PluginHostCompatibility.checkInfo({'data': video(2)}).supported,
      isTrue,
    );
  });

  test('malformed persisted metadata is refused without running scripts', () {
    expect(PluginHostCompatibility.checkStoredInfo('{bad').supported, isFalse);
    expect(PluginHostCompatibility.checkStoredInfo('[]').supported, isFalse);
    expect(
      PluginHostCompatibility.checkStoredInfo(jsonEncode(video(3))).supported,
      isFalse,
    );
  });

  test(
    'both cloud manifest readers retain explicit bad requirements for rejection',
    () {
      final raw = {
        'uuid': 'fixture-plugin',
        'version': '1',
        'requirements': {'version': 2},
      };
      final public = CloudPluginManifest.fromJson(raw);
      final internal = CloudPluginManifestInternal.fromJson(raw);
      expect(
        PluginHostCompatibility.checkInfo(
          public.compatibilityMetadata,
        ).supported,
        isFalse,
      );
      expect(
        PluginHostCompatibility.checkInfo(
          internal.compatibilityMetadata,
        ).supported,
        isFalse,
      );
      expect(
        PluginHostCompatibility.checkInfo(
          CloudPluginManifest.fromJson({}).compatibilityMetadata,
        ).supported,
        isTrue,
      );
    },
  );

  test(
    'skip feedback is typed, bounded and contains no script or account configuration',
    () {
      final row = {
        'uuid': 'fixture-plugin',
        'version': '3',
        'getInfoJson': jsonEncode(video(3)),
        'originScript': 'private-script',
        'config': 'private-account',
      };
      expect(PluginHostCompatibility.reportSkippedPluginInfo(row), isTrue);
      expect(PluginHostCompatibility.reportSkippedPluginInfo(row), isTrue);
      final issues = PluginHostCompatibilityNotices.instance.takePending();
      expect(issues, hasLength(1));
      expect(issues.single.name, 'Fixture');
      expect(issues.single.version, '3');
      expect(
        issues.single.reasons,
        contains(PluginHostCompatibilityReason.videoLibraryProtocol),
      );
      expect(PluginHostCompatibilityNotices.instance.issues.value, isEmpty);
      expect(
        () => PluginHostCompatibility.requireCompatiblePluginInfo(row),
        throwsA(isA<PluginHostCompatibilityException>()),
      );
      expect(
        PluginHostCompatibility.reportSkippedPluginInfo({
          ...row,
          'isDeleted': true,
        }),
        isFalse,
      );
    },
  );

  test(
    'acknowledgment clears only the shown issue instances and retains concurrent same-source updates',
    () {
      final notices = PluginHostCompatibilityNotices.instance;
      PluginHostCompatibilityIssue issue(String uuid, String version) =>
          PluginHostCompatibilityIssue(
            uuid: uuid,
            name: uuid,
            version: version,
            reasons: {PluginHostCompatibilityReason.videoLibraryProtocol},
          );
      final old = issue('same-source', '3');
      final shownOther = issue('shown-other', '3');
      notices.record(old);
      notices.record(shownOther);
      final shown = notices.issues.value.toList(growable: false);
      // Same public fields still represent a newly reported, unseen issue.
      final newer = issue('same-source', '3');
      final arrivedWhileOpen = issue('new-source', '3');
      notices.record(newer);
      notices.record(arrivedWhileOpen);
      notices.acknowledge(shown);
      expect(notices.issues.value, [newer, arrivedWhileOpen]);
      expect(notices.issues.value.first, same(newer));
      notices.acknowledge(shown);
      expect(notices.issues.value, [newer, arrivedWhileOpen]);
      notices.acknowledge([newer]);
      expect(notices.issues.value, [arrivedWhileOpen]);
    },
  );

  test(
    'full replacement retains current script for skipped UUID without retaining foreign database id',
    () {
      final bad = {
        'uuid': 'same',
        'getInfoJson': jsonEncode(video(3)),
        'originScript': 'new incompatible',
      };
      final good = {
        'uuid': 'compatible',
        'getInfoJson': jsonEncode(video(2)),
        'originScript': 'good',
      };
      final old = {
        'id': 42,
        'uuid': 'same',
        'originScript': 'existing-compatible',
        'getInfoJson': jsonEncode(video(1)),
      };
      final output = PluginHostCompatibility.projectRestoredPluginInfos(
        [bad, good],
        [old],
      );
      expect(output, hasLength(2));
      expect(output[0]['originScript'], 'existing-compatible');
      expect(output[0]['id'], 0);
      expect(output[1], good);
      expect(
        PluginHostCompatibility.projectRestoredPluginInfos([bad], []),
        isEmpty,
      );
    },
  );
}
