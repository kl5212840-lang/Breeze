import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:zephyr/service/backup_security/private_backup_workspace.dart';

/// Only the user's explicit save action sends a local copy to Files. No config
/// text enters preferences, diagnostics, logs, cloud sync or network requests.
Future<bool> saveRoutingConfigCopy(
  String contents, {
  required bool dark,
}) async {
  const filename = 'Breeze-Shadowrocket.conf';
  if (Platform.isAndroid) {
    final workspace = await createPrivateBackupWorkspace();
    try {
      final file = File(p.join(workspace.path, filename));
      await file.writeAsString(contents, flush: true);
      final result = await const MethodChannel(
        'breeze/backup_security',
      ).invokeMethod<String>('exportRoutingFile', {'path': file.path});
      if (result == 'saved') return true;
      if (result == 'cancelled') return false;
      throw const FileSystemException('Could not export config');
    } finally {
      await workspace.delete(recursive: true);
    }
  }
  if (Platform.isIOS) {
    final result = await const MethodChannel(
      'breeze.routing.export',
    ).invokeMethod<String>('save', {'contents': contents, 'dark': dark});
    if (result == 'saved') return true;
    if (result == 'cancelled') return false;
    throw const FileSystemException('Could not export config');
  }
  final location = await getSaveLocation(suggestedName: filename);
  if (location == null) return false;
  await File(location.path).writeAsString(contents, flush: true);
  return true;
}
