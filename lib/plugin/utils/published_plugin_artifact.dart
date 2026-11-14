import 'dart:convert';

import 'package:crypto/crypto.dart';

String publishedPluginScriptSha256(String script) =>
    sha256.convert(utf8.encode(script.trim())).toString();

String normalizePublishedPluginVersion(String version) =>
    version.trim().replaceFirst(RegExp(r'^[vV](?=\d)'), '');

String? parsePublishedPluginSha256(Object? value) {
  final hash = value is String ? value.trim().toLowerCase() : '';
  return RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ? hash : null;
}

/// The catalog publishes the SHA-256 of the decoded, trimmed CJS. Verify it
/// before executing getInfo or replacing any installed code. Old catalogs may
/// omit the digest, but a declared digest must match.
void verifyPublishedPluginScript(String script, String expectedSha256) {
  final expected = expectedSha256.trim().toLowerCase();
  if (expected.isEmpty) return;
  if (parsePublishedPluginSha256(expected) == null ||
      publishedPluginScriptSha256(script) != expected) {
    throw StateError('插件文件校验失败，请刷新插件商店后重试');
  }
}

void verifyPublishedPluginVersion(String actual, String expected) {
  if (expected.trim().isEmpty) return;
  if (normalizePublishedPluginVersion(actual) !=
      normalizePublishedPluginVersion(expected)) {
    throw StateError('插件版本与商店清单不一致，请刷新插件商店后重试');
  }
}
