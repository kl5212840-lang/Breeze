import 'package:zephyr/page/donwload_task/service/download_center_removal.dart';
import 'package:zephyr/service/download/comic_download_preview.dart';
import 'dart:async';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/widgets/soft_cover_background.dart';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';
import 'package:zephyr/page/video/video_cover_overlay.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/collection_cover_fit.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';

// Half the existing detailed-follow cover, within ListTile's leading slot.
const _width = 42.0, _height = 56.0;

Widget _frame(Widget image, {double width = _width, double height = _height}) =>
    SizedBox(
      width: width,
      height: height,
      child: ClipRRect(borderRadius: BorderRadius.circular(6), child: image),
    );

/// Only read the small cover property, not a whole download entity's chapter
/// JSON, when byte progress causes its visible work row to rebuild.
class DownloadComicTaskCover extends StatelessWidget {
  const DownloadComicTaskCover({
    super.key,
    required this.source,
    required this.comicId,
    this.width = _width,
    this.height = _height,
  });
  final String source, comicId;
  final double width, height;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: ComicDownloadPreview.changes,
    builder: (context, _, _) => CollectionCoverFitBuilder(
      builder: (context, fit) {
        UnifiedComicCover? cover;
        final query = objectbox.unifiedDownloadBox
            .query(
              UnifiedComicDownload_.uniqueKey.equals(
                buildDownloadTaskKey(source, comicId),
              ),
            )
            .build();
        final property = query.property(UnifiedComicDownload_.cover);
        try {
          final raw = property.find().firstOrNull;
          if (raw != null && raw.length <= 16384) {
            final value = jsonDecode(raw);
            if (value is Map<String, dynamic>) {
              cover = UnifiedComicCover.fromJson(value);
            }
          }
        } catch (_) {
          // Missing/old metadata is a neutral work icon, never a guessed request.
        } finally {
          property.close();
          query.close();
        }
        if (cover == null ||
            (cover.url.trim().isEmpty && cover.cachePath.isEmpty)) {
          cover = switch (ComicDownloadPreview.cover(source, comicId)) {
            final value? => UnifiedComicCover.fromJson(value),
            _ => cover,
          };
        }
        final ready =
            cover != null &&
            (cover.url.trim().isNotEmpty || cover.cachePath.isNotEmpty);
        return _frame(
          ready
              ? CoverWidget(
                  fileServer: cover.url,
                  path: cover.cachePath,
                  id: comicId,
                  pictureType: PictureType.cover,
                  from: source,
                  roundedCorner: false,
                  fit: fit,
                  containBackground: true,
                  width: width,
                  height: height,
                )
              : CollectionCoverPrivacy(
                  fit: fit,
                  mosaicPlaceholder: const Center(
                    child: Icon(Icons.menu_book_outlined),
                  ),
                  child: const Center(child: Icon(Icons.menu_book_outlined)),
                ),
          width: width,
          height: height,
        );
      },
    ),
  );
}

class DownloadVideoTaskCover extends StatelessWidget {
  const DownloadVideoTaskCover({
    super.key,
    required this.row,
    required this.fallback,
    this.width = _width,
    this.height = _height,
    this.localOnly = false,
  });
  final Map<String, dynamic> row;
  final Widget fallback;
  final double width, height;
  final bool localOnly;

  Widget _overlay({required String durationText, required Widget child}) =>
      isVideoExternalReceipt(row)
      ? child
      : VideoCoverOverlay(durationText: durationText, child: child);

  @override
  Widget build(BuildContext context) => _DownloadLocalPoster(
    row: row,
    localOnly: localOnly,
    builder: (context, localPath) => CollectionCoverFitBuilder(
      builder: (context, fit) {
        final totalMs = row['durationMs'];
        final durationText = totalMs is int && totalMs > 0
            ? formatKnownVideoDuration(Duration(milliseconds: totalMs))
            : knownVideoDurationText(
                row['sourceDuration'] is String
                    ? row['sourceDuration'] as String
                    : '',
              );
        if (localPath != null) {
          final pixelRatio = MediaQuery.devicePixelRatioOf(context);
          final image = createCoverImageProvider(
            localPath,
            width: (width * pixelRatio).ceil().clamp(1, 512),
            height: (height * pixelRatio).ceil().clamp(1, 512),
          );
          return _frame(
            _overlay(
              durationText: durationText,
              child: CollectionCoverPrivacy(
                fit: fit,
                image: image,
                mosaicPlaceholder: Center(child: fallback),
                child: SoftCoverBackground(
                  image: image,
                  enabled: fit == BoxFit.contain,
                  child: Image(
                    image: image,
                    fit: fit,
                    errorBuilder: (_, _, _) => Center(child: fallback),
                  ),
                ),
              ),
            ),
            width: width,
            height: height,
          );
        }
        final raw = localOnly ? null : row['cover'];
        final image = raw is String && raw.length <= 4096
            ? Uri.tryParse(raw)
            : null;
        final page = Uri.tryParse('${row['url']}');
        if (image?.scheme != 'https' ||
            image?.host.isNotEmpty != true ||
            image?.userInfo.isEmpty != true ||
            image?.hasQuery != false ||
            image?.hasFragment != false ||
            (image?.hasPort == true && image?.port != 443) ||
            page?.host.isNotEmpty != true) {
          return _frame(
            _overlay(
              durationText: durationText,
              child: CollectionCoverPrivacy(
                fit: fit,
                mosaicPlaceholder: Center(child: fallback),
                child: Center(child: fallback),
              ),
            ),
            width: width,
            height: height,
          );
        }
        return _frame(
          _overlay(
            durationText: durationText,
            child: VideoThumbnail(
              url: raw as String,
              source: row['source'] as String?,
              referrer: page!,
              fit: fit,
              containBackground: true,
              cacheWidth: (width * MediaQuery.devicePixelRatioOf(context))
                  .ceil()
                  .clamp(1, 256),
            ),
          ),
          width: width,
          height: height,
        );
      },
    ),
  );
}

/// Memoize per public resource identity: byte-progress rebuilds must not reopen
/// the metadata index or recreate the current image's loading state.
class _DownloadLocalPoster extends StatefulWidget {
  const _DownloadLocalPoster({
    required this.row,
    required this.builder,
    this.localOnly = false,
  });
  final bool localOnly;
  final Map<String, dynamic> row;
  final Widget Function(BuildContext, String?) builder;
  @override
  State<_DownloadLocalPoster> createState() => _DownloadLocalPosterState();
}

class _DownloadLocalPosterState extends State<_DownloadLocalPoster> {
  late Future<String?> _path;
  @override
  void initState() {
    super.initState();
    _path = _request();
    VideoDownloadedDetails.posterChanges.addListener(_reload);
  }

  Future<String?> _request() async {
    final path = await VideoDownloadedDetails.localPosterForResource(
      widget.row,
    );
    if (path == null && !widget.localOnly)
      unawaited(VideoDownloadedDetails.ensureLocalPoster(widget.row));
    return path;
  }

  Object _binding(Map<String, dynamic> row) => (
    row['resourceId'],
    row['source'],
    row['url'],
    row['format'],
    row['assetId'],
    row['generation'],
    row['taskKey'],
    row['at'],
    row['available'],
    row['filePresent'],
    row['status'],
  );
  void _reload() {
    if (mounted)
      setState(
        () => _path = VideoDownloadedDetails.localPosterForResource(widget.row),
      );
  }

  @override
  void didUpdateWidget(_DownloadLocalPoster oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localOnly != widget.localOnly ||
        _binding(oldWidget.row) != _binding(widget.row)) {
      _path = _request();
    }
  }

  @override
  void dispose() {
    VideoDownloadedDetails.posterChanges.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _path,
    builder: (context, snapshot) => widget.builder(context, snapshot.data),
  );
}
