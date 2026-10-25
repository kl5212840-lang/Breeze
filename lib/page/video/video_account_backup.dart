import 'package:flutter_inappwebview/flutter_inappwebview.dart';

typedef VideoAccountCall =
    Future<Map<String, dynamic>> Function(String, Map<String, dynamic>);

/// A deliberately small site-cookie subset, never the whole browser store.
/// Authentication remains a website concern; backup is not proof of login.
class VideoAccountBackup {
  VideoAccountBackup(this.origin, this.name, this.cookies);
  final Uri origin;
  final String name;
  final List<Map<String, dynamic>> cookies;

  static bool accountCookieName(String name) =>
      RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]{1,120}$").hasMatch(name) &&
      !RegExp(
        r'^(?:__cf|cf_|_cf|xsrf|csrf|_ga|_gid|_fbp)|challenge|turnstile|captcha',
        caseSensitive: false,
      ).hasMatch(name);

  static VideoAccountBackup? parse(dynamic raw, Uri origin) {
    if (raw is! Map ||
        raw['version'] != 1 ||
        raw['origin'] != origin.origin ||
        raw['deleted'] == true) {
      return null;
    }
    final cookies = <Map<String, dynamic>>[];
    for (final value
        in (raw['cookies'] is List ? raw['cookies'] as List : const []).take(
          32,
        )) {
      if (value is! Map) continue;
      final cookie = Map<String, dynamic>.from(value);
      final name = cookie['name'];
      final token = cookie['value'];
      final domain = cookie['domain']
          ?.toString()
          .replaceFirst(RegExp(r'^\.'), '')
          .toLowerCase();
      final path = cookie['path'];
      final expires = cookie['expires'];
      if (name is! String ||
          !accountCookieName(name) ||
          token is! String ||
          token.isEmpty ||
          token.length > 4096 ||
          RegExp(r'[\r\n\x00]').hasMatch(token) ||
          domain != origin.host ||
          cookie['httpOnly'] != true ||
          path is! String ||
          !path.startsWith('/') ||
          path.length > 256 ||
          RegExp(r'[\r\n\x00]').hasMatch(path) ||
          (expires != null &&
              (expires is! int ||
                  expires <= DateTime.now().millisecondsSinceEpoch))) {
        continue;
      }
      cookies.add({
        'name': name,
        'value': token,
        'domain': origin.host,
        'path': path,
        'httpOnly': true,
        'secure': true,
        'expires': expires,
      });
      if (cookies.length == 16) break;
    }
    if (cookies.isEmpty ||
        cookies.fold<int>(0, (n, c) => n + (c['value'] as String).length) >
            24000) {
      return null;
    }
    final name = raw['name'] is String ? (raw['name'] as String).trim() : '';
    return VideoAccountBackup(
      origin,
      name.length > 80 ? name.substring(0, 80) : name,
      cookies,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'origin': origin.origin,
    'name': name,
    'cookies': cookies,
  };
}

abstract class VideoAccountCookies {
  Future<List<Map<String, dynamic>>> read(Uri origin);
  Future<void> set(Uri origin, Map<String, dynamic> cookie);
  Future<void> delete(Uri origin, Map<String, dynamic> cookie);
}

class PlatformVideoAccountCookies implements VideoAccountCookies {
  final _manager = CookieManager.instance();
  @override
  Future<List<Map<String, dynamic>>> read(Uri origin) async =>
      (await _manager.getCookies(url: WebUri(origin.toString())))
          .map(
            (c) => <String, dynamic>{
              'name': c.name,
              'value': '${c.value ?? ''}',
              'domain': c.domain ?? origin.host,
              'path': c.path ?? '/',
              'httpOnly': c.isHttpOnly == true,
              'secure': c.isSecure == true,
              'expires': c.expiresDate?.toInt(),
            },
          )
          .toList();
  @override
  Future<void> set(Uri origin, Map<String, dynamic> cookie) async {
    final saved = await _manager.setCookie(
      url: WebUri(origin.toString()),
      name: cookie['name'] as String,
      value: cookie['value'] as String,
      domain: origin.host,
      path: cookie['path'] as String,
      expiresDate: cookie['expires'] as int?,
      isSecure: true,
      isHttpOnly: true,
    );
    if (!saved) throw StateError('Cookie write failed');
  }

  @override
  Future<void> delete(Uri origin, Map<String, dynamic> cookie) async {
    await _manager.deleteCookie(
      url: WebUri(origin.toString()),
      name: cookie['name'] as String,
      domain: cookie['domain'] as String?,
      path: cookie['path'] as String? ?? '/',
    );
  }
}

class VideoAccountService {
  VideoAccountService({
    required this.origin,
    required this.call,
    required this.cookies,
    required this.readFn,
    required this.saveFn,
    required this.forgetFn,
  });
  final Uri origin;
  final VideoAccountCall call;
  final VideoAccountCookies cookies;
  final String readFn, saveFn, forgetFn;
  bool _working = false;

  static bool supported(Map<String, dynamic> config, Uri home) =>
      config['version'] == 1 &&
      config['origin'] == home.origin &&
      ['readFn', 'saveFn', 'forgetFn'].every(
        (key) => RegExp(
          r'^[A-Za-z][A-Za-z0-9_]{0,63}$',
        ).hasMatch('${config[key] ?? ''}'),
      );

  Future<VideoAccountBackup?> read() async {
    final response = await call(readFn, {}).timeout(const Duration(seconds: 8));
    final data = response['data'];
    return VideoAccountBackup.parse(
      data is Map ? data['backup'] : null,
      origin,
    );
  }

  Future<void> backup(String name) async {
    final snapshot = VideoAccountBackup.parse({
      'version': 1,
      'origin': origin.origin,
      'name': name,
      'cookies': await cookies.read(origin).timeout(const Duration(seconds: 5)),
    }, origin);
    if (snapshot == null) throw const FormatException('No account session');
    final response = await call(saveFn, {
      'backup': snapshot.toJson(),
    }).timeout(const Duration(seconds: 8));
    if (response['data'] is! Map || response['data']['saved'] != true) {
      throw StateError('Account backup not saved');
    }
  }

  Future<void> forget() async {
    final response = await call(
      forgetFn,
      {},
    ).timeout(const Duration(seconds: 8));
    if (response['data'] is! Map || response['data']['saved'] != true) {
      throw StateError('Account backup not removed');
    }
  }

  Future<void> restore(VideoAccountBackup snapshot) async {
    if (_working) return;
    final valid = VideoAccountBackup.parse(snapshot.toJson(), origin);
    if (valid == null) throw const FormatException('No account session');
    _working = true;
    try {
      final currentRaw = await cookies
          .read(origin)
          .timeout(const Duration(seconds: 5));
      // Keep original metadata for rollback. Never delete verification,
      // non-HttpOnly, unrelated-domain or another plugin's cookies.
      final current = currentRaw
          .where(
            (c) =>
                c['httpOnly'] == true &&
                VideoAccountBackup.accountCookieName('${c['name']}') &&
                '${c['domain']}'
                        .replaceFirst(RegExp(r'^\.'), '')
                        .toLowerCase() ==
                    origin.host,
          )
          .toList();
      try {
        for (final c in current) {
          await cookies.delete(origin, c).timeout(const Duration(seconds: 3));
        }
        for (final c in valid.cookies) {
          await cookies.set(origin, c).timeout(const Duration(seconds: 3));
        }
        final applied = await cookies
            .read(origin)
            .timeout(const Duration(seconds: 5));
        for (final expected in valid.cookies) {
          if (!applied.any(
            (actual) =>
                actual['name'] == expected['name'] &&
                actual['value'] == expected['value'] &&
                actual['path'] == expected['path'] &&
                '${actual['domain']}'
                        .replaceFirst(RegExp(r'^\.'), '')
                        .toLowerCase() ==
                    origin.host,
          )) {
            throw StateError('Account session was not written');
          }
        }
      } catch (_) {
        // Cleanup itself can fail. Still attempt every original entry instead
        // of abandoning rollback after the first unavailable platform call.
        var rollbackIncomplete = false;
        for (final c in valid.cookies) {
          try {
            await cookies.delete(origin, c).timeout(const Duration(seconds: 3));
          } catch (_) {
            rollbackIncomplete = true;
          }
        }
        for (final c in current) {
          try {
            await cookies.set(origin, c).timeout(const Duration(seconds: 3));
          } catch (_) {
            rollbackIncomplete = true;
          }
        }
        if (rollbackIncomplete) {
          throw StateError('Account restore failed; rollback incomplete');
        }
        rethrow;
      }
    } finally {
      _working = false;
    }
  }
}
