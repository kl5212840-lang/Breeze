import 'package:zephyr/config/global/global_setting.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/page/video/omo_network.dart' show omoNetworkSource;
import 'package:zephyr/page/video/video_account_backup.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/service/plugin_account_profiles.dart';
import 'package:zephyr/service/plugin_account_sync_coordinator.dart';
import '../test_helper.dart';

final _origin = Uri.parse('https://site.example');
Map<String, dynamic> _cookie(String value) => {
  'name': 'session',
  'value': value,
  'domain': _origin.host,
  'path': '/',
  'secure': true,
  'httpOnly': true,
  'expires': null,
};

class _Cookies implements VideoAccountCookies {
  List<Map<String, dynamic>> values = [_cookie('A')];
  int writes = 0;
  int reads = 0;
  bool reorderReads = false;
  @override
  Future<List<Map<String, dynamic>>> read(Uri origin) async {
    expect(origin, _origin);
    reads++;
    final rows = values.map((row) => Map<String, dynamic>.from(row)).toList();
    return reorderReads && reads.isEven ? rows.reversed.toList() : rows;
  }

  @override
  Future<void> set(Uri origin, Map<String, dynamic> cookie) async {
    expect(origin, _origin);
    writes++;
    values.removeWhere((row) => row['name'] == cookie['name']);
    values.add(Map<String, dynamic>.from(cookie));
  }

  @override
  Future<void> delete(Uri origin, Map<String, dynamic> cookie) async {
    expect(origin, _origin);
    writes++;
    values.removeWhere((row) => row['name'] == cookie['name']);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const source = omoNetworkSource;
  late _Cookies cookies;
  late PluginAccountSyncCoordinator coordinator;
  Object? lease;
  var unavailable = false;
  Future<PluginAccountAuthentication?> identity() async {
    if (unavailable) return null;
    if (cookies.values.isEmpty)
      throw const PluginAccountAuthenticationRejected();
    final id =
        cookies.values.firstWhere((row) => row['name'] == 'session')['value']
            as String;
    return PluginAccountAuthentication(
      serverIdentity: id,
      label: 'Member $id',
      origin: _origin.origin,
    );
  }

  Future<void> capture(String id) async {
    cookies.values = [_cookie(id)];
    await coordinator.captureAuthenticated(source, explicitSave: true);
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    unavailable = false;
    cookies = _Cookies();
    final user = objectbox.userSettingBox.get(1)!;
    user.globalSetting = const GlobalSettingState(
      syncSetting: SyncSettingState(syncPlugins: true),
    );
    objectbox.userSettingBox.put(user);
    pluginSessionWriteFence.advance(source);
    objectbox.pluginConfigBox.removeMany(
      objectbox.pluginConfigBox
          .getAll()
          .where((row) => row.name == source)
          .map((row) => row.id)
          .toList(),
    );
    coordinator = PluginAccountSyncCoordinator.instance;
    lease = await coordinator.registerStoredSession(
      source: source,
      origin: _origin,
      cookies: cookies,
      authenticated: () async => await identity() != null,
      identity: identity,
    );
  });
  tearDown(() {
    if (lease != null) coordinator.unregister(source, lease!);
    lease = null;
  });

  test(
    'a confirmed nonportable account stays saved and can complete manual login later, while cancellation restores the current account',
    () async {
      await capture('A');
      coordinator.unregister(source, lease!);
      cookies.values = [];
      lease = await coordinator.registerStoredSession(
        source: source,
        origin: _origin,
        cookies: cookies,
        authenticated: () async => true,
        identity: () async => PluginAccountAuthentication(
          serverIdentity: 'B',
          label: 'Member B',
          origin: _origin.origin,
        ),
      );
      await coordinator.captureAuthenticated(source, explicitSave: true);
      var b = PluginAccountProfiles.read(
        source,
      ).profiles.values.singleWhere((row) => row.serverIdentity == 'B');
      expect(PluginAccountProfiles.requiresWebLogin(b), isTrue);
      expect(b.bundle.keys, [
        'account.backup',
      ], reason: 'identity-only B never inherits A credentials or cookies');
      final restored = PluginAccountProfilesData.parse(
        PluginAccountProfiles.read(source).toJson(),
        source: source,
      );
      expect(restored, isNotNull);
      expect(
        restored!.profiles[b.id]!.bundle,
        b.bundle,
        reason:
            'the version-one account collection and cloud projection retain the explicit unavailable-session marker',
      );
      expect(
        VideoAccountBackup.parse(
          b.bundle['account.backup'],
          _origin,
          source: source,
        ),
        isNull,
      );
      expect(await PluginAccountProfiles.selected(source), b.id);
      expect(PluginAccountIdentities.current(source)?.serverIdentity, 'B');
      coordinator.unregister(source, lease!);
      lease = await coordinator.registerStoredSession(
        source: source,
        origin: _origin,
        cookies: cookies,
        authenticated: () async => await identity() != null,
        identity: identity,
      );
      await capture('A');
      final a = PluginAccountProfiles.read(
        source,
      ).profiles.values.singleWhere((row) => row.serverIdentity == 'A');
      final service = PluginAccountAuthenticationService(source);
      await expectLater(
        service.switchToWithLogin(
          b.id,
          login: () async => throw StateError('user cancelled'),
        ),
        throwsStateError,
      );
      expect(cookies.values, [_cookie('A')]);
      expect(await PluginAccountProfiles.selected(source), a.id);
      expect(
        PluginAccountProfiles.requiresWebLogin(
          PluginAccountProfiles.read(source).profiles[b.id]!,
        ),
        isTrue,
      );
      await service.switchToWithLogin(
        b.id,
        login: () async {
          cookies.values = [_cookie('B')];
        },
      );
      b = PluginAccountProfiles.read(source).profiles[b.id]!;
      expect(PluginAccountProfiles.requiresWebLogin(b), isFalse);
      expect(await PluginAccountProfiles.selected(source), b.id);
      expect(PluginAccountIdentities.current(source)?.serverIdentity, 'B');
      expect(cookies.values, [_cookie('B')]);
    },
  );

  test(
    'Omo A to B to A uses exact saved cookies and fresh proof; failed switch restores A',
    () async {
      expect(readHostPluginConfiguration(source)['account.backup'], isNull);
      await capture('A');
      final first = PluginAccountProfiles.read(
        source,
      ).profiles.values.singleWhere((row) => !row.deleted);
      final firstActive = VideoAccountBackup.parse(
        readHostPluginConfiguration(source)['account.backup'],
        _origin,
      )!;
      final firstSaved = VideoAccountBackup.parse(
        first.bundle['account.backup'],
        _origin,
      )!;
      expect(first.serverIdentity, 'A');
      expect(
        firstSaved.sessionFingerprint,
        firstActive.sessionFingerprint,
        reason:
            'first profile commit uses the fingerprint after account.backup was persisted',
      );
      expect(await PluginAccountProfiles.selected(source), first.id);
      await capture('B');
      final second = PluginAccountProfiles.read(
        source,
      ).profiles.values.singleWhere((row) => row.serverIdentity == 'B');
      final secondActive = VideoAccountBackup.parse(
        readHostPluginConfiguration(source)['account.backup'],
        _origin,
      )!;
      final secondSaved = VideoAccountBackup.parse(
        second.bundle['account.backup'],
        _origin,
      )!;
      expect(
        secondSaved.sessionFingerprint,
        secondActive.sessionFingerprint,
        reason:
            'a new snapshot can update the active account without rejecting its own write',
      );
      expect(await PluginAccountProfiles.selected(source), second.id);
      final records = PluginAccountProfiles.read(source);
      final a = records.profiles.values.singleWhere(
        (row) => row.serverIdentity == 'A',
      );
      final b = records.profiles.values.singleWhere(
        (row) => row.serverIdentity == 'B',
      );
      await PluginAccountProfiles.switchTo(
        source,
        a.id,
        authenticate: (profile) => coordinator.activateProfile(source, profile),
      );
      expect(cookies.values.single['value'], 'A');
      expect(PluginAccountIdentities.current(source)?.serverIdentity, 'A');
      expect(await PluginAccountProfiles.selected(source), a.id);
      unavailable = true;
      await expectLater(
        PluginAccountProfiles.switchTo(
          source,
          b.id,
          authenticate: (profile) =>
              coordinator.activateProfile(source, profile),
        ),
        throwsA(isA<PluginAccountSwitchFailed>()),
      );
      expect(cookies.values.single['value'], 'A');
      expect(
        (readHostPluginConfiguration(source)['account.backup']
            as Map)['cookies'],
        [_cookie('A')],
      );
      unavailable = false;
      await coordinator.refreshCurrentIdentity(source, requireFresh: true);
      expect(PluginAccountIdentities.current(source)?.serverIdentity, 'A');
      expect(await PluginAccountProfiles.selected(source), a.id);
    },
  );
  test(
    'saved Web credentials use the source login continuation and fresh identity after lease replacement',
    () async {
      await capture('A');
      final credentials = {
        'version': 1,
        'deleted': false,
        'origin': _origin.origin,
        'account': 'B',
        'password': 'synthetic-password',
      };
      await PluginAccountProfiles.rememberCredentials(source, credentials);
      final target = PluginAccountProfiles.read(
        source,
      ).profiles.values.singleWhere((row) => row.kind == 'password');
      final service = PluginAccountAuthenticationService(source);
      var opened = 0;
      await service.switchToWithLogin(
        target.id,
        login: () async {
          opened++;
          expect(
            cookies.values,
            isEmpty,
            reason:
                'only the reversible source allowlist is cleared, without server logout',
          );
          expect(
            readHostPluginConfiguration(source)['account.credentials'],
            credentials,
          );
          cookies.values = [_cookie('B')];
          coordinator.unregister(source, lease!);
          lease = await coordinator.registerStoredSession(
            source: source,
            origin: _origin,
            cookies: cookies,
            authenticated: () async => true,
            identity: () async {
              if (cookies.values.isEmpty)
                throw const PluginAccountAuthenticationRejected();
              final id = cookies.values.single['value'] as String;
              return PluginAccountAuthentication(
                serverIdentity: id,
                label: 'Member $id',
                publicSummary: {
                  'extern': {'username': id},
                },
              );
            },
          );
        },
      );
      expect(opened, 1);
      expect(cookies.values.single['value'], 'B');
      expect(PluginAccountIdentities.current(source)?.serverIdentity, 'B');
      expect(await PluginAccountProfiles.selected(source), target.id);
      final saved = PluginAccountProfiles.read(source).profiles[target.id]!;
      expect(saved.serverIdentity, 'B');
      expect(saved.bundle['account.backup'], isA<Map>());
      await service.switchTo(target.id);
      expect(
        opened,
        1,
        reason: 'the freshly confirmed saved session does not reopen the form',
      );
      final a = PluginAccountProfiles.read(source).profiles.values.singleWhere(
        (row) => row.kind == 'web' && row.serverIdentity == 'A',
      );
      await service.switchTo(a.id);
      expect(cookies.values.single['value'], 'A');
      expect(PluginAccountIdentities.current(source)?.serverIdentity, 'A');
      expect(
        PluginAccountProfiles.read(
          source,
        ).profiles[target.id]?.bundle['account.backup'],
        isA<Map>(),
        reason:
            'leaving a confirmed credential profile preserves its exact saved session',
      );
      await service.switchTo(target.id);
      expect(cookies.values.single['value'], 'B');
      expect(PluginAccountIdentities.current(source)?.serverIdentity, 'B');
      expect(
        opened,
        1,
        reason: 'B to A to B reuses both confirmed saved sessions',
      );
    },
  );
  test(
    'cancelled Web credential continuation restores the old session without selecting the target',
    () async {
      await capture('A');
      final selected = await PluginAccountProfiles.selected(source);
      await PluginAccountProfiles.rememberCredentials(source, {
        'version': 1,
        'deleted': false,
        'origin': _origin.origin,
        'account': 'B',
        'password': 'synthetic-password',
      });
      final target = PluginAccountProfiles.read(
        source,
      ).profiles.values.singleWhere((row) => row.kind == 'password');
      for (final formFails in [false, true]) {
        await expectLater(
          PluginAccountAuthenticationService(source).switchToWithLogin(
            target.id,
            login: () async {
              if (formFails) throw StateError('Synthetic form unavailable');
            },
          ),
          throwsA(
            formFails
                ? isA<StateError>()
                : isA<PluginAccountAuthenticationRejected>(),
          ),
        );
        expect(cookies.values.single['value'], 'A');
        await coordinator.refreshCurrentIdentity(source, requireFresh: true);
        expect(PluginAccountIdentities.current(source)?.serverIdentity, 'A');
        expect(await PluginAccountProfiles.selected(source), selected);
      }
    },
  );
  test(
    'a newer account epoch during Web credential continuation cannot be overwritten',
    () async {
      await capture('A');
      await PluginAccountProfiles.rememberCredentials(source, {
        'version': 1,
        'deleted': false,
        'origin': _origin.origin,
        'account': 'B',
        'password': 'synthetic-password',
      });
      final target = PluginAccountProfiles.read(
        source,
      ).profiles.values.singleWhere((row) => row.kind == 'password');
      await expectLater(
        PluginAccountAuthenticationService(source).switchToWithLogin(
          target.id,
          login: () async {
            pluginSessionWriteFence.advance(source);
            cookies.values = [_cookie('C')];
            replaceActivePluginAccount(source, {
              'account.credentials': {
                'version': 1,
                'deleted': false,
                'origin': _origin.origin,
                'account': 'C',
                'password': 'newer-synthetic-password',
              },
            });
          },
        ),
        throwsA(isA<PluginSessionChanged>()),
      );
      expect(cookies.values.single['value'], 'C');
      expect(
        (readHostPluginConfiguration(source)['account.credentials']
            as Map)['account'],
        'C',
      );
      expect(
        PluginAccountProfiles.read(source).profiles[target.id]?.serverIdentity,
        isEmpty,
      );
    },
  );
  for (final portable in [true, false]) {
    test(
      'fresh Omo login binds real username to UID in one saved profile, portable=$portable',
      () async {
        coordinator.unregister(source, lease!);
        cookies.values = portable ? [_cookie('session-for-42')] : [];
        lease = await coordinator.registerStoredSession(
          source: source,
          origin: _origin,
          cookies: cookies,
          authenticated: () async => true,
          identity: () async => PluginAccountAuthentication(
            serverIdentity: '42',
            label: 'Public nickname',
            publicSummary: const {
              'extern': {'username': 'real-login'},
            },
          ),
        );
        await savePluginConfigValue(source, 'account.credentials', {
          'version': 1,
          'deleted': false,
          'origin': _origin.origin,
          'account': 'real-login',
          'password': 'synthetic-native-password',
        });
        await coordinator.captureAuthenticated(source, explicitSave: true);
        final rows = PluginAccountProfiles.read(
          source,
        ).profiles.values.where((row) => !row.deleted).toList();
        expect(rows, hasLength(1));
        final profile = rows.single;
        expect(profile.identity, 'real-login');
        expect(profile.serverIdentity, '42');
        expect(profile.kind, 'password');
        expect(
          (profile.bundle['account.credentials'] as Map)['account'],
          'real-login',
        );
        expect(profile.bundle.containsKey('account.backup'), portable);
        expect(await PluginAccountProfiles.selected(source), profile.id);
        await coordinator.captureAuthenticated(source, explicitSave: true);
        expect(
          PluginAccountProfiles.read(
            source,
          ).profiles.values.where((row) => !row.deleted),
          hasLength(1),
        );
        expect(PluginAccountIdentities.current(source)?.serverIdentity, '42');
      },
    );
  }
  test(
    'unknown fresh account response cannot attach another cookie snapshot to an earlier proof',
    () async {
      await capture('A');
      final before = readHostPluginConfiguration(source)['account.backup'];
      cookies.values = [_cookie('B')];
      unavailable = true;
      await expectLater(
        coordinator.captureAuthenticated(source),
        throwsStateError,
      );
      expect(readHostPluginConfiguration(source)['account.backup'], before);
      expect(
        PluginAccountIdentities.current(source)?.serverIdentity,
        'A',
        reason: 'transport/unknown does not revoke a valid receipt',
      );
      expect(
        PluginAccountProfiles.read(
          source,
        ).profiles.values.where((row) => !row.deleted).single.serverIdentity,
        'A',
      );
    },
  );
  test(
    'explicit Web signout clears live allowlist cookies with no backup, preserving saved profiles',
    () async {
      await capture('A');
      final saved = PluginAccountProfiles.read(source).profiles.values.single;
      replaceActivePluginAccount(source, const {});
      await coordinator.refreshCurrentIdentity(source, requireFresh: true);
      expect(readHostPluginConfiguration(source)['account.backup'], isNull);
      await PluginAccountAuthenticationService(source).signOut();
      expect(cookies.values, isEmpty);
      expect(PluginAccountIdentities.current(source), isNull);
      expect(
        PluginAccountProfiles.read(source).profiles[saved.id]?.deleted,
        isFalse,
      );
      expect(await PluginAccountProfiles.selected(source), isNull);
    },
  );
  test(
    'removing another saved account leaves current session; current removal signs out and remains tombstoned',
    () async {
      await capture('A');
      await capture('B');
      await capture('A');
      var records = PluginAccountProfiles.read(source);
      final a = records.profiles.values.singleWhere(
        (row) => row.serverIdentity == 'A',
      );
      final b = records.profiles.values.singleWhere(
        (row) => row.serverIdentity == 'B',
      );
      final writes = cookies.writes;
      await PluginAccountProfiles.delete(source, b.id);
      expect(cookies.writes, writes);
      expect(cookies.values.single['value'], 'A');
      expect(PluginAccountIdentities.current(source)?.serverIdentity, 'A');
      await PluginAccountProfiles.delete(
        source,
        a.id,
        signOutCurrent: PluginAccountAuthenticationService(source).signOut,
      );
      expect(cookies.values, isEmpty);
      records = PluginAccountProfiles.read(source);
      expect(records.profiles[a.id]?.deleted, isTrue);
      expect(records.profiles[b.id]?.deleted, isTrue);
      await PluginAccountProfiles.rememberCurrent(source);
      expect(
        PluginAccountProfiles.read(source).profiles[a.id]?.deleted,
        isTrue,
      );
    },
  );
  test(
    'queued local cloud-session application completes before a fresh identity read',
    () async {
      await capture('A');
      await capture('B');
      cookies.values = [_cookie('A')];
      await coordinator.markRestorePending({source});
      expect(PluginAccountIdentities.current(source)?.serverIdentity, 'B');
      final proof = await coordinator.refreshCurrentIdentity(
        source,
        requireFresh: true,
      );
      expect(cookies.values.single['value'], 'B');
      expect(proof?.serverIdentity, 'B');
      expect(
        await coordinator.restoreOnEntry(source),
        AccountSessionRestoreResult.notPending,
      );
    },
  );
  test(
    'old registration and delayed identity cannot survive an installation epoch change',
    () async {
      final gate = Completer<PluginAccountAuthentication?>();
      coordinator.unregister(source, lease!);
      lease = await coordinator.registerStoredSession(
        source: source,
        origin: _origin,
        cookies: cookies,
        authenticated: () async => true,
        identity: () => gate.future,
      );
      final old = coordinator.refreshCurrentIdentity(
        source,
        requireFresh: true,
      );
      await Future<void>.delayed(Duration.zero);
      await LocalPluginInstallationState.instance.setDataExclusions(
        source,
        const {},
        beforeWrite: (_) async {},
      );
      gate.complete(
        const PluginAccountAuthentication(serverIdentity: 'old-install'),
      );
      await expectLater(old, throwsA(anything));
      expect(coordinator.hasProfileAccess(source), isFalse);
      expect(PluginAccountIdentities.current(source), isNull);
      expect(cookies.writes, 0);
    },
  );
  test(
    'a replacement account capture waits for the old lease and persists its own fresh account even when the old read fails',
    () async {
      final entered = Completer<void>();
      final oldIdentity = Completer<PluginAccountAuthentication?>();
      coordinator.unregister(source, lease!);
      lease = await coordinator.registerStoredSession(
        source: source,
        origin: _origin,
        cookies: cookies,
        authenticated: () async => true,
        identity: () {
          entered.complete();
          return oldIdentity.future;
        },
      );
      final oldCapture = coordinator.captureAuthenticated(source);
      final oldFailure = expectLater(
        oldCapture,
        throwsA(isA<PluginSessionChanged>()),
      );
      await entered.future;
      coordinator.unregister(source, lease!);
      cookies.values = [_cookie('B')];
      var newReads = 0;
      lease = await coordinator.registerStoredSession(
        source: source,
        origin: _origin,
        cookies: cookies,
        authenticated: () async => true,
        identity: () async {
          newReads++;
          return PluginAccountAuthentication(
            serverIdentity: 'B',
            label: 'Member B',
            origin: _origin.origin,
          );
        },
      );
      final newCapture = coordinator.captureAuthenticated(
        source,
        explicitSave: true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        newReads,
        0,
        reason: 'replacement snapshots remain serialized behind the old owner',
      );
      expect(PluginAccountProfiles.read(source).profiles, isEmpty);
      oldIdentity.complete(
        PluginAccountAuthentication(
          serverIdentity: 'A',
          label: 'Member A',
          origin: _origin.origin,
        ),
      );
      await oldFailure;
      await newCapture;
      expect(newReads, 1);
      final profile = PluginAccountProfiles.read(
        source,
      ).profiles.values.singleWhere((row) => !row.deleted);
      expect(profile.serverIdentity, 'B');
      expect(await PluginAccountProfiles.selected(source), profile.id);
      final snapshot = VideoAccountBackup.parse(
        readHostPluginConfiguration(source)['account.backup'],
        _origin,
      )!;
      expect(snapshot.cookies, [_cookie('B')]);
      expect(PluginAccountIdentities.current(source)?.serverIdentity, 'B');
      expect(
        cookies.writes,
        0,
        reason: 'capture does not mutate either browser session',
      );
    },
  );
  test(
    'native cookie enumeration order does not prevent a freshly verified Omo account from persisting',
    () async {
      cookies.values = [
        _cookie('A'),
        {..._cookie('auxiliary'), 'name': 'session_aux'},
      ];
      cookies.reorderReads = true;
      expect(readHostPluginConfiguration(source)['account.backup'], isNull);
      expect(PluginAccountProfiles.read(source).profiles, isEmpty);
      await coordinator.captureAuthenticated(source, explicitSave: true);
      final records = PluginAccountProfiles.read(
        source,
      ).profiles.values.where((row) => !row.deleted).toList();
      expect(records, hasLength(1));
      expect(records.single.serverIdentity, 'A');
      final backup = VideoAccountBackup.parse(
        records.single.bundle['account.backup'],
        _origin,
      )!;
      expect(backup.cookies, hasLength(2));
      final active = VideoAccountBackup.parse(
        readHostPluginConfiguration(source)['account.backup'],
        _origin,
      )!;
      expect(backup.sessionFingerprint, active.sessionFingerprint);
      expect(active.profileId, records.single.id);
      expect(
        (await coordinator.refreshCurrentIdentity(
          source,
          requireFresh: true,
        ))?.serverIdentity,
        'A',
      );
      expect(await PluginAccountProfiles.selected(source), records.single.id);
      expect(
        cookies.writes,
        0,
        reason:
            'saving the authenticated session does not rewrite browser cookies',
      );
    },
  );
  test(
    'a genuinely changed cookie value between identity and capture cannot save the wrong account bundle',
    () async {
      coordinator.unregister(source, lease!);
      lease = await coordinator.registerStoredSession(
        source: source,
        origin: _origin,
        cookies: cookies,
        authenticated: () async => true,
        identity: () async {
          cookies.values = [_cookie('B')];
          return PluginAccountAuthentication(
            serverIdentity: 'A',
            label: 'Member A',
            origin: _origin.origin,
          );
        },
      );
      await coordinator.captureAuthenticated(source, explicitSave: true);
      expect(readHostPluginConfiguration(source)['account.backup'], isNull);
      expect(
        PluginAccountProfiles.read(
          source,
        ).profiles.values.where((row) => !row.deleted),
        isEmpty,
      );
      expect(cookies.writes, 0);
    },
  );
}
