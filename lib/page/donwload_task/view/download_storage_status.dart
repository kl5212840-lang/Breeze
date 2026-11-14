import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/donwload_task/service/download_center_resources.dart';
import 'package:zephyr/page/donwload_task/service/download_storage_usage.dart';
import 'package:zephyr/service/download/download_byte_amount.dart';
import 'package:zephyr/service/download/download_admission.dart';

/// Read only when settings or the end of the download list needs the values.
class DownloadStorageStatus extends StatefulWidget {
  const DownloadStorageStatus({
    super.key,
    required this.builder,
    this.enabled = true,
    this.comics,
    this.videos,
    this.partial = false,
    this.refreshRevision = 0,
  });

  final Widget Function(BuildContext, String? used, String? available) builder;
  final bool enabled, partial;
  final int refreshRevision;
  final List<DownloadComicResource>? comics;
  final List<Map<String, dynamic>>? videos;

  @override
  State<DownloadStorageStatus> createState() => _DownloadStorageStatusState();
}

class _DownloadStorageStatusState extends State<DownloadStorageStatus> {
  Future<DownloadStorageUsage>? _usage;
  Future<int?>? _available;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _read();
  }

  @override
  void didUpdateWidget(covariant DownloadStorageStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      if (oldWidget.enabled) _revision++;
      return;
    }
    if (!oldWidget.enabled ||
        oldWidget.partial != widget.partial ||
        oldWidget.refreshRevision != widget.refreshRevision ||
        !_sameComics(oldWidget.comics, widget.comics) ||
        !_sameVideos(oldWidget.videos, widget.videos)) {
      _read();
    }
  }

  bool _sameVideos(
    List<Map<String, dynamic>>? a,
    List<Map<String, dynamic>>? b,
  ) =>
      identical(a, b) ||
      (a != null &&
          b != null &&
          hasUnmeasuredSavedVideo(a) == hasUnmeasuredSavedVideo(b) &&
          mapEquals(savedVideoSizes(a), savedVideoSizes(b)));

  bool _sameComics(
    List<DownloadComicResource>? a,
    List<DownloadComicResource>? b,
  ) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    return Iterable<int>.generate(a.length).every(
      (index) =>
          a[index].key == b[index].key &&
          a[index].metricsVersion == b[index].metricsVersion,
    );
  }

  void _read() {
    final revision = ++_revision;
    _usage = DownloadStorageUsage.read(
      comics: widget.comics,
      videos: widget.videos,
      partial: widget.partial,
      current: () => mounted && revision == _revision,
    );
    _available = DownloadAdmission.instance.availableBytes();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<DownloadStorageUsage>(
    future: _usage,
    builder: (context, used) => FutureBuilder<int?>(
      future: _available,
      builder: (context, free) {
        final result = used.data;
        final String? usage;
        if (result == null) {
          usage = used.connectionState == ConnectionState.done
              ? t.download.spaceUnavailable
              : null;
        } else if (result.partial) {
          usage = result.knownBytes > 0
              ? t.download.spaceAtLeast(
                  size: downloadByteAmount(result.knownBytes, lowerBound: true),
                )
              : t.download.spaceUnavailable;
        } else {
          usage = downloadByteAmount(result.knownBytes);
        }
        return widget.builder(
          context,
          usage,
          free.data == null
              ? free.connectionState == ConnectionState.done
                    ? t.download.spaceUnavailable
                    : null
              : downloadByteAmount(free.data!),
        );
      },
    ),
  );
}
