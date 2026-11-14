import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:zephyr/util/get_path.dart';

/// These directories contain only temporary backup/recovery material. Startup
/// cleanup runs before any producer starts, never as a general cache sweep.
Future<void> cleanupInterruptedPrivateBackupWork() async {
  final cache = await getCachePath();
  for (final name in [
    'backup-private-v1',
    'breeze-file-unlock',
    'recovery-export',
  ]) {
    final directory = Directory(p.join(cache, name));
    if (await FileSystemEntity.type(directory.path, followLinks: false) ==
        FileSystemEntityType.directory) {
      await directory.delete(recursive: true);
    }
  }
}

Future<Directory> createPrivateBackupWorkspace() async {
  final root = Directory(p.join(await getCachePath(), 'backup-private-v1'));
  await root.create(recursive: true);
  if (await FileSystemEntity.type(root.path, followLinks: false) !=
      FileSystemEntityType.directory) {
    throw const FileSystemException('Backup workspace unavailable');
  }
  return root.createTemp('export-');
}
