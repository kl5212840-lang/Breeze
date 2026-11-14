import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';

String shelfDeletePrompt({
  required ShelfPageMode mode,
  required int folders,
  required int comics,
}) {
  if (folders == 0 && comics == 0) return '';
  if (mode == ShelfPageMode.history) {
    return '${t.bookshelf.deleteHistoryQuestion(count: comics)}\n\n${t.bookshelf.deleteHistoryHint}';
  }
  final question = folders == 0
      ? t.bookshelf.deleteComicsQuestion(count: comics)
      : comics == 0
      ? t.bookshelf.deleteFoldersQuestion(count: folders)
      : t.bookshelf.deleteMixedQuestion(folders: folders, comics: comics);
  return [
    question,
    if (folders > 0) t.bookshelf.deleteFolderContentsHint,
    mode == ShelfPageMode.download
        ? t.bookshelf.deleteDownloadsHint
        : t.bookshelf.deleteFavoritesHint,
  ].join('\n\n');
}
