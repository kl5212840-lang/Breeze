import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/video_account_backup.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/plugin_account_sync_coordinator.dart';

class _Cookies implements VideoAccountCookies {
  final values = <Map<String, dynamic>>[];
  int writes = 0;
  void Function()? onWrite;
  bool failNextSet = false;
  @override
  Future<List<Map<String, dynamic>>> read(Uri origin) async =>
      values.map((e) => Map<String, dynamic>.from(e)).toList();
  @override
  Future<void> set(Uri origin, Map<String, dynamic> cookie) async {
    writes++;
    onWrite?.call();
    if (failNextSet) {
      failNextSet = false;
      throw StateError('Synthetic cookie write failure');
    }
    values.removeWhere(
      (c) => c['name'] == cookie['name'] && c['path'] == cookie['path'],
    );
    values.add(Map<String, dynamic>.from(cookie));
  }

  @override
  Future<void> delete(Uri origin, Map<String, dynamic> cookie) async {
    writes++;
    onWrite?.call();
    values.removeWhere(
      (c) => c['name'] == cookie['name'] && c['path'] == cookie['path'],
    );
  }
}

class _CookieLease extends _Cookies implements VideoAccountCookieLifetime {
  int closes = 0;
  @override
  Future<void> closeAccountCookieAccess() async { closes++; }
}

Map<String, dynamic> _cookie(String name, String value) => {
  'name': name,
  'value': value,
  'domain': 'site.example',
  'path': '/',
  'httpOnly': true,
  'secure': true,
  'expires': null,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'fresh authentication captures only filtered cookies and deduplicates writes',
    () async {
      final configuration = <String, dynamic>{};
      var authenticated = false, saves = 0;
      final cookies = _Cookies()
        ..values.addAll([
          _cookie('session', 'synthetic-session'),
          _cookie('cf_clearance', 'synthetic-cf'),
          _cookie('csrf', 'synthetic-csrf'),
        ]);
      final coordinator = PluginAccountSyncCoordinator.forTesting(
        readConfiguration: (_) => configuration,
      );
      await coordinator.register(
        source: 'source',
        origin: Uri.parse('https://site.example'),
        accountSync: {
          'version': 1,
          'origin': 'https://site.example',
          'readFn': 'read',
          'saveFn': 'save',
          'forgetFn': 'forget',
        },
        cookies: cookies,
        authenticated: () async => authenticated,
        call: (fn, args) async {
          if (fn == 'save') {
            configuration['account.backup'] = args['backup'];
            saves++;
          }
          return {
            'data': fn == 'read'
                ? {'backup': configuration['account.backup']}
                : {'saved': true},
          };
        },
      );
      await coordinator.captureAuthenticated('source');
      expect(saves, 0);
      authenticated = true;
      await coordinator.captureAuthenticated('source');
      expect(saves, 1);
      expect(
        (configuration['account.backup']['cookies'] as List).map(
          (c) => c['name'],
        ),
        ['session'],
      );
      await coordinator.captureAuthenticated('source');
      expect(saves, 1);
      cookies.values.clear();
      await coordinator.captureAuthenticated('source');
      expect(saves, 1, reason: 'device session loss is not portable logout');
    },
  );

  test(
    'only global restore schedules one cookie apply; stale and disabled requests do not overwrite',
    () async {
      final savedCookie = _cookie('session', 'cloud-session');
      final configuration = <String, dynamic>{
        'account.backup': {
          'version': 1,
          'origin': 'https://site.example',
          'name': '',
          'cookies': [savedCookie],
        },
      };
      var enabled = true;
      final generation = pluginSessionWriteFence.generation('source');
      final mutationStates = <bool>[];
      final cookies = _Cookies()
        ..onWrite = () => mutationStates.add(
          pluginSessionWriteFence.isChanging('source'),
        );
      final coordinator = PluginAccountSyncCoordinator.forTesting(
        readConfiguration: (_) => configuration,
        enabled: () => enabled,
      );
      final lease = await coordinator.register(
        source: 'source',
        origin: Uri.parse('https://site.example'),
        accountSync: {
          'version': 1,
          'origin': 'https://site.example',
          'readFn': 'read',
          'saveFn': 'save',
          'forgetFn': 'forget',
        },
        cookies: cookies,
        authenticated: () async => false,
        call: (fn, args) async => {
          'data': {'backup': configuration['account.backup']},
        },
      );
      expect(
        await coordinator.restoreOnEntry('source'),
        AccountSessionRestoreResult.notPending,
      );
      expect(cookies.writes, 0);
      expect(pluginSessionWriteFence.generation('source'), generation);
      await coordinator.markRestorePending({'source'});
      enabled = false;
      expect(
        await coordinator.restoreOnEntry('source'),
        AccountSessionRestoreResult.notPending,
      );
      expect(cookies.writes, 0);
      expect(pluginSessionWriteFence.generation('source'), generation);
      enabled = true;
      expect(
        await coordinator.restoreOnEntry('source'),
        AccountSessionRestoreResult.restored,
      );
      expect(cookies.values.single['value'], 'cloud-session');
      expect(mutationStates, [true]);
      expect(pluginSessionWriteFence.generation('source'), generation + 2);
      expect(pluginSessionWriteFence.isChanging('source'), false);
      final writes = cookies.writes;
      expect(
        await coordinator.restoreOnEntry('source'),
        AccountSessionRestoreResult.notPending,
      );
      expect(cookies.writes, writes);
      expect(pluginSessionWriteFence.generation('source'), generation + 2);
      await coordinator.markRestorePending({'source'});
      configuration['account.credentials'] = {'account': 'new-local-login'};
      expect(
        await coordinator.restoreOnEntry('source'),
        AccountSessionRestoreResult.notPending,
      );
      expect(cookies.writes, writes);
      expect(pluginSessionWriteFence.generation('source'), generation + 2);
      coordinator.unregister('source', lease);
      await coordinator.markRestorePending({'source'});
      expect(
        await coordinator.restoreOnEntry('source'),
        AccountSessionRestoreResult.notPending,
      );
    },
  );
  test(
    'expired snapshots never clear live cookies, explicit deletion keeps CF cookies',
    () async {
      final configuration = <String, dynamic>{
        'account.backup': {
          'version': 1,
          'origin': 'https://site.example',
          'cookies': [
            {..._cookie('session', 'expired'), 'expires': 1},
          ],
        },
      };
      final cookies = _Cookies()
        ..values.addAll([
          _cookie('session', 'current-device'),
          _cookie('cf_clearance', 'current-cf'),
        ]);
      final generation = pluginSessionWriteFence.generation('source');
      final mutationStates = <bool>[];
      cookies.onWrite = () => mutationStates.add(
        pluginSessionWriteFence.isChanging('source'),
      );
      final coordinator = PluginAccountSyncCoordinator.forTesting(
        readConfiguration: (_) => configuration,
      );
      await coordinator.register(
        source: 'source',
        origin: Uri.parse('https://site.example'),
        accountSync: {
          'version': 1,
          'origin': 'https://site.example',
          'readFn': 'read',
          'saveFn': 'save',
          'forgetFn': 'forget',
        },
        cookies: cookies,
        authenticated: () async => false,
        call: (fn, args) async => {
          'data': {'backup': configuration['account.backup']},
        },
      );
      await coordinator.markRestorePending({'source'});
      expect(
        await coordinator.restoreOnEntry('source'),
        AccountSessionRestoreResult.notPending,
      );
      expect(cookies.writes, 0);
      expect(pluginSessionWriteFence.generation('source'), generation);
      configuration['account.backup'] = {
        'version': 1,
        'origin': 'https://site.example',
        'deleted': true,
      };
      await coordinator.markRestorePending({'source'});
      expect(
        await coordinator.restoreOnEntry('source'),
        AccountSessionRestoreResult.cleared,
      );
      expect(cookies.values.single['name'], 'cf_clearance');
      expect(mutationStates, [true]);
      expect(pluginSessionWriteFence.generation('source'), generation + 2);
      expect(pluginSessionWriteFence.isChanging('source'), false);
    },
  );

  for (final sessionChanged in [false, true]) {
    test(
      sessionChanged
          ? 'a newer local session cancels a pending restore during preflight'
          : 'a browser replacement can apply a pending restore before any write',
      () async {
        const source = 'replaced-restore-source';
        final origin = Uri.parse('https://site.example');
        final backup = {
          'version': 1,
          'origin': origin.origin,
          'cookies': [_cookie('session', 'cloud-session')],
        };
        final coordinator = PluginAccountSyncCoordinator.forTesting(
          readConfiguration: (_) => {'account.backup': backup},
        );
        Future<Object> register(_Cookies cookies, VideoAccountCall call) =>
            coordinator.register(
              source: source,
              origin: origin,
              accountSync: {
                'version': 1,
                'origin': origin.origin,
                'readFn': 'read',
                'saveFn': 'save',
                'forgetFn': 'forget',
              },
              cookies: cookies,
              authenticated: () async => false,
              call: call,
            );
        final readStarted = Completer<void>();
        final finishRead = Completer<void>();
        final firstCookies = _Cookies();
        await register(firstCookies, (_, _) async {
          readStarted.complete();
          await finishRead.future;
          return {
            'data': {'backup': backup},
          };
        });
        await coordinator.markRestorePending({source});
        final first = coordinator.restoreOnEntry(source);
        await readStarted.future;
        final nextCookies = _Cookies();
        await register(
          nextCookies,
          (_, _) async => {
            'data': {'backup': backup},
          },
        );
        if (sessionChanged) pluginSessionWriteFence.advance(source);
        final next = coordinator.restoreOnEntry(source);
        finishRead.complete();

        expect(await first, AccountSessionRestoreResult.notPending);
        expect(firstCookies.writes, 0);
        expect(
          await next,
          sessionChanged
              ? AccountSessionRestoreResult.notPending
              : AccountSessionRestoreResult.restored,
        );
        expect(nextCookies.writes, sessionChanged ? 0 : 1);
        expect(
          await coordinator.restoreOnEntry(source),
          AccountSessionRestoreResult.notPending,
        );
      },
    );
  }

  test('a failed cookie restore rolls back and seals its session owner', () async {
    const source = 'failing-source';
    final origin = Uri.parse('https://site.example');
    final configuration = {
      'account.backup': {
        'version': 1,
        'origin': origin.origin,
        'cookies': [_cookie('session', 'cloud-session')],
      },
    };
    final generation = pluginSessionWriteFence.generation(source);
    final mutationStates = <bool>[];
    final cookies = _Cookies()
      ..values.add(_cookie('session', 'existing-session'))
      ..failNextSet = true
      ..onWrite = () => mutationStates.add(
        pluginSessionWriteFence.isChanging(source),
      );
    final coordinator = PluginAccountSyncCoordinator.forTesting(
      readConfiguration: (_) => configuration,
    );
    await coordinator.register(
      source: source,
      origin: origin,
      accountSync: {
        'version': 1,
        'origin': origin.origin,
        'readFn': 'read',
        'saveFn': 'save',
        'forgetFn': 'forget',
      },
      cookies: cookies,
      authenticated: () async => false,
      call: (_, _) async => {
        'data': {'backup': configuration['account.backup']},
      },
    );
    await coordinator.markRestorePending({source});
    expect(
      await coordinator.restoreOnEntry(source),
      AccountSessionRestoreResult.failed,
    );
    expect(mutationStates, [true, true, true, true]);
    expect(cookies.values.single['value'], 'existing-session');
    expect(pluginSessionWriteFence.generation(source), generation + 2);
    expect(pluginSessionWriteFence.isChanging(source), false);
    expect(
      await coordinator.restoreOnEntry(source),
      AccountSessionRestoreResult.notPending,
    );
    expect(pluginSessionWriteFence.generation(source), generation + 2);
  });

  test(
    'late authenticated callback from an unregistered browser cannot save',
    () async {
      final configuration = <String, dynamic>{};
      final gate = Completer<bool>();
      var saves = 0;
      final coordinator = PluginAccountSyncCoordinator.forTesting(
        readConfiguration: (_) => configuration,
      );
      final lease = await coordinator.register(
        source: 'source',
        origin: Uri.parse('https://site.example'),
        accountSync: {
          'version': 1,
          'origin': 'https://site.example',
          'readFn': 'read',
          'saveFn': 'save',
          'forgetFn': 'forget',
        },
        cookies: _Cookies()..values.add(_cookie('session', 'synthetic')),
        authenticated: () => gate.future,
        call: (fn, args) async {
          if (fn == 'save') saves++;
          return {
            'data': {'saved': true},
          };
        },
      );
      final operation = coordinator.captureAuthenticated('source');
      coordinator.unregister('source', lease);
      gate.complete(true);
      await operation;
      expect(saves, 0);
    },
  );
  test('replaced registration closes only its cookie lease and stale unregister cannot close the replacement', () async {
    final coordinator = PluginAccountSyncCoordinator.forTesting(readConfiguration: (_) => {});
    final oldCookies = _CookieLease(), newCookies = _CookieLease();
    Future<Object> register(_Cookies cookies) => coordinator.register(
      source: 'source', origin: Uri.parse('https://site.example'),
      accountSync: {'version': 1, 'origin': 'https://site.example', 'readFn': 'read', 'saveFn': 'save', 'forgetFn': 'forget'},
      cookies: cookies, authenticated: () async => false,
      call: (_, _) async => {'data': {'backup': null}},
    );
    final old = await register(oldCookies);
    final current = await register(newCookies);
    expect(oldCookies.closes, 1);
    expect(coordinator.isRegistered('source', current), isTrue);
    coordinator.unregister('source', old);
    expect(newCookies.closes, 0);
    coordinator.unregister('source', current);
    expect(newCookies.closes, 1);
    expect(coordinator.isRegistered('source', current), isFalse);
  });

}
