import 'package:zephyr/i18n/strings.g.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/video_profile_header.dart';

/// Identity and library navigation stay mounted while only the tab body loads.
/// The shell belongs to one confirmed site profile, never to a public author.
class VideoPersonalShell extends StatefulWidget {
  const VideoPersonalShell({
    super.key,
    required this.account,
    required this.page,
    required this.tabs,
    required this.current,
    required this.onTab,
    required this.onOpenSite,
    this.onAccountSettings,
    required this.child,
    this.overview,
  });
  final Map<String, dynamic> account;
  final Uri page, current;
  final List<({String title, Uri url})> tabs;
  final ValueChanged<Uri> onTab;
  final VoidCallback onOpenSite;
  final VoidCallback? onAccountSettings;
  final Widget child;
  final Widget? overview;

  @override
  State<VideoPersonalShell> createState() => _VideoPersonalShellState();
}

class _VideoPersonalShellState extends State<VideoPersonalShell>
    with TickerProviderStateMixin {
  late TabController _tabs;
  Duration? _tabDuration;
  int get _index {
    final index = widget.tabs.indexWhere(
      (tab) =>
          tab.url.path.replaceAll(RegExp(r'/$'), '') ==
          widget.current.path.replaceAll(RegExp(r'/$'), ''),
    );
    return index < 0 ? 0 : index;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final duration = VideoMotion.feedback(context);
    if (_tabDuration == duration) return;
    final index = _tabDuration == null ? _index : _tabs.index;
    if (_tabDuration != null) _tabs.dispose();
    _tabDuration = duration;
    _createTabs(index);
  }

  void _createTabs(int index) {
    _tabs = TabController(
      length: widget.tabs.length,
      initialIndex: index,
      vsync: this,
      animationDuration: _tabDuration,
    );
  }

  @override
  void didUpdateWidget(covariant VideoPersonalShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabs.length != widget.tabs.length) {
      _tabs.dispose();
      _createTabs(_index);
    } else if (_tabs.index != _index) {
      _tabs.index = _index;
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.overview != null &&
        widget.current.path.replaceFirst(RegExp(r'/$'), '') ==
            widget.page.path.replaceFirst(RegExp(r'/$'), '') &&
        !widget.current.hasQuery) {
      return widget.overview!;
    }
    return Column(
      children: [
        if (widget.overview != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.account['name']?.toString() ??
                        t.videoPlayback.siteAccount,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (widget.account['status'] != 'signedIn')
                    Text(
                      t.videoPlayback.accountUnconfirmed,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        if (widget.overview == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
            child: VideoProfileHeader(
              account: widget.account,
              page: widget.page,
              compact: true,
              onOpenSite: widget.onOpenSite,
              onAccountSettings: widget.onAccountSettings,
            ),
          ),
        if (widget.tabs.isNotEmpty)
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorSize: TabBarIndicatorSize.label,
            padding: const EdgeInsetsDirectional.only(end: 16),
            onTap: (index) => widget.onTab(widget.tabs[index].url),
            tabs: [
              for (final tab in widget.tabs)
                Tab(
                  text:
                      widget.overview != null &&
                          tab.url.path == widget.page.path
                      ? t.videoPersonal.overview
                      : tab.title,
                ),
            ],
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
