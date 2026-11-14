import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_help.dart';

Future<void> openDownloadHelp(BuildContext context) => showBookshelfHelpDialog(
  context,
  title: t.bookshelf.contextHelp(section: t.bookshelf.download),
  content: [
    t.download.helpExport,
    t.download.helpHls,
    t.download.helpDelete,
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
        ? t.download.helpContinueIos
        : t.download.helpContinue,
  ].join('\n\n'),
);
