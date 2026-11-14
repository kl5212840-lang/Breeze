import 'package:zephyr/page/video/video_download_navigation.dart';
import 'package:zephyr/page/video/video_detail_sections.dart';
import 'package:zephyr/widgets/native_material_surface.dart';
import 'package:zephyr/page/video/video_playback_download_adapter.dart';
import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/video_network_scope.dart';
import 'dart:async';
import 'dart:io';

import 'package:zephyr/page/video/video_page_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_diagnostic_preferences.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/page/video/video_playback_settings_page.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_playback_quick_panel.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';
import 'package:zephyr/page/video/video_card_metadata.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/page/video/video_site_access.dart';
import 'package:zephyr/page/video/video_site_operations.dart';
import 'package:zephyr/page/video/video_engagement.dart';
import 'package:zephyr/page/video/video_community_page.dart';
import 'package:zephyr/page/video/video_playlist_picker.dart';
import 'package:zephyr/page/video/video_site_action_models.dart';
import 'package:zephyr/page/video/video_system_share.dart';
import 'package:zephyr/page/video/video_download_sheet.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/video_panel_transition.dart';
import 'package:zephyr/page/video/video_selection_panel.dart';
import 'package:zephyr/page/video/video_side_panel.dart';
import 'package:zephyr/page/video/video_episode_sequence.dart';
import 'package:zephyr/page/video/video_episode_picker.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/page/video/video_local_favorite_action.dart';
import 'package:zephyr/util/debouncer.dart';

typedef NativeEpisodeLoad = ({
  NativePlaybackSession session,
  VideoSiteOperations? operations,
});

enum _LinePlaybackPhase { preparing, ready, playing, failed, cancelled }

typedef _LinePlaybackAttempt = ({
  _LinePlaybackPhase phase,
  Duration? elapsed,
  Duration progressAnchor,
});

/// Native video detail. Playback starts inline; fullscreen is opt-in.
class NativeVideoPage extends StatefulWidget {
  const NativeVideoPage({
    super.key,
    required this.session,
    this.initialMedia,
    this.onOpenVideo,
    this.initialEpisodeSequence,
    this.onOpenCreator,
    this.onOpenCreatorWorks,
    this.onOpenUploader,
    this.onSearchTag,
    this.onOpenTag,
    this.refreshSession,
    this.preferredSource = 'auto',
    this.source,
    this.onVerifySite,
    this.initialPosition,
    this.siteVerification,
    this.siteOperations,
    this.initialSiteInteraction,
    this.downloadAdapter,
    this.onOpenAccount,
    this.initialPlaybackState,
    this.onPlaybackExit,
    this.loadEpisode,
    this.onEpisodeChanged,
    this.detailBuilder,
    this.detailToolsBuilder,
    this.extraPlayerActions,
    this.onOpenWebsite,
    this.onPlaybackError,
    this.analyzePlayback,
    this.extraFailureActions,
    this.resourceLines,
    this.autoResourceFallback = false,
    this.recoverCurrentResource,
    this.onResolutionCancelled,
    this.playerFactory,
    this.networkContext,
    this.historyMetadata,
    this.historyCoverUrl,
    this.initialHistory,
    this.initialProgressWatch,
    this.onMediaPrepared,
    this.downloadSourceDuration,
    this.onDownloadEpisodes,
    this.offlineOnly = false,
    this.initialControlsVisible = true,
  });

  final VideoPlayerController Function(NativePlaybackSource)? playerFactory;
  final OmoNetworkContext? networkContext;
  final Map<String, String> Function(NativePlaybackSession)? historyMetadata;
  final Uri? historyCoverUrl;
  final Future<List<VideoWatchRecord>>? initialHistory;

  /// The original watch identity when a verified same episode used another line.
  final Uri? initialProgressWatch;
  final VoidCallback? onMediaPrepared;
  final String? Function(NativePlaybackSession)? downloadSourceDuration;
  final Future<void> Function(NativePlaybackSession)? onDownloadEpisodes;
  final AsyncCallback? onOpenWebsite;
  final ValueChanged<String>? onPlaybackError;
  final Future<void> Function(BuildContext, NativePlaybackSession, String)?
  analyzePlayback;
  final List<Widget> Function(
    BuildContext,
    NativePlaybackSession,
    ValueChanged<NativeVideoCard>,
  )?
  extraFailureActions;
  final List<NativeVideoResourceLine> Function(NativePlaybackSession)?
  resourceLines;
  final bool autoResourceFallback;

  /// Device-owned playback has no website/source navigation or network recovery.
  final bool offlineOnly;
  final bool initialControlsVisible;
  final Future<NativePlaybackSession?> Function(NativePlaybackSession current)?
  recoverCurrentResource;
  final ValueChanged<Uri>? onResolutionCancelled;
  final VideoPlaybackDownloadAdapter Function(NativePlaybackSession)?
  downloadAdapter;
  final NativePlaybackSession session;
  final Future<NativePlaybackSession?>? initialMedia;
  final VideoEpisodeSequence? initialEpisodeSequence;
  final Future<NativeEpisodeLoad> Function(Uri)? loadEpisode;
  final ValueChanged<NativeEpisodeLoad>? onEpisodeChanged;
  final Widget Function(
    BuildContext,
    NativePlaybackSession,
    Future<void> Function(AsyncCallback),
    Future<void> Function(AsyncCallback),
    Widget,
  )?
  detailBuilder;
  final Widget Function(VoidCallback openEpisodes, VoidCallback openSources)?
  detailToolsBuilder;
  final List<Widget> Function(
    BuildContext,
    NativePlaybackSession,
    Future<void> Function(AsyncCallback),
    Future<void> Function(AsyncCallback),
  )?
  extraPlayerActions;
  final ValueChanged<Uri>? onOpenVideo;
  final AsyncCallback? onOpenCreator;
  final AsyncCallback? onOpenCreatorWorks;
  final AsyncCallback? onOpenUploader;
  final Future<void> Function(String)? onSearchTag;
  final Future<void> Function(Uri)? onOpenTag;
  final Future<NativePlaybackSession> Function()? refreshSession;
  final String preferredSource;
  final String? source;
  final ValueChanged<Duration>? onVerifySite;
  final Duration? initialPosition;
  final ValueListenable<bool>? siteVerification;
  final VideoSiteOperations? siteOperations;
  final VideoSiteResult<VideoInteractionState>? initialSiteInteraction;
  final VoidCallback? onOpenAccount;
  final NativePlaybackReturnState? initialPlaybackState;
  final ValueChanged<NativePlaybackReturnState>? onPlaybackExit;

  @override
  State<NativeVideoPage> createState() => _NativeVideoPageState();
}

class _NativeVideoPageState extends State<NativeVideoPage>
    with WidgetsBindingObserver {
  bool _downloadOpen = false;
  bool get _canAutoResourceFallback =>
      !widget.offlineOnly && widget.autoResourceFallback;
  late NativePlaybackSession _session;
  late VideoEpisodeSequence _episodeSequence;
  final _episodeReturns = <Uri, NativePlaybackReturnState>{};
  bool _episodeLoading = false, _episodeCancelled = false;
  Completer<void>? _episodeAbort;
  Completer<void>? _retryAbort;
  VideoPlayerController? _episodeStartingPlayer;
  NativeVideoCard? _episodeRetryTarget;
  String? _episodeFailureStage, _episodeFailureType;
  final _episodeRetirements = <Future<void>>{};
  final _retiredPlayers = Expando<Future<void>>();
  final _localReadLeases = Expando<ManagedVideoReadLease>();
  final _hlsReadLeases = Expando<VideoHlsPlaybackLease>();
  bool _relatedPageOpen = false;
  bool _auxiliaryOverlayOpen = false;
  Timer? _episodeWaitTimer;
  bool _showEpisodeWait = false;
  bool _autoResourceActive = false;
  String _autoResourceLabel = '';
  int _autoResourceAttempt = 0, _autoResourceTotal = 0;
  int _autoResourceGeneration = 0;
  final _autoResourceTried = <Uri>{};
  final _linePlaybackAttempts = <Uri, _LinePlaybackAttempt>{};
  final _failedMediaUrls = <Uri>{};
  bool _recoveringResource = false;
  bool _rawRecoveryPending = false;
  final _rawRecoveriesTried = <Uri>{};
  Completer<void>? _resourceRecoveryAbort;
  Uri? _pendingResolutionUri;
  Completer<void>? _mediaAbort;
  NativeVideoCard? _queuedManualLine;
  NativePlaybackReturnState? _queuedManualIntent, _activeSwitchIntent;
  bool _interruptingMedia = false;
  List<NativeVideoResourceLine> get _resourceLines =>
      widget.resourceLines?.call(_session) ?? const [];
  bool get _hasSourceChoices => widget.resourceLines != null
      ? _resourceLines.length > 1
      : _session.sources.length > 1;
  String get _currentSourceLabel => widget.resourceLines != null
      ? (_resourceLines.where((line) => line.current).firstOrNull?.label ?? '')
      : videoSourceLabel(_session.sources[_sourceIndex], _sourceIndex);
  String get _selectionTitle => _session.isSitePlaylist
      ? t.videoPlayback.sitePlaylist
      : t.videoPlayback.episodes;

  VideoEpisodeSequence _newSequence(NativePlaybackSession session) =>
      VideoEpisodeSequence(
        session.playbackEntries,
        order: session.isSitePlaylist
            ? VideoEpisodeOrder.site
            : VideoEpisodeOrder.ascending,
      );

  VideoSiteOperations? get _operations => _engagement?.operations;
  bool get _hanimeOnlineDetail =>
      !widget.offlineOnly &&
      _session.watchUrl.host == 'hanime1.me' &&
      (_operations != null || widget.initialMedia != null);

  void _markCurrentLineFailed() {
    final media = _session.sources.elementAtOrNull(_sourceIndex)?.url;
    if (media != null) _failedMediaUrls.add(media);
    final previous = _linePlaybackAttempts[_session.watchUrl];
    _linePlaybackAttempts[_session.watchUrl] = (
      phase: _LinePlaybackPhase.failed,
      elapsed: previous?.elapsed,
      progressAnchor: previous?.progressAnchor ?? _resumePosition,
    );
  }

  String _resourceLineSubtitle(NativeVideoResourceLine line) {
    if (line.target == null && !line.current) {
      return t.videoPlayback.episodeMissingOnLine;
    }
    final attempt =
        _linePlaybackAttempts[line.current
            ? _session.watchUrl
            : line.target?.watchUrl];
    final resolving = line.resolving || (_rawRecoveryPending && line.current);
    final state = resolving
        ? t.videoSource.lineResolving
        : switch (attempt?.phase) {
            _LinePlaybackPhase.preparing => t.videoSource.linePreparing,
            _LinePlaybackPhase.ready => t.videoSource.lineReady,
            _LinePlaybackPhase.playing => t.videoSource.linePlayed,
            _LinePlaybackPhase.failed => t.videoSource.lineFailed,
            _LinePlaybackPhase.cancelled => t.videoSource.lineCancelled,
            null => '',
          };
    return state.isNotEmpty ? state : t.videoSource.lineUntested;
  }

  VideoPlaybackPreferences _preferences = const VideoPlaybackPreferences();
  ValueNotifier<String> get _interfaceStyle =>
      AppInterfaceStyleScope.styleOf(context) ??
      VideoPlaybackPreferences.interfaceStyle;
  bool get _usesSystemControls => _interfaceStyle.value != 'breeze';

  late final Future<OmoNetworkContext?>? _network =
      widget.networkContext == null
      ? null
      : Future.value(widget.networkContext);
  VideoPlayerController? _controller;
  VideoPlayerValue? _lastPlayableValue;
  Timer? _hideTimer;
  Timer? _stallWatchdog;
  Duration? _stallPosition;
  Timer? _feedbackTimer;
  Timer? _actionNoticeTimer;
  String? _actionNotice;
  Duration? _dragPosition;
  String? _seekFeedback;
  Alignment _seekFeedbackAlignment = Alignment.center;
  int _sourceIndex = 0;
  int _loadEpoch = 0;
  bool _loading = true;
  bool _failed = false;
  bool _verificationRequired = false;
  bool _leavingToSite = false;
  bool _retrying = false;
  bool _foreground = true;
  bool _hostPlaybackPaused = false;
  bool _routeExited = false;
  bool get _canResumePlayback =>
      _foreground &&
      !_hostPlaybackPaused &&
      !_verificationRequired &&
      !_relatedPageOpen;
  late final VideoDownloadPlaybackOwner _downloadPlaybackOwner;
  bool _controlsVisible = true;
  int _controlsTapEpoch = 0;
  final _controlHoldEpochs = <String, int>{};
  final _controlInteractions = <String>{};
  bool _fullscreen = false;
  bool _portraitFullscreen = false;
  bool _changingFullscreen = false;
  bool _holdingFastForward = false;
  bool _swiping = false;
  bool _muted = false;
  bool _locked = false;
  bool _descriptionExpanded = false;
  bool _tagsExpanded = false;
  bool _commentsSelected = false, _commentsOpened = false;
  VideoEngagementController? _engagement;
  final _detailContentKey = GlobalKey();
  bool get _editingComments =>
      !_fullscreen &&
      _commentsSelected &&
      MediaQuery.viewInsetsOf(context).bottom > 0;
  VideoQuickSection? _quickSection;
  VideoQuickSection _lastQuickSection = VideoQuickSection.playback;
  (bool, bool?)? _pendingFullscreen;
  PageStorageBucket _quickStorage = PageStorageBucket();
  int _preferenceReadEpoch = 0;
  int _preferenceWriteId = 0;
  final _pendingPreferenceValues = <String, Object>{};
  final _pendingPreferenceIds = <String, int>{};
  Duration _swipeOrigin = Duration.zero;
  double _swipeDistance = 0;
  double _speed = 1;
  double _doubleTapX = 0;
  double _tapAreaWidth = 1;
  Duration _resumePosition = Duration.zero;
  bool _resumePlaying = true;
  int _lastSavedSecond = -1;
  DateTime _lastUiTick = DateTime.fromMillisecondsSinceEpoch(0);
  bool? _lastPlaying;
  bool? _lastBuffering;
  String _lastPlaybackError = '';
  bool _analysisEnabled = false;
  int _analysisEpoch = 0;
  bool get _canAnalyze => _analysisEnabled && widget.analyzePlayback != null;

  Future<void> _readAnalysisPreference() async {
    final epoch = ++_analysisEpoch;
    final source = widget.source;
    final enabled = source == null || source.isEmpty
        ? widget.analyzePlayback != null
        : await SourceDiagnosticPreferences.enabled(source);
    if (mounted && epoch == _analysisEpoch) {
      setState(() => _analysisEnabled = enabled);
    }
  }

  void _recordPlaybackError(String error) {
    _lastPlaybackError = error;
    widget.onPlaybackError?.call(error);
  }

  Future<void> _analyzePlayback() async {
    final analyze = widget.analyzePlayback;
    if (!_canAnalyze || analyze == null) return;
    final source = widget.source;
    if (source != null &&
        source.isNotEmpty &&
        !await SourceDiagnosticPreferences.enabled(source)) {
      return;
    }
    if (!mounted) return;
    final sources = _sourceIndex >= 0 && _sourceIndex < _session.sources.length
        ? [_session.sources[_sourceIndex]]
        : <NativePlaybackSource>[];
    final current = _session.withSources(sources);
    _closeQuickSettings();
    _holdControls('analysis');
    try {
      await analyze(context, current, _lastPlaybackError);
    } finally {
      if (mounted) _releaseControls('analysis');
    }
  }

  String get _progressKey => videoPlaybackProgressKey(_session.watchUrl);

  bool get _isPhone =>
      (Platform.isIOS || Platform.isAndroid) && !isTabletWithOutContext();

  @override
  void initState() {
    super.initState();
    _controlsVisible = widget.initialControlsVisible;
    _foreground = !{
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.detached,
    }.contains(WidgetsBinding.instance.lifecycleState);
    _hostPlaybackPaused = !_foreground;
    _downloadPlaybackOwner = VideoDownloadNavigation.register(
      _pauseForDownloadTasks,
    );
    _session = widget.session;
    _episodeSequence =
        (!_session.isSitePlaylist
            ? widget.initialEpisodeSequence?.reconciled(_session.episodes)
            : null) ??
        _newSequence(_session);
    if (widget.siteOperations case final operations?) {
      _engagement = VideoEngagementController(
        operations: operations,
        onLogin: () => _leaveSiteActions(login: true),
      )..addListener(_onEngagementChanged);
      unawaited(_engagement!.load(initial: widget.initialSiteInteraction));
      _retainObservedCreator();
    }
    WidgetsBinding.instance.addObserver(this);
    widget.siteVerification?.addListener(_onSiteVerification);
    VideoPlaybackPreferences.changes.addListener(_onPreferencesChanged);
    SourceDiagnosticPreferences.changes.addListener(_readAnalysisPreference);
    unawaited(_readAnalysisPreference());
    unawaited(_restoreAndLoad());
  }

  @override
  void didUpdateWidget(covariant NativeVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.offlineOnly &&
        !identical(oldWidget.session, widget.session) &&
        _session.watchUrl == oldWidget.session.watchUrl &&
        _session.watchUrl == widget.session.watchUrl) {
      // Offline metadata and the episode list can arrive after this exact
      // media source starts. Keep the controller, intent and progress.
      _session = widget.session;
      _episodeSequence = _session.isSitePlaylist
          ? _newSequence(_session)
          : _episodeSequence.reconciled(_session.episodes);
    }
  }

  void _onEngagementChanged() {
    if (mounted) setState(() {});
  }

  void _retainObservedCreator() {
    final source = widget.source;
    if (_hanimeOnlineDetail &&
        source != null &&
        videoSiteDocumentMatches(_session.watchUrl, _operations?.page)) {
      unawaited(VideoDownloadedDetails.retainObservedCreator(source, _session));
    }
  }

  Future<void> _favoriteVideo() async {
    final engagement = _engagement;
    if (engagement == null || engagement.working) return;
    final operations = engagement.operations;
    final style = _interfaceStyle;
    engagement.hold(true);
    _holdControls('site-actions');
    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        pageBuilder: (dialogContext, _, _) {
          void close() {
            if (!operations.writeInFlight) Navigator.of(dialogContext).pop();
          }

          return SafeArea(
            child: LayoutBuilder(
              builder: (_, constraints) {
                final side = constraints.maxWidth > constraints.maxHeight;
                return Stack(
                  children: [
                    ModalBarrier(
                      color: Colors.black45,
                      dismissible: true,
                      onDismiss: close,
                      semanticsLabel: MaterialLocalizations.of(
                        dialogContext,
                      ).modalBarrierDismissLabel,
                    ),
                    Align(
                      alignment: side
                          ? Alignment.centerRight
                          : Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: AppInterfaceStyleScope(
                          style: style,
                          child: NativeMaterialSurface(
                            key: const ValueKey('video-playlist.material'),
                            radius: 16,
                            floating: true,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth:
                                    constraints.maxWidth.clamp(0.0, 480.0) - 16,
                                maxWidth:
                                    constraints.maxWidth.clamp(0.0, 480.0) - 16,
                                maxHeight:
                                    (constraints.maxHeight * (side ? 1 : .72) -
                                            16)
                                        .clamp(120.0, constraints.maxHeight),
                              ),
                              child: VideoPlaylistPicker(
                                operations: operations,
                                onLogin: engagement.onLogin,
                                onWebsite: _leaveSiteActions,
                                onClose: close,
                                onChanged: engagement.setFavorite,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      );
    } finally {
      await operations.cancelRead();
      if (mounted && identical(_engagement, engagement)) {
        engagement.hold(false);
        _releaseControls('site-actions');
      }
    }
  }

  VideoPlaybackDownloadAdapter? _downloadAdapter(
    NativePlaybackSession session,
  ) => VideoPlaybackDownloadAdapter.resolve(
    session,
    declared: widget.downloadAdapter,
    hasWebsiteDownload: _engagement?.operations != null,
  );

  Future<void> _downloadVideo() async {
    final engagement = _engagement;
    if (_downloadOpen ||
        engagement?.held == true ||
        engagement?.working == true)
      return;
    unawaited(
      VideoDownloadedDetails.saveSession(
        widget.source ?? '',
        _session,
      ).catchError((Object _) {}),
    );
    final downloadEpisodes = widget.onDownloadEpisodes;
    if (downloadEpisodes != null) {
      _downloadOpen = true;
      _holdControls('episode-download');
      try {
        await downloadEpisodes(_session);
      } finally {
        _downloadOpen = false;
        if (mounted) _releaseControls('episode-download');
      }
      return;
    }
    final operations = engagement?.operations;
    final session = _session;
    final player = _controller?.value;
    final durationMs =
        !_episodeLoading &&
            player?.isInitialized == true &&
            player!.duration > Duration.zero
        ? player.duration.inMilliseconds
        : null;
    final adapter = _downloadAdapter(session);
    if (adapter == null && operations == null) return;
    if (adapter != null && adapter.choices.isEmpty) return;
    final refreshDownloadSession = widget.refreshSession;
    final downloadSource = widget.source;
    final downloadContext = widget.networkContext;
    final downloadGeneration = pluginSessionWriteFence.generation(
      downloadSource ?? '',
    );
    final downloadWatch = videoPlaybackIdentity(session.watchUrl);
    bool downloadCurrent() =>
        mounted &&
        widget.source == downloadSource &&
        identical(widget.networkContext, downloadContext) &&
        identical(_engagement, engagement) &&
        videoPlaybackIdentity(_session.watchUrl) == downloadWatch &&
        !pluginSessionWriteFence.isChanging(downloadSource ?? '') &&
        pluginSessionWriteFence.generation(downloadSource ?? '') ==
            downloadGeneration;
    Future<VideoPlaybackDownloadAdapter> refreshDownloadAdapter() async {
      if (!downloadCurrent() || refreshDownloadSession == null)
        throw StateError('Download session changed');
      // Read fresh download choices only. The playing controller/session and
      // position remain owned by the existing player throughout this request.
      final fresh = await refreshDownloadSession();
      if (!downloadCurrent() ||
          videoPlaybackIdentity(fresh.watchUrl) != downloadWatch)
        throw StateError('Download session changed');
      final result = _downloadAdapter(fresh);
      if (result == null) throw StateError('Download choices unavailable');
      return result;
    }

    _downloadOpen = true;
    engagement?.hold(true);
    _holdControls('system-download');
    try {
      await showVideoTaskSheet<void>(
        context: context,
        useRootNavigator: true,
        systemStyle: _usesSystemControls,
        networkSource: widget.source,
        network: _network,
        builder: (sheetContext) => VideoDownloadNavigationOrigin(
          origin: context,
          child: VideoDownloadSheet(
            source: widget.source ?? '',
            networkContext: widget.networkContext?.token,
            readChoices:
                adapter?.readChoices ?? operations!.readDownloadChoices,
            choicesAreSnapshot: adapter != null,
            refreshAdapter: adapter != null && refreshDownloadSession != null
                ? refreshDownloadAdapter
                : null,
            headersForChoice: adapter?.headersForChoice,
            emptyMessage: adapter == null
                ? null
                : t.videoDownload.unsupportedMedia,
            video: session.watchUrl,
            title: session.title,
            cover: session.coverUrl?.toString(),
            durationMs: durationMs,
            sourceDuration: widget.downloadSourceDuration?.call(session),
            onClose: () => Navigator.of(sheetContext).pop(),
            onWebsite: adapter == null ? _leaveSiteActions : null,
          ),
        ),
      );
    } finally {
      await operations?.cancelRead();
      if (mounted && identical(_engagement, engagement))
        engagement?.hold(false);
      _downloadOpen = false;
      _releaseControls('system-download');
    }
  }

  void _clearActionNotice() {
    _actionNoticeTimer?.cancel();
    if (mounted && _actionNotice != null) setState(() => _actionNotice = null);
  }

  void _showActionNotice(String message) {
    _actionNoticeTimer?.cancel();
    setState(() => _actionNotice = message);
    _actionNoticeTimer = Timer(const Duration(seconds: 3), _clearActionNotice);
  }

  Future<void> _shareVideo(Rect anchor) async {
    _clearActionNotice();
    final engagement = _engagement;
    if (engagement?.held == true) return;
    engagement?.hold(true);
    _holdControls('system-share');
    try {
      final result = await VideoSystemShare.share(
        video: _session.watchUrl,
        title: _session.title,
        anchor: anchor,
      );
      if (!mounted) return;
      if (result == VideoShareStatus.failed ||
          result == VideoShareStatus.unavailable) {
        _showActionNotice(t.videoCommunity.shareFailed);
      }
    } finally {
      if (mounted && identical(_engagement, engagement)) {
        engagement?.hold(false);
      }
      _releaseControls('system-share');
    }
  }

  Future<void> _setSiteAction(VideoSiteAction action, bool enabled) async {
    final engagement = _engagement;
    if (engagement == null) return;
    _holdControls('site-write');
    try {
      await engagement.set(action, enabled);
      if (mounted && _fullscreen && engagement.error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(engagement.error!)));
      }
    } finally {
      _releaseControls('site-write');
    }
  }

  void _onSiteVerification() {
    if (!mounted ||
        widget.siteVerification?.value != true ||
        _verificationRequired) {
      return;
    }
    _cancelEpisodeRead();
    final value = _controller?.value;
    if (value?.isInitialized == true && value?.hasError != true) {
      _resumePosition = value!.position;
    }
    _hideTimer?.cancel();
    setState(() {
      _quickSection = null;
      _controlInteractions.remove('quick-settings');
      _verificationRequired = true;
      _failed = true;
      _loading = false;
      _controlsVisible = true;
      _locked = false;
      _holdingFastForward = false;
    });
    unawaited(
      _controller
          ?.pause()
          .timeout(const Duration(seconds: 2))
          .catchError((_) {}),
    );
  }

  Future<void> _restoreAndLoad() async {
    final epoch = _loadEpoch;
    try {
      _preferences = await VideoPlaybackPreferences.read();
      _speed = _preferences.defaultSpeed;
      _resumePlaying = _preferences.autoplay;
      _resumePosition = await _storedProgress(
        widget.initialProgressWatch ?? _session.watchUrl,
        history: widget.initialHistory,
        localResourceId: _session.sources
            .elementAtOrNull(_preferredSourceIndex())
            ?.localResourceId,
      );
    } catch (_) {
      // Local progress is optional; it must never block playback.
    }
    if (widget.initialPlaybackState case final returned?) {
      _resumePosition = returned.position;
      _resumePlaying = returned.playing;
    }
    if (widget.initialPosition != null) {
      _resumePosition = widget.initialPosition!;
    }
    if (widget.initialMedia case final pending?) {
      NativePlaybackSession? media;
      try {
        media = await pending;
      } catch (_) {
        // The visible detail remains available if media resolution fails.
      }
      if (!mounted || _routeExited || epoch != _loadEpoch) return;
      if (media case final resolved?
          when resolved.watchUrl == _session.watchUrl) {
        setState(() => _session = _session.withSources(resolved.sources));
      }
    }
    if (mounted) await _loadSource(_preferredSourceIndex());
  }

  Future<Duration> _storedProgress(
    Uri watchUrl, {
    Future<List<VideoWatchRecord>>? history,
    String? localResourceId,
  }) async {
    bool canResume() =>
        _preferences.recordHistory && _preferences.resumeProgress;
    if (!canResume()) return Duration.zero;
    final source = widget.source;
    final watch = VideoWatchRecord.canonicalUrl(watchUrl);
    if (source != null && watch != null) {
      try {
        final records = await (history ?? VideoWatchHistory.read(source))
            .timeout(const Duration(seconds: 2));
        final record = records
            .where((row) => row.watchUrl == watch)
            .firstOrNull;
        if (record != null) {
          if (record.completed || !canResume()) return Duration.zero;
          if (widget.offlineOnly) {
            if (localResourceId == null) return Duration.zero;
            final recordedResource = record.localResourceId;
            if (recordedResource != null) {
              if (recordedResource != localResourceId) return Duration.zero;
            } else if (record.position > Duration.zero &&
                !await VideoLocalResources.isUniquePlaybackVersion(
                  source,
                  watch,
                  localResourceId,
                )) {
              return Duration.zero;
            }
          }
          return canResume() ? record.position : Duration.zero;
        }
      } catch (_) {
        // Older numeric progress remains usable if metadata cannot be read.
      }
    }
    // The old numeric key is shared by sources with the same public URL and
    // has no version information. Offline playback uses source history.
    if (widget.offlineOnly) return Duration.zero;
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getInt(videoPlaybackProgressKey(watchUrl)) ?? 0;
      return canResume() && saved > 0
          ? Duration(milliseconds: saved)
          : Duration.zero;
    } catch (_) {
      return Duration.zero;
    }
  }

  int _preferredSourceIndex() {
    if (widget.preferredSource == 'auto') return 0;
    final ranked = <(int, int)>[];
    for (var i = 0; i < _session.sources.length; i++) {
      final quality = int.tryParse(
        RegExp(r'\d{3,4}').firstMatch(_session.sources[i].label)?.group(0) ??
            '',
      );
      if (quality != null) ranked.add((i, quality));
    }
    ranked.sort((a, b) => a.$2.compareTo(b.$2));
    if (ranked.isEmpty) return 0;
    return widget.preferredSource == 'highest'
        ? ranked.last.$1
        : ranked.first.$1;
  }

  void _onPreferencesChanged() => unawaited(_reloadPreferences());

  Future<void> _reloadPreferences() async {
    final epoch = ++_preferenceReadEpoch;
    try {
      final saved = await VideoPlaybackPreferences.read();
      if (!mounted || epoch != _preferenceReadEpoch) return;
      final previousDefault = _preferences.defaultSpeed;
      setState(
        () => _preferences = VideoPlaybackPreferences.fromValues({
          ...saved.toValues(),
          ..._pendingPreferenceValues,
        }),
      );
      if (previousDefault != _preferences.defaultSpeed) {
        await _setSpeed(_preferences.defaultSpeed);
      }
    } catch (_) {
      // Keep the active playback and its last known preferences usable.
    }
  }

  Future<void> _savePlayerPreference(String key, Object value) async {
    final id = ++_preferenceWriteId;
    _pendingPreferenceIds[key] = id;
    _pendingPreferenceValues[key] = value;
    setState(
      () => _preferences = VideoPlaybackPreferences.fromValues({
        ..._preferences.toValues(),
        key: value,
      }),
    );
    try {
      await VideoPlaybackPreferences.save(key, value);
    } catch (_) {
      if (mounted && _pendingPreferenceIds[key] == id) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(t.videoPlayback.settingsSaveFailed)),
          );
      }
    } finally {
      if (_pendingPreferenceIds[key] == id) {
        _pendingPreferenceIds.remove(key);
        _pendingPreferenceValues.remove(key);
      }
      if (mounted) await _reloadPreferences();
    }
  }

  void _openQuickSettings([
    VideoQuickSection section = VideoQuickSection.playback,
  ]) {
    if (_quickSection == null) _quickStorage = PageStorageBucket();
    _holdControls('quick-settings');
    unawaited(_setFastForward(false));
    setState(() {
      _quickSection = section;
      _lastQuickSection = section;
    });
  }

  void _closeQuickSettings() {
    if (_quickSection == null) return;
    setState(() => _quickSection = null);
    _releaseControls('quick-settings');
  }

  bool _blockDocumentChangeForSiteWrite() {
    if (_operations?.writeInFlight != true) return false;
    _showActionNotice(t.videoCommunity.busy);
    return true;
  }

  void _selectEpisode(
    NativeVideoCard card, {
    NativePlaybackReturnState? selectionIntent,
  }) {
    _closeQuickSettings();
    if (card.isCurrent(_session.watchUrl) ||
        _blockDocumentChangeForSiteWrite()) {
      return;
    }
    _autoResourceGeneration++;
    if (_autoResourceActive ||
        _episodeLoading ||
        _retrying ||
        _recoveringResource ||
        _interruptingMedia) {
      _queuedManualLine = card;
      _queuedManualIntent =
          _activeSwitchIntent ??
          _queuedManualIntent ??
          (position: _resumePosition, playing: _resumePlaying);
      if (_retrying && _mediaAbort != null && !_interruptingMedia) {
        unawaited(_interruptMediaForSelection());
      } else {
        _cancelEpisodeRead(discardQueued: false);
      }
      return;
    }
    if (_loading && widget.loadEpisode != null) {
      _queuedManualLine = card;
      _queuedManualIntent = (
        position: _resumePosition,
        playing: _resumePlaying,
      );
      unawaited(_interruptMediaForSelection());
      return;
    }
    _queuedManualLine = null;
    _queuedManualIntent = null;
    _autoResourceTried.clear();
    _failedMediaUrls.clear();
    _rawRecoveriesTried.clear();
    if (widget.loadEpisode != null) {
      unawaited(_switchEpisode(card, selectionIntent: selectionIntent));
    } else {
      widget.onOpenVideo?.call(card.watchUrl);
    }
  }

  void _drainManualSelection() {
    if (_autoResourceActive ||
        _episodeLoading ||
        _loading ||
        _retrying ||
        _recoveringResource ||
        _interruptingMedia) {
      return;
    }
    final manual = _queuedManualLine;
    final intent = _queuedManualIntent;
    _queuedManualLine = null;
    _queuedManualIntent = null;
    if (manual != null && mounted && _foreground && !_verificationRequired) {
      _selectEpisode(manual, selectionIntent: intent);
    }
  }

  Future<void> _interruptMediaForSelection() async {
    _interruptingMedia = true;
    _cancelEpisodeRead(discardQueued: false);
    _loadEpoch++;
    _cancelMediaPreparation();
    final player = _controller;
    player?.removeListener(_onPlayerChanged);
    _controller = null;
    final attempt = _linePlaybackAttempts[_session.watchUrl];
    _linePlaybackAttempts[_session.watchUrl] = (
      phase: _LinePlaybackPhase.cancelled,
      elapsed: attempt?.elapsed,
      progressAnchor: attempt?.progressAnchor ?? _resumePosition,
    );
    setState(() {
      _loading = false;
      _failed = true;
    });
    try {
      if (player != null) {
        await _retireEpisodePlayer(player).timeout(const Duration(seconds: 5));
      }
    } catch (_) {
      // The subsequent transaction checks pending native-player retirements.
      // Never create a second player to bypass an unfinished teardown.
    } finally {
      _interruptingMedia = false;
      if (mounted) _drainManualSelection();
    }
  }

  Future<void> _openPlaybackSettings() async {
    _closeQuickSettings();
    _holdControls('settings');
    try {
      await Navigator.of(context).push<void>(
        videoPageRoute(
          networkSource: widget.source,
          network: _network,
          builder: (_) => VideoPlaybackSettingsPage(source: widget.source),
        ),
      );
    } finally {
      _releaseControls('settings');
    }
    if (mounted) await _reloadPreferences();
  }

  Future<void> _persistProgress() async {
    final session = _session;
    final progressKey = _progressKey;
    if (_routeExited || !_preferences.recordHistory) return;
    // A failed or retiring native player can lose its position before exit.
    final value = _lastPlayableValue;
    if (value == null || value.duration <= Duration.zero) {
      return;
    }
    final position = value.position;
    final completed =
        value.isCompleted ||
        position.inMilliseconds >= value.duration.inMilliseconds * 0.98;
    final historyMinimum = Duration(seconds: widget.offlineOnly ? 1 : 5);
    try {
      var historySaved = false;
      if ((position >= historyMinimum || value.isCompleted) &&
          widget.source != null &&
          VideoWatchRecord.canonicalUrl(session.watchUrl) != null) {
        try {
          await VideoWatchHistory.record(
            widget.source!,
            VideoWatchRecord(
              watchUrl: session.watchUrl,
              title: session.title,
              coverUrl: widget.historyCoverUrl ?? session.coverUrl,
              metadata: widget.historyMetadata?.call(session) ?? const {},
              position: position,
              duration: value.duration,
              updatedAt: DateTime.now().toUtc(),
              completed: completed,
              localResourceId: widget.offlineOnly
                  ? session.sources
                        .elementAtOrNull(_sourceIndex)
                        ?.localResourceId
                  : null,
            ),
          ).timeout(const Duration(seconds: 3));
          historySaved = true;
        } catch (_) {
          // Optional history cannot block playback or route exit.
        }
      }
      if (widget.offlineOnly) return;
      final preferences = await SharedPreferences.getInstance();
      // New records own source-scoped progress. Retain the old numeric key
      // only as a migration/storage-failure fallback, not a second history.
      if (historySaved || !_preferences.resumeProgress || completed) {
        await preferences.remove(progressKey);
      } else if (position >= const Duration(seconds: 5)) {
        await preferences.setInt(progressKey, position.inMilliseconds);
      }
    } catch (_) {
      // Never surface a storage failure as a playback error.
    }
  }

  Future<bool> _pauseForDownloadTasks() async {
    if (!mounted) return true;
    // Persist a deliberate pause intent before awaiting native code. A late
    // preparation, episode switch or related-page return must not resume audio.
    _hostPlaybackPaused = true;
    _resumePlaying = false;
    _stallWatchdog?.cancel();
    _hideTimer?.cancel();
    final player = _controller;
    if (player?.value.isInitialized == true && !player!.value.hasError) {
      _resumePosition = player.value.position;
    }
    try {
      final starting = _episodeStartingPlayer;
      if (player != null)
        await player.pause().timeout(const Duration(seconds: 3));
      if (starting != null) {
        await starting.pause().timeout(const Duration(seconds: 3));
        if (starting.value.isPlaying) return false;
      }
      if (!mounted) return true;
      if (_controller != null && !identical(player, _controller)) {
        await _controller!.pause().timeout(const Duration(seconds: 3));
      }
      if (_controller?.value.isPlaying == true) return false;
      if (_routeExited) return true;
      unawaited(_persistProgress());
      unawaited(_setFastForward(false));
      _showControls();
      return true;
    } catch (_) {
      if (mounted) _showControls();
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_routeExited) return;
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
    }
    // iOS may briefly report `inactive` during fullscreen rotation. Pause
    // only when the app actually leaves the foreground.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _foreground = false;
      // A pending player setup or child page can finish after we foreground.
      // Keep the pause intent until the user explicitly starts playback.
      _hostPlaybackPaused = true;
      _resumePlaying = false;
      _cancelEpisodeRead();
      final controller = _controller;
      if (controller?.value.isInitialized == true &&
          controller?.value.hasError != true) {
        _resumePosition = controller!.value.position;
      }
      if (controller != null) {
        unawaited(_runPlayerCommand(controller, controller.pause));
      }
      unawaited(_setFastForward(false));
      _dragPosition = null;
      unawaited(_persistProgress());
      _showControls();
    }
  }

  VoidCallback? _relatedAction(AsyncCallback? action) =>
      action == null || _relatedPageOpen
      ? null
      : () => unawaited(_showRelatedPage(action));

  Future<void> _showRelatedPage(AsyncCallback action) async {
    if (_relatedPageOpen) return;
    final player = _controller;
    final playing = player?.value.isPlaying == true;
    final fullscreen = _fullscreen;
    final portrait = _portraitFullscreen;
    _relatedPageOpen = true;
    _cancelEpisodeRead();
    _holdControls('related-page');
    try {
      await player?.pause();
      await _persistProgress();
      if (fullscreen) await _setFullscreen(false);
      if (mounted) await action();
    } finally {
      _relatedPageOpen = false;
      if (mounted && !_routeExited) {
        if (fullscreen) await _setFullscreen(true, portrait: portrait);
        if (playing && _canResumePlayback && identical(player, _controller)) {
          await player?.play();
        }
        _releaseControls('related-page');
      }
    }
  }

  Future<void> _portraitComments() async {
    final engagement = _engagement;
    if (engagement == null || engagement.working) return;
    final style = _interfaceStyle;
    engagement.hold(true);
    _holdControls('comments-sheet');
    try {
      await showVideoTaskSheet<void>(
        context: context,
        systemStyle: style.value != 'breeze',
        networkSource: widget.source,
        network: _network,
        builder: (sheetContext) => AppInterfaceStyleScope(
          style: style,
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .72,
            child: VideoCommunityPage(
              key: ValueKey('feed-comments.${_session.watchUrl}'),
              operations: engagement.operations,
              onLogin: () => _leaveSiteActions(login: true),
              onWebsite: _leaveSiteActions,
            ),
          ),
        ),
      );
    } finally {
      await engagement.operations.cancelRead();
      if (mounted && identical(engagement, _engagement)) engagement.hold(false);
      _releaseControls('comments-sheet');
    }
  }

  Future<void> _showAuxiliaryOverlay(AsyncCallback action) async {
    if (_auxiliaryOverlayOpen) return;
    _auxiliaryOverlayOpen = true;
    _holdControls('source-overlay');
    try {
      if (mounted) await action();
    } finally {
      _auxiliaryOverlayOpen = false;
      _releaseControls('source-overlay');
    }
  }

  Future<void> _startPreparedPlayer(VideoPlayerController player) {
    // video_player can schedule its progress timer after the platform play
    // reply even when this controller was paused or disposed during the wait.
    return runZoned(
      player.play,
      zoneSpecification: ZoneSpecification(
        createPeriodicTimer: (_, parent, zone, duration, tick) {
          final timer = parent.createPeriodicTimer(zone, duration, tick);
          if (_retiredPlayers[player] != null || !_canResumePlayback) {
            timer.cancel();
          }
          return timer;
        },
      ),
    );
  }

  Future<void> _retireEpisodePlayer(VideoPlayerController player) {
    final previous = _retiredPlayers[player];
    if (previous != null) return previous;
    final disposal = player.dispose().then((_) async {
      await _hlsReadLeases[player]?.release();
      _hlsReadLeases[player] = null;
      _localReadLeases[player]?.release();
      _localReadLeases[player] = null;
    });
    _retiredPlayers[player] = disposal;
    _episodeRetirements.add(disposal);
    unawaited(
      disposal.then(
        (_) => _episodeRetirements.remove(disposal),
        onError: (Object _, StackTrace _) {},
      ),
    );
    return disposal;
  }

  Future<void> _waitForEpisodeRetirements() async {
    // Never allocate a replacement while a discarded candidate still owns its
    // native player. A stuck teardown yields retry rather than extra players.
    await Future.wait(
      _episodeRetirements.toList(),
    ).timeout(const Duration(seconds: 3));
  }

  void _cancelEpisodeRead({
    bool discardQueued = true,
    bool cancelRecovery = true,
    bool notifyResolution = true,
  }) {
    _episodeCancelled = true;
    if (discardQueued) {
      _queuedManualLine = null;
      _queuedManualIntent = null;
    }
    _autoResourceGeneration++;
    final target = _pendingResolutionUri;
    _pendingResolutionUri = null;
    if (target != null && notifyResolution) {
      widget.onResolutionCancelled?.call(target);
    }
    final abort = _episodeAbort;
    if (abort != null && !abort.isCompleted) abort.complete();
    final retry = _retryAbort;
    if (retry != null && !retry.isCompleted) retry.complete();
    unawaited(
      _episodeStartingPlayer
          ?.pause()
          .timeout(const Duration(seconds: 2))
          .catchError((_) {}),
    );
    if (cancelRecovery && _recoveringResource) {
      final recovery = _resourceRecoveryAbort;
      if (recovery != null && !recovery.isCompleted) recovery.complete();
      if (_mediaAbort != null) {
        _loadEpoch++;
        _cancelMediaPreparation();
        final player = _controller;
        _controller = null;
        player?.removeListener(_onPlayerChanged);
        if (player != null) {
          unawaited(_retireEpisodePlayer(player).catchError((_) {}));
        }
        _loading = false;
        _failed = true;
      }
    }
  }

  void _cancelMediaPreparation() {
    final abort = _mediaAbort;
    if (abort != null && !abort.isCompleted) abort.complete();
  }

  Future<T> _awaitEpisode<T>(Future<T> request) {
    final abort = _episodeAbort;
    if (!_canAutoResourceFallback || abort == null) return request;
    return Future.any([
      request,
      abort.future.then<T>((_) => throw StateError('Episode switch cancelled')),
    ]);
  }

  // Every caller is an explicit selection. Mode, orientation and gesture
  // preferences cannot revoke a valid manual switch after its network read.
  Future<void> _switchEpisode(
    NativeVideoCard target, {
    DateTime? deadline,
    bool automatic = false,
    NativePlaybackReturnState? selectionIntent,
  }) async {
    bool canContinue() =>
        mounted &&
        !_routeExited &&
        !_episodeCancelled &&
        _foreground &&
        !_relatedPageOpen &&
        !_verificationRequired;
    final load = widget.loadEpisode;
    final previous = _controller;
    final oldEngagement = _engagement;
    if (load == null ||
        (previous == null && !_failed) ||
        _episodeLoading ||
        _loading ||
        _retrying ||
        oldEngagement?.working == true ||
        oldEngagement?.operations.writeInFlight == true ||
        target.isCurrent(_session.watchUrl)) {
      return;
    }
    final oldSession = _session;
    final hadPlayablePrevious =
        !_failed &&
        previous?.value.isInitialized == true &&
        previous?.value.hasError != true;
    final oldState =
        selectionIntent ??
        (
          position:
              previous?.value.isInitialized == true &&
                  previous?.value.hasError != true
              ? previous!.value.position
              : _resumePosition,
          playing: automatic
              ? _resumePlaying
              : previous?.value.isPlaying ?? _preferences.autoplay,
        );
    _activeSwitchIntent = oldState;
    final sourceLabel = _session.sources.elementAtOrNull(_sourceIndex)?.label;
    _episodeReturns[oldSession.watchUrl] = oldState;
    _episodeCancelled = false;
    _episodeAbort = Completer<void>();
    _episodeRetryTarget = null;
    _episodeFailureStage = _episodeFailureType = null;
    var stage = 'save-progress';
    _showEpisodeWait = false;
    _episodeWaitTimer?.cancel();
    _episodeWaitTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted && _episodeLoading) setState(() => _showEpisodeWait = true);
    });
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    setState(() => _episodeLoading = true);
    _holdControls('episode-switch');
    oldEngagement?.hold(true);
    VideoPlayerController? candidate;
    NativeEpisodeLoad? loaded;
    Stopwatch? setupClock;
    var committed = false, previousReleased = false;
    try {
      await _persistProgress();
      if (!mounted) return;
      stage = 'pause-current';
      if (previous != null) {
        await previous.pause().timeout(const Duration(seconds: 3));
      }
      if (!canContinue()) throw StateError('Episode switch cancelled');
      // A manual choice has exactly one authoritative site-document read.
      // No detached fetch, speculative session cache or competing binding task.
      stage = 'read-foreground';
      final remaining = deadline?.difference(DateTime.now());
      _pendingResolutionUri = target.watchUrl;
      var abandonedRead = false;
      try {
        final request = load(target.watchUrl).then((value) {
          if (abandonedRead || !canContinue()) {
            value.operations?.dispose();
            throw StateError('Episode switch cancelled');
          }
          return value;
        });
        loaded = await _awaitEpisode<NativeEpisodeLoad>(
          request.timeout(
            remaining != null && remaining < const Duration(seconds: 45)
                ? remaining
                : const Duration(seconds: 45),
          ),
        );
      } on TimeoutException {
        if (_pendingResolutionUri == target.watchUrl) {
          widget.onResolutionCancelled?.call(target.watchUrl);
        }
        rethrow;
      } finally {
        abandonedRead = loaded == null;
        if (_pendingResolutionUri == target.watchUrl) {
          _pendingResolutionUri = null;
        }
      }
      if (!mounted) return;
      if (!canContinue()) {
        throw StateError('Episode switch cancelled');
      }
      stage = 'validate-identity';
      final next = loaded.session;
      if (next.watchUrl != target.watchUrl || next.sources.isEmpty) {
        throw const FormatException('Episode identity/source unavailable');
      }
      var sourceIndex = next.sources.indexWhere(
        (source) => source.label == sourceLabel,
      );
      if (sourceIndex < 0) sourceIndex = 0;
      final returned = _episodeReturns[next.watchUrl];
      final sameEpisode = _resourceLines.any(
        (line) => line.target?.watchUrl == target.watchUrl,
      );
      final shouldPlay = sameEpisode
          ? oldState.playing
          : returned?.playing ?? oldState.playing;
      stage = 'restore-target-progress';
      final position = sameEpisode
          ? oldState.position
          : returned?.position ??
                await _storedProgress(
                  next.watchUrl,
                  localResourceId: next.sources[sourceIndex].localResourceId,
                );
      if (!canContinue()) throw StateError('Episode switch cancelled');
      stage = 'release-current-media';
      previous?.removeListener(_onPlayerChanged);
      setState(() => _controller = null);
      previousReleased = previous != null;
      if (previous != null) {
        await _retireEpisodePlayer(
          previous,
        ).timeout(const Duration(seconds: 8));
      }
      await _waitForEpisodeRetirements();
      if (!mounted || _episodeCancelled) {
        throw StateError('Episode switch cancelled');
      }
      final localDeadline = DateTime.now().add(const Duration(seconds: 45));
      final mediaDeadline = deadline != null && deadline.isBefore(localDeadline)
          ? deadline
          : localDeadline;
      final sourceOrder =
          [
                sourceIndex,
                for (var n = 0; n < next.sources.length; n++)
                  if (n != sourceIndex) n,
              ]
              .where(
                (index) =>
                    !automatic ||
                    !_failedMediaUrls.contains(next.sources[index].url),
              )
              .take(3)
              .toList();
      for (final attempt in sourceOrder) {
        sourceIndex = attempt;
        setupClock = Stopwatch()..start();
        _linePlaybackAttempts[target.watchUrl] = (
          phase: _LinePlaybackPhase.preparing,
          elapsed: null,
          progressAnchor: position,
        );
        if (mounted) setState(() {});
        try {
          stage = 'create-media';
          candidate = await _createPlayer(next.sources[attempt]);
          if (!canContinue()) throw StateError('Episode switch cancelled');
          stage = 'initialize-media';
          widget.networkContext?.notePlaybackSetup(
            'episode_stage=$stage; begin',
          );
          await _awaitEpisode(
            candidate.initialize().timeout(_mediaAttemptTime(mediaDeadline)),
          );
          stage = 'configure-media';
          // A new AVPlayer already starts at zero. An unnecessary exact seek
          // can wait for more media bytes and turn a ready source into failure.
          if (position > Duration.zero && position < candidate.value.duration) {
            stage = 'resume-seek';
            widget.networkContext?.notePlaybackSetup(
              'episode_stage=$stage; begin',
            );
            await _awaitEpisode(
              candidate
                  .seekTo(position)
                  .timeout(_mediaAttemptTime(mediaDeadline)),
            );
          }
          stage = 'volume';
          widget.networkContext?.notePlaybackSetup(
            'episode_stage=$stage; begin',
          );
          await _awaitEpisode(
            candidate
                .setVolume(_muted ? 0 : 1)
                .timeout(_mediaAttemptTime(mediaDeadline)),
          );
          stage = 'speed';
          widget.networkContext?.notePlaybackSetup(
            'episode_stage=$stage; begin',
          );
          await _awaitEpisode(
            candidate
                .setPlaybackSpeed(_speed)
                .timeout(_mediaAttemptTime(mediaDeadline)),
          );
          if (!canContinue()) throw StateError('Episode switch cancelled');
          if (shouldPlay && _canResumePlayback) {
            stage = 'play';
            widget.networkContext?.notePlaybackSetup(
              'episode_stage=$stage; begin',
            );
            final timeout = _mediaAttemptTime(mediaDeadline);
            _episodeStartingPlayer = candidate;
            try {
              await _awaitEpisode(
                _startPreparedPlayer(candidate).timeout(timeout),
              );
            } finally {
              _episodeStartingPlayer = null;
            }
          }
          if (candidate.value.hasError) {
            throw StateError('Episode media failed during setup');
          }
          setupClock.stop();
          _linePlaybackAttempts[target.watchUrl] = (
            phase: _LinePlaybackPhase.ready,
            elapsed: setupClock.elapsed,
            progressAnchor: position,
          );
          break;
        } catch (error) {
          if (!_episodeCancelled) {
            _failedMediaUrls.add(next.sources[attempt].url);
          }
          if (candidate != null) {
            await _retireEpisodePlayer(
              candidate,
            ).timeout(const Duration(seconds: 8));
            candidate = null;
          }
          if (!canContinue() ||
              attempt == sourceOrder.last ||
              !DateTime.now().isBefore(mediaDeadline) ||
              (stage != 'create-media' &&
                  stage != 'initialize-media' &&
                  stage != 'play' &&
                  error is! TimeoutException)) {
            rethrow;
          }
          // A failed media URL is not a failed episode. Try only other sources
          // from this verified target; never read/commit a different identity.
        }
      }
      if (candidate == null) throw StateError('No playable target source');
      if (!canContinue()) {
        throw StateError('Episode switch cancelled');
      }
      previous?.removeListener(_onPlayerChanged);
      oldEngagement?.removeListener(_onEngagementChanged);
      oldEngagement?.dispose();
      oldEngagement?.operations.dispose();
      _loadEpoch++;
      final preparedValue = candidate.value;
      setState(() {
        _session = next;
        if (next.isSitePlaylist || oldSession.isSitePlaylist) {
          _episodeSequence = _newSequence(next);
        } else if (next.episodes.any((card) => card.isCurrent(next.watchUrl))) {
          _episodeSequence = _episodeSequence.reconciled(next.episodes);
        }
        _controller = candidate;
        _lastPlayableValue = preparedValue;
        _sourceIndex = sourceIndex;
        _failed = false;
        _loading = false;
        _commentsOpened = false;
        _commentsSelected = false;
        _descriptionExpanded = false;
        _tagsExpanded = false;
        _lastSavedSecond = -1;
        _resumePosition = position;
        _resumePlaying = !_hostPlaybackPaused && shouldPlay;
        _engagement = loaded!.operations == null
            ? null
            : (VideoEngagementController(
                operations: loaded.operations!,
                onLogin: () => _leaveSiteActions(login: true),
              )..addListener(_onEngagementChanged));
      });
      candidate.addListener(_onPlayerChanged);
      stage = 'commit-identity';
      widget.onEpisodeChanged?.call(loaded);
      committed = true;
      unawaited(_engagement?.load() ?? Future<void>.value());
      _retainObservedCreator();
    } catch (error) {
      setupClock?.stop();
      _linePlaybackAttempts[target.watchUrl] = (
        phase: _episodeCancelled
            ? _LinePlaybackPhase.cancelled
            : _LinePlaybackPhase.failed,
        elapsed: setupClock?.elapsed,
        progressAnchor: Duration.zero,
      );
      _episodeFailureStage = stage;
      _episodeFailureType = error.runtimeType.toString();
      widget.networkContext?.notePlaybackSetup(
        'episode_stage=$stage; fail; category=${omoRelayFailureCategory(error)}; elapsed_ms=${setupClock?.elapsedMilliseconds ?? 0}',
      );
      if (kDebugMode) {
        debugPrint(
          'Episode switch failed: $_episodeFailureStage ($_episodeFailureType)',
        );
        debugPrint(
          error
              .toString()
              .replaceAll(RegExp(r'https?://\S+'), '<url>')
              .split('\n')
              .first,
        );
      }
      if (mounted && !_routeExited && !committed) {
        // The hidden document may already be the failed target. Restore its
        // identity before releasing actions bound to the retained old video.
        var restoredSession = oldSession;
        if (_queuedManualLine == null &&
            (!_canAutoResourceFallback ||
                oldEngagement?.operations != null ||
                loaded?.operations != null)) {
          try {
            final restored = await load(
              oldSession.watchUrl,
            ).timeout(const Duration(seconds: 45));
            if (restored.session.watchUrl == oldSession.watchUrl &&
                restored.session.sources.isNotEmpty) {
              restoredSession = restored.session;
            }
            restored.operations?.dispose();
          } catch (_) {}
        }
        final cancelled = _episodeCancelled;
        if (_routeExited) return;
        if (previousReleased && mounted) {
          // Restore the old selection through the same single-player source
          // setup. Keep identity/progress, rather than a second live AVPlayer.
          if (candidate != null) {
            await _retireEpisodePlayer(
              candidate,
            ).timeout(const Duration(seconds: 8)).catchError((_) {});
            candidate = null;
          }
          if (mounted) {
            // The fresh document can renew signed URLs or select another CDN.
            // Reopening the disposed old player must use those fresh sources.
            setState(() => _session = restoredSession);
            _resumePosition = oldState.position;
            _resumePlaying = oldState.playing && !_episodeCancelled;
            final restoredIndex = restoredSession.sources.indexWhere(
              (source) => source.label == sourceLabel,
            );
            if (hadPlayablePrevious && _queuedManualLine == null) {
              await _loadSource(
                restoredIndex < 0 ? 0 : restoredIndex,
                forcePlay: oldState.playing && !_episodeCancelled,
                restoringEpisode: true,
              );
            } else {
              // Retain the prior identity and position while a newer choice
              // waits, or when the prior resource has already failed.
              setState(() {
                _controller = null;
                _loading = false;
                _failed = true;
              });
            }
            _episodeCancelled =
                _episodeCancelled ||
                cancelled ||
                !_foreground ||
                _verificationRequired;
          }
        } else if (mounted &&
            previous != null &&
            oldState.playing &&
            !_episodeCancelled &&
            _canResumePlayback) {
          await previous.play().catchError((_) {});
        }
        if (mounted &&
            !_episodeCancelled &&
            _controller?.value.isInitialized == true) {
          setState(() => _episodeRetryTarget = target);
        }
      }
    } finally {
      if (!committed) {
        if (candidate != null) {
          await _retireEpisodePlayer(
            candidate,
          ).timeout(const Duration(seconds: 3)).catchError((_) {});
        }
        loaded?.operations?.dispose();
      }
      _episodeAbort = null;
      _activeSwitchIntent = null;
      _episodeWaitTimer?.cancel();
      if (mounted) {
        if (identical(_engagement, oldEngagement)) oldEngagement?.hold(false);
        setState(() {
          _episodeLoading = false;
          _showEpisodeWait = false;
        });
        _releaseControls('episode-switch');
        if (!automatic) _drainManualSelection();
      }
    }
  }

  Future<VideoPlayerController> _createPlayer(
    NativePlaybackSource source,
  ) async {
    final localId = source.localResourceId;
    if (widget.offlineOnly && localId == null) {
      throw const FormatException(
        'Offline playback requires a managed resource',
      );
    }
    if (localId != null) {
      if (source.url.scheme == 'breeze-hls') {
        if (source.headers.isNotEmpty) {
          throw const FormatException('Invalid managed video source');
        }
        final lease = VideoLocalResources.acquireHlsReadLease(localId);
        VideoHlsPlaybackLease? native;
        try {
          native = await VideoHlsAssets.acquirePlayback(source.url, localId);
          final player = VideoPlayerController.file(
            File.fromUri(native.fileUrl),
            videoPlayerOptions: VideoPlayerOptions(
              allowBackgroundPlayback: true,
            ),
          );
          _localReadLeases[player] = lease;
          _hlsReadLeases[player] = native;
          return player;
        } catch (_) {
          await native?.release();
          lease.release();
          rethrow;
        }
      }
      if (!VideoLocalResources.authorizesFile(source.url, localId) ||
          source.headers.isNotEmpty) {
        throw const FormatException('Invalid managed video source');
      }
      final lease = VideoLocalResources.acquireReadLease(source.url, localId);
      try {
        final player = VideoPlayerController.file(
          File.fromUri(source.url),
          videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
        );
        _localReadLeases[player] = lease;
        return player;
      } catch (_) {
        lease.release();
        rethrow;
      }
    }
    return widget.playerFactory?.call(source) ??
        widget.networkContext?.player(source.url, source.headers) ??
        VideoPlayerController.networkUrl(
          source.url,
          httpHeaders: source.headers,
          videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
        );
  }

  Future<void> _tryAutomaticResourceLines({DateTime? deadline}) async {
    if (!_canAutoResourceFallback ||
        _autoResourceActive ||
        !_failed ||
        !_foreground ||
        _relatedPageOpen ||
        _verificationRequired ||
        _episodeLoading ||
        !mounted) {
      return;
    }
    final generation = ++_autoResourceGeneration;
    final original = _session.watchUrl;
    _autoResourceTried.add(original);
    final scheduled = {..._autoResourceTried};
    final targets = _resourceLines
        .where((line) => !line.current && line.target != null)
        .map((line) => line.target!)
        .where((target) => scheduled.add(target.watchUrl))
        .toList();
    if (targets.isEmpty) return;
    setState(() {
      _autoResourceActive = true;
      _autoResourceAttempt = 0;
      _autoResourceTotal = targets.length;
    });
    final limit = deadline ?? DateTime.now().add(const Duration(seconds: 60));
    try {
      for (final target in targets) {
        if (!mounted ||
            !_foreground ||
            generation != _autoResourceGeneration ||
            _verificationRequired ||
            !DateTime.now().isBefore(limit)) {
          break;
        }
        _autoResourceTried.add(target.watchUrl);
        setState(() {
          _autoResourceAttempt++;
          _autoResourceLabel =
              _resourceLines
                  .where((line) => line.target?.watchUrl == target.watchUrl)
                  .firstOrNull
                  ?.label ??
              '';
        });
        await _switchEpisode(target, deadline: limit, automatic: true);
        if (_session.watchUrl == target.watchUrl && !_failed) break;
      }
    } finally {
      if (mounted) {
        setState(() => _autoResourceActive = false);
        _drainManualSelection();
      }
    }
  }

  Duration _mediaAttemptTime(DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      throw TimeoutException('Media source deadline');
    }
    const attempt = Duration(seconds: 25);
    return remaining < attempt ? remaining : attempt;
  }

  Future<void> _recoverCurrentResource({DateTime? deadline}) async {
    if (!_canAutoResourceFallback ||
        _routeExited ||
        _recoveringResource ||
        _autoResourceActive ||
        _episodeLoading ||
        _loading ||
        _retrying ||
        !_foreground ||
        _relatedPageOpen ||
        !mounted) {
      return;
    }
    final watch = _session.watchUrl;
    final limit = deadline ?? DateTime.now().add(const Duration(seconds: 45));
    final abort = Completer<void>();
    _resourceRecoveryAbort = abort;
    _recoveringResource = true;
    bool current() =>
        mounted &&
        _foreground &&
        !_verificationRequired &&
        !abort.isCompleted &&
        _session.watchUrl == watch;
    try {
      while (current() && _failed && DateTime.now().isBefore(limit)) {
        final tried = <int>{
          for (var n = 0; n < _session.sources.length; n++)
            if (_failedMediaUrls.contains(_session.sources[n].url)) n,
        };
        final alternative = [
          for (var n = 0; n < _session.sources.length; n++)
            if (!tried.contains(n)) n,
        ].firstOrNull;
        if (alternative != null) {
          final media = _session.sources[alternative].url;
          await _loadSource(
            alternative,
            forcePlay: _resumePlaying,
            attempted: tried,
            mediaDeadline: limit,
          );
          // A failed teardown can stop setup before any source is attempted.
          if (_failed && !_failedMediaUrls.contains(media)) break;
          continue;
        }
        final recover = widget.recoverCurrentResource;
        if (recover == null || !_rawRecoveriesTried.add(watch)) break;
        final remaining = limit.difference(DateTime.now());
        if (remaining <= Duration.zero) break;
        setState(() => _rawRecoveryPending = true);
        _pendingResolutionUri = watch;
        NativePlaybackSession? renewed;
        try {
          renewed =
              await Future.any([
                recover(_session),
                abort.future.then<NativePlaybackSession?>(
                  (_) => throw StateError('Resource recovery cancelled'),
                ),
              ]).timeout(
                remaining < const Duration(seconds: 10)
                    ? remaining
                    : const Duration(seconds: 10),
              );
        } catch (_) {
          // Normal retry and website playback remain available. A failed
          // discovery must not restart the ordinary first-play parser.
          if (_pendingResolutionUri == watch) {
            widget.onResolutionCancelled?.call(watch);
          }
        } finally {
          if (_pendingResolutionUri == watch) _pendingResolutionUri = null;
          if (mounted) setState(() => _rawRecoveryPending = false);
        }
        if (!current() || renewed?.watchUrl != watch) break;
        final seen = {for (final source in _session.sources) source.url};
        final additions = renewed!.sources
            .where(
              (source) =>
                  source.url.scheme == 'https' &&
                  source.url.host.isNotEmpty &&
                  source.url.userInfo.isEmpty &&
                  !_failedMediaUrls.contains(source.url) &&
                  seen.add(source.url),
            )
            .toList();
        if (additions.isEmpty) break;
        setState(
          () => _session = _session.withSources([
            ..._session.sources,
            ...additions,
          ]),
        );
      }
    } finally {
      _recoveringResource = false;
      if (identical(_resourceRecoveryAbort, abort)) {
        _resourceRecoveryAbort = null;
      }
      if (mounted) {
        setState(() => _rawRecoveryPending = false);
        _drainManualSelection();
      }
    }
    if (current() && _failed && DateTime.now().isBefore(limit)) {
      await _tryAutomaticResourceLines(deadline: limit);
    }
  }

  Future<void> _loadSource(
    int index, {
    bool forcePlay = false,
    Set<int> attempted = const {},
    DateTime? mediaDeadline,
    bool restoringEpisode = false,
  }) async {
    if (!mounted || _routeExited) return;
    _clearActionNotice();
    if (!restoringEpisode) {
      if (_episodeLoading) _episodeCancelled = true;
      _cancelEpisodeRead(discardQueued: false, cancelRecovery: false);
    }
    _stallWatchdog?.cancel();
    _stallWatchdog = null;
    if (widget.siteVerification?.value == true) {
      _onSiteVerification();
      return;
    }
    _verificationRequired = false;
    if (index < 0 || index >= _session.sources.length) {
      setState(() {
        _loading = false;
        _quickSection = null;
        _controlInteractions.remove('quick-settings');
        _failed = true;
        _controlsVisible = true;
      });
      return;
    }
    final epoch = ++_loadEpoch;
    final previous = _controller;
    final resumeAt =
        previous?.value.isInitialized == true &&
            previous?.value.hasError != true
        ? previous!.value.position
        : _resumePosition;
    final shouldPlay =
        !_hostPlaybackPaused &&
        (forcePlay ||
            (previous == null ? _resumePlaying : previous.value.isPlaying));
    _resumePosition = resumeAt;
    _resumePlaying = shouldPlay;
    _controller = null;
    setState(() {
      _sourceIndex = index;
      _loading = true;
      _failed = false;
      _dragPosition = null;
      _holdingFastForward = false;
    });
    if (previous != null) {
      try {
        previous.removeListener(_onPlayerChanged);
        await _retireEpisodePlayer(
          previous,
        ).timeout(const Duration(seconds: 5));
      } catch (_) {
        // A stalled platform player must not trap the retry button forever.
      }
    }
    if (!mounted || epoch != _loadEpoch) return;

    try {
      await _waitForEpisodeRetirements();
    } catch (_) {
      if (mounted && epoch == _loadEpoch) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
      return;
    }
    if (!mounted || epoch != _loadEpoch) return;
    final deadline =
        mediaDeadline ?? DateTime.now().add(const Duration(seconds: 45));
    final source = _session.sources[index];
    final watch = _session.watchUrl;
    final setupClock = Stopwatch()..start();
    _cancelMediaPreparation();
    final mediaAbort = Completer<void>();
    _mediaAbort = mediaAbort;
    _linePlaybackAttempts[watch] = (
      phase: _LinePlaybackPhase.preparing,
      elapsed: null,
      progressAnchor: resumeAt,
    );
    VideoPlayerController? created;
    var initializing = true;
    var setupStage = 'create';
    void setupPhase(String stage) {
      setupStage = stage;
      widget.networkContext?.notePlaybackSetup(
        'stage=$stage; begin; elapsed_ms=${setupClock.elapsedMilliseconds}',
      );
    }

    bool isCurrent() => mounted && epoch == _loadEpoch;
    Future<void> prepare(VideoPlayerController controller) async {
      setupPhase('initialize');
      await controller.initialize();
      initializing = false;
      if (!isCurrent()) return;
      controller.addListener(_onPlayerChanged);
      if (resumeAt > Duration.zero) {
        final duration = controller.value.duration;
        final target =
            duration > const Duration(seconds: 5) &&
                widget.initialPlaybackState == null &&
                resumeAt >= duration - const Duration(seconds: 5)
            ? Duration.zero
            : resumeAt < duration
            ? resumeAt
            : Duration.zero;
        if (target > Duration.zero) {
          setupPhase('resume_seek');
          await controller.seekTo(target);
        }
      }
      if (!isCurrent()) return;
      setupPhase('volume');
      await controller.setVolume(_muted ? 0 : 1);
      setupPhase('speed');
      await controller.setPlaybackSpeed(_speed);
      if (!isCurrent()) return;
      if (shouldPlay && _canResumePlayback) {
        setupPhase('play');
        await _startPreparedPlayer(controller);
      }
      widget.networkContext?.notePlaybackSetup(
        'stage=ready; elapsed_ms=${setupClock.elapsedMilliseconds}',
      );
    }

    try {
      final controller = await _createPlayer(source);
      created = controller;
      if (!isCurrent()) {
        await _retireEpisodePlayer(controller);
        return;
      }
      _controller = controller;
      // Bound the complete setup, including resume seeking and native play,
      // rather than timing only metadata initialization.
      await Future.any([
        prepare(controller),
        mediaAbort.future.then<void>(
          (_) => throw StateError('Media setup cancelled'),
        ),
      ]).timeout(_mediaAttemptTime(deadline));
      if (!isCurrent()) return;
      setupClock.stop();
      _linePlaybackAttempts[watch] = (
        phase: _LinePlaybackPhase.ready,
        elapsed: setupClock.elapsed,
        progressAnchor: resumeAt,
      );
      if (controller.value.isInitialized && !controller.value.hasError) {
        _lastPlayableValue = controller.value;
      }
      setState(() => _loading = false);
      _scheduleControlsHide();
      widget.onMediaPrepared?.call();
    } catch (error) {
      if (!isCurrent()) return;
      setupClock.stop();
      final value = created?.value;
      widget.networkContext?.notePlaybackSetup(
        'stage=$setupStage; fail; category=${omoRelayFailureCategory(error)}; '
        'initialized=${value?.isInitialized ?? false}; buffering=${value?.isBuffering ?? false}; '
        'playing=${value?.isPlaying ?? false}; elapsed_ms=${setupClock.elapsedMilliseconds}',
      );
      _failedMediaUrls.add(source.url);
      _linePlaybackAttempts[watch] = (
        phase: _LinePlaybackPhase.failed,
        elapsed: setupClock.elapsed,
        progressAnchor: resumeAt,
      );
      final failedEpoch = ++_loadEpoch;
      _controller = null;
      final controller = created;
      if (controller != null) {
        controller.removeListener(_onPlayerChanged);
        await _retireEpisodePlayer(
          controller,
        ).timeout(const Duration(seconds: 5)).catchError((_) {});
      }
      if (!mounted || failedEpoch != _loadEpoch) return;
      final tried = {...attempted, index};
      final alternative = [
        for (var n = 0; n < _session.sources.length; n++)
          if (!tried.contains(n)) n,
      ].firstOrNull;
      if (alternative != null &&
          (initializing || error is TimeoutException) &&
          tried.length < 3 &&
          _foreground &&
          !_verificationRequired &&
          DateTime.now().isBefore(deadline)) {
        await _loadSource(
          alternative,
          forcePlay: shouldPlay,
          attempted: tried,
          mediaDeadline: deadline,
          restoringEpisode: restoringEpisode,
        );
        return;
      }
      _recordPlaybackError(
        'stage=$setupStage; category=${omoRelayFailureCategory(error)}; elapsed_ms=${setupClock.elapsedMilliseconds}',
      );
      setState(() {
        _loading = false;
        _quickSection = null;
        _controlInteractions.remove('quick-settings');
        _failed = true;
        _controlsVisible = true;
        _locked = false;
      });
      if (!_recoveringResource) {
        unawaited(_recoverCurrentResource(deadline: deadline));
      }
    } finally {
      if (identical(_mediaAbort, mediaAbort)) _mediaAbort = null;
    }
  }

  Future<void> _retryPlayback({int? nextSource}) async {
    if (_retrying || _loading || _episodeLoading || !_foreground || !mounted) {
      return;
    }
    _hostPlaybackPaused = false;
    _retrying = true;
    final abort = _retryAbort = Completer<void>();
    final retryWatch = _session.watchUrl;
    bool current() =>
        mounted &&
        !_routeExited &&
        _foreground &&
        !abort.isCompleted &&
        _session.watchUrl == retryWatch;
    final retryDeadline = DateTime.now().add(const Duration(seconds: 45));
    _autoResourceTried.clear();
    _failedMediaUrls.clear();
    _rawRecoveriesTried.clear();
    try {
      if (nextSource != null) {
        _retryAbort = null;
        await _loadSource(nextSource, forcePlay: true);
        return;
      }
      final refresh = widget.offlineOnly ? null : widget.refreshSession;
      if (refresh != null) {
        setState(() {
          _loading = true;
          _failed = false;
          _verificationRequired = false;
          _controlsVisible = true;
        });
        try {
          _pendingResolutionUri = retryWatch;
          final session = await Future.any<NativePlaybackSession?>([
            refresh().timeout(const Duration(seconds: 25)),
            abort.future.then<NativePlaybackSession?>((_) => null),
          ]);
          if (_pendingResolutionUri == retryWatch) _pendingResolutionUri = null;
          if (session == null || !current()) return;
          if (session.watchUrl != retryWatch) {
            throw const FormatException('Playback identity changed');
          }
          // Loading the accepted session cancels other resolution owners.
          _retryAbort = null;
          setState(
            () => _session = NativePlaybackSession(
              title: session.title,
              watchUrl: session.watchUrl,
              sources: session.sources,
              description: session.description.isEmpty
                  ? _session.description
                  : session.description,
              tags: session.tags.isEmpty ? _session.tags : session.tags,
              coverUrl: _session.coverUrl,
              episodes: _session.episodes,
              sitePlaylist: _session.sitePlaylist,
              related: _session.related,
              creator: _session.creator,
              uploader: _session.uploader,
              creatorName: _session.creatorName,
              creatorUrl: _session.creatorUrl,
              tagTargets: _session.tagTargets,
              metadata: session.metadata.isEmpty
                  ? _session.metadata
                  : session.metadata,
            ),
          );
          await _loadSource(_preferredSourceIndex(), forcePlay: true);
          return;
        } on VideoSiteVerificationRequired {
          if (current()) {
            try {
              await _controller?.pause().timeout(const Duration(seconds: 2));
            } catch (_) {
              // A failed platform player must not prevent human verification.
            }
            if (!current()) return;
            setState(() {
              _loading = false;
              _quickSection = null;
              _controlInteractions.remove('quick-settings');
              _failed = true;
              _verificationRequired = true;
            });
          }
          return;
        } catch (_) {
          if (_pendingResolutionUri == retryWatch) {
            _pendingResolutionUri = null;
            widget.onResolutionCancelled?.call(retryWatch);
          }
        }
      }
      if (current()) {
        _retryAbort = null;
        await _loadSource(_sourceIndex, forcePlay: true);
      }
    } finally {
      if (identical(_retryAbort, abort)) _retryAbort = null;
      if (_pendingResolutionUri == retryWatch) _pendingResolutionUri = null;
      if (mounted && !_routeExited && abort.isCompleted && _loading) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
      _retrying = false;
      if (mounted) _drainManualSelection();
      if (mounted && _failed) {
        unawaited(_recoverCurrentResource(deadline: retryDeadline));
      }
    }
  }

  void _onPlayerChanged() {
    if (!mounted) return;
    if (!_canResumePlayback && _controller?.value.isPlaying == true) {
      unawaited(
        _controller
            ?.pause()
            .timeout(const Duration(seconds: 2))
            .catchError((_) {}),
      );
      return;
    }
    if (_routeExited) return;
    if (_controller?.value.hasError == true && !_failed) {
      // Platform errors may replace the value with an uninitialized value
      // at 00:00. Keep the last good position captured before that error.
      _recordPlaybackError(_controller?.value.errorDescription ?? 'platform');
      _hideTimer?.cancel();
      setState(() {
        _quickSection = null;
        _controlInteractions.remove('quick-settings');
        _failed = true;
        _loading = false;
        _controlsVisible = true;
        _locked = false;
        _holdingFastForward = false;
      });
      _markCurrentLineFailed();
      unawaited(_recoverCurrentResource());
      return;
    }
    final value = _controller?.value;
    var lineStateChanged = false;
    if (_canAutoResourceFallback &&
        value?.isBuffering == true &&
        _resumePlaying &&
        !_loading &&
        !_episodeLoading &&
        !_failed &&
        _foreground) {
      final player = _controller;
      final position = value!.position;
      // Buffering flags can remain true while buffered media still advances.
      // Only a full interval without movement and with playback intent is a
      // stall. A deliberate pause is never a reason to change resources.
      if (_stallWatchdog == null || _stallPosition != position) {
        _stallWatchdog?.cancel();
        _stallPosition = position;
        _stallWatchdog = Timer(const Duration(seconds: 20), () {
          _stallWatchdog = null;
          if (!mounted ||
              !identical(player, _controller) ||
              !_foreground ||
              !_resumePlaying ||
              _relatedPageOpen ||
              _episodeLoading ||
              _loading ||
              _failed ||
              _controller?.value.position != position ||
              _controller?.value.isBuffering != true) {
            return;
          }
          setState(() {
            _failed = true;
            _loading = false;
            _controlsVisible = true;
          });
          _markCurrentLineFailed();
          _recordPlaybackError('buffering_timeout');
          unawaited(_recoverCurrentResource());
        });
      }
    } else {
      _stallWatchdog?.cancel();
      _stallWatchdog = null;
      _stallPosition = null;
    }
    if (value?.isPlaying != true || value?.isBuffering == true) {
      _hideTimer?.cancel();
      _controlsVisible = true;
    }
    if (value != null && value.isInitialized && !value.hasError && !_loading) {
      _lastPlayableValue = value;
      final attempt = _linePlaybackAttempts[_session.watchUrl];
      if (value.isPlaying &&
          !value.isBuffering &&
          attempt != null &&
          attempt.phase == _LinePlaybackPhase.ready &&
          value.position >
              attempt.progressAnchor + const Duration(milliseconds: 200)) {
        _linePlaybackAttempts[_session.watchUrl] = (
          phase: _LinePlaybackPhase.playing,
          elapsed: attempt.elapsed,
          progressAnchor: attempt.progressAnchor,
        );
        lineStateChanged = true;
      }
      _resumePosition = value.position;
      if (!value.isBuffering)
        _resumePlaying = !_hostPlaybackPaused && value.isPlaying;
      final second = value.position.inSeconds;
      if (second >= 5 && second ~/ 5 != _lastSavedSecond ~/ 5) {
        _lastSavedSecond = second;
        unawaited(_persistProgress());
      }
    }
    final now = DateTime.now();
    final stateChanged =
        value?.isPlaying != _lastPlaying ||
        value?.isBuffering != _lastBuffering;
    if (!stateChanged &&
        !lineStateChanged &&
        now.difference(_lastUiTick) < const Duration(milliseconds: 250)) {
      return;
    }
    _lastUiTick = now;
    _lastPlaying = value?.isPlaying;
    _lastBuffering = value?.isBuffering;
    if (stateChanged &&
        value?.isPlaying == true &&
        value?.isBuffering != true) {
      _scheduleControlsHide();
    }
    setState(() {});
  }

  void _toggleControls() {
    if (!mounted ||
        _failed ||
        _locked ||
        MediaQuery.accessibleNavigationOf(context))
      return;
    _controlsTapEpoch++;
    _hideTimer?.cancel();
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _scheduleControlsHide();
  }

  void _showControls() {
    if (!mounted) return;
    _hideTimer?.cancel();
    setState(() => _controlsVisible = true);
    _scheduleControlsHide();
  }

  void _holdControls(String interaction) {
    _controlInteractions.add(interaction);
    _controlHoldEpochs[interaction] = _controlsTapEpoch;
    _hideTimer?.cancel();
    if (mounted) setState(() => _controlsVisible = true);
  }

  void _releaseControls(String interaction) {
    // A recognizer can cancel before its drag ever starts. Such a cancellation
    // must not reveal controls ahead of the pending single-tap callback, which
    // would then toggle those freshly revealed controls off again.
    if (!_controlInteractions.remove(interaction)) return;
    final heldAt = _controlHoldEpochs.remove(interaction);
    if (!mounted) return;
    if (heldAt != null && heldAt != _controlsTapEpoch) {
      _scheduleControlsHide();
    } else {
      _showControls();
    }
  }

  bool get _canHideControls =>
      _foreground &&
      !MediaQuery.accessibleNavigationOf(context) &&
      !_failed &&
      _controller?.value.isPlaying == true &&
      _controller?.value.isBuffering != true &&
      _dragPosition == null &&
      !_holdingFastForward &&
      _controlInteractions.isEmpty;

  void _scheduleControlsHide() {
    _hideTimer?.cancel();
    if (!_canHideControls) return;
    _hideTimer = Timer(Duration(seconds: _preferences.hideSeconds), () {
      if (mounted && _canHideControls) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  Future<bool> _runPlayerCommand(
    VideoPlayerController controller,
    Future<void> Function() command, {
    bool fatal = true,
  }) async {
    try {
      await command().timeout(const Duration(seconds: 5));
      return mounted && identical(controller, _controller);
    } catch (_) {
      if (!mounted || !identical(controller, _controller)) return false;
      _hideTimer?.cancel();
      if (fatal) {
        setState(() {
          _quickSection = null;
          _controlInteractions.remove('quick-settings');
          _failed = true;
          _loading = false;
          _controlsVisible = true;
          _locked = false;
          _holdingFastForward = false;
          _dragPosition = null;
        });
        unawaited(
          controller
              .pause()
              .timeout(const Duration(seconds: 2))
              .catchError((_) {}),
        );
      } else {
        _showControls();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(t.videoPlayback.actionFailed)));
      }
      return false;
    }
  }

  Future<void> _seekTo(Duration position) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    await _runPlayerCommand(controller, () => controller.seekTo(position));
  }

  Future<void> _togglePlay() async {
    if (!_foreground || _verificationRequired) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final value = controller.value;
    if (value.isPlaying) {
      if (!await _runPlayerCommand(controller, controller.pause)) return;
      _resumePlaying = false;
      unawaited(_persistProgress());
    } else {
      if (value.duration > Duration.zero && value.position >= value.duration) {
        if (!await _runPlayerCommand(
          controller,
          () => controller.seekTo(Duration.zero),
        )) {
          return;
        }
      }
      if (!_foreground || _verificationRequired) return;
      _hostPlaybackPaused = false;
      if (!await _runPlayerCommand(controller, controller.play)) return;
      _resumePlaying = !_hostPlaybackPaused;
    }
    _showControls();
  }

  Future<void> _seekBy(int seconds) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final value = controller.value;
    final target = value.position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : target > value.duration
        ? value.duration
        : target;
    if (!await _runPlayerCommand(
      controller,
      () => controller.seekTo(clamped),
    )) {
      return;
    }
    _feedbackTimer?.cancel();
    setState(() {
      _seekFeedback = seconds < 0 ? '−10s' : '+10s';
      _seekFeedbackAlignment = seconds < 0
          ? Alignment.centerLeft
          : Alignment.centerRight;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 850), () {
      if (mounted) setState(() => _seekFeedback = null);
    });
    _showControls();
  }

  Future<void> _setFastForward(bool enabled) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_holdingFastForward == enabled) return;
    _hideTimer?.cancel();
    setState(() => _holdingFastForward = enabled);
    try {
      await controller
          .setPlaybackSpeed(enabled ? _preferences.holdSpeed : _speed)
          .timeout(const Duration(seconds: 5));
      if (enabled &&
          mounted &&
          _controller == controller &&
          controller.value.isPlaying &&
          _holdingFastForward) {
        unawaited(HapticFeedback.lightImpact());
      } else if (!enabled && mounted) {
        _showControls();
      }
    } catch (_) {
      if (mounted &&
          _controller == controller &&
          enabled &&
          _holdingFastForward) {
        setState(() => _holdingFastForward = false);
      }
    }
  }

  Future<void> _setSpeed(double speed) async {
    final controller = _controller;
    if (controller == null) return;
    if (!_holdingFastForward &&
        !await _runPlayerCommand(
          controller,
          () => controller.setPlaybackSpeed(speed),
          fatal: false,
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _speed = speed);
    _showControls();
  }

  Future<void> _toggleMute() async {
    final muted = !_muted;
    final controller = _controller;
    if (controller == null ||
        !await _runPlayerCommand(
          controller,
          () => controller.setVolume(muted ? 0 : 1),
          fatal: false,
        )) {
      return;
    }
    if (mounted) setState(() => _muted = muted);
    _showControls();
  }

  Future<void> _setFullscreen(bool enabled, {bool? portrait}) async {
    final nextPortrait =
        portrait ?? _preferences.fullscreenOrientation == 'portrait';
    if (_changingFullscreen) {
      _pendingFullscreen = (enabled, portrait);
      return;
    }
    if ((_fullscreen == enabled &&
        (!enabled || _portraitFullscreen == nextPortrait))) {
      return;
    }
    final wasFullscreen = _fullscreen;
    final wasPortrait = _portraitFullscreen;
    final wasLocked = _locked;
    _changingFullscreen = true;
    _swiping = false;
    _dragPosition = null;
    unawaited(_setFastForward(false));
    try {
      if (enabled) {
        if (mounted) {
          setState(() {
            _fullscreen = true;
            _portraitFullscreen = nextPortrait;
          });
        }
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.immersiveSticky,
        ).timeout(const Duration(seconds: 5));
        if (_isPhone) {
          // Portrait fullscreen is an explicit orientation lock, independent
          // of the device's physical tilt (for example while lying down).
          await SystemChrome.setPreferredOrientations(
            nextPortrait
                ? const [DeviceOrientation.portraitUp]
                : const [
                    DeviceOrientation.landscapeLeft,
                    DeviceOrientation.landscapeRight,
                  ],
          ).timeout(const Duration(seconds: 5));
        }
      } else {
        _locked = false;
        if (_isPhone) {
          await SystemChrome.setPreferredOrientations(const [
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]).timeout(const Duration(seconds: 5));
        }
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
        ).timeout(const Duration(seconds: 5));
        if (mounted) setState(() => _fullscreen = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _fullscreen = wasFullscreen;
        _portraitFullscreen = wasPortrait;
        _locked = wasLocked;
      });
      // System UI and orientation are separate operations. Failure of one
      // must not prevent attempting to restore the other, or strand controls.
      final restore = <Future<void> Function()>[
        () => SystemChrome.setEnabledSystemUIMode(
          wasFullscreen
              ? SystemUiMode.immersiveSticky
              : SystemUiMode.edgeToEdge,
        ),
        if (_isPhone)
          () => SystemChrome.setPreferredOrientations(
            wasFullscreen
                ? wasPortrait
                      ? const [DeviceOrientation.portraitUp]
                      : const [
                          DeviceOrientation.landscapeLeft,
                          DeviceOrientation.landscapeRight,
                        ]
                : const [
                    DeviceOrientation.portraitUp,
                    DeviceOrientation.portraitDown,
                  ],
          ),
      ];
      for (final operation in restore) {
        if (!mounted) break;
        try {
          await operation().timeout(const Duration(seconds: 2));
        } catch (_) {
          // The platform may still be unavailable; keep an explicit retry.
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(t.videoPlayback.actionFailed)));
      }
    } finally {
      _changingFullscreen = false;
      final pending = _pendingFullscreen;
      _pendingFullscreen = null;
      if (mounted && pending != null) {
        unawaited(_setFullscreen(pending.$1, portrait: pending.$2));
      }
      _showControls();
    }
  }

  void _beginSwipe() {
    if (_controller?.value.isInitialized != true) return;
    _hideTimer?.cancel();
    _swiping = true;
    _swipeOrigin = _controller!.value.position;
    _swipeDistance = 0;
    setState(() => _dragPosition = _swipeOrigin);
  }

  void _updateSwipe(double delta) {
    if (!_swiping) return;
    if (_dragPosition == null || _controller == null) return;
    _swipeDistance += delta;
    final duration = _controller!.value.duration;
    final range = duration.inMilliseconds.clamp(0, 120000);
    final target =
        _swipeOrigin.inMilliseconds +
        (_swipeDistance / _tapAreaWidth * range).round();
    setState(
      () => _dragPosition = Duration(
        milliseconds: target.clamp(0, duration.inMilliseconds),
      ),
    );
  }

  void _endSwipe({bool cancelled = false}) {
    // A tap also cancels Flutter's drag recognizer. It must not reveal the
    // controls before the pending single-tap callback toggles them again.
    if (!_swiping) return;
    _swiping = false;
    final target = _dragPosition;
    setState(() => _dragPosition = null);
    if (!cancelled && target != null) unawaited(_seekTo(target));
    _showControls();
  }

  void _toggleLock() {
    unawaited(_setFastForward(false));
    setState(() {
      _locked = !_locked;
      _dragPosition = null;
    });
    _showControls();
  }

  Future<void> _backToWeb() async {
    if (_leavingToSite) return;
    _leavingToSite = true;
    if (_fullscreen) await _setFullscreen(false);
    if (!mounted) return;
    if (widget.onOpenWebsite case final open?) {
      try {
        await _controller
            ?.pause()
            .timeout(const Duration(seconds: 2))
            .catchError((_) {});
        if (mounted) await open();
      } finally {
        _leavingToSite = false;
      }
      return;
    }
    Navigator.of(context).pop(true);
  }

  void _exitSourceFromPlayer() {
    if (_leavingToSite) return;
    _leavingToSite = true;
    _closeQuickSettings();
    // The quick panel belongs to this route. Close its state rather than
    // popping a route, then let normal player disposal restore system chrome.
    exitSourceToDiscover(context);
  }

  void _leaveSiteActions({bool login = false}) {
    final route = ModalRoute.of(context);
    if (route != null) {
      Navigator.of(context).popUntil((candidate) => candidate == route);
    }
    if (login && widget.onOpenAccount != null) {
      widget.onOpenAccount!();
    } else {
      unawaited(_backToWeb());
    }
  }

  Future<void> _verifySite() async {
    if (_leavingToSite) return;
    _leavingToSite = true;
    if (_fullscreen) await _setFullscreen(false);
    if (mounted) widget.onVerifySite?.call(_resumePosition);
  }

  String _time(Duration value) {
    final total = value.inSeconds;
    final minutes = ((total ~/ 60) % 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    if (total >= 3600) {
      return '${(total ~/ 3600).toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _downloadPlaybackOwner.release();
    _episodeWaitTimer?.cancel();
    // The owning detail page invalidates its requests when it disposes. Do
    // not synchronously ask a parent to rebuild during child-tree teardown.
    _cancelEpisodeRead(notifyResolution: false);
    _cancelMediaPreparation();
    widget.siteVerification?.removeListener(_onSiteVerification);
    VideoPlaybackPreferences.changes.removeListener(_onPreferencesChanged);
    SourceDiagnosticPreferences.changes.removeListener(_readAnalysisPreference);
    _analysisEpoch++;
    _preferenceReadEpoch++;
    _engagement?.removeListener(_onEngagementChanged);
    _engagement?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _stallWatchdog?.cancel();
    _hideTimer?.cancel();
    _feedbackTimer?.cancel();
    _actionNoticeTimer?.cancel();
    _loadEpoch++;
    unawaited(_persistProgress());
    final controller = _controller;
    if (controller != null) {
      unawaited(_retireEpisodePlayer(controller).catchError((_) {}));
    }
    if (_fullscreen) {
      unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
      if (_isPhone) {
        unawaited(
          SystemChrome.setPreferredOrientations(const [
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]),
        );
      }
    }
    super.dispose();
  }

  void _backFromPlayer() {
    if (_fullscreen) {
      unawaited(_setFullscreen(false));
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _finishPlaybackOnPop() {
    if (_routeExited) return;
    final player = _controller;
    final value = player?.value;
    final ready = value?.isInitialized == true && !value!.hasError;
    final position = ready ? value.position : _resumePosition;
    final playing =
        !_hostPlaybackPaused && (ready ? value.isPlaying : _resumePlaying);
    // A successor can read the history before this route's exit animation
    // disposes the player. Queue the final snapshot at the committed pop.
    if (ready && !_loading) _lastPlayableValue = value;
    unawaited(_persistProgress());
    _routeExited = true;
    _hostPlaybackPaused = true;
    _resumePlaying = false;
    _loadEpoch++;
    _stallWatchdog?.cancel();
    _hideTimer?.cancel();
    if (player != null) {
      unawaited(
        player.pause().timeout(const Duration(seconds: 2)).catchError((_) {}),
      );
    }
    _cancelEpisodeRead(notifyResolution: false);
    _cancelMediaPreparation();
    widget.onPlaybackExit?.call((position: position, playing: playing));
  }

  Widget _siteControl(
    VideoSiteAction action, {
    bool rail = false,
    bool subtle = false,
  }) {
    final engagement = _engagement!;
    final like = action == VideoSiteAction.like;
    final selected = like
        ? engagement.state.liked == true
        : engagement.state.disliked == true;
    final count = like
        ? engagement.state.positiveVotes ?? _session.metadata.positiveVotes
        : engagement.state.negativeVotes ?? _session.metadata.negativeVotes;
    final label = like ? t.videoCommunity.like : t.videoCommunity.dislike;
    return _countedControl(
      caption: count?.toString() ?? label,
      label: label,
      selected: selected,
      rail: rail,
      subtle: subtle,
      button: NativeVideoIconButton(
        bare: subtle,
        iconSize: subtle ? 20 : VideoControlMetrics.glyphExtent,
        tooltip: label,
        symbol: like
            ? (selected ? 'hand.thumbsup.fill' : 'hand.thumbsup')
            : (selected ? 'hand.thumbsdown.fill' : 'hand.thumbsdown'),
        icon: like
            ? (selected ? Icons.thumb_up : Icons.thumb_up_outlined)
            : (selected ? Icons.thumb_down : Icons.thumb_down_outlined),
        onPressed: engagement.working || engagement.unconfirmedAction != null
            ? null
            : () => unawaited(_setSiteAction(action, !selected)),
      ),
    );
  }

  Widget _countedControl({
    required String caption,
    required String label,
    required Widget button,
    bool selected = false,
    bool rail = false,
    bool subtle = false,
  }) => Semantics(
    selected: selected,
    label: label,
    value: caption == label ? null : caption,
    child: SizedBox(
      width: rail ? 64 : 52,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          button,
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : subtle
                  ? Colors.white70
                  : Colors.white,
            ),
          ),
          if (rail) const SizedBox(height: 8),
        ],
      ),
    ),
  );

  List<Widget> _fullscreenActions({bool rail = false, bool subtle = false}) {
    if (_engagement == null) {
      final download = _downloadAdapter(_session);
      return [
        if (download != null || widget.onDownloadEpisodes != null)
          NativeVideoIconButton(
            key: const ValueKey('video-resolved-download'),
            light: true,
            tooltip:
                widget.onDownloadEpisodes == null && download!.choices.isEmpty
                ? t.videoDownload.unsupportedMedia
                : t.videoDownload.title,
            symbol: 'arrow.down.to.line',
            icon: Icons.download_outlined,
            onPressed:
                _downloadOpen ||
                    (widget.onDownloadEpisodes == null &&
                        download!.choices.isEmpty)
                ? null
                : () => unawaited(_downloadVideo()),
          ),
        ...?widget.extraPlayerActions?.call(
          context,
          _session,
          _showRelatedPage,
          _showAuxiliaryOverlay,
        ),
      ];
    }
    return [
      _siteControl(VideoSiteAction.like, rail: rail, subtle: subtle),
      if (rail) _siteControl(VideoSiteAction.dislike, rail: true),
      _countedControl(
        subtle: subtle,
        rail: rail,
        label: t.videoCommunity.favorite,
        caption: t.videoCommunity.favorite,
        selected: _engagement!.favorite == true,
        button: NativeVideoIconButton(
          bare: subtle,
          iconSize: subtle ? 20 : VideoControlMetrics.glyphExtent,
          tooltip: t.videoCommunity.favorite,
          symbol: _engagement!.favorite == true ? 'star.fill' : 'star',
          icon: _engagement!.favorite == true
              ? Icons.star_rounded
              : Icons.star_outline_rounded,
          onPressed: _engagement!.working
              ? null
              : () => unawaited(_favoriteVideo()),
        ),
      ),
      if (!rail)
        _countedControl(
          subtle: subtle,
          label: t.videoDownload.title,
          caption: t.videoDownload.title,
          button: NativeVideoIconButton(
            bare: subtle,
            iconSize: subtle ? 20 : VideoControlMetrics.glyphExtent,
            tooltip: t.videoDownload.title,
            symbol: 'arrow.down.to.line',
            icon: Icons.download_outlined,
            onPressed: _engagement!.held
                ? null
                : () => unawaited(_downloadVideo()),
          ),
        ),
      Builder(
        builder: (anchor) => _countedControl(
          subtle: subtle,
          rail: rail,
          label: t.videoCommunity.share,
          caption: t.videoCommunity.share,
          button: NativeVideoIconButton(
            bare: subtle,
            iconSize: subtle ? 20 : VideoControlMetrics.glyphExtent,
            tooltip: t.videoCommunity.share,
            symbol: 'arrowshape.turn.up.right',
            icon: Icons.reply_rounded,
            mirrorFallbackIcon: true,
            onPressed: _engagement!.held
                ? null
                : () {
                    final box = anchor.findRenderObject() as RenderBox?;
                    if (box != null && box.hasSize) {
                      unawaited(
                        _shareVideo(box.localToGlobal(Offset.zero) & box.size),
                      );
                    }
                  },
          ),
        ),
      ),
    ];
  }

  double _timeLabelWidth(String text, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width + 4;
    painter.dispose();
    return width;
  }

  Widget _controlLayout({
    required bool ready,
    required bool ended,
    required bool playing,
    required Duration position,
    required Duration duration,
    required bool wide,
  }) {
    final rich = wide && MediaQuery.textScalerOf(context).scale(14) <= 22;
    final portrait =
        _fullscreen &&
        _portraitFullscreen &&
        MediaQuery.sizeOf(context).height >= 500;
    final timeStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Colors.white,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final timeText =
        '${ready ? _time(position) : '--:--'} / ${ready && duration > Duration.zero ? _time(duration) : '--:--'}';
    final systemTimeline =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        _usesSystemControls;
    final dragging = _dragPosition != null;
    Widget time() => Text(
      timeText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: timeStyle,
    );
    Widget timeline({bool centered = false}) => SizedBox(
      height: 44,
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: systemTimeline ? 3 : 2,
          trackShape: centered
              ? const RoundedRectSliderTrackShape()
              : const VideoTimelineTrackShape(),
          thumbShape: systemTimeline
              ? RoundSliderThumbShape(
                  enabledThumbRadius: dragging ? 7 : 5,
                  elevation: 0,
                  pressedElevation: 0,
                )
              : const RoundSliderThumbShape(enabledThumbRadius: 4),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        ),
        child: Slider(
          semanticFormatterCallback: (v) =>
              _time(Duration(milliseconds: v.round())),
          min: 0,
          max: duration.inMilliseconds > 0
              ? duration.inMilliseconds.toDouble()
              : 1,
          value: position.inMilliseconds.toDouble().clamp(
            0,
            duration.inMilliseconds > 0
                ? duration.inMilliseconds.toDouble()
                : 1,
          ),
          secondaryTrackValue:
              (_controller?.value.buffered.lastOrNull?.end.inMilliseconds ?? 0)
                  .toDouble()
                  .clamp(
                    0,
                    duration.inMilliseconds > 0
                        ? duration.inMilliseconds.toDouble()
                        : 1,
                  ),
          activeColor: systemTimeline
              ? Colors.white.withValues(alpha: .92)
              : Theme.of(context).colorScheme.primary,
          inactiveColor: Colors.white24,
          secondaryActiveColor: systemTimeline
              ? Colors.white38
              : Colors.white54,
          thumbColor: systemTimeline
              ? Colors.white.withValues(alpha: dragging ? .96 : .82)
              : null,
          overlayColor: systemTimeline
              ? WidgetStatePropertyAll(Colors.white.withValues(alpha: .13))
              : null,
          onChangeStart: (v) {
            _hideTimer?.cancel();
            setState(() => _dragPosition = Duration(milliseconds: v.round()));
          },
          onChanged: (v) =>
              setState(() => _dragPosition = Duration(milliseconds: v.round())),
          onChangeEnd: (v) {
            setState(() => _dragPosition = null);
            unawaited(_seekTo(Duration(milliseconds: v.round())));
            _scheduleControlsHide();
          },
        ),
      ),
    );
    final play = NativeVideoIconButton(
      tooltip: ended
          ? t.videoPlayback.replay
          : playing
          ? t.videoPlayback.pause
          : t.videoPlayback.play,
      symbol: ended
          ? 'arrow.counterclockwise'
          : playing
          ? 'pause.fill'
          : 'play.fill',
      icon: ended
          ? Icons.replay_rounded
          : playing
          ? Icons.pause_rounded
          : Icons.play_arrow_rounded,
      onPressed: () => unawaited(_togglePlay()),
    );
    final speedLabel =
        '${_speed == _speed.roundToDouble() ? _speed.toStringAsFixed(1) : _speed}×';
    final speedWidth =
        (_timeLabelWidth(
                  speedLabel,
                  Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ) +
                24)
            .clamp(64.0, double.infinity);
    final speed = NativeVideoTextButton(
      maxWidth: speedWidth,
      label: speedLabel,
      tooltip: t.videoPlayback.speed,
      onPressed: () => _openQuickSettings(VideoQuickSection.speed),
    );
    final portraitButton = NativeVideoIconButton(
      tooltip: _fullscreen
          ? t.videoPlayback.switchToPortrait
          : t.videoPlayback.portraitFullscreen,
      symbol: 'rectangle.portrait',
      icon: Icons.stay_current_portrait_rounded,
      onPressed: () => unawaited(_setFullscreen(true, portrait: true)),
    );
    final landscapeButton = NativeVideoIconButton(
      tooltip: portrait
          ? t.videoPlayback.switchToLandscape
          : t.videoPlayback.fullscreen,
      symbol: 'arrow.up.left.and.arrow.down.right',
      icon: Icons.fullscreen_rounded,
      onPressed: () => unawaited(_setFullscreen(true, portrait: false)),
    );
    final collapse = NativeVideoIconButton(
      tooltip: t.videoPlayback.exitFullscreen,
      symbol: 'arrow.down.right.and.arrow.up.left',
      icon: Icons.fullscreen_exit_rounded,
      onPressed: () => unawaited(_setFullscreen(false)),
    );
    final top = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NativeVideoIconButton(
          tooltip: _fullscreen ? t.videoPlayback.exitFullscreen : t.common.back,
          symbol: 'chevron.left',
          icon: Icons.arrow_back_ios_new_rounded,
          onPressed: _backFromPlayer,
        ),
        Expanded(
          child: wide
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: Text(
                    _session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: Colors.white),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        if (rich) ..._fullscreenActions(),
        if (_fullscreen)
          NativeVideoIconButton(
            tooltip: t.videoPlayback.lockControls,
            symbol: 'lock.open',
            icon: Icons.lock_open_rounded,
            onPressed: _toggleLock,
          ),
        NativeVideoIconButton(
          tooltip: t.videoPlayback.playbackSettings,
          symbol: 'ellipsis',
          icon: Icons.more_horiz_rounded,
          onPressed: _openQuickSettings,
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Column(
        children: [
          top,
          if (portrait)
            Expanded(
              child: Stack(
                children: [
                  Positioned(
                    left: 8,
                    bottom: 12,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_session.creator case final creator?)
                          TextButton.icon(
                            onPressed: _relatedAction(widget.onOpenCreator),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                              minimumSize: const Size(44, 44),
                            ),
                            icon: CircleAvatar(
                              radius: 18,
                              child: creator.avatarUrl == null
                                  ? const Icon(
                                      Icons.person_outline_rounded,
                                      size: 20,
                                    )
                                  : ClipOval(
                                      child: VideoThumbnail(
                                        url: creator.avatarUrl.toString(),
                                        referrer: _session.watchUrl,
                                        placeholderIcon:
                                            Icons.person_outline_rounded,
                                      ),
                                    ),
                            ),
                            label: Text(
                              creator.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        Text(
                          _session.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.titleSmall?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            const Spacer(),
          if (portrait && _engagement != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ..._fullscreenActions(subtle: true).take(2),
                _countedControl(
                  caption: t.videoCommunity.comments,
                  label: t.videoCommunity.comments,
                  subtle: true,
                  button: NativeVideoIconButton(
                    bare: true,
                    iconSize: 20,
                    tooltip: t.videoCommunity.comments,
                    symbol: 'text.bubble',
                    icon: Icons.chat_bubble_outline_rounded,
                    onPressed: () => unawaited(_portraitComments()),
                  ),
                ),
                _fullscreenActions(subtle: true).last,
              ],
            ),
          if (portrait &&
              _session.playbackEntries.isNotEmpty &&
              (widget.loadEpisode != null || widget.onOpenVideo != null))
            Row(
              children: [
                NativeVideoTextButton(
                  label: _selectionTitle,
                  tooltip: _selectionTitle,
                  onPressed: () =>
                      _openQuickSettings(VideoQuickSection.episodes),
                ),
                if (_episodeSequence.items.length <= 1)
                  const Spacer()
                else
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        _episodeSequence.playbackIndexOf(_session.watchUrl) < 0
                            ? (_session.isSitePlaylist
                                  ? t.videoPlayback.playlistCurrentMissing
                                  : t.videoPlayback.episodeOrderUnavailable)
                            : '${_episodeSequence.playbackIndexOf(_session.watchUrl) + 1}/${_episodeSequence.items.length}',
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: Colors.white70),
                      ),
                    ),
                  ),
                if (_episodeSequence.items.length > 1)
                  for (final direction in [-1, 1])
                    NativeVideoIconButton(
                      tooltip: _session.isSitePlaylist
                          ? (direction < 0
                                ? t.videoPlayback.previousPlaylistEntry
                                : t.videoPlayback.nextPlaylistEntry)
                          : (direction < 0
                                ? t.videoPlayback.previousEpisode
                                : t.videoPlayback.nextEpisode),
                      symbol: direction < 0 ? 'backward.end' : 'forward.end',
                      icon: direction < 0
                          ? Icons.skip_previous_rounded
                          : Icons.skip_next_rounded,
                      onPressed:
                          _episodeLoading ||
                              _episodeSequence.adjacent(
                                    _session.watchUrl,
                                    direction,
                                  ) ==
                                  null
                          ? null
                          : () => _selectEpisode(
                              _episodeSequence.adjacent(
                                _session.watchUrl,
                                direction,
                              )!,
                            ),
                    ),
              ],
            ),
          if (ready) ...[
            if (!_fullscreen)
              LayoutBuilder(
                builder: (context, constraints) {
                  final timeWidth = _timeLabelWidth(timeText, timeStyle);
                  final stacked =
                      timeWidth + 44 + speedWidth + 88 + 64 >
                      constraints.maxWidth;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (stacked)
                        Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: time(),
                              ),
                            ),
                            speed,
                          ],
                        ),
                      Row(
                        key: const ValueKey('video-controls.inline-bottom'),
                        children: [
                          play,
                          Expanded(child: timeline(centered: true)),
                          if (!stacked) ...[
                            SizedBox(width: timeWidth, child: time()),
                            SizedBox(width: speedWidth, child: speed),
                          ],
                          portraitButton,
                          landscapeButton,
                        ],
                      ),
                    ],
                  );
                },
              )
            else ...[
              if (!portrait)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(alignment: Alignment.centerLeft, child: time()),
                ),
              timeline(),
              Row(
                key: ValueKey(
                  portrait
                      ? 'video-controls.portrait-bottom'
                      : 'video-controls.landscape-bottom',
                ),
                children: [
                  play,
                  if (rich) ...[
                    NativeVideoIconButton(
                      tooltip: t.videoPlayback.rewind10,
                      symbol: 'gobackward.10',
                      icon: Icons.replay_10_rounded,
                      onPressed: () => unawaited(_seekBy(-10)),
                    ),
                    NativeVideoIconButton(
                      tooltip: t.videoPlayback.forward10,
                      symbol: 'goforward.10',
                      icon: Icons.forward_10_rounded,
                      onPressed: () => unawaited(_seekBy(10)),
                    ),
                  ],
                  if (portrait)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: time(),
                      ),
                    )
                  else
                    const Spacer(),
                  if (wide &&
                      _session.playbackEntries.isNotEmpty &&
                      (widget.onOpenVideo != null ||
                          widget.loadEpisode != null))
                    NativeVideoTextButton(
                      maxWidth: 100,
                      label: _selectionTitle,
                      tooltip: _selectionTitle,
                      onPressed: () =>
                          _openQuickSettings(VideoQuickSection.episodes),
                    ),
                  speed,
                  if (wide && _hasSourceChoices)
                    NativeVideoTextButton(
                      maxWidth: 100,
                      label: _currentSourceLabel,
                      tooltip: t.videoPlayback.source,
                      onPressed: () =>
                          _openQuickSettings(VideoQuickSection.sources),
                    ),
                  if (!portrait) portraitButton,
                  if (portrait) ...[
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        collapse,
                        Text(
                          t.videoPlayback.minimizeShort,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        landscapeButton,
                        Text(
                          t.videoPlayback.landscapeShort,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ] else
                    collapse,
                ],
              ),
            ],
          ],
          if (!ready && !portrait)
            Row(
              children: [
                const Spacer(),
                portraitButton,
                if (_fullscreen) collapse else landscapeButton,
              ],
            ),
          if (!ready && portrait)
            Row(
              children: [
                const Spacer(),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    collapse,
                    Text(
                      t.videoPlayback.minimizeShort,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    landscapeButton,
                    Text(
                      t.videoPlayback.landscapeShort,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _quickSettingsOverlay(BoxConstraints constraints) {
    final side = constraints.maxWidth > constraints.maxHeight;
    final padding = MediaQuery.paddingOf(context);
    final reservedTop = side
        ? 0.0
        : padding.top + _inlinePlayerHeight(constraints.maxWidth);
    final panel = VideoBottomPanelLayout(
      reservedTop: reservedTop,
      purpose: switch (_quickSection ?? _lastQuickSection) {
        VideoQuickSection.playback => VideoPanelPurpose.controls,
        VideoQuickSection.speed => VideoPanelPurpose.speed,
        VideoQuickSection.sources => VideoPanelPurpose.sources,
        VideoQuickSection.episodes => VideoPanelPurpose.episodes,
      },
      labels: (_quickSection ?? _lastQuickSection) == VideoQuickSection.sources
          ? [for (final line in _resourceLines) line.label]
          : const [],
      child: SizedBox(
        width: double.infinity,
        child: Theme(
          data: Theme.of(context),
          child: PageStorage(
            bucket: _quickStorage,
            child: VideoPlaybackQuickPanel(
              offlineOnly: widget.offlineOnly,
              showSeekActions: !_fullscreen,
              floating: false,
              resourcePicker: widget.resourceLines == null
                  ? null
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final line in _resourceLines)
                          ListTile(
                            key: ValueKey('video-resource-line.${line.id}'),
                            title: Text(
                              line.label,
                              style: TextStyle(
                                fontWeight: line.current
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(_resourceLineSubtitle(line)),
                            subtitleTextStyle: Theme.of(
                              context,
                            ).textTheme.bodySmall,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 2,
                            ),
                            selected: line.current,
                            trailing: line.current
                                ? const Icon(Icons.check_rounded)
                                : null,
                            onTap: line.current || line.target == null
                                ? null
                                : () {
                                    final target = line.target!;
                                    // A resource change keeps the current episode's
                                    // progress; it is not a request to restart it.
                                    _episodeReturns[target.watchUrl] = (
                                      position:
                                          _controller?.value.position ??
                                          _resumePosition,
                                      playing:
                                          _controller?.value.isPlaying ??
                                          _resumePlaying,
                                    );
                                    _closeQuickSettings();
                                    _selectEpisode(target);
                                  },
                          ),
                      ],
                    ),
              episodePicker: _session.isSitePlaylist
                  ? null
                  : VideoEpisodePicker(
                      sequence: _episodeSequence,
                      current: _session.watchUrl,
                      onChanged: (next) {
                        setState(() => _episodeSequence = next);
                      },
                      onSelected:
                          widget.onOpenVideo != null ||
                              widget.loadEpisode != null
                          ? _selectEpisode
                          : null,
                    ),
              side: side,
              section: _quickSection ?? _lastQuickSection,
              preferences: _preferences,
              session: _session,
              sourceIndex: _sourceIndex,
              speed: _speed,
              muted: _muted,
              ready:
                  !_loading &&
                  !_failed &&
                  _controller?.value.isInitialized == true,
              watchLater: _engagement?.state.watchLater,
              siteBusy:
                  _engagement?.working == true ||
                  _engagement?.unconfirmedAction != null,
              onWatchLater: _engagement == null
                  ? null
                  : () => unawaited(
                      _setSiteAction(
                        VideoSiteAction.watchLater,
                        _engagement!.state.watchLater != true,
                      ),
                    ),
              siteFeedback: _engagement == null
                  ? null
                  : VideoEngagementStatus(
                      controller: _engagement!,
                      onWebsite: _leaveSiteActions,
                    ),
              onSpeed: (v) => unawaited(_setSpeed(v)),
              onSource: (i) {
                if (_quickSection == VideoQuickSection.sources) {
                  _closeQuickSettings();
                }
                if (i != _sourceIndex) unawaited(_loadSource(i));
              },
              onPreference: (key, value) =>
                  unawaited(_savePlayerPreference(key, value)),
              onMute: () => unawaited(_toggleMute()),
              onSeek: (v) => unawaited(_seekBy(v)),
              onClose: _closeQuickSettings,
              onFullSettings: () => unawaited(_openPlaybackSettings()),
              onAnalysis: !_canAnalyze
                  ? null
                  : () => unawaited(_analyzePlayback()),
              onWebsite: () {
                _closeQuickSettings();
                unawaited(_backToWeb());
              },
              onExitSource: _exitSourceFromPlayer,
              onEpisode: _selectEpisode,
            ),
          ),
        ),
      ),
    );
    return panel;
  }

  Widget _playerSurface() {
    final controller = _controller;
    final value = controller?.value;
    final ready = value?.isInitialized == true;
    final duration = ready ? value!.duration : Duration.zero;
    final position = _dragPosition ?? (ready ? value!.position : Duration.zero);
    final ended =
        ready &&
        duration > Duration.zero &&
        (value!.isCompleted || value.position >= duration) &&
        !value.isPlaying;
    final controlsShown =
        !_locked &&
        _quickSection == null &&
        (_controlsVisible ||
            MediaQuery.accessibleNavigationOf(context) ||
            _failed ||
            ended);

    return LayoutBuilder(
      builder: (context, constraints) {
        _tapAreaWidth = constraints.maxWidth;
        final seekingEnabled =
            ready && !_locked && !_failed && _preferences.swipeSeek;
        return RawGestureDetector(
          key: const ValueKey('video-gesture-surface'),
          behavior: HitTestBehavior.opaque,
          gestures: {
            if (seekingEnabled)
              _VideoSeekRecognizer:
                  GestureRecognizerFactoryWithHandlers<_VideoSeekRecognizer>(
                    _VideoSeekRecognizer.new,
                    (recognizer) {
                      recognizer.edgeWidth = _fullscreen ? 0 : 24;
                      recognizer.width = constraints.maxWidth;
                      recognizer.gestureSettings = MediaQuery.gestureSettingsOf(
                        context,
                      );
                      recognizer.dragStartBehavior = DragStartBehavior.down;
                      recognizer.onStart = (_) => _beginSwipe();
                      recognizer.onUpdate = (details) =>
                          _updateSwipe(details.delta.dx);
                      recognizer.onEnd = (_) => _endSwipe();
                      recognizer.onCancel = () => _endSwipe(cancelled: true);
                    },
                  ),
          },
          child: Listener(
            // Flutter reports cancellation of an accepted drag through its
            // end callback. Handle the pointer cancellation before that can
            // commit a preview as an intentional seek.
            onPointerCancel: (_) => _endSwipe(cancelled: true),
            child: ColoredBox(
              color: Colors.black,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap:
                        _failed ||
                            _locked ||
                            MediaQuery.accessibleNavigationOf(context)
                        ? null
                        : _toggleControls,
                    onDoubleTapDown:
                        _failed || _locked || _preferences.doubleTap == 'off'
                        ? null
                        : (details) => _doubleTapX = details.localPosition.dx,
                    onDoubleTap:
                        _failed || _locked || _preferences.doubleTap == 'off'
                        ? null
                        : () => unawaited(
                            _preferences.doubleTap == 'playPause' ||
                                    (_doubleTapX >= _tapAreaWidth * 0.3 &&
                                        _doubleTapX <= _tapAreaWidth * 0.7)
                                ? _togglePlay()
                                : _seekBy(
                                    _doubleTapX < _tapAreaWidth * 0.3
                                        ? -10
                                        : 10,
                                  ),
                          ),
                    onLongPressStart:
                        _failed || _locked || _preferences.holdSpeed == 0
                        ? null
                        : (_) => unawaited(_setFastForward(true)),
                    onLongPressEnd: _failed || _locked
                        ? null
                        : (_) => unawaited(_setFastForward(false)),
                    onLongPressCancel: () => unawaited(_setFastForward(false)),
                    child: AnimatedSwitcher(
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: KeyedSubtree(
                        key: ObjectKey(controller),
                        child: ready
                            ? ClipRect(
                                child: SizedBox.expand(
                                  child: FittedBox(
                                    fit:
                                        _preferences.cover &&
                                            !(_fullscreen &&
                                                _portraitFullscreen) &&
                                            (_fullscreen ||
                                                constraints.maxHeight <=
                                                    constraints.maxWidth *
                                                            9 /
                                                            16 +
                                                        1)
                                        ? BoxFit.cover
                                        : BoxFit.contain,
                                    child: SizedBox(
                                      width: value!.size.width,
                                      height: value.size.height,
                                      child: VideoPlayer(controller!),
                                    ),
                                  ),
                                ),
                              )
                            : _episodeLoading && _session.coverUrl != null
                            ? Center(
                                child: VideoThumbnail(
                                  url: _session.coverUrl.toString(),
                                  placeholderIcon: Icons.play_arrow_rounded,
                                  referrer: _session.watchUrl,
                                ),
                              )
                            : const SizedBox.expand(),
                      ),
                    ),
                  ),
                  if (_fullscreen && _actionNotice != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      top: MediaQuery.viewPaddingOf(context).top + 64,
                      child: VideoActionNotice(
                        message: _actionNotice!,
                        onClose: _clearActionNotice,
                      ),
                    ),
                  if (!_failed &&
                      !_loading &&
                      !_episodeLoading &&
                      _actionNotice == null &&
                      _episodeRetryTarget != null)
                    Positioned(
                      left: 12,
                      right: 12,
                      top: _fullscreen
                          ? MediaQuery.viewPaddingOf(context).top + 64
                          : 60,
                      child: Material(
                        color: const Color(0xEE192025),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12, right: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  t.videoPlayback.episodeSwitchFailed,
                                  maxLines: 2,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    _selectEpisode(_episodeRetryTarget!),
                                child: Text(t.common.retry),
                              ),
                              IconButton(
                                tooltip: t.common.close,
                                onPressed: () =>
                                    setState(() => _episodeRetryTarget = null),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_showEpisodeWait || _rawRecoveryPending)
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 130,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _toggleControls,
                        child: Semantics(
                          liveRegion: true,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_showEpisodeWait || _rawRecoveryPending)
                                const LinearProgressIndicator(minHeight: 2),
                              const SizedBox(height: 8),
                              Text(
                                _rawRecoveryPending
                                    ? t.videoSource.lineResolving
                                    : _autoResourceActive
                                    ? t.videoSource.autoSwitchAttempt(
                                        line: _autoResourceLabel,
                                        current: _autoResourceAttempt,
                                        total: _autoResourceTotal,
                                      )
                                    : t.videoPlayback.episodeWaiting,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
                              ),
                              if (_canAutoResourceFallback)
                                TextButton(
                                  key: const ValueKey('video-switch.cancel'),
                                  onPressed: _cancelEpisodeRead,
                                  child: Text(t.common.cancel),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_loading && !_episodeLoading)
                    IgnorePointer(
                      child: Center(
                        child: Semantics(
                          label: t.videoPlayback.buffering,
                          child: const CircularProgressIndicator(),
                        ),
                      ),
                    ),
                  if (ready &&
                      value!.isBuffering &&
                      !_failed &&
                      !_loading &&
                      !_episodeLoading &&
                      _episodeRetryTarget == null)
                    Positioned(
                      top: _fullscreen ? 60 : 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text(
                              t.videoPlayback.buffering,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_failed)
                    Positioned(
                      top: MediaQuery.paddingOf(context).top,
                      left: MediaQuery.paddingOf(context).left,
                      child: NativeVideoIconButton(
                        tooltip: _fullscreen
                            ? t.videoPlayback.exitFullscreen
                            : t.common.back,
                        symbol: 'chevron.left',
                        icon: Icons.arrow_back_ios_new_rounded,
                        onPressed: _backFromPlayer,
                      ),
                    ),
                  if (_failed &&
                      !_episodeLoading &&
                      !_loading &&
                      !_rawRecoveryPending)
                    Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 44, 16, 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _verificationRequired
                                  ? t.videoPlayback.verificationRequired
                                  : t.videoPlayback.playFailed,
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              children: [
                                if (_verificationRequired &&
                                    widget.onVerifySite != null)
                                  TextButton(
                                    onPressed: () => unawaited(_verifySite()),
                                    child: Text(
                                      t.videoPlayback.continueVerification,
                                    ),
                                  ),
                                if (!widget.offlineOnly)
                                  TextButton(
                                    onPressed: () => unawaited(_backToWeb()),
                                    child: Text(
                                      widget.onOpenWebsite == null
                                          ? t.videoPlayback.backToWeb
                                          : t.videoPlayback.openWebsitePlayer,
                                    ),
                                  ),
                                TextButton(
                                  onPressed: () => unawaited(_retryPlayback()),
                                  child: Text(t.common.retry),
                                ),
                                if (widget.resourceLines != null &&
                                    _hasSourceChoices)
                                  TextButton(
                                    onPressed: () => _openQuickSettings(
                                      VideoQuickSection.sources,
                                    ),
                                    child: Text(t.videoPlayback.source),
                                  ),
                                if (_sourceIndex + 1 < _session.sources.length)
                                  TextButton(
                                    onPressed: () => unawaited(
                                      _retryPlayback(
                                        nextSource: _sourceIndex + 1,
                                      ),
                                    ),
                                    child: Text(t.videoPlayback.nextSource),
                                  ),
                              ],
                            ),
                            if (widget.extraFailureActions case final actions?)
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                children: actions(
                                  context,
                                  _session,
                                  _selectEpisode,
                                ),
                              ),
                            if (_canAnalyze)
                              TextButton(
                                key: const ValueKey('video-failure.analysis'),
                                onPressed: () => unawaited(_analyzePlayback()),
                                child: Text(t.videoPlayback.playbackAnalysis),
                              ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    top:
                        (_fullscreen ? MediaQuery.paddingOf(context).top : 0) +
                        8,
                    left: _fullscreen ? MediaQuery.paddingOf(context).left : 0,
                    right: _fullscreen
                        ? MediaQuery.paddingOf(context).right
                        : 0,
                    child: IgnorePointer(
                      child: AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 160),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, -0.2),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: _holdingFastForward && !_failed
                            ? Center(
                                key: const ValueKey('video-hold-speed-hint'),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: Text(
                                      t.videoPlayback.fastForwardRate(
                                        rate: _preferences.holdSpeed,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  if (_dragPosition != null && !_failed)
                    Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_swiping)
                                Text(
                                  '${position >= _swipeOrigin ? '+' : '−'}${t.videoPlayback.seconds(value: (position - _swipeOrigin).inSeconds.abs())}',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              Text(
                                '${_time(position)} / ${_time(duration)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_seekFeedback != null &&
                      !_failed &&
                      _dragPosition == null)
                    IgnorePointer(
                      child: Align(
                        alignment: _seekFeedbackAlignment,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            _seekFeedback!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!_failed)
                    IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: controlsShown ? 1 : 0,
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black54,
                                Colors.transparent,
                                Colors.black87,
                              ],
                              stops: [0, 0.4, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (!_failed)
                    AnimatedOpacity(
                      opacity: controlsShown ? 1 : 0,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 180),
                      child: IgnorePointer(
                        ignoring: !controlsShown,
                        child: Padding(
                          padding: _fullscreen
                              ? MediaQuery.paddingOf(context)
                              : EdgeInsets.zero,
                          child: _controlLayout(
                            ready: ready && !_loading,
                            ended: ended,
                            playing: value?.isPlaying == true,
                            position: position,
                            duration: duration,
                            wide:
                                _fullscreen &&
                                !_portraitFullscreen &&
                                constraints.maxWidth >= 600,
                          ),
                        ),
                      ),
                    ),
                  if (_fullscreen && _locked)
                    Positioned(
                      left: MediaQuery.paddingOf(context).left + 12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton.filledTonal(
                          tooltip: t.videoPlayback.unlockControls,
                          onPressed: _toggleLock,
                          icon: const Icon(Icons.lock_rounded),
                        ),
                      ),
                    ),
                  if (ready && !controlsShown && !_failed)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          value: duration.inMilliseconds > 0
                              ? position.inMilliseconds /
                                    duration.inMilliseconds
                              : 0,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _videoRow(
    String title,
    List<NativeVideoCard> videos, {
    bool episodes = false,
    bool playlist = false,
  }) {
    if (videos.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context), colors = theme.colorScheme;
    final scaler = MediaQuery.textScalerOf(context);
    final width = scaler.scale(14) > 22 ? 190.0 : 150.0;
    final titleHeight =
        scaler.scale(theme.textTheme.bodyMedium?.fontSize ?? 14) * 3;
    final showLabels =
        episodes &&
        videos.any(
          (card) =>
              card.episodeLabel.isNotEmpty &&
              card.episodeLabel != card.title.trim(),
        );
    final labelHeight = showLabels
        ? scaler.scale(theme.textTheme.labelMedium?.fontSize ?? 12) * 1.5 + 4
        : 0.0;
    final byline = videos.any(
      (card) => card.metadata
          .byline(creator: card.creator?.name ?? '', fallback: card.subtitle)
          .isNotEmpty,
    );
    final statistics = videos.any((card) => card.metadata.hasCardStatistics);
    final metadataHeight =
        scaler.scale(theme.textTheme.bodySmall?.fontSize ?? 12) *
        1.4 *
        ((byline ? 1 : 0) + (statistics ? 1 : 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (episodes)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              !_episodeSequence.numbered &&
                      _episodeSequence.order != VideoEpisodeOrder.manual
                  ? t.videoPlayback.episodeOrderFallback
                  : switch (_episodeSequence.order) {
                      VideoEpisodeOrder.ascending =>
                        t.videoPlayback.episodeAscending,
                      VideoEpisodeOrder.descending =>
                        t.videoPlayback.episodeDescending,
                      VideoEpisodeOrder.site => t.videoPlayback.episodeSite,
                      VideoEpisodeOrder.manual => t.videoPlayback.episodeManual,
                    },
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          height:
              width * 9 / 16 + 8 + titleHeight + labelHeight + metadataHeight,
          child: ListView.separated(
            key: PageStorageKey(
              'video-row.${_session.watchUrl}.${playlist ? 'playlist' : episodes}',
            ),
            scrollDirection: Axis.horizontal,
            itemCount: videos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, index) {
              final card = videos[index],
                  current =
                      (episodes || playlist) &&
                      videos[index].isCurrent(_session.watchUrl);
              return SizedBox(
                width: width,
                child: Semantics(
                  selected: current,
                  label: current ? t.videoPlayback.currentEpisode : null,
                  child: Tooltip(
                    message: card.title,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: widget.onOpenVideo == null || current
                          ? null
                          : () {
                              if (!_blockDocumentChangeForSiteWrite()) {
                                widget.onOpenVideo!(card.watchUrl);
                              }
                            },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: VideoCardCover(
                                url: card.coverUrl?.toString() ?? '',
                                referrer: card.watchUrl,
                                metadata: card.metadata,
                                current: current,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (showLabels)
                            SizedBox(
                              height: labelHeight,
                              child: Text(
                                card.episodeLabel == card.title.trim()
                                    ? ''
                                    : card.episodeLabel,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colors.primary,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          Text(
                            card.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: current
                                  ? colors.primary
                                  : colors.onSurface,
                              fontWeight: current
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          VideoCardFacts(
                            metadata: card.metadata,
                            creator: card.creator?.name ?? '',
                            fallback: card.subtitle,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _inlineTools({bool compact = false}) {
    if (_editingComments) return const SizedBox.shrink();
    final episodes =
        _session.playbackEntries.isNotEmpty &&
        (widget.onOpenVideo != null || widget.loadEpisode != null);
    final deferredMedia = widget.initialMedia != null;
    final sources = deferredMedia || _hasSourceChoices;
    // API detail pages expose the episode picker beside Share. The catalog
    // reserves its transport actions so late media cannot move the detail.
    final download = widget.onDownloadEpisodes == null
        ? _downloadAdapter(_session)
        : null;
    final showDownload =
        download != null || (deferredMedia && _operations == null);
    if (!episodes && !sources && !showDownload) return const SizedBox.shrink();
    final current = _session.playbackEntries
        .where((card) => card.isCurrent(_session.watchUrl))
        .firstOrNull;
    final theme = Theme.of(context), colors = theme.colorScheme;
    Widget tool({
      required String label,
      required String value,
      required IconData icon,
      required VideoQuickSection section,
      bool enabled = true,
    }) {
      final summary = section == VideoQuickSection.sources && value != '—'
          ? value
          : '$label · $value';
      return TextButton(
        key: ValueKey('video-inline.${section.name}'),
        style: TextButton.styleFrom(
          foregroundColor: colors.onSurface,
          minimumSize: Size(44, compact ? 44 : 48),
          alignment: AlignmentDirectional.centerStart,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 4 : 8,
          ),
        ),
        onPressed: enabled ? () => _openQuickSettings(section) : null,
        child: Row(
          children: [
            Icon(icon, size: compact ? 18 : 22),
            SizedBox(width: compact ? 6 : 8),
            Expanded(
              child: compact
                  ? Text(
                      summary,
                      semanticsLabel: section == VideoQuickSection.sources
                          ? '$label · $value'
                          : null,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          value,
                          maxLines:
                              deferredMedia &&
                                  section == VideoQuickSection.sources
                              ? 1
                              : 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (_, constraints) {
        final one =
            MediaQuery.textScalerOf(context).scale(14) > (compact ? 20 : 22) ||
            constraints.maxWidth < (compact ? 280 : 340);
        final available = constraints.maxWidth - 8;
        final count =
            (episodes ? 1 : 0) + (sources ? 1 : 0) + (showDownload ? 1 : 0);
        final columns = one ? 1 : count;
        final width = (available - 8 * (columns - 1)) / columns;
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 4,
            vertical: compact ? 0 : 4,
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (episodes)
                SizedBox(
                  width: width,
                  child: tool(
                    label: _selectionTitle,
                    value: current?.episodeLabel.isNotEmpty == true
                        ? t.videoPlayback.currentOfTotal(
                            current: current!.episodeLabel,
                            total: _session.playbackEntries.length,
                          )
                        : t.videoPlayback.episodeCount(
                            count: _session.playbackEntries.length,
                          ),
                    icon: Icons.playlist_play_rounded,
                    section: VideoQuickSection.episodes,
                  ),
                ),
              if (showDownload)
                SizedBox(
                  width: width,
                  child: TextButton.icon(
                    key: const ValueKey('video-inline.download'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 48),
                    ),
                    onPressed:
                        _downloadOpen || download?.choices.isNotEmpty != true
                        ? null
                        : () => unawaited(_downloadVideo()),
                    icon: const Icon(Icons.download_outlined),
                    label: Text(
                      !deferredMedia && download?.choices.isEmpty == true
                          ? t.videoDownload.unsupportedMedia
                          : t.videoDownload.title,
                    ),
                  ),
                ),
              if (sources)
                SizedBox(
                  width: width,
                  child: tool(
                    label: t.videoPlayback.source,
                    value: deferredMedia && _session.sources.isEmpty
                        ? '—'
                        : _currentSourceLabel,
                    icon: Icons.video_settings_outlined,
                    section: VideoQuickSection.sources,
                    enabled: _hasSourceChoices,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _hanimeAuthorRow() {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final creator = _session.creator;
    final name = _session.creatorName;
    final engagement = _engagement;
    final works = creator == null || widget.onOpenCreatorWorks == null
        ? null
        : _relatedAction(widget.onOpenCreatorWorks);
    final profile = name.isEmpty ? null : _relatedAction(widget.onOpenCreator);
    final identity = TextButton.icon(
      key: const ValueKey('video.hanime.author'),
      style: TextButton.styleFrom(
        alignment: AlignmentDirectional.centerStart,
        foregroundColor: colors.onSurface,
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 44),
      ),
      onPressed: profile,
      icon: CircleAvatar(
        radius: 16,
        backgroundColor: colors.surfaceContainerHigh,
        foregroundColor: colors.onSurfaceVariant,
        child: creator?.avatarUrl == null
            ? const Icon(Icons.person_outline_rounded, size: 20)
            : ClipOval(
                child: SizedBox.square(
                  dimension: 32,
                  child: VideoThumbnail(
                    url: creator!.avatarUrl.toString(),
                    referrer: _session.watchUrl,
                  ),
                ),
              ),
      ),
      label: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
    final actions = <Widget>[
      if (works != null)
        TextButton(
          key: const ValueKey('video.hanime.author-works'),
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: works,
          child: Text(t.videoCommunity.viewCreatorWorks),
        ),
      if (engagement != null) VideoFollowButton(controller: engagement),
    ];
    if (name.isEmpty && actions.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 330 ||
            MediaQuery.textScalerOf(context).scale(14) > 18;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (name.isNotEmpty) identity,
              Wrap(spacing: 4, children: actions),
            ],
          );
        }
        return Row(
          children: [
            if (name.isNotEmpty) Expanded(child: identity) else const Spacer(),
            for (final action in actions) ...[const SizedBox(width: 4), action],
          ],
        );
      },
    );
  }

  Widget _detailContent() {
    if (widget.detailBuilder case final builder?) {
      return ColoredBox(
        key: _detailContentKey,
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            if (_actionNotice != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: VideoActionNotice(
                  message: _actionNotice!,
                  onClose: _clearActionNotice,
                ),
              ),
            Expanded(
              child: builder(
                context,
                _session,
                _showRelatedPage,
                _showAuxiliaryOverlay,
                widget.detailToolsBuilder?.call(
                      () => _openQuickSettings(VideoQuickSection.episodes),
                      () => _openQuickSettings(VideoQuickSection.sources),
                    ) ??
                    _inlineTools(),
              ),
            ),
          ],
        ),
      );
    }
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tags = _tagsExpanded ? _session.tags : _session.tags.take(4);
    return ColoredBox(
      key: _detailContentKey,
      color: colors.surface,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              if (_actionNotice != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: VideoActionNotice(
                    message: _actionNotice!,
                    onClose: _clearActionNotice,
                  ),
                ),
              if (!_hanimeOnlineDetail) _inlineTools(),
              if (_operations != null)
                _editingComments
                    ? Row(
                        children: [
                          IconButton(
                            tooltip: t.common.back,
                            onPressed: _backFromPlayer,
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          ),
                          Expanded(
                            child: Text(
                              t.videoCommunity.comments,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            tooltip: t.videoCommunity.closeKeyboard,
                            onPressed: () => FocusScope.of(context).unfocus(),
                            icon: const Icon(Icons.keyboard_hide_rounded),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          for (final comments in [false, true])
                            Expanded(
                              child: Semantics(
                                selected: _commentsSelected == comments,
                                child: TextButton(
                                  onPressed: () => setState(() {
                                    _commentsSelected = comments;
                                    if (comments) _commentsOpened = true;
                                  }),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(44, 48),
                                    foregroundColor:
                                        _commentsSelected == comments
                                        ? colors.primary
                                        : colors.onSurfaceVariant,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        comments
                                            ? t.videoCommunity.comments
                                            : t.videoCommunity.overview,
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        height: 2,
                                        width: 24,
                                        color: _commentsSelected == comments
                                            ? colors.primary
                                            : Colors.transparent,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              if (_hanimeOnlineDetail && _commentsSelected)
                _inlineTools(compact: true),
              Expanded(
                child: VideoDetailSections(
                  storageKey: 'video-detail',
                  commentsSelected: _commentsSelected,
                  onSelected: (comments) {
                    if (!mounted || _commentsSelected == comments) return;
                    setState(() {
                      _commentsSelected = comments;
                      if (comments) _commentsOpened = true;
                    });
                  },
                  onPrepareComments: () {
                    if (mounted && !_commentsOpened)
                      setState(() => _commentsOpened = true);
                  },
                  children: [
                    ListView(
                      key: PageStorageKey('video-detail.${_session.watchUrl}'),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        _hanimeOnlineDetail ? 6 : 20,
                        16,
                        24,
                      ),
                      children: [
                        if (_hanimeOnlineDetail) _hanimeAuthorRow(),
                        if (!_hanimeOnlineDetail &&
                            (_session.creatorName.isNotEmpty ||
                                _engagement != null)) ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    alignment: AlignmentDirectional.centerStart,
                                    foregroundColor: colors.onSurface,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(44, 48),
                                  ),
                                  icon: CircleAvatar(
                                    radius: 20,
                                    backgroundColor:
                                        colors.surfaceContainerHigh,
                                    foregroundColor: colors.onSurfaceVariant,
                                    child: _session.creator?.avatarUrl == null
                                        ? const Icon(
                                            Icons.person_outline_rounded,
                                            size: 24,
                                          )
                                        : ClipOval(
                                            child: SizedBox(
                                              width: 40,
                                              height: 40,
                                              child: VideoThumbnail(
                                                url: _session.creator!.avatarUrl
                                                    .toString(),
                                                referrer: _session.watchUrl,
                                              ),
                                            ),
                                          ),
                                  ),
                                  label: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _session.creatorName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        t.videoMetadata.author,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                  onPressed: _session.creatorName.isEmpty
                                      ? null
                                      : _relatedAction(widget.onOpenCreator),
                                ),
                              ),
                              if (_engagement case final engagement?) ...[
                                const SizedBox(width: 12),
                                VideoFollowButton(controller: engagement),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (!_hanimeOnlineDetail &&
                            widget.onOpenCreatorWorks != null &&
                            _session.creator != null)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton(
                              onPressed: _relatedAction(
                                widget.onOpenCreatorWorks,
                              ),
                              child: Text(t.videoCommunity.viewCreatorWorks),
                            ),
                          ),
                        Text(
                          _session.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                        if (_session.metadata.viewsLabel != null ||
                            _session.metadata.publishedDate != null) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              if (_session.metadata.viewsLabel
                                  case final views?)
                                Text(
                                  t.videoMetadata.views(value: views),
                                  key: const ValueKey('video-main-views'),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              if (_session.metadata.publishedDate
                                  case final date?)
                                Text(
                                  date,
                                  key: const ValueKey('video-main-date'),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ],
                        if (_hanimeOnlineDetail && !_commentsSelected)
                          _inlineTools(compact: true),
                        if (_engagement == null &&
                            widget.source?.isNotEmpty == true &&
                            videoPublicPage(_session.watchUrl)?.path ==
                                '/watch')
                          VideoLocalFavoriteAction(
                            source: widget.source!,
                            session: _session,
                          ),
                        if (_engagement case final engagement?) ...[
                          const SizedBox(height: 8),
                          VideoEngagement(
                            publicMetadata: _session.metadata,
                            controller: engagement,
                            compact: _hanimeOnlineDetail,
                            localFavorite:
                                widget.source?.isNotEmpty == true &&
                                    videoPublicPage(_session.watchUrl)?.path ==
                                        '/watch'
                                ? VideoLocalFavoriteAction(
                                    source: widget.source!,
                                    session: _session,
                                    detailAction: true,
                                    compact: _hanimeOnlineDetail,
                                  )
                                : null,
                            onFavorite: () => unawaited(_favoriteVideo()),
                            onDownload: () => unawaited(_downloadVideo()),
                            onShare: (anchor) => unawaited(_shareVideo(anchor)),
                          ),
                          VideoEngagementStatus(
                            controller: engagement,
                            onWebsite: _leaveSiteActions,
                          ),
                        ],
                        if (_engagement == null && _session.metadata.hasVotes)
                          VideoVoteSummary(metadata: _session.metadata),
                        if (_session.uploader case final uploader?) ...[
                          const SizedBox(height: 12),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              alignment: AlignmentDirectional.centerStart,
                              foregroundColor: colors.onSurfaceVariant,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(44, 44),
                            ),
                            onPressed: _relatedAction(widget.onOpenUploader),
                            icon: CircleAvatar(
                              radius: 14,
                              backgroundColor: colors.surfaceContainerHigh,
                              child: uploader.avatarUrl == null
                                  ? const Icon(
                                      Icons.person_outline_rounded,
                                      size: 18,
                                    )
                                  : ClipOval(
                                      child: SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: VideoThumbnail(
                                          url: uploader.avatarUrl.toString(),
                                          referrer: _session.watchUrl,
                                        ),
                                      ),
                                    ),
                            ),
                            label: Text(
                              '${t.videoCommunity.uploader} · ${uploader.name}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        if (_session.description.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          AnimatedSize(
                            duration: VideoMotion.feedback(context),
                            alignment: AlignmentDirectional.topStart,
                            curve: Curves.easeOutCubic,
                            child: Text(
                              _session.description,
                              maxLines: _descriptionExpanded ? null : 3,
                              overflow: _descriptionExpanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                height: 1.5,
                              ),
                            ),
                          ),
                          if (_session.description.length > 100)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Semantics(
                                button: true,
                                excludeSemantics: true,
                                label: _descriptionExpanded
                                    ? t.videoPlayback.collapseDescription
                                    : t.videoPlayback.expandDescription,
                                onTap: () => setState(
                                  () => _descriptionExpanded =
                                      !_descriptionExpanded,
                                ),
                                expanded: _descriptionExpanded,
                                child: TextButton.icon(
                                  icon: VideoDisclosureIndicator(
                                    expanded: _descriptionExpanded,
                                    size: 18,
                                  ),
                                  onPressed: () => setState(
                                    () => _descriptionExpanded =
                                        !_descriptionExpanded,
                                  ),
                                  label: Text(
                                    _descriptionExpanded
                                        ? t.videoPlayback.collapseDescription
                                        : t.videoPlayback.expandDescription,
                                  ),
                                ),
                              ),
                            ),
                        ],
                        if (_session.tags.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          AnimatedSize(
                            duration: VideoMotion.feedback(context),
                            alignment: AlignmentDirectional.topStart,
                            curve: Curves.easeOutCubic,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                for (final tag in tags)
                                  ActionChip(
                                    label: Text(
                                      tag,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    labelStyle: theme.textTheme.labelMedium,
                                    backgroundColor: colors.surfaceContainer,
                                    side: BorderSide.none,
                                    onPressed:
                                        widget.onSearchTag == null &&
                                            widget.onOpenTag == null
                                        ? null
                                        : _relatedAction(() async {
                                            final target =
                                                _session.tagTargets[tag];
                                            if (target != null &&
                                                widget.onOpenTag != null) {
                                              await widget.onOpenTag!(target);
                                            } else {
                                              await widget.onSearchTag?.call(
                                                tag
                                                    .replaceFirst(
                                                      RegExp(r'\s*\(\d+\)$'),
                                                      '',
                                                    )
                                                    .trim(),
                                              );
                                            }
                                          }),
                                  ),
                                if (_session.tags.length > 4)
                                  Semantics(
                                    button: true,
                                    excludeSemantics: true,
                                    label: _tagsExpanded
                                        ? t.videoPlayback.collapseTags
                                        : t.videoPlayback.moreTags(
                                            count: _session.tags.length - 4,
                                          ),
                                    onTap: () => setState(
                                      () => _tagsExpanded = !_tagsExpanded,
                                    ),
                                    expanded: _tagsExpanded,
                                    child: ActionChip(
                                      avatar: VideoDisclosureIndicator(
                                        expanded: _tagsExpanded,
                                        size: 18,
                                      ),
                                      chipAnimationStyle: VideoMotion.chip(
                                        context,
                                      ),
                                      label: Text(
                                        _tagsExpanded
                                            ? t.videoPlayback.collapseTags
                                            : t.videoPlayback.moreTags(
                                                count: _session.tags.length - 4,
                                              ),
                                      ),
                                      onPressed: () => setState(
                                        () => _tagsExpanded = !_tagsExpanded,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (widget.onOpenVideo != null) ...[
                          _videoRow(
                            _selectionTitle,
                            _episodeSequence.items,
                            episodes: !_session.isSitePlaylist,
                            playlist: _session.isSitePlaylist,
                          ),
                          _videoRow(t.videoPlayback.related, _session.related),
                        ],
                      ],
                    ),
                    if (_commentsOpened && _operations != null)
                      VideoCommunityPage(
                        key: ValueKey('video-comments.${_session.watchUrl}'),
                        operations: _operations!,
                        embedded: true,
                        editing: _editingComments,
                        onLogin: () => _leaveSiteActions(login: true),
                        onWebsite: _leaveSiteActions,
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _inlinePlayerHeight(double width) {
    final theme = Theme.of(context), scaler = MediaQuery.textScalerOf(context);
    final value = _controller?.value;
    final time = TextPainter(
      text: TextSpan(
        text:
            '${_time(value?.position ?? Duration.zero)} / ${_time(value?.duration ?? Duration.zero)}',
        style: theme.textTheme.labelMedium,
      ),
      textDirection: Directionality.of(context),
      textScaler: scaler,
    )..layout(maxWidth: (width - 40).clamp(1.0, double.infinity));
    final speed = TextPainter(
      text: TextSpan(text: '1.0×', style: theme.textTheme.labelLarge),
      textDirection: Directionality.of(context),
      textScaler: scaler,
    )..layout();
    // Preserve full-size touch targets and time at accessibility sizes rather
    // than squeezing controls into the natural 16:9 video height.
    final controls =
        48 +
        44 +
        (speed.height + 16).clamp(48.0, double.infinity) +
        time.height +
        4;
    time.dispose();
    speed.dispose();
    return (width * 9 / 16).clamp(controls, double.infinity);
  }

  Widget _inlineLayout() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Rotation is asynchronous: after exiting fullscreen the window can
        // remain landscape briefly. Fit that viewport instead of overflowing
        // a full-width 16:9 player while waiting for portrait orientation.
        if (!_editingComments && constraints.maxWidth > constraints.maxHeight) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  const Expanded(flex: 3, child: SizedBox.expand()),
                  Expanded(flex: 2, child: _detailContent()),
                ],
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: constraints.maxWidth * 3 / 5,
                child: _playerSurface(),
              ),
            ],
          );
        }
        final height = _editingComments
            ? 0.0
            : _inlinePlayerHeight(constraints.maxWidth);
        // Keep one player/control subtree, in its original rectangle. Painting
        // the details first prevents native controls splitting later body paint
        // into another platform-view overlay during page transitions.
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                SizedBox(height: height),
                Expanded(child: _detailContent()),
              ],
            ),
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              height: height,
              child: _editingComments
                  ? const SizedBox.shrink()
                  : _playerSurface(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => VideoNetworkScope(
    source: widget.source ?? '',
    network: _network,
    child: AppInterfaceStyleScope(
      style: _interfaceStyle,
      child: Builder(builder: _buildPage),
    ),
  );

  Widget _buildPage(BuildContext context) {
    return VideoControlAppearance(
      systemControls: AppInterfaceStyleScope.usesSystem(context),
      child: PopScope(
        canPop: !_fullscreen && _quickSection == null,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            _finishPlaybackOnPop();
            return;
          }
          if (_quickSection != null) {
            _closeQuickSettings();
          } else if (_fullscreen) {
            unawaited(_setFullscreen(false));
          }
        },
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            systemNavigationBarColor: _fullscreen
                ? Colors.black
                : Theme.of(context).colorScheme.surface,
            systemNavigationBarIconBrightness: _fullscreen
                ? Brightness.light
                : Theme.of(context).brightness == Brightness.light
                ? Brightness.dark
                : Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: _fullscreen
                ? Colors.black
                : Theme.of(context).colorScheme.surface,
            body: LayoutBuilder(
              builder: (context, constraints) => Stack(
                fit: StackFit.expand,
                children: [
                  VideoPageSafeArea(
                    fullscreen: _fullscreen,
                    child: _fullscreen ? _playerSurface() : _inlineLayout(),
                  ),
                  VideoPanelTransition(
                    open: _quickSection != null,
                    side: constraints.maxWidth > constraints.maxHeight,
                    onDismiss: _closeQuickSettings,
                    child: _quickSettingsOverlay(constraints),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Let the route own edge-back before joining the gesture arena. Ignoring an
/// already accepted edge drag would still steal navigation from its parent.
class _VideoSeekRecognizer extends HorizontalDragGestureRecognizer {
  double edgeWidth = 0;
  double width = double.infinity;
  bool _inside(Offset position) =>
      position.dx >= edgeWidth && position.dx <= width - edgeWidth;
  @override
  bool isPointerAllowed(PointerEvent event) =>
      _inside(event.localPosition) && super.isPointerAllowed(event);
  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) =>
      _inside(event.localPosition) && super.isPointerPanZoomAllowed(event);
}
