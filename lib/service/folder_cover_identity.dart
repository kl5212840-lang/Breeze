import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Portable artwork keys use the folder's stable identity, never its name,
/// display path, ObjectBox row ID, or a device's absolute image path.
abstract final class FolderCoverIdentity {
  static final _key = RegExp(r'^folder-cover:(comic|video):[0-9a-f]{64}$');
  static bool valid(String key) => _key.hasMatch(key);
  static String comic(String syncId) => _make('comic', syncId);
  static String video(String folderId) => _make('video', folderId);
  static String _make(String domain, String id) {
    if (id.isEmpty || id.length > 512)
      throw const FormatException('Invalid folder identity');
    final key = 'folder-cover:$domain:${sha256.convert(utf8.encode(id))}';
    if (!valid(key)) throw const FormatException('Invalid folder identity');
    return key;
  }
}
