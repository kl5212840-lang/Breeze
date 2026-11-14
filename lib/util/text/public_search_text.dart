import 'package:zephyr/util/text/chinese_convert.dart';

/// Search always normalizes both input and public text to simplified Chinese;
/// display-language preferences never change which local records match.
String normalizePublicSearchText(String value) {
  final text = value.trim().toLowerCase();
  if (text.isEmpty) return '';
  try {
    return t2s(text);
  } catch (_) {
    return text;
  }
}
