import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/models/shelf_delete_prompt.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';

void main() {
  setUp(() => LocaleSettings.setLocale(AppLocale.zhCn));
  test('comic-only deletion never implies that a folder was selected', () {
    final message = shelfDeletePrompt(
      mode: ShelfPageMode.favorite,
      folders: 0,
      comics: 4,
    );
    expect(message.split('\n').first, contains('4'));
    expect(message.split('\n').first, isNot(contains('文件夹')));
    expect(message, isNot(contains('递归')));
    expect(message, isNot(contains(t.bookshelf.deleteFolderContentsHint)));
  });
  test('folder consequences appear only when folders are selected', () {
    for (final comics in [0, 3]) {
      final message = shelfDeletePrompt(
        mode: ShelfPageMode.favorite,
        folders: 2,
        comics: comics,
      );
      expect(message, contains(t.bookshelf.deleteFolderContentsHint));
      expect(message, isNot(contains('递归')));
    }
    final history = shelfDeletePrompt(
      mode: ShelfPageMode.history,
      folders: 0,
      comics: 3,
    );
    expect(history, contains(t.bookshelf.deleteHistoryHint));
    expect(history, isNot(contains(t.bookshelf.deleteFolderContentsHint)));
    expect(
      shelfDeletePrompt(mode: ShelfPageMode.favorite, folders: 0, comics: 0),
      isEmpty,
    );
  });
}
