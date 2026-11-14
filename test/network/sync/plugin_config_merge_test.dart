import 'dart:convert';
import 'package:zephyr/network/sync/sync_direction.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/network/sync/plugin_config_merge.dart';

void main() {
  test(
    'absent-value field tombstones beat stale values in either direction',
    () {
      final live = updatePluginConfigField({}, 'private.setting', {
        'value': 'synthetic',
      }, nowMs: 10);
      final deleted = deletePluginConfigField(
        live,
        'private.setting',
        nowMs: 20,
      );
      for (final pair in [(deleted, live), (live, deleted)]) {
        final merged =
            jsonDecode(
                  mergePluginConfigData(
                    jsonEncode(pair.$1),
                    jsonEncode(pair.$2),
                    localUpdatedAt: 1000000,
                    remoteUpdatedAt: 1000000,
                    preferRemoteOnConflict: true,
                  ),
                )
                as Map<String, dynamic>;
        expect(visiblePluginConfig(merged), isEmpty);
        expect(
          merged[pluginConfigSyncFields]['private.setting']['deleted'],
          isTrue,
        );
      }
      final rewritten = updatePluginConfigField(
        deleted,
        'private.setting',
        'new value',
        nowMs: 30,
      );
      final merged = jsonDecode(
        mergePluginConfigData(
          jsonEncode(deleted),
          jsonEncode(rewritten),
          localUpdatedAt: 1000000,
          remoteUpdatedAt: 1000000,
          preferRemoteOnConflict: false,
        ),
      );
      expect(merged['private.setting'], 'new value');
    },
  );
  Map<String, dynamic> merge(
    Map<String, dynamic> a,
    Map<String, dynamic> b, {
    int at = 0,
    int bt = 0,
    bool remote = false,
    bool protectVersionedLocalFields = false,
  }) =>
      jsonDecode(
            mergePluginConfigData(
              jsonEncode(a),
              jsonEncode(b),
              localUpdatedAt: at,
              remoteUpdatedAt: bt,
              preferRemoteOnConflict: remote,
              protectVersionedLocalFields: protectVersionedLocalFields,
            ),
          )
          as Map<String, dynamic>;

  test('concurrent changes to different fields survive', () {
    final base = updatePluginConfigField({}, 'theme', 'light', nowMs: 10);
    final a = updatePluginConfigField(base, 'theme', 'dark', nowMs: 20);
    final b = updatePluginConfigField(base, 'account.credentials', {
      'account': 'a',
      'password': 'b',
    }, nowMs: 30);
    final result = merge(a, b);
    expect(result['theme'], 'dark');
    expect(result['account.credentials'], b['account.credentials']);
  });

  test(
    'credentials stay atomic and deletion is retained against stale copy',
    () {
      final old = updatePluginConfigField({}, 'account.credentials', {
        'account': 'a',
        'password': 'b',
        'deleted': false,
      }, nowMs: 10);
      final deleted = updatePluginConfigField(old, 'account.credentials', {
        'version': 1,
        'deleted': true,
      }, nowMs: 20);
      expect(merge(deleted, old)['account.credentials'], {
        'version': 1,
        'deleted': true,
      });
      expect(merge(old, deleted)['account.credentials'], {
        'version': 1,
        'deleted': true,
      });
    },
  );

  test('same value retains metadata including nested map order', () {
    final first = updatePluginConfigField({}, 'x', {'a': 1, 'b': 2}, nowMs: 10);
    final second = updatePluginConfigField(first, 'x', {
      'b': 2,
      'a': 1,
    }, nowMs: 20);
    expect(second, first);
  });

  test('legacy backup uses block timestamp and conflict preference', () {
    expect(merge({'x': 1}, {'x': 2}, at: 20, bt: 10)['x'], 1);
    expect(merge({'x': 1}, {'x': 2}, at: 10, bt: 10, remote: true)['x'], 2);
    expect(merge({'x': null}, {'x': 2}, at: 20, bt: 10)['x'], isNull);
  });

  test('malformed backup cannot clear valid data', () {
    final result = mergePluginConfigData(
      '{"x":1}',
      'bad',
      localUpdatedAt: 0,
      remoteUpdatedAt: 10,
      preferRemoteOnConflict: true,
    );
    expect(jsonDecode(result), {'x': 1});
  });

  test('host metadata is hidden from full plugin configuration', () {
    final data = updatePluginConfigField({}, 'x', '', nowMs: 1);
    expect(visiblePluginConfig(data), {'x': ''});
    expect(updatePluginConfigField(data, pluginConfigSyncFields, 'bad'), data);
  });

  test('equal revisions converge independently of side', () {
    final a = updatePluginConfigField({}, 'x', 'a', nowMs: 10);
    final b = updatePluginConfigField({}, 'x', 'b', nowMs: 10);
    expect(merge(a, b), merge(b, a));
  });

  test(
    'old import protects explicit local values without guessing a field name',
    () {
      for (final value in [
        null,
        '',
        {'deleted': true},
      ]) {
        final local = updatePluginConfigField(
          {'unversioned': 'before'},
          'vendor.choice',
          value,
          nowMs: 20,
        );
        final result = merge(
          local,
          {'vendor.choice': 'stale', 'unversioned': 'after', 'new': 42},
          bt: 1000,
          remote: true,
          protectVersionedLocalFields: true,
        );
        expect(result['vendor.choice'], value);
        expect(
          (result[pluginConfigSyncFields] as Map)['vendor.choice'],
          (local[pluginConfigSyncFields] as Map)['vendor.choice'],
        );
        expect(result['unversioned'], 'after');
        expect(result['new'], 42);
      }
    },
  );

  test(
    'old import still accepts a genuinely newer valid remote field revision',
    () {
      final local = updatePluginConfigField(
        {},
        'vendor.choice',
        'local',
        nowMs: 20,
      );
      final remote = updatePluginConfigField(
        {},
        'vendor.choice',
        'remote',
        nowMs: 30,
      );
      expect(
        merge(
          local,
          remote,
          protectVersionedLocalFields: true,
        )['vendor.choice'],
        'remote',
      );
      expect(
        merge(
          remote,
          local,
          protectVersionedLocalFields: true,
        )['vendor.choice'],
        'remote',
      );
    },
  );

  test(
    'invalid local provenance does not protect a changed unversioned value',
    () {
      final local = updatePluginConfigField(
        {},
        'vendor.choice',
        'original',
        nowMs: 20,
      )..['vendor.choice'] = 'changed-without-revision';
      expect(
        merge(
          local,
          {'vendor.choice': 'remote'},
          bt: 1000,
          protectVersionedLocalFields: true,
        )['vendor.choice'],
        'remote',
      );
    },
  );

  test(
    'an invalid remote revision cannot promote an old value over valid local provenance',
    () {
      final local = updatePluginConfigField(
        {},
        'vendor.choice',
        null,
        nowMs: 20,
      );
      final remote = updatePluginConfigField(
        {},
        'vendor.choice',
        'original',
        nowMs: 1000,
      )..['vendor.choice'] = 'changed-without-revision';
      expect(
        merge(
          local,
          remote,
          bt: 1000,
          protectVersionedLocalFields: true,
        )['vendor.choice'],
        isNull,
      );
    },
  );

  test(
    'normal sync retains its existing block fallback for unversioned remote fields',
    () {
      final local = updatePluginConfigField(
        {},
        'vendor.choice',
        null,
        nowMs: 20,
      );
      expect(
        merge(local, {'vendor.choice': 'remote'}, bt: 1000)['vendor.choice'],
        'remote',
      );
    },
  );
  test(
    'manual directions override field clocks while missing fields and explicit deletions retain their semantics',
    () {
      final local = updatePluginConfigField(
        {'localOnly': true},
        'choice',
        'local',
        nowMs: 40,
      );
      final remote = updatePluginConfigField(
        {'cloudOnly': true},
        'choice',
        'cloud',
        nowMs: 10,
      );
      for (final direction in [SyncDirection.upload, SyncDirection.restore]) {
        final result =
            jsonDecode(
                  mergePluginConfigData(
                    jsonEncode(local),
                    jsonEncode(remote),
                    localUpdatedAt: 40,
                    remoteUpdatedAt: 10,
                    preferRemoteOnConflict: false,
                    direction: direction,
                  ),
                )
                as Map<String, dynamic>;
        expect(
          result['choice'],
          direction == SyncDirection.upload ? 'local' : 'cloud',
        );
        expect(result['localOnly'], isTrue);
        expect(result['cloudOnly'], isTrue);
      }
      final deleted = deletePluginConfigField(remote, 'choice', nowMs: 11);
      final restored =
          jsonDecode(
                mergePluginConfigData(
                  jsonEncode(local),
                  jsonEncode(deleted),
                  localUpdatedAt: 40,
                  remoteUpdatedAt: 11,
                  preferRemoteOnConflict: false,
                  direction: SyncDirection.restore,
                ),
              )
              as Map<String, dynamic>;
      expect(restored.containsKey('choice'), isFalse);
      expect(restored[pluginConfigSyncFields]['choice']['deleted'], isTrue);
    },
  );

  test(
    'a field edited during restore survives while untouched cloud fields apply',
    () {
      final baseline = updatePluginConfigField(
        {'other': 'before'},
        'choice',
        'local',
        nowMs: 20,
      );
      final current = updatePluginConfigField(
        baseline,
        'choice',
        'during-network',
        nowMs: 30,
      );
      final incoming = updatePluginConfigField(
        {'other': 'cloud'},
        'choice',
        'cloud',
        nowMs: 10,
      );
      final result = jsonDecode(
        preserveInterveningPluginConfigEdits(
          jsonEncode(baseline),
          jsonEncode(current),
          jsonEncode(incoming),
        ),
      );
      expect(result['choice'], 'during-network');
      expect(result['other'], 'cloud');
      expect(result[pluginConfigSyncFields]['choice']['updatedAt'], 30);
    },
  );
}
