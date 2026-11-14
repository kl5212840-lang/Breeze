import 'package:flutter/foundation.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/util/json/json_value.dart';

typedef BikaLineCall =
    Future<Map<String, dynamic>> Function(
      String source,
      String function,
      Map<String, dynamic> core,
    );

Future<Map<String, dynamic>> callBikaAccessLines(
  String source,
  String function,
  Map<String, dynamic> core,
) {
  if (source != bikaPlusSourceId) throw StateError('Unsupported source');
  return callUnifiedComicPlugin(
    from: source,
    fnPath: function,
    core: core,
    notifyUnauthorized: false,
  );
}

bool supportsBikaAccessLines(String source, Object? info) =>
    source == bikaPlusSourceId &&
    asJsonMap(
          asJsonMap(asJsonMap(info)['breezeExperience'])['bikaExperience'],
        )['accessLinesVersion'] ==
        1;

bool supportsBikaImageQuality(String source, Object? info) =>
    source == bikaPlusSourceId &&
    asJsonMap(
          asJsonMap(asJsonMap(info)['breezeExperience'])['bikaExperience'],
        )['imageQualityVersion'] ==
        1;

/// A successful explicit selection invalidates only this source's consumers.
/// No timer, background switch, or second persistent settings store is used.
class BikaAccessLines {
  static final changes = ValueNotifier<int>(0);
  static int _nextRun = 0;
  static String nextRunId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_nextRun++}';
  static void selected() => changes.value++;
}

class BikaAccessLine {
  const BikaAccessLine(
    this.base,
    this.elapsedMs, {
    this.requiresAuthentication = false,
  });
  final String base;
  final int elapsedMs;
  final bool requiresAuthentication;
  String get host => Uri.parse(base).host;
  static BikaAccessLine? fromJson(Object? raw) {
    final map = asJsonMap(raw);
    final base = map['base'];
    final elapsed = map['elapsedMs'];
    final uri = base is String ? Uri.tryParse(base) : null;
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.host.startsWith('picaapi.') ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.path != '/' ||
        uri.hasQuery ||
        uri.hasFragment ||
        elapsed is! int ||
        elapsed < 0)
      return null;
    return BikaAccessLine(
      base,
      elapsed,
      requiresAuthentication: map['requiresAuthentication'] == true,
    );
  }
}
