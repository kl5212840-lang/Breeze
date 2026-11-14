import 'dart:async';
import 'dart:collection';

import 'package:flutter/services.dart';

/// Release-enabled, page-owned flight recorder. Never persists or uploads data.
/// Transport callbacks enter from a different isolate/zone, so subscribe by
/// source only while that page is resolving. Never record request arguments,
/// headers, bodies, account values or native context tokens.
class PlaybackTrace {
  final _clock = Stopwatch()..start();
  final _events = Queue<String>();
  static final _active = <String, Map<PlaybackTrace, int>>{};
  static bool isCapturing(String source) => _active[source]?.isNotEmpty == true;
  static const _maxEvents = 80, _maxCharacters = 24000;
  int _characters = 0, _sequence = 0;

  void add(String stage, String message) {
    final event =
        '#${++_sequence} +${_clock.elapsedMilliseconds}ms '
        '${sanitizePlaybackLog(stage, limit: 100)} '
        '${sanitizePlaybackLog(message)}';
    _events.add(event);
    _characters += event.length + 1;
    while (_events.length > _maxEvents || _characters > _maxCharacters) {
      _characters -= _events.removeFirst().length + 1;
    }
  }

  void failure(String stage, Object error, StackTrace stack) {
    final message = error is PlatformException
        ? '${error.runtimeType}: code=${error.code}; message=${error.message}; '
              'nativeStack=${error.stacktrace ?? "unavailable"}'
        : error is FormatException
        ? 'FormatException: ${error.message}; offset=${error.offset}'
        : '${error.runtimeType}: $error';
    add(stage, '$message\nstack:\n$stack');
  }

  Future<T> run<T>(String source, Future<T> Function() action) async {
    final listeners = _active.putIfAbsent(source, () => {});
    listeners[this] = (listeners[this] ?? 0) + 1;
    try {
      return await action();
    } finally {
      final count = listeners[this]! - 1;
      if (count == 0) {
        listeners.remove(this);
      } else {
        listeners[this] = count;
      }
      if (listeners.isEmpty) _active.remove(source);
    }
  }

  static void note(String source, String stage, String message) {
    for (final trace in _active[source]?.keys.toList() ?? <PlaybackTrace>[]) {
      trace.add(stage, message);
    }
  }

  static void error(
    String source,
    String stage,
    Object error,
    StackTrace stack,
  ) {
    for (final trace in _active[source]?.keys.toList() ?? <PlaybackTrace>[]) {
      trace.failure(stage, error, stack);
    }
  }

  String export() =>
      _events.isEmpty ? 'No playback events captured.' : _events.join('\n');
}

/// Keep actual error names/messages and stack locations, redact embedded data.
/// URLs retain only public host/port (no credentials, paths, queries or fragments).
String sanitizePlaybackLog(String input, {int limit = 5000}) {
  var text = input.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
  text = text.replaceAllMapped(
    RegExp(r'''(?:https?|socks5?)://[^\s<>"']+''', caseSensitive: false),
    (match) {
      final uri = Uri.tryParse(match[0]!);
      if (uri == null || uri.host.isEmpty) return '<url>';
      return '${uri.scheme}://${uri.host}${uri.hasPort ? ":${uri.port}" : ""}/<redacted>';
    },
  );
  // Header values may contain spaces/semicolons; drop the entire value line.
  text = text.replaceAll(
    RegExp(
      r'''\b(?:set-cookie|cookie|authorization|proxy-authorization|x-api-key|api-key|x-auth-token|x-access-token|x-session-id|x-csrf-token|x-xsrf-token)\b["']?\s*[:=][^\r\n]*''',
      caseSensitive: false,
    ),
    '<private-header>',
  );
  text = text.replaceAll(
    RegExp(
      r'''["']?(?:password|passwd|token|access[_-]?token|refresh[_-]?token|api[_-]?key|client[_-]?secret|client[_-]?token|networkContext|session[_-]?(?:id|key)|csrf[_-]?token|xsrf[_-]?token|secret|email|username|account[_-]?id|user[_-]?id)["']?\s*[:=]\s*(?:"[^"\r\n]*"|'[^'\r\n]*'|[^\s,;}]+)''',
      caseSensitive: false,
    ),
    '<private-value>',
  );
  text = text.replaceAll(
    RegExp(r'\bBearer\s+[^\s,;]+', caseSensitive: false),
    '<authorization>',
  );
  text = text.replaceAll(RegExp(r'[^\s@]+@[^\s@]+\.[a-zA-Z]{2,}'), '<email>');
  text = text.replaceAll(RegExp(r'\b[A-Za-z0-9_-]{40,}\b'), '<opaque-value>');
  text = text.replaceAll(RegExp(r'\b\d{9,}\b'), '<number>');
  return text.length <= limit
      ? text
      : '${text.substring(0, limit)}\n<truncated>';
}
