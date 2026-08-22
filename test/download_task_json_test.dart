import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';

void main() {
  test('下载任务 payload 会保留 source 隔离和章节 checkpoint', () {
    final task = DownloadTaskJson(
      from: 'plugin-a',
      comicId: 'comic/1',
      comicName: '测试漫画',
      chapterRefs: const [
        DownloadChapterTaskRef(
          chapterId: 'chapter-1',
          logicalKey: 'logical-1',
          requestId: 'request-1',
          storageChapterId: 'storage-1',
          title: '第 1 话',
          order: 1,
        ),
      ],
      stateCode: 'running',
      phaseCode: 'downloadingChapter',
      completedChapterKeys: const ['chapter-0'],
      currentChapterKey: 'chapter-1',
      completedChapterCount: 1,
      totalChapterCount: 2,
      currentChapterCompletedImages: 3,
      currentChapterTotalImages: 10,
    );

    final restored = DownloadTaskJson.fromJson(
      jsonDecode(jsonEncode(task.toJson())) as Map<String, dynamic>,
    );

    expect(task.taskKey, 'plugin-a:comic/1');
    expect(restored.schemaVersion, currentDownloadTaskSchemaVersion);
    expect(restored.stateCode, 'running');
    expect(restored.phaseCode, 'downloadingChapter');
    expect(restored.completedChapterKeys, ['chapter-0']);
    expect(restored.currentChapterKey, 'chapter-1');
    expect(restored.currentChapterCompletedImages, 3);
    expect(restored.currentChapterTotalImages, 10);
  });
}
