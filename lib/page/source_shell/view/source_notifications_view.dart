import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';

class SourceNotice {
  const SourceNotice({
    this.id = '',
    required this.title,
    this.content = '',
    this.time = '',
    this.type = '',
    this.read,
  });

  final String id;
  final String title;
  String get displayTitle => title.isEmpty ? t.sourceNotices.notice : title;
  final String content;
  final String time;
  final String type;
  final bool? read;

  factory SourceNotice.fromMap(Map<String, dynamic> data) {
    final value = data['read'];
    final read = data['readKnown'] == false
        ? null
        : switch (value) {
            true || 1 || '1' || 'true' => true,
            false || 0 || '0' || 'false' => false,
            _ => null,
          };
    final id = data['id'];
    final title = (data['title']?.toString() ?? '').trim();
    final time = data['time'] ?? data['date'];
    return SourceNotice(
      id: id is String || id is num && id.isFinite ? id.toString().trim() : '',
      title: title,
      content: (data['content']?.toString() ?? '').trim(),
      time: time is DateTime ? time.toIso8601String() : time?.toString() ?? '',
      type: (data['type']?.toString() ?? '').trim(),
      read: read,
    );
  }

  bool get canMarkRead => id.isNotEmpty && read == false;
  bool get isTracking => type == 'comic_follow';
  bool get isSiteNotice => type == 'site_notice';

  SourceNotice withRead(bool? value) => SourceNotice(
    id: id,
    title: title,
    content: content,
    time: time,
    type: type,
    read: value,
  );
}

/// Format explicit calendar dates and Unix seconds/milliseconds only. Invalid
/// dates remain unknown, rather than allowing DateTime's overflow normalization.
String formatSourceNoticeTime(String value) {
  final raw = value.trim();
  DateTime? date;
  var dateOnly = false;
  if (RegExp(r'^\d{10}$|^\d{13}$').hasMatch(raw)) {
    final epoch = int.tryParse(raw);
    if (epoch != null) {
      date = DateTime.fromMillisecondsSinceEpoch(
        raw.length == 10 ? epoch * 1000 : epoch,
      );
    }
  } else {
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?(?:Z|([+-])(\d{2}):?(\d{2}))?)?$',
    ).firstMatch(raw);
    if (match == null) return '';
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final calendar = DateTime.utc(year, month, day);
    if (year < 1 ||
        calendar.year != year ||
        calendar.month != month ||
        calendar.day != day ||
        int.parse(match[4] ?? '0') > 23 ||
        int.parse(match[5] ?? '0') > 59 ||
        int.parse(match[6] ?? '0') > 59 ||
        int.parse(match[8] ?? '0') > 23 ||
        int.parse(match[9] ?? '0') > 59) {
      return '';
    }
    dateOnly = match[4] == null;
    date = DateTime.tryParse(raw);
  }
  if (date == null) return '';
  final local = dateOnly ? date : date.toLocal();
  final day = t.sourceNotices.date(
    year: local.year,
    month: local.month,
    day: local.day,
  );
  if (dateOnly) return day;
  String two(int value) => value.toString().padLeft(2, '0');
  return '$day ${two(local.hour)}:${two(local.minute)}';
}

enum _NoticeFilter { all, unread, tracking, site }

/// Presentation only: opening a row never marks it read. The owner controls
/// requests, account identity, confirmed read state and mutation progress.
class SourceNotificationsView extends StatefulWidget {
  const SourceNotificationsView({
    super.key,
    required this.notices,
    required this.loading,
    required this.marking,
    required this.complete,
    required this.onRefresh,
    required this.onOpen,
    this.error,
    this.unreadCount,
    this.total,
    this.onMarkRead,
    this.onMarkLoadedRead,
    this.onBack,
    this.showHeading = true,
  });

  final List<SourceNotice> notices;
  final bool loading;
  final bool marking;
  final String? error;
  final int? unreadCount;
  final bool complete;
  final int? total;
  final Future<void> Function() onRefresh;
  final ValueChanged<SourceNotice> onOpen;
  final ValueChanged<SourceNotice>? onMarkRead;
  final VoidCallback? onMarkLoadedRead;
  final VoidCallback? onBack;
  final bool showHeading;

  @override
  State<SourceNotificationsView> createState() =>
      _SourceNotificationsViewState();
}

class _SourceNotificationsViewState extends State<SourceNotificationsView> {
  _NoticeFilter _filter = _NoticeFilter.all;
  bool _refreshing = false;
  bool get _busy => widget.loading || widget.marking || _refreshing;

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() => _refreshing = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final visible = widget.notices
        .where(
          (notice) => switch (_filter) {
            _NoticeFilter.all => true,
            _NoticeFilter.unread => notice.read == false,
            _NoticeFilter.tracking => notice.isTracking,
            _NoticeFilter.site => notice.isSiteNotice,
          },
        )
        .toList();
    final markable = widget.notices.any((notice) => notice.canMarkRead);
    final unread = widget.unreadCount;
    final total = widget.total;
    final loaded = widget.notices.length;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        key: const PageStorageKey('source-notifications-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showHeading)
                    Row(
                      children: [
                        if (widget.onBack != null)
                          IconButton(
                            tooltip: t.common.back,
                            onPressed: widget.onBack,
                            constraints: const BoxConstraints(
                              minWidth: 44,
                              minHeight: 44,
                            ),
                            icon: const Icon(Icons.arrow_back),
                          ),
                        Expanded(
                          child: Text(
                            t.sourceNotices.title,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                  Text(
                    unread != null && unread >= 0
                        ? t.sourceNotices.unreadCount(count: unread)
                        : t.sourceNotices.unreadCountUnknown,
                    key: const ValueKey('source-notices-unread-count'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    total != null && total >= loaded
                        ? t.sourceNotices.loadedWithTotal(
                            count: loaded,
                            total: total,
                          )
                        : t.sourceNotices.loaded(count: loaded),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final (filter, label) in [
                        (_NoticeFilter.all, t.common.all),
                        (_NoticeFilter.unread, t.sourceNotices.unread),
                        (_NoticeFilter.tracking, t.sourceNotices.tracking),
                        (_NoticeFilter.site, t.sourceNotices.site),
                      ])
                        ConstrainedBox(
                          key: ValueKey('source-notices-filter-${filter.name}'),
                          constraints: const BoxConstraints(
                            minHeight: 44,
                            minWidth: 44,
                          ),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: _filter == filter,
                            materialTapTargetSize: MaterialTapTargetSize.padded,
                            onSelected: (_) => setState(() => _filter = filter),
                          ),
                        ),
                    ],
                  ),
                  if (widget.onMarkLoadedRead != null) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      key: const ValueKey('source-notices-mark-loaded'),
                      onPressed: !_busy && markable
                          ? widget.onMarkLoadedRead
                          : null,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                      icon: const Icon(Icons.done_all),
                      label: Text(
                        widget.marking
                            ? t.sourceNotices.marking
                            : t.sourceNotices.markLoadedRead,
                      ),
                    ),
                    Text(
                      widget.complete
                          ? t.sourceNotices.loadedReadScope
                          : t.sourceNotices.partialReadScope,
                      key: const ValueKey('source-notices-scope'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (widget.loading || widget.marking) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                  if (widget.error?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.error!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.error,
                      ),
                    ),
                    TextButton.icon(
                      key: const ValueKey('source-notices-retry'),
                      onPressed: _busy ? null : _refresh,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: Text(t.common.retry),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (visible.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  widget.loading && widget.notices.isEmpty
                      ? t.sourceNotices.loading
                      : widget.error != null && widget.notices.isEmpty
                      ? t.sourceNotices.unavailable
                      : _filter == _NoticeFilter.unread
                      ? t.sourceNotices.unreadEmpty
                      : t.sourceNotices.empty,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: visible.length,
              itemBuilder: (context, index) =>
                  _notice(context, visible[index], index),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _notice(BuildContext context, SourceNotice notice, int index) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final time = formatSourceNoticeTime(notice.time);
    return Column(
      key: ValueKey('source-notice-${notice.id}-$index'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: ValueKey('source-notice-open-${notice.id}-$index'),
          onTap: () => widget.onOpen(notice),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  height: 24,
                  child: Center(
                    child: notice.read == false
                        ? Semantics(
                            label: t.sourceNotices.unread,
                            child: Container(
                              key: ValueKey(
                                'source-notice-unread-${notice.id}-$index',
                              ),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: colors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notice.displayTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: notice.read == false
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (notice.content.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          notice.content,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children:
                            [
                                  if (time.isNotEmpty)
                                    Text(
                                      time,
                                      key: ValueKey(
                                        'source-notice-time-${notice.id}-$index',
                                      ),
                                    ),
                                  if (notice.isTracking)
                                    Text(t.sourceNotices.tracking)
                                  else if (notice.isSiteNotice)
                                    Text(t.sourceNotices.site),
                                  Text(
                                    notice.read == null
                                        ? t.sourceNotices.readUnknown
                                        : notice.read!
                                        ? t.sourceNotices.read
                                        : t.sourceNotices.unread,
                                  ),
                                ]
                                .map(
                                  (child) => DefaultTextStyle.merge(
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                    child: child,
                                  ),
                                )
                                .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.onMarkRead != null && notice.canMarkRead)
          Padding(
            padding: const EdgeInsets.fromLTRB(44, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: ValueKey('source-notice-mark-${notice.id}-$index'),
                onPressed: _busy ? null : () => widget.onMarkRead!(notice),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                icon: const Icon(Icons.done),
                label: Text(t.sourceNotices.markRead),
              ),
            ),
          ),
        const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}
