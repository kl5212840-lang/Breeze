import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';

class _BlockedRemovalPreferences extends InMemorySharedPreferencesStore {
  _BlockedRemovalPreferences() : super.empty();
  final started = Completer<void>(), release = Completer<void>();
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (!started.isCompleted) {
      started.complete();
      await release.future;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocalPluginInstallationState state;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    state = LocalPluginInstallationState();
  });

  test('removal survives reload and advances a future source clock', () async {
    await state.markRemoved('dynamic-source', revision: 4102444800000);
    expect(state.isRemoved('dynamic-source'), isTrue);
    expect(state.removedAt('dynamic-source'), greaterThan(4102444800000));
    final reloaded = LocalPluginInstallationState();
    await reloaded.load();
    expect(reloaded.removedUuids, {'dynamic-source'});
    expect(reloaded.installationEpoch('dynamic-source'), 1);
  });

  test(
    'explicit installation keeps data masks; explicit restore clears them',
    () async {
      final writes = <Map<String, dynamic>>[];
      Future<void> beforeWrite(Map<String, dynamic> next) async {
        final prefs = await SharedPreferences.getInstance();
        // Journal preparation sees the original value, before the write.
        expect(
          prefs.getString(LocalPluginInstallationState.storageKey),
          isNot(next.values.single),
        );
        writes.add(next);
      }

      await state.markRemoved('source');
      await state.setDataExclusions('source', {
        PluginDataScope.records,
        PluginDataScope.accountSettings,
      }, beforeWrite: beforeWrite);
      final epoch = state.installationEpoch('source');
      await state.completeExplicitInstallation(
        'source',
        beforeWrite: beforeWrite,
      );
      expect(state.isRemoved('source'), isFalse);
      expect(state.isDataExcluded('source', PluginDataScope.records), isTrue);
      expect(state.installationEpoch('source'), epoch + 1);
      await state.clearForExplicitRestore(['source'], beforeWrite: beforeWrite);
      expect(state.excludedSources(PluginDataScope.records), isEmpty);
      expect(state.excludedSources(PluginDataScope.accountSettings), isEmpty);
      expect(writes, hasLength(3));
    },
  );

  test(
    'journal failure leaves persisted and published state untouched',
    () async {
      await state.markRemoved('source');
      final prefs = await SharedPreferences.getInstance();
      final before = prefs.getString(LocalPluginInstallationState.storageKey);
      await expectLater(
        state.clearForExplicitRestore(
          ['source'],
          beforeWrite: (_) async {
            throw StateError('fixture journal failure');
          },
        ),
        throwsStateError,
      );
      expect(prefs.getString(LocalPluginInstallationState.storageKey), before);
      expect(state.isRemoved('source'), isTrue);
      expect(state.installationEpoch('source'), 1);
    },
  );

  test('corrupt state cannot silently revive a known removed source', () async {
    await state.markRemoved('source');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      LocalPluginInstallationState.storageKey,
      '{"version":99}',
    );
    await expectLater(state.reload(), throwsFormatException);
    expect(state.isRemoved('source'), isTrue);
    expect(state.installationEpoch('source'), 1);
  });

  test(
    'unavailable platform preferences are surfaced, not an empty installation list',
    () async {
      final unavailable = LocalPluginInstallationState(
        preferences: () async {
          throw MissingPluginException('fixture unavailable');
        },
      );
      await expectLater(
        unavailable.load(),
        throwsA(isA<MissingPluginException>()),
      );
    },
  );

  test('invalid identities cannot enter the device document', () async {
    for (final source in ['', '..', 'a/b', 'a\\b', 'a\u0000b']) {
      await expectLater(state.markRemoved(source), throwsFormatException);
    }
    expect(
      (await SharedPreferences.getInstance()).containsKey(
        LocalPluginInstallationState.storageKey,
      ),
      isFalse,
    );
  });

  test(
    'legacy removed-only document remains local and gains an epoch',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        LocalPluginInstallationState.storageKey,
        jsonEncode({
          'version': 1,
          'removed': {'legacy-source': 100},
        }),
      );
      await state.load();
      expect(state.isRemoved('legacy-source'), isTrue);
      expect(state.installationEpoch('legacy-source'), 1);
      expect(state.excludedSources(PluginDataScope.records), isEmpty);
    },
  );

  test('installation leases are counted and released once', () {
    final first = state.beginExplicitInstallation('source');
    final second = state.beginExplicitInstallation('source');
    first.release();
    first.release();
    expect(state.isInstalling('source'), isTrue);
    second.release();
    expect(state.isInstalling('source'), isFalse);
  });

  test(
    'install beginning during the native marker write withdraws that old removal',
    () async {
      await state.load();
      final previous = SharedPreferencesStorePlatform.instance;
      final store = _BlockedRemovalPreferences();
      SharedPreferencesStorePlatform.instance = store;
      LocalPluginInstallationLease? installation;
      try {
        final removal = state.markRemoved('source', expectedEpoch: 0);
        final rejected = expectLater(
          removal,
          throwsA(isA<PluginLifecycleChanged>()),
        );
        await store.started.future.timeout(const Duration(seconds: 3));
        installation = state.beginExplicitInstallation('source');
        store.release.complete();
        await rejected;
        expect(state.isRemoved('source'), isFalse);
        expect(state.installationEpoch('source'), 0);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.containsKey(LocalPluginInstallationState.storageKey),
          isFalse,
        );
        expect(
          (await store.getAll()).keys.where(
            (key) => key.contains('plugin-removals'),
          ),
          isEmpty,
        );
      } finally {
        if (!store.release.isCompleted) store.release.complete();
        installation?.release();
        SharedPreferencesStorePlatform.instance = previous;
      }
    },
  );
}
