import 'dart:async';

/// A configured development proxy must not be rejected solely because one
/// external connectivity-check service is unavailable on the current route.
Future<bool> probeDevelopmentProxy(
  Future<int> Function(Uri target) request, {
  Duration timeout = const Duration(seconds: 3),
}) {
  final result = Completer<bool>();
  final targets = [
    Uri.parse('https://www.apple.com/library/test/success.html'),
    Uri.parse('https://www.gstatic.com/generate_204'),
  ];
  var remaining = targets.length;
  for (final target in targets) {
    unawaited(() async {
      try {
        final status = await request(target).timeout(timeout);
        if (status >= 200 &&
            status < 500 &&
            status != 407 &&
            !result.isCompleted) {
          result.complete(true);
        }
      } catch (_) {
        // A refusal, timeout or TLS failure is local to this probe target.
      } finally {
        remaining--;
        if (remaining == 0 && !result.isCompleted) result.complete(false);
      }
    }());
  }
  return result.future;
}
