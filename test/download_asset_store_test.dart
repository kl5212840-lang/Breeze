import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/service/download/download_asset_store.dart';

void main() {
  test('原子写入提交后只保留最终文件', () async {
    final root = await Directory.systemTemp.createTemp('breeze_asset_store_');
    addTearDown(() => root.delete(recursive: true));

    final finalPath = '${root.path}${Platform.pathSeparator}image.jpg';
    await DownloadAssetStore.writeBytesAtomically(
      Uint8List.fromList(const [1, 2, 3]),
      finalPath: finalPath,
      taskId: 'task/with:special',
    );

    expect(await File(finalPath).readAsBytes(), [1, 2, 3]);
    final entries = await root.list().toList();
    expect(entries.whereType<File>().map((file) => file.path), [finalPath]);
  });

  test('空数据写入失败且不创建最终文件', () async {
    final root = await Directory.systemTemp.createTemp('breeze_asset_store_');
    addTearDown(() => root.delete(recursive: true));

    final finalPath = '${root.path}${Platform.pathSeparator}empty.jpg';
    await expectLater(
      DownloadAssetStore.writeBytesAtomically(
        Uint8List(0),
        finalPath: finalPath,
        taskId: 'empty',
      ),
      throwsStateError,
    );

    expect(await File(finalPath).exists(), isFalse);
    expect((await root.list().toList()).whereType<File>(), isEmpty);
  });

  test('历史路径越界时不被视为下载根目录内路径', () {
    final root = Directory.systemTemp.path;
    expect(
      DownloadAssetStore.isWithinRoot(
        root,
        '$root${Platform.pathSeparator}downloads${Platform.pathSeparator}comic',
      ),
      isTrue,
    );
    expect(
      DownloadAssetStore.isWithinRoot(
        root,
        '$root${Platform.pathSeparator}..${Platform.pathSeparator}outside',
      ),
      isFalse,
    );
  });
}
