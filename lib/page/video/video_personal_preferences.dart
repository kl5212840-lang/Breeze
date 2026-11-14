import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// User-selected presentation/filter state; contains no account session.
abstract final class VideoPersonalPreferences {
  static const prefix = 'breeze.video.personal.preferences.v1.';
  static Future<void>? _tail;
  static Future<void> flush() async {
    await _tail;
  }

  static Future<Map<String, dynamic>> read(String scope) async {
    try {
      await _tail;
      final raw = (await SharedPreferences.getInstance()).getString(
        '$prefix${Uri.encodeComponent(scope)}',
      );
      return raw == null
          ? {}
          : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  static Future<void> write(String scope, Map<String, dynamic> value) {
    final next = (_tail ?? Future<void>.value()).then(
      (_) => _write(scope, value),
    );
    final tail = next.then<void>((_) {}, onError: (Object _) {});
    _tail = tail;
    unawaited(
      tail.then((_) {
        if (identical(_tail, tail)) _tail = null;
      }),
    );
    return next;
  }

  static Future<void> _write(String scope, Map<String, dynamic> value) async {
    if (!await (await SharedPreferences.getInstance()).setString(
      '$prefix${Uri.encodeComponent(scope)}',
      jsonEncode(value),
    )) {
      throw StateError('Personal list preference was not saved');
    }
  }
}
