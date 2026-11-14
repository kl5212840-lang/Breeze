import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';

Future<void> showBookshelfHelpDialog(
  BuildContext context, {
  required String title,
  required String content,
}) => showDialog<void>(
  context: context,
  useRootNavigator: true,
  builder: (dialog) => AlertDialog(
    scrollable: true,
    title: Text(title),
    content: Text(content),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(dialog),
        child: Text(t.common.gotIt),
      ),
    ],
  ),
);

String bookshelfHelpTitle({
  required bool video,
  required ShelfPageMode mode,
}) => t.bookshelf.contextHelp(
  section:
      '${video ? t.bookshelf.mediaVideos : t.bookshelf.mediaComics} · ${switch (mode) {
        ShelfPageMode.favorite => t.bookshelf.favorite,
        ShelfPageMode.history => t.bookshelf.history,
        ShelfPageMode.download => t.bookshelf.download,
      }}',
);

String bookshelfHelpContent({
  required bool video,
  required ShelfPageMode mode,
}) => switch (mode) {
  ShelfPageMode.favorite =>
    video ? t.bookshelf.helpFavoriteVideo : t.bookshelf.helpFavoriteComic,
  ShelfPageMode.history => t.bookshelf.helpHistory,
  ShelfPageMode.download =>
    video ? t.bookshelf.videoExportsHint : t.bookshelf.helpDownloadComic,
};
