import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/omofun_native_history_scope.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/source_profile_video_preview.dart';

/// A small preview of real, authenticated records; no invented posters or IDs.
class OmoSiteHistoryPreview extends StatefulWidget {
  const OmoSiteHistoryPreview({
    super.key,
    required this.client,
    required this.source,
    this.onViewAll,
    this.active = true,
  });
  final OmoSiteClient client;
  final String source;
  final VoidCallback? onViewAll;
  final bool active;
  @override
  State<OmoSiteHistoryPreview> createState() => _OmoSiteHistoryPreviewState();
}

class _OmoSiteHistoryPreviewState extends State<OmoSiteHistoryPreview> {
  List<OmoHistoryEntry> _rows = [];
  int _epoch = 0, _revision = -1;
  bool _opening = false, _openFailed = false, _loading = false, _failed = false;
  @override
  void initState() {
    super.initState();
    widget.client.addListener(_changed);
    _changed();
  }

  void _changed() {
    if (!widget.active || _revision == widget.client.revision) return;
    _revision = widget.client.revision;
    final epoch = ++_epoch;
    if (mounted)
      setState(() {
        _rows = [];
        _opening = false;
        _openFailed = false;
        _failed = false;
        _loading = widget.client.account != null;
      });
    if (widget.client.account != null) unawaited(_read(epoch, _revision));
  }

  Future<void> _read(int epoch, int revision) async {
    try {
      final page = await widget.client.privateIndex('history', preview: true);
      if (!mounted || epoch != _epoch || revision != widget.client.revision)
        return;
      setState(() {
        _rows = page.items.take(8).toList();
        _failed = page.count > 0 && page.items.isEmpty;
        _loading = false;
      });
    } catch (_) {
      if (mounted && epoch == _epoch && revision == widget.client.revision) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant OmoSiteHistoryPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client != widget.client ||
        oldWidget.source != widget.source ||
        oldWidget.active != widget.active) {
      oldWidget.client.removeListener(_changed);
      widget.client.addListener(_changed);
      _revision = -1;
      _changed();
    }
  }

  @override
  void dispose() {
    _epoch++;
    widget.client.removeListener(_changed);
    super.dispose();
  }

  Future<void> _open(OmoHistoryEntry row, OmoNativeHistoryScope scope) async {
    if (_opening) return;
    final epoch = _epoch;
    setState(() {
      _opening = true;
      _openFailed = false;
    });
    try {
      await scope.openEntry(row);
    } catch (_) {
      if (mounted && epoch == _epoch) setState(() => _openFailed = true);
    } finally {
      if (mounted && epoch == _epoch) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = OmoNativeHistoryScope.maybeOf(context);
    if (widget.client.account == null || scope == null)
      return const SizedBox.shrink();
    return SourceProfileVideoPreview(
      key: ValueKey('omo-site-history.${widget.source}.$_revision'),
      identity: 'site-history.${widget.source}.$_revision',
      title: t.omoAccount.siteHistory,
      icon: Icons.cloud_outlined,
      onViewAll: widget.onViewAll ?? () {},
      loading: _loading,
      failed: _failed || _openFailed,
      onRetry: () {
        _revision = -1;
        _changed();
      },
      items: _rows
          .map(
            (row) => SourceProfileVideoPreviewItem(
              id: row.cardId,
              title: row.title,
              note: [
                row.episodeLabel,
                row.watchedAt,
              ].where((value) => value.isNotEmpty).join(' · '),
              cover: ApiVideoPoster(item: row.card, source: widget.source),
              onOpen: () => unawaited(_open(row, scope)),
            ),
          )
          .toList(),
    );
  }
}

/// The website's following list is its existing authenticated favorites API.
/// It is separate from local history and clears its private preview on identity changes.
class OmoSiteFollowingPreview extends StatefulWidget {
  const OmoSiteFollowingPreview({
    super.key,
    required this.client,
    required this.source,
    required this.onViewAll,
    required this.onOpen,
    this.active = true,
    this.responsivePreview = false,
  });
  final bool responsivePreview;
  final OmoSiteClient client;
  final String source;
  final VoidCallback onViewAll;
  final Future<void> Function(OmoFavorite) onOpen;
  final bool active;
  @override
  State<OmoSiteFollowingPreview> createState() =>
      _OmoSiteFollowingPreviewState();
}

class _OmoSiteFollowingPreviewState extends State<OmoSiteFollowingPreview> {
  List<OmoFavorite> _rows = [];
  int _epoch = 0, _revision = -1;
  bool _loading = false, _failed = false, _opening = false;
  @override
  void initState() {
    super.initState();
    widget.client.addListener(_changed);
    _changed();
  }

  void _changed() {
    if (!widget.active || _revision == widget.client.revision) return;
    _revision = widget.client.revision;
    final epoch = ++_epoch, revision = _revision;
    setState(() {
      _rows = [];
      _failed = false;
      _opening = false;
      _loading = widget.client.account != null;
    });
    if (_loading) unawaited(_read(epoch, revision));
  }

  Future<void> _read(int epoch, int revision) async {
    try {
      final page = await widget.client.favorites();
      if (!mounted || epoch != _epoch || revision != widget.client.revision)
        return;
      setState(() {
        _rows = page.items.take(8).toList();
        _failed = page.unmappedCount > 0 && page.items.isEmpty;
        _loading = false;
      });
    } catch (_) {
      if (mounted && epoch == _epoch && revision == widget.client.revision)
        setState(() {
          _loading = false;
          _failed = true;
        });
    }
  }

  Future<void> _open(OmoFavorite favorite) async {
    if (_opening ||
        _revision != widget.client.revision ||
        widget.client.account == null)
      return;
    final epoch = _epoch;
    setState(() => _opening = true);
    try {
      await widget.onOpen(favorite);
    } catch (_) {
      if (mounted && epoch == _epoch) setState(() => _failed = true);
    } finally {
      if (mounted && epoch == _epoch) setState(() => _opening = false);
    }
  }

  @override
  void didUpdateWidget(covariant OmoSiteFollowingPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client != widget.client ||
        oldWidget.source != widget.source ||
        oldWidget.active != widget.active) {
      oldWidget.client.removeListener(_changed);
      widget.client.addListener(_changed);
      _revision = -1;
      _changed();
    }
  }

  @override
  void dispose() {
    _epoch++;
    widget.client.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.client.account == null) return const SizedBox.shrink();
    return SourceProfileVideoPreview(
      identity: 'site-following.${widget.source}.$_revision',
      responsivePreview: widget.responsivePreview,
      title: t.videoSource.siteFavorites,
      icon: Icons.favorite_border_rounded,
      onViewAll: widget.onViewAll,
      loading: _loading,
      failed: _failed,
      onRetry: () {
        _revision = -1;
        _changed();
      },
      items: _rows
          .take(widget.responsivePreview ? 4 : 8)
          .map(
            (favorite) => SourceProfileVideoPreviewItem(
              id: favorite.recordId,
              title: favorite.item.title,
              note: favorite.item.remarks,
              cover: ApiVideoPoster(item: favorite.item, source: widget.source),
              onOpen: () => unawaited(_open(favorite)),
            ),
          )
          .toList(),
    );
  }
}
