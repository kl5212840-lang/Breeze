import 'dart:io';

final _retryAfter = RegExp(
  r'retry-after[ :=]+([^\r\n]+)',
  caseSensitive: false,
);

bool isTransientHttpStatus(int status) =>
    status == 408 ||
    status == 425 ||
    status == 429 ||
    status >= 500 && status <= 599;

String? sanitizedRetryAfter(String? header) {
  final value = header?.trim();
  if (value == null || value.isEmpty || value.length > 128) return null;
  if (RegExp(r'^\d+$').hasMatch(value)) {
    final seconds = int.tryParse(value);
    return seconds == null || seconds < 0 ? null : '$seconds';
  }
  try {
    return HttpDate.format(HttpDate.parse(value));
  } on FormatException {
    return null;
  } on HttpException {
    return null;
  }
}

Duration? httpRetryAfterDelay(String text, {required DateTime now}) {
  final raw = _retryAfter.firstMatch(text)?.group(1)?.trim();
  final value = sanitizedRetryAfter(raw?.replaceFirst(RegExp(r'[)）]$'), ''));
  if (value == null) return null;
  final seconds = int.tryParse(value);
  if (seconds != null) {
    // Keep both the duration and the resulting DateTime representable.
    const maxSecondsSinceEpoch = 8640000000000;
    final secondsSinceEpoch =
        now.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
    final limit = maxSecondsSinceEpoch - secondsSinceEpoch;
    if (limit <= 1) return Duration.zero;
    return Duration(seconds: seconds.clamp(0, limit - 1));
  }
  final delay = HttpDate.parse(value).difference(now);
  return delay.isNegative ? Duration.zero : delay;
}
