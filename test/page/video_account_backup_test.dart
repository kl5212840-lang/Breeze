import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/video/video_account_backup.dart';

final _origin = Uri.parse('https://hanime1.me/');
Map<String, dynamic> _cookie(
  String name, {
  String domain = 'hanime1.me',
  String value = 'fake-session',
  bool httpOnly = true,
  int? expires,
}) => {
  'name': name,
  'domain': domain,
  'value': value,
  'httpOnly': httpOnly,
  'secure': true,
  'path': '/',
  'expires': expires,
};
Map<String, dynamic> _backup(List<Map<String, dynamic>> cookies) => {
  'version': 1,
  'origin': _origin.origin,
  'name': 'Example',
  'cookies': cookies,
};

class _Cookies implements VideoAccountCookies {
  final List<Map<String, dynamic>> values = [];
  bool failNextSet = false;
  final failDeleteNames = <String>{};
  final failSetNames = <String>{};
  @override
  Future<List<Map<String, dynamic>>> read(Uri origin) async => List.of(values);
  @override
  Future<void> delete(Uri origin, Map<String, dynamic> cookie) async {
    if (failDeleteNames.contains(cookie['name'])) {
      throw StateError('delete failed');
    }
    values.removeWhere(
      (c) => c['name'] == cookie['name'] && c['domain'] == cookie['domain'],
    );
  }

  @override
  Future<void> set(Uri origin, Map<String, dynamic> cookie) async {
    if (failSetNames.contains(cookie['name'])) throw StateError('write failed');
    if (failNextSet) {
      failNextSet = false;
      throw StateError('write failed');
    }
    values.removeWhere(
      (c) => c['name'] == cookie['name'] && c['domain'] == cookie['domain'],
    );
    values.add(Map.of(cookie));
  }
}

void main() {
  for (final failedStep in ['cleanup', 'first-restore']) {
    test(
      'rollback attempts remaining account entries after $failedStep fails',
      () async {
        final cookies = _Cookies()
          ..values.addAll([
            _cookie('old_session', value: 'old'),
            _cookie('old_remember', value: 'old-remember'),
            _cookie('cf_clearance'),
          ])
          ..failNextSet = true;
        if (failedStep == 'cleanup') {
          cookies.failDeleteNames.add('new_session');
        } else {
          cookies.failSetNames.add('old_session');
        }
        final service = VideoAccountService(
          origin: _origin,
          cookies: cookies,
          call: (_, _) async => {},
          readFn: 'read',
          saveFn: 'save',
          forgetFn: 'forget',
        );
        final backup = VideoAccountBackup.parse(
          _backup([_cookie('new_session', value: 'new')]),
          _origin,
        )!;
        await expectLater(service.restore(backup), throwsStateError);
        expect(cookies.values.map((c) => c['name']), contains('old_remember'));
        expect(cookies.values.map((c) => c['name']), contains('cf_clearance'));
        if (failedStep == 'cleanup') {
          expect(cookies.values.map((c) => c['name']), contains('old_session'));
        }
      },
    );
  }

  test(
    'only first-party HttpOnly account candidates survive both restore and export',
    () {
      final raw = _backup([
        _cookie('site_session'),
        _cookie('cf_clearance'),
        _cookie('__cf_bm'),
        _cookie('XSRF-TOKEN'),
        _cookie('other', domain: 'bika.example'),
        _cookie('expired', expires: 1),
        _cookie('public', httpOnly: false),
        _cookie('header', value: 'x\r\nCookie: secret'),
      ]);
      final parsed = VideoAccountBackup.parse(raw, _origin)!;
      expect(parsed.cookies.map((c) => c['name']), ['site_session']);
      expect(
        VideoAccountBackup.parse({
          ...raw,
          'origin': 'https://other.example',
        }, _origin),
        isNull,
      );
      expect(
        VideoAccountBackup.parse({...raw, 'deleted': true}, _origin),
        isNull,
      );
    },
  );

  test(
    'restore replaces only account cookies and rollback keeps current account on failure',
    () async {
      final cookies = _Cookies()
        ..values.addAll([
          _cookie('site_session', value: 'old'),
          _cookie('cf_clearance'),
          _cookie('other', domain: 'other.example'),
          _cookie('public', httpOnly: false),
        ]);
      final service = VideoAccountService(
        origin: _origin,
        cookies: cookies,
        call: (_, _) async => {},
        readFn: 'read',
        saveFn: 'save',
        forgetFn: 'forget',
      );
      final backup = VideoAccountBackup.parse(
        _backup([_cookie('site_session', value: 'new')]),
        _origin,
      )!;
      cookies.failNextSet = true;
      await expectLater(service.restore(backup), throwsStateError);
      expect(
        cookies.values.firstWhere((c) => c['name'] == 'site_session')['value'],
        'old',
      );
      await service.restore(backup);
      expect(
        cookies.values.firstWhere((c) => c['name'] == 'site_session')['value'],
        'new',
      );
      expect(
        cookies.values.map((c) => c['name']),
        containsAll(['cf_clearance', 'other', 'public']),
      );
    },
  );

  test(
    'explicit backup filters cookies before entering the plugin bridge',
    () async {
      final cookies = _Cookies()
        ..values.addAll([_cookie('site_session'), _cookie('cf_clearance')]);
      Map<String, dynamic>? sent;
      final service = VideoAccountService(
        origin: _origin,
        cookies: cookies,
        call: (fn, core) async {
          sent = core;
          return {
            'data': {'saved': true},
          };
        },
        readFn: 'read',
        saveFn: 'save',
        forgetFn: 'forget',
      );
      await service.backup('Example');
      expect(
        (sent!['backup']['cookies'] as List).single['name'],
        'site_session',
      );
      expect(sent.toString(), isNot(contains('cf_clearance')));
    },
  );

  test(
    'unsupported sources and failed plugin writes are not reported as success',
    () async {
      expect(
        VideoAccountService.supported({
          'version': 1,
          'origin': 'https://other.example',
          'readFn': 'x',
          'saveFn': 'x',
          'forgetFn': 'x',
        }, _origin),
        isFalse,
      );
      final cookies = _Cookies()..values.add(_cookie('site_session'));
      final service = VideoAccountService(
        origin: _origin,
        cookies: cookies,
        call: (_, _) async => {
          'data': {'saved': false},
        },
        readFn: 'read',
        saveFn: 'save',
        forgetFn: 'forget',
      );
      await expectLater(service.backup('Example'), throwsStateError);
      await expectLater(service.forget(), throwsStateError);
    },
  );
}
