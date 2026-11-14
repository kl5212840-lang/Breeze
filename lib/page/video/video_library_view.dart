import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_history.dart';
import 'package:zephyr/service/collection_view_preferences.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/page/video/video_browse_theme.dart';
import 'package:zephyr/page/video/video_page_route.dart';

const videoLocalHistoryRouteName = 'breeze.video.local-history';

/// Local history owns a root page, independent of the source's account shell.
/// Opening a record pushes above this page so its conditions and position stay.
Future<void> openVideoLocalHistory(
  BuildContext context, {
  required String source,
  required String siteHost,
  required void Function(BuildContext, Uri) onOpenVideo,
}) => Navigator.of(context, rootNavigator: true).push<void>(
  videoPageRoute<void>(
    settings: const RouteSettings(name: videoLocalHistoryRouteName),
    builder: (routeContext) => InheritedTheme.captureAll(
      context,
      Theme(
        data: videoBrowseTheme(Theme.of(context)),
        child: Scaffold(
          body: VideoLibraryView(
            source: source,
            siteHost: siteHost,
            onOpenVideo: (uri) => onOpenVideo(routeContext, uri),
          ),
        ),
      ),
    ),
  ),
);

/// Local records share the source toolbar and management flow.
class VideoLibraryView extends StatefulWidget {
  const VideoLibraryView({
    super.key,
    required this.source,
    required this.siteHost,
    required this.onOpenVideo,
    this.revision = 0,
    this.onBack,
  });
  final String source, siteHost;
  final int revision;
  final ValueChanged<Uri> onOpenVideo;
  final VoidCallback? onBack;
  @override
  State<VideoLibraryView> createState() => _VideoLibraryViewState();
}

class _VideoLibraryViewState extends State<VideoLibraryView> {
  ApiVideoView _mode = ApiVideoView.grid;
  bool _saving = false;
  int _epoch = 0;
  String get _scope =>
      'plugin|${widget.source}|https://${widget.siteHost}/|history';
  @override
  void initState() {
    super.initState();
    CollectionViewPreferences.changes.addListener(_readView);
    unawaited(_readView());
  }

  @override
  void didUpdateWidget(VideoLibraryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.siteHost != widget.siteHost) {
      _epoch++;
      _saving = false;
      _mode = ApiVideoView.grid;
      unawaited(_readView());
    }
  }

  Future<void> _readView() async {
    if (_saving) return;
    final epoch = ++_epoch, scope = _scope;
    try {
      final value = await CollectionViewPreferences.read(scope);
      if (mounted && epoch == _epoch && scope == _scope && !_saving) {
        setState(
          () => _mode = value == 'list' ? ApiVideoView.list : ApiVideoView.grid,
        );
      }
    } catch (_) {
      /* Unavailable preferences do not hide local records. */
    }
  }

  Future<void> _toggleView() async {
    if (_saving) return;
    final epoch = ++_epoch, scope = _scope, old = _mode;
    setState(() {
      _saving = true;
      _mode = old == ApiVideoView.grid ? ApiVideoView.list : ApiVideoView.grid;
    });
    try {
      await CollectionViewPreferences.write(scope, _mode.name);
    } catch (_) {
      if (mounted && epoch == _epoch && scope == _scope) {
        setState(() => _mode = old);
        showErrorToast(t.videoLibrary.saveFailed);
      }
    } finally {
      if (mounted && epoch == _epoch && scope == _scope)
        setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _epoch++;
    CollectionViewPreferences.changes.removeListener(_readView);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ApiVideoHistory(
          key: ValueKey(
            'video-library.${widget.source}.${widget.siteHost}.${widget.revision}',
          ),
          source: widget.source,
          home: Uri.https(widget.siteHost, '/'),
          allowStandaloneWatch: true,
          headerLeading: SourceBackButton(onPressed: widget.onBack),
          compactHeader: true,
          posterAspectRatio: 2 / 3,
          mode: _mode,
          onToggleView: _saving ? null : () => unawaited(_toggleView()),
          onOpen: (_, watch) async => widget.onOpenVideo(watch),
        ),
      ),
    ],
  );
}
