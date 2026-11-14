import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/util/error_filter.dart';

/// A closed set of outcomes for the tracking UI. Plugin messages and response
/// bodies are never rendered or stored on a follow.
enum ComicFollowCheckFailure {
  network,
  sourceUnavailable,
  invalidResponse,
  signInRequired,
  notFound,
  pluginDisabled,
  pluginMissing,
  unknown,
}

class ComicFollowCheckException implements Exception {
  const ComicFollowCheckException(
    this.reason, {
    this.retryable = false,
    this.httpStatus,
    this.message,
  });

  final ComicFollowCheckFailure reason;
  final bool retryable;
  final int? httpStatus;
  final String? message;

  static ComicFollowCheckException? fromPluginEnvelope(
    Object? value, {
    String type = 'comic_follow_error',
  }) {
    if (value is! Map || value['type'] != type) return null;
    final reason = switch (value['reason']) {
      'network' => ComicFollowCheckFailure.network,
      'sourceUnavailable' => ComicFollowCheckFailure.sourceUnavailable,
      'invalidResponse' => ComicFollowCheckFailure.invalidResponse,
      'signInRequired' => ComicFollowCheckFailure.signInRequired,
      'notFound' => ComicFollowCheckFailure.notFound,
      _ => ComicFollowCheckFailure.unknown,
    };
    final allowSourceRecovery =
        type != 'comic_follow_error' &&
        reason == ComicFollowCheckFailure.sourceUnavailable;
    final message = value['message'];
    return ComicFollowCheckException(
      reason,
      retryable:
          (reason == ComicFollowCheckFailure.network || allowSourceRecovery) &&
          value['retryable'] == true,
      message: message is String ? readableErrorMessage(message) : null,
    );
  }
}

final _pluginHttpStatus = RegExp(
  r'(?:\bstatus(?:\s*code)?[ :=]+|\bhttp(?:\s*error)?[ :=]+|^)([1-5]\d{2})\b',
  caseSensitive: false,
);

ComicFollowCheckException classifyComicFollowCheckFailure(
  Object error, {
  String? additionalEnvelopeType,
}) {
  if (error is ComicFollowCheckException) return error;
  if (error is PluginLoginRequiredException) {
    return const ComicFollowCheckException(
      ComicFollowCheckFailure.signInRequired,
    );
  }
  if (error is FormatException || error is TypeError) {
    return const ComicFollowCheckException(
      ComicFollowCheckFailure.invalidResponse,
    );
  }
  final message = normalizeSearchErrorMessage(error);
  final payload = quickJsErrorMessage(error);
  if (payload != null && payload.startsWith('{')) {
    try {
      final decoded = jsonDecode(payload);
      final typed =
          ComicFollowCheckException.fromPluginEnvelope(decoded) ??
          (additionalEnvelopeType == null
              ? null
              : ComicFollowCheckException.fromPluginEnvelope(
                  decoded,
                  type: additionalEnvelopeType,
                ));
      if (typed != null) return typed;
    } on FormatException {
      // Older bundles may throw arbitrary strings.
    }
  }
  final text = message.toLowerCase();
  final status = int.tryParse(
    _pluginHttpStatus.firstMatch(text)?.group(1) ?? '',
  );
  if (status != null) {
    if (status == 408) {
      return const ComicFollowCheckException(
        ComicFollowCheckFailure.network,
        retryable: true,
      );
    }
    // A gateway may return 401/403/404 for the endpoint. Only a structured
    // source result can assert a work-specific sign-in or availability issue.
    return ComicFollowCheckException(
      ComicFollowCheckFailure.sourceUnavailable,
      httpStatus: status,
    );
  }
  final plain = payload?.toLowerCase() ?? text;
  if (plain == 'unauthorized' || plain == 'forbidden' || plain == 'not found') {
    return const ComicFollowCheckException(
      ComicFollowCheckFailure.sourceUnavailable,
    );
  }
  if (text.contains('unexpected token') ||
      text.contains('unexpected end of json') ||
      text.contains('syntaxerror:') ||
      text.contains('json parse') ||
      text.contains('invalid json')) {
    return const ComicFollowCheckException(
      ComicFollowCheckFailure.invalidResponse,
    );
  }
  if (error is SocketException ||
      error is TimeoutException ||
      error is HandshakeException ||
      isTransientNetworkError(error)) {
    return const ComicFollowCheckException(
      ComicFollowCheckFailure.network,
      retryable: true,
    );
  }
  return const ComicFollowCheckException(ComicFollowCheckFailure.unknown);
}
