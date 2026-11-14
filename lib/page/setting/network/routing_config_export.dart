import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

/// Only the user's explicit save action sends a local copy to Files. No config
/// text enters preferences, diagnostics, logs, cloud sync or network requests.
Future<bool> saveRoutingConfigCopy(
  String contents, {
  required bool dark,
}) async {
  if (Platform.isIOS) {
    final result = await const MethodChannel(
      'breeze.routing.export',
    ).invokeMethod<String>('save', {'contents': contents, 'dark': dark});
    if (result == 'saved') return true;
    if (result == 'cancelled') return false;
    throw const FileSystemException('Could not export config');
  }
  final location = await getSaveLocation(
    suggestedName: 'Breeze-Shadowrocket.conf',
  );
  if (location == null) return false;
  await File(location.path).writeAsString(contents, flush: true);
  return true;
}
