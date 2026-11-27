import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_help.dart';
import 'package:zephyr/page/donwload_task/service/download_comic_archive.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';

Future<void> openDownloadHelp(BuildContext context) => showBookshelfHelpDialog(
  context,
  title: t.bookshelf.contextHelp(section: t.bookshelf.download),
  content: [
    if (DownloadComicArchiveService.supported) t.download.helpExport,
    if (VideoHlsAssets.supported) t.download.helpHls,
    t.download.helpDelete,
    t.download.helpContinue,
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS)
      t.download.helpContinueIos,
  ].join('\n\n'),
);
