import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/plugin/utils/plugin_release_policy.dart';

void main() {
  const id = 'released-plugin';
  const original = 'module.exports = {getInfo(){return {version:"0.11.4"}}};';
  Map<String, dynamic> release({int series = 1, String version = '0.1.0'}) => {
    'uuid': id,
    'version': version,
    'releaseSeries': series,
    'migrationFrom': [
      {
        'version': '0.11.4',
        'scriptSha256': PluginReleasePolicy.scriptDigest(original),
      },
    ],
  };
  bool upgrade({
    String version = '0.11.4',
    String script = original,
    int series = 0,
    Map<String, dynamic>? remote,
  }) => PluginReleasePolicy.canUpgrade(
    uuid: id,
    localVersion: version,
    localScript: script,
    localInfo: {'releaseSeries': series},
    remoteInfo: remote ?? release(),
  );

  test('identified published legacy content moves to public 0.1.0', () {
    expect(upgrade(), isTrue);
    expect(upgrade(script: '\n$original\n'), isTrue);
  });
  test('unpublished higher or edited same-version builds are preserved', () {
    expect(upgrade(version: '0.11.5'), isFalse);
    expect(upgrade(script: '$original\n// local changes'), isFalse);
    expect(upgrade(script: ''), isFalse);
    expect(upgrade(remote: {...release(), 'uuid': 'another-plugin'}), isFalse);
    expect(upgrade(remote: {...release()}..remove('migrationFrom')), isFalse);
  });
  test(
    'normal formal patches update and stale legacy catalogs never roll back',
    () {
      expect(
        upgrade(
          version: '0.1.0',
          series: 1,
          remote: release(version: '0.1.1'),
        ),
        isTrue,
      );
      expect(upgrade(version: '0.1.0', series: 1), isFalse);
      expect(upgrade(version: '0.1.1', series: 1), isFalse);
      expect(
        upgrade(
          version: '0.1.0',
          series: 1,
          remote: release(series: 0, version: '0.11.4'),
        ),
        isFalse,
      );
      expect(upgrade(remote: release(series: 2)), isFalse);
    },
  );
  test('catalog priority follows series then public version', () {
    expect(
      PluginReleasePolicy.compareCatalog(
        release(),
        release(series: 0, version: '0.11.4'),
      ),
      greaterThan(0),
    );
    expect(
      PluginReleasePolicy.compareCatalog(
        release(series: 0, version: '0.11.4'),
        release(),
      ),
      lessThan(0),
    );
    expect(
      PluginReleasePolicy.compareCatalog(release(version: '0.1.1'), release()),
      greaterThan(0),
    );
  });
  test('file integrity and actual identity must agree before replacement', () {
    final expected = {
      ...release(),
      'scriptSha256': PluginReleasePolicy.scriptDigest(original),
    };
    expect(
      () => PluginReleasePolicy.verifyScript(original, expected),
      returnsNormally,
    );
    expect(
      () =>
          PluginReleasePolicy.verifyScript('$original// corruption', expected),
      throwsStateError,
    );
    expect(
      () => PluginReleasePolicy.verifyScript(original, release()),
      throwsStateError,
    );
    expect(
      () => PluginReleasePolicy.verifyInfo(release(), expected),
      returnsNormally,
    );
    for (final actual in [
      release(version: '0.1.1'),
      release(series: 0),
      {...release(), 'uuid': 'other'},
    ]) {
      expect(
        () => PluginReleasePolicy.verifyInfo(actual, expected),
        throwsStateError,
      );
    }
  });
}
