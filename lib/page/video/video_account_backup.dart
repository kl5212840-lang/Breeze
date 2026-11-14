import 'package:zephyr/network/sync/plugin_account_profiles_data.dart'
    show accountProfileDigest;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

typedef VideoAccountCall =
    Future<Map<String, dynamic>> Function(String, Map<String, dynamic>);

/// A deliberately small site-cookie subset, never the whole browser store.
/// Authentication remains a website concern; backup is not proof of login.
class VideoAccountBackup {
  VideoAccountBackup(this.origin, this.name, this.cookies, {this.profileId});
  final Uri origin;
  final String name;
  final String? profileId;
  final List<Map<String, dynamic>> cookies;

  /// WebKit does not promise cookie enumeration order. Equality still covers
  /// every filtered cookie value and attribute, never just the account label.
  String get sessionFingerprint {
    final ordered = [...cookies]
      ..sort(
        (a, b) => '${a['domain']}|${a['path']}|${a['name']}'.compareTo(
          '${b['domain']}|${b['path']}|${b['name']}',
        ),
      );
    return accountProfileDigest(ordered);
  }

  static bool accountCookieName(String name) =>
      RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]{1,120}$").hasMatch(name) &&
      !RegExp(
        r'^(?:__cf|cf_|_cf|xsrf|csrf|_ga|_gid|_fbp)|challenge|turnstile|captcha',
        caseSensitive: false,
      ).hasMatch(name);

  // MacCMS's declared login group is user_id/user_name/user_check. Only Omo's
  // known HTTPS origins opt into its real JS-readable cookie attributes.
  static bool omoAccountOrigin(String? source, Uri origin) =>
      source == 'ccc2fe17-c0a8-4fd8-a596-835772686404' &&
      origin.scheme == 'https' &&
      origin.userInfo.isEmpty &&
      origin.port == 443 &&
      const {'www.omofuna.com', 'omofuna.com'}.contains(origin.host);
  static bool omoAccountCookie(String? source, Uri origin, String name) =>
      omoAccountOrigin(source, origin) &&
      const {'user_id', 'user_name', 'user_check'}.contains(name);

  static VideoAccountBackup? parse(dynamic raw, Uri origin, {String? source}) =>
      _parse(raw, origin, source: source);
  static VideoAccountBackup? _parse(
    dynamic raw,
    Uri origin, {
    String? source,
    bool requireComplete = true,
  }) {
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
          (omoAccountOrigin(source, origin) &&
              !omoAccountCookie(source, origin, name)) ||
          token is! String ||
          token.isEmpty ||
          token.length > 4096 ||
          RegExp(r'[\r\n\x00]').hasMatch(token) ||
          (domain != origin.host &&
              !(omoAccountCookie(source, origin, name) &&
                  origin.host == 'www.omofuna.com' &&
                  domain == 'omofuna.com')) ||
          (omoAccountCookie(source, origin, name) &&
              cookie['secure'] is! bool) ||
          (cookie['httpOnly'] != true &&
              !(omoAccountCookie(source, origin, name) &&
                  cookie['httpOnly'] == false)) ||
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
        'domain': omoAccountCookie(source, origin, name)
            ? '${cookie['domain']}'.toLowerCase()
            : origin.host,
        'path': path,
        'httpOnly': cookie['httpOnly'] == true,
        'secure': omoAccountCookie(source, origin, name)
            ? cookie['secure'] == true
            : true,
        'expires': expires,
      });
      if (cookies.length == 16) break;
    }
    if (cookies.isEmpty ||
        requireComplete &&
            omoAccountOrigin(source, origin) &&
            !cookies.map((cookie) => cookie['name']).toSet().containsAll(const {
              'user_id',
              'user_name',
              'user_check',
            }) ||
        cookies.fold<int>(0, (n, c) => n + (c['value'] as String).length) >
            24000) {
      return null;
    }
    final name = raw['name'] is String ? (raw['name'] as String).trim() : '';
    return VideoAccountBackup(
      origin,
      name.length > 80 ? name.substring(0, 80) : name,
      cookies,
      profileId:
          raw['profileId'] is String &&
              RegExp(r'^[a-f0-9]{64}$').hasMatch(raw['profileId'] as String)
          ? raw['profileId'] as String
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'origin': origin.origin,
    'name': name,
    'cookies': cookies,
    if (profileId != null) 'profileId': profileId,
  };
}

abstract class VideoAccountCookies {
  Future<List<Map<String, dynamic>>> read(Uri origin);
  Future<void> set(Uri origin, Map<String, dynamic> cookie);
  Future<void> delete(Uri origin, Map<String, dynamic> cookie);
}

/// A per-registration lease, independent of the browser's own lifetime.
/// Closing an old lease must not close a newer lease on the same controller.
abstract interface class VideoAccountCookieLifetime {
  Future<void> closeAccountCookieAccess();
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
      domain: cookie['domain'] as String? ?? origin.host,
      path: cookie['path'] as String,
      expiresDate: cookie['expires'] as int?,
      isSecure: cookie['secure'] == true,
      isHttpOnly: cookie['httpOnly'] == true,
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
    this.source,
  });
  final String? source;
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
      source: source,
    );
  }

  Future<void> backup(String name) async {
    final snapshot = VideoAccountBackup.parse(
      {
        'version': 1,
        'origin': origin.origin,
        'name': name,
        'cookies': await cookies
            .read(origin)
            .timeout(const Duration(seconds: 5)),
      },
      origin,
      source: source,
    );
    if (snapshot == null) throw const FormatException('No account session');
    await saveSnapshot(snapshot);
  }

  Future<void> saveSnapshot(
    VideoAccountBackup snapshot, {
    void Function()? beforeSave,
  }) async {
    final valid = VideoAccountBackup.parse(
      snapshot.toJson(),
      origin,
      source: source,
    );
    if (valid == null) throw const FormatException('No account session');
    beforeSave?.call();
    final response = await call(saveFn, {
      'backup': valid.toJson(),
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

  Future<void> restore(
    VideoAccountBackup snapshot, {
    bool Function()? canApply,
  }) async {
    if (_working) throw StateError('Account session operation in progress');
    final valid = VideoAccountBackup.parse(
      snapshot.toJson(),
      origin,
      source: source,
    );
    if (valid == null) throw const FormatException('No account session');
    await _replaceCookies(valid.cookies, canApply: canApply);
  }

  Future<bool> isDeleted() async {
    final response = await call(readFn, {}).timeout(const Duration(seconds: 8));
    final data = response['data'];
    final backup = data is Map ? data['backup'] : null;
    return backup is Map &&
        backup['version'] == 1 &&
        backup['origin'] == origin.origin &&
        backup['deleted'] == true;
  }

  Future<void> clearSession({bool Function()? canApply}) =>
      _replaceCookies(const [], canApply: canApply);

  Future<void> _replaceCookies(
    List<Map<String, dynamic>> replacement, {
    bool Function()? canApply,
  }) async {
    if (_working) throw StateError('Account session operation in progress');
    void guard() {
      if (canApply?.call() == false)
        throw StateError('Account session changed');
    }

    guard();
    _working = true;
    try {
      final currentRaw = await cookies
          .read(origin)
          .timeout(const Duration(seconds: 5));
      guard();
      // Keep original metadata for rollback. The source-specific parser admits
      // only its declared login group; provider/unrelated cookies stay intact.
      final current = currentRaw
          .where(
            (c) =>
                VideoAccountBackup._parse(
                  {
                    'version': 1,
                    'origin': origin.origin,
                    'cookies': [c],
                  },
                  origin,
                  source: source,
                  requireComplete: false,
                ) !=
                null,
          )
          .toList();
      try {
        for (final c in current) {
          guard();
          await cookies.delete(origin, c).timeout(const Duration(seconds: 3));
        }
        for (final c in replacement) {
          guard();
          await cookies.set(origin, c).timeout(const Duration(seconds: 3));
        }
        final applied = await cookies
            .read(origin)
            .timeout(const Duration(seconds: 5));
        guard();
        for (final previous in current) {
          final retained = replacement.any(
            (cookie) =>
                cookie['name'] == previous['name'] &&
                cookie['path'] == previous['path'],
          );
          if (!retained &&
              applied.any(
                (cookie) =>
                    cookie['name'] == previous['name'] &&
                    cookie['path'] == previous['path'],
              )) {
            throw StateError('Previous account session was not removed');
          }
        }
        for (final expected in replacement) {
          if (!applied.any(
            (actual) =>
                actual['name'] == expected['name'] &&
                actual['value'] == expected['value'] &&
                actual['path'] == expected['path'] &&
                '${actual['domain']}'
                        .replaceFirst(RegExp(r'^\.'), '')
                        .toLowerCase() ==
                    '${expected['domain']}'
                        .replaceFirst(RegExp(r'^\.'), '')
                        .toLowerCase() &&
                (source == null ||
                    actual['httpOnly'] == expected['httpOnly'] &&
                        actual['secure'] == expected['secure']),
          )) {
            throw StateError('Account session was not written');
          }
        }
      } catch (_) {
        // A new local login owns the browser now; stale rollback must not
        // overwrite it. The source-scoped native adapter also fences late IO.
        if (canApply?.call() == false) rethrow;
        // Cleanup itself can fail. Still attempt every original entry instead
        // of abandoning rollback after the first unavailable platform call.
        var rollbackIncomplete = false;
        for (final c in replacement) {
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
