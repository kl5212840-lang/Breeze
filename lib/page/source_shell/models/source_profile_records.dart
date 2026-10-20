import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

/// Local records are independent of the current folder. The profile preview and
/// its full list should include comics kept in nested folders as well.
class SourceProfileRecords {
  const SourceProfileRecords({
    required this.favorites,
    required this.history,
    required this.downloads,
  });

  final List<UnifiedComicListItem> favorites;
  final List<UnifiedComicListItem> history;
  final List<UnifiedComicListItem> downloads;

  List<UnifiedComicListItem> of(ShelfPageMode mode) => switch (mode) {
    ShelfPageMode.favorite => favorites,
    ShelfPageMode.history => history,
    ShelfPageMode.download => downloads,
  };
}

SourceProfileRecords loadSourceProfileRecords(Iterable<String> sources) {
  final sourceSet = sources
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet();
  bool includes(String source) => sourceSet.contains(source.trim());

  final favoriteQuery = objectbox.unifiedFavoriteBox
      .query(UnifiedComicFavorite_.deleted.equals(false))
      .order(UnifiedComicFavorite_.createdAt, flags: Order.descending)
      .build();
  final historyQuery = objectbox.unifiedHistoryBox
      .query(UnifiedComicHistory_.deleted.equals(false))
      .order(UnifiedComicHistory_.updatedAt, flags: Order.descending)
      .build();
  final downloadQuery = objectbox.unifiedDownloadBox
      .query(UnifiedComicDownload_.deleted.equals(false))
      .order(UnifiedComicDownload_.downloadedAt, flags: Order.descending)
      .build();
  try {
    return SourceProfileRecords(
      favorites: favoriteQuery
          .find()
          .where((e) => includes(e.source))
          .map(unifiedComicFromUnifiedFavorite)
          .toList(),
      history: historyQuery
          .find()
          .where((e) => includes(e.source))
          .map(unifiedComicFromUnifiedHistory)
          .toList(),
      downloads: downloadQuery
          .find()
          .where((e) => includes(e.source))
          .map(unifiedComicFromUnifiedDownload)
          .toList(),
    );
  } finally {
    favoriteQuery.close();
    historyQuery.close();
    downloadQuery.close();
  }
}
