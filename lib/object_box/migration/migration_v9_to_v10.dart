import 'package:zephyr/main.dart';

/// v9 -> v10：清理无法恢复的旧下载任务记录。
///
/// 旧任务只保存了展示状态和一次性 payload，没有章节检查点。保留它们会让
/// 新调度器误把旧格式当成可恢复任务，因此只清理 DownloadTask；漫画记录、
/// 书架链接和磁盘上的历史图片均不受影响。
Future<void> migrateV9ToV10() async {
  final count = objectbox.downloadTaskBox.removeAll();
  logger.i('[migration_v9_to_v10] 已清理 $count 条旧下载任务记录');
}
