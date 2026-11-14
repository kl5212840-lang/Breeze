import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/network/sync/plugin_account_projection.dart';
import 'package:zephyr/network/sync/plugin_config_merge.dart';

Map<String, dynamic> _block(Map<String, dynamic> config) => {
  'pluginConfigs': [
    {'name': 'source', 'config': jsonEncode(config)},
  ],
  'pluginInfos': [
    {'uuid': 'source', 'version': 'cloud-version'},
  ],
};
Map<String, dynamic> _config(Map<String, dynamic> block) =>
    Map<String, dynamic>.from(
      jsonDecode((block['pluginConfigs'] as List).first['config'] as String)
          as Map,
    );

void main() {
  test(
    'automatic account backup retains remote nonaccount fields and plugin metadata',
    () {
      final local = updatePluginConfigField(
        updatePluginConfigField({}, 'theme', 'local-theme', nowMs: 100),
        'account.credentials',
        {'account': 'synthetic-a', 'password': 'synthetic-p'},
        nowMs: 20,
      );
      final remote = updatePluginConfigField(
        {},
        'theme',
        'remote-theme',
        nowMs: 10,
      );
      final result = mergePluginAccountsForBackup(
        _block(local),
        _block(remote),
        sources: {'source'},
        localUpdatedAt: 100,
        remoteUpdatedAt: 10,
      );
      expect(_config(result)['theme'], 'remote-theme');
      expect(
        _config(result)['account.credentials'],
        local['account.credentials'],
      );
      expect(result['pluginInfos'], _block(remote)['pluginInfos']);
    },
  );

  test(
    'different auth identities never mix password or authorization fields',
    () {
      var a = updatePluginConfigField(
        {},
        'auth.account',
        'synthetic-a',
        nowMs: 10,
      );
      a = updatePluginConfigField(
        a,
        'auth.password',
        'password-a',
        nowMs: 1000,
      );
      a = updatePluginConfigField(
        a,
        'auth.authorization',
        'token-a',
        nowMs: 1001,
      );
      var b = updatePluginConfigField(
        {},
        'auth.account',
        'synthetic-b',
        nowMs: 20,
      );
      b = updatePluginConfigField(b, 'auth.password', 'password-b', nowMs: 21);
      b = updatePluginConfigField(
        b,
        'auth.authorization',
        'token-b',
        nowMs: 22,
      );
      final result = jsonDecode(
        mergePluginAccountConfigData(
          jsonEncode(a),
          jsonEncode(b),
          localUpdatedAt: 1001,
          remoteUpdatedAt: 22,
          preferRemoteOnConflict: false,
        ),
      );
      expect(result['auth.account'], 'synthetic-b');
      expect(result['auth.password'], 'password-b');
      expect(result['auth.authorization'], 'token-b');
    },
  );

  test(
    'versioned cookie deletion beats stale backup; nonparticipants cannot upload',
    () {
      final old = updatePluginConfigField({}, 'account.backup', {
        'deleted': false,
      }, nowMs: 10);
      final deleted = updatePluginConfigField(old, 'account.backup', {
        'deleted': true,
      }, nowMs: 20);
      final result = mergePluginAccountsForBackup(
        _block(deleted),
        _block(old),
        sources: {'source'},
        localUpdatedAt: 20,
        remoteUpdatedAt: 1000,
      );
      expect(_config(result)['account.backup']['deleted'], isTrue);
      final skipped = mergePluginAccountsForBackup(
        _block(deleted),
        _block(old),
        sources: {'other'},
        localUpdatedAt: 20,
        remoteUpdatedAt: 1000,
      );
      expect(_config(skipped)['account.backup']['deleted'], isFalse);
    },
  );

  test(
    'field tombstone cannot be resurrected by an unversioned older device',
    () {
      final old = updatePluginConfigField({}, 'account.credentials', {
        'account': 'synthetic',
      }, nowMs: 10);
      final deleted = deletePluginConfigField(
        old,
        'account.credentials',
        nowMs: 20,
      );
      final result = mergePluginAccountsForBackup(
        _block({
          'account.credentials': {'account': 'stale'},
        }),
        _block(deleted),
        sources: {'source'},
        localUpdatedAt: 1000,
        remoteUpdatedAt: 20,
      );
      expect(_config(result).containsKey('account.credentials'), isFalse);
      expect(
        _config(
          result,
        )[pluginConfigSyncFields]['account.credentials']['deleted'],
        isTrue,
      );
    },
  );
}
