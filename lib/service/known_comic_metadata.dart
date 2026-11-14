import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/page/comic_list/cubit/jm_collection_metadata.dart';
import 'package:zephyr/page/comic_list/cubit/jm_collection_snapshots.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

/// Restore already acquired public fields only. Opening a local shelf/download
/// never starts a source request or revives a deleted record.
Future<void> restoreKnownComicMetadata({String? kind}) async {
  try {
    final rows = <UnifiedComicListItem>[
      if (kind == null || kind == 'favorite')
        ...objectbox.unifiedFavoriteBox
            .getAll()
            .where((e) => !e.deleted)
            .map(unifiedComicFromUnifiedFavorite),
      if (kind == null || kind == 'history')
        ...objectbox.unifiedHistoryBox
            .getAll()
            .where((e) => !e.deleted)
            .map(unifiedComicFromUnifiedHistory),
      if (kind == null || kind == 'download')
        ...objectbox.unifiedDownloadBox
            .getAll()
            .where((e) => !e.deleted)
            .map(unifiedComicFromUnifiedDownload),
    ];
    for (final source in rows.map((e) => e.source).toSet()) {
      final account = JmCollectionSnapshots.instance.accountScope(source);
      if (account == null) continue;
      await JmCollectionMetadata.instance.hydrate(
        account,
        rows.where((e) => e.source == source).toList(),
        canApply: () =>
            JmCollectionSnapshots.instance.accountScope(source) == account,
      );
    }
  } catch (_) {
    /* Optional cached fields never hide the original local records. */
  }
}
