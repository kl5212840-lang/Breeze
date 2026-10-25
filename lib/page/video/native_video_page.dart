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
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';
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
import 'package:zephyr/page/video/video_episode_sequence.dart';
import 'package:zephyr/page/video/video_episode_picker.dart';
import 'package:zephyr/util/debouncer.dart';

typedef NativeEpisodeLoad = ({
  NativePlaybackSession session,
  VideoSiteOperations? operations,
});

/// Native video detail. Playback starts inline; fullscreen is opt-in.
class NativeVideoPage extends StatefulWidget {
  const NativeVideoPage({
    super.key,
    required this.session,
    this.onOpenVideo,
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
    this.onOpenAccount,
    this.initialPlaybackState,
    this.onPlaybackExit,
    this.loadEpisode,
    this.onEpisodeChanged,
  });

  final NativePlaybackSession session;
  final Future<NativeEpisodeLoad> Function(Uri)? loadEpisode;
  final ValueChanged<NativeEpisodeLoad>? onEpisodeChanged;
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
  final VoidCallback? onOpenAccount;
  final NativePlaybackReturnState? initialPlaybackState;
  final ValueChanged<NativePlaybackReturnState>? onPlaybackExit;

  @override
  State<NativeVideoPage> createState() => _NativeVideoPageState();
}

class _NativeVideoPageState extends State<NativeVideoPage>
    with WidgetsBindingObserver {
  late NativePlaybackSession _session;
  late VideoEpisodeSequence _episodeSequence;
  final _episodeReturns = <Uri, NativePlaybackReturnState>{};
  bool _episodeLoading = false, _episodeCancelled = false;
  NativeVideoCard? _episodeRetryTarget;
  String? _episodeFailureStage, _episodeFailureType;
  final _episodeRetirements = <Future<void>>{};
  final _retiredPlayers = Expando<Future<void>>();
  bool _relatedPageOpen = false;
  Timer? _episodeWaitTimer;
  bool _showEpisodeWait = false;
  VideoSiteOperations? get _operations => _engagement?.operations;

  VideoPlaybackPreferences _preferences = const VideoPlaybackPreferences();
  VideoPlayerController? _controller;
  Timer? _hideTimer;
  Timer? _feedbackTimer;
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
  bool _controlsVisible = true;
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

  String get _progressKey =>
      'breeze.video.progress.${_session.watchUrl.host}.'
      '${_session.watchUrl.queryParameters['v'] ?? _session.watchUrl.path}';

  bool get _isPhone =>
      (Platform.isIOS || Platform.isAndroid) && !isTabletWithOutContext();

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _episodeSequence = VideoEpisodeSequence(_session.episodes);
    if (widget.siteOperations case final operations?) {
      _engagement = VideoEngagementController(
        operations: operations,
        onLogin: () => _leaveSiteActions(login: true),
      )..addListener(_onEngagementChanged);
      unawaited(_engagement!.load());
    }
    WidgetsBinding.instance.addObserver(this);
    widget.siteVerification?.addListener(_onSiteVerification);
    VideoPlaybackPreferences.changes.addListener(_onPreferencesChanged);
    unawaited(_restoreAndLoad());
  }

  void _onEngagementChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _favoriteVideo() async {
    final engagement = _engagement;
    if (engagement == null || engagement.working) return;
    final operations = engagement.operations;
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
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
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

  Future<void> _downloadVideo() async {
    final engagement = _engagement;
    if (engagement == null || engagement.held || engagement.working) return;
    final operations = engagement.operations;
    engagement.hold(true);
    _holdControls('system-download');
    try {
      await showVideoTaskSheet<void>(
        context: context,
        builder: (sheetContext) => VideoDownloadSheet(
          readChoices: operations.readDownloadChoices,
          video: _session.watchUrl,
          title: _session.title,
          onClose: () => Navigator.of(sheetContext).pop(),
          onWebsite: _leaveSiteActions,
        ),
      );
    } finally {
      await operations.cancelRead();
      if (mounted && identical(_engagement, engagement)) engagement.hold(false);
      _releaseControls('system-download');
    }
  }

  Future<void> _shareVideo(Rect anchor) async {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result == VideoShareStatus.unavailable
                  ? t.videoCommunity.shareUnavailable
                  : t.videoCommunity.shareFailed,
            ),
          ),
        );
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
    try {
      _preferences = await VideoPlaybackPreferences.read();
      _speed = _preferences.defaultSpeed;
      _resumePlaying = _preferences.autoplay;
      final preferences = await SharedPreferences.getInstance();
      var saved = preferences.getInt(_progressKey) ?? 0;
      final source = widget.source;
      if (source != null &&
          _preferences.recordHistory &&
          _preferences.resumeProgress) {
        try {
          final records = await VideoWatchHistory.read(
            source,
          ).timeout(const Duration(seconds: 2));
          final watch = VideoWatchRecord.canonicalUrl(_session.watchUrl);
          final record = records
              .where((record) => record.watchUrl == watch)
              .firstOrNull;
          if (record != null) {
            saved = record.completed ? 0 : record.position.inMilliseconds;
          }
        } catch (_) {
          // Older numeric progress remains usable if metadata cannot be read.
        }
      }
      if (mounted &&
          saved > 0 &&
          _preferences.resumeProgress &&
          _preferences.recordHistory) {
        _resumePosition = Duration(milliseconds: saved);
      }
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
    if (mounted) await _loadSource(_preferredSourceIndex());
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

  void _selectEpisode(NativeVideoCard card) {
    _closeQuickSettings();
    if (card.isCurrent(_session.watchUrl)) return;
    if (widget.loadEpisode != null) {
      unawaited(_switchEpisode(card));
    } else {
      widget.onOpenVideo?.call(card.watchUrl);
    }
  }

  Future<void> _openPlaybackSettings() async {
    _closeQuickSettings();
    _holdControls('settings');
    try {
      await Navigator.of(context).push<void>(
        videoPageRoute(
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
    if (!_preferences.recordHistory) return;
    final value = _controller?.value;
    if (value?.isInitialized != true || value!.duration <= Duration.zero) {
      return;
    }
    final position = value.position;
    final completed =
        value.isCompleted ||
        position.inMilliseconds >= value.duration.inMilliseconds * 0.98;
    try {
      var historySaved = false;
      if ((position >= const Duration(seconds: 5) || value.isCompleted) &&
          widget.source != null &&
          VideoWatchRecord.canonicalUrl(session.watchUrl) != null) {
        try {
          await VideoWatchHistory.record(
            widget.source!,
            VideoWatchRecord(
              watchUrl: session.watchUrl,
              title: session.title,
              coverUrl: session.coverUrl,
              position: position,
              duration: value.duration,
              updatedAt: DateTime.now().toUtc(),
              completed: completed,
            ),
          ).timeout(const Duration(seconds: 3));
          historySaved = true;
        } catch (_) {
          // Watch-list metadata is optional; keep saving the resume position.
        }
      }
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
    }
    // iOS may briefly report `inactive` during fullscreen rotation. Pause
    // only when the app actually leaves the foreground.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _foreground = false;
      _cancelEpisodeRead();
      final controller = _controller;
      if (controller?.value.isInitialized == true) {
        _resumePosition = controller!.value.position;
        _resumePlaying = false;
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
      action == null || _relatedPageOpen || _episodeLoading
      ? null
      : () => unawaited(_showRelatedPage(action));

  Future<void> _showRelatedPage(AsyncCallback action) async {
    if (_relatedPageOpen || _episodeLoading) return;
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
      if (mounted) {
        if (fullscreen) await _setFullscreen(true, portrait: portrait);
        if (playing &&
            _foreground &&
            !_verificationRequired &&
            identical(player, _controller)) {
          await player?.play();
        }
        _releaseControls('related-page');
      }
    }
  }

  Future<void> _portraitComments() async {
    final engagement = _engagement;
    if (engagement == null || engagement.working) return;
    engagement.hold(true);
    _holdControls('comments-sheet');
    try {
      await showVideoTaskSheet<void>(
        context: context,
        builder: (sheetContext) => SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .72,
          child: VideoCommunityPage(
            key: ValueKey('feed-comments.${_session.watchUrl}'),
            operations: engagement.operations,
            onLogin: () => _leaveSiteActions(login: true),
            onWebsite: _leaveSiteActions,
          ),
        ),
      );
    } finally {
      await engagement.operations.cancelRead();
      if (mounted && identical(engagement, _engagement)) engagement.hold(false);
      _releaseControls('comments-sheet');
    }
  }

  Future<void> _retireEpisodePlayer(VideoPlayerController player) {
    final previous = _retiredPlayers[player];
    if (previous != null) return previous;
    final disposal = player.dispose();
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

  void _cancelEpisodeRead() {
    _episodeCancelled = true;
  }

  // Every caller is an explicit selection. Mode, orientation and gesture
  // preferences cannot revoke a valid manual switch after its network read.
  Future<void> _switchEpisode(NativeVideoCard target) async {
    bool canContinue() =>
        mounted && !_episodeCancelled && _foreground && !_verificationRequired;
    final load = widget.loadEpisode;
    final previous = _controller;
    final oldEngagement = _engagement;
    if (load == null ||
        previous == null ||
        _episodeLoading ||
        _loading ||
        _retrying ||
        oldEngagement?.working == true ||
        target.isCurrent(_session.watchUrl)) {
      return;
    }
    final oldSession = _session;
    final oldState = (
      position: previous.value.position,
      playing: previous.value.isPlaying,
    );
    final sourceLabel = _session.sources.elementAtOrNull(_sourceIndex)?.label;
    _episodeReturns[oldSession.watchUrl] = oldState;
    _episodeCancelled = false;
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
    var committed = false, previousReleased = false;
    try {
      await _persistProgress();
      if (!mounted) return;
      stage = 'pause-current';
      await previous.pause().timeout(const Duration(seconds: 3));
      if (!canContinue()) throw StateError('Episode switch cancelled');
      // A manual choice has exactly one authoritative site-document read.
      // No detached fetch, speculative session cache or competing binding task.
      stage = 'read-foreground';
      loaded = await load(target.watchUrl).timeout(const Duration(seconds: 45));
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
      stage = 'release-current-media';
      previous.removeListener(_onPlayerChanged);
      setState(() => _controller = null);
      previousReleased = true;
      await _retireEpisodePlayer(previous).timeout(const Duration(seconds: 8));
      await _waitForEpisodeRetirements();
      if (!mounted || _episodeCancelled) {
        throw StateError('Episode switch cancelled');
      }
      final returned = _episodeReturns[next.watchUrl];
      final position = returned?.position ?? Duration.zero;
      final mediaDeadline = DateTime.now().add(const Duration(seconds: 45));
      final sourceOrder = [
        sourceIndex,
        for (var n = 0; n < next.sources.length; n++)
          if (n != sourceIndex) n,
      ].take(3).toList();
      for (final attempt in sourceOrder) {
        sourceIndex = attempt;
        candidate = _createPlayer(next.sources[attempt]);
        try {
          stage = 'initialize-media';
          await candidate.initialize().timeout(
            _mediaAttemptTime(mediaDeadline),
          );
          stage = 'configure-media';
          // A new AVPlayer already starts at zero. An unnecessary exact seek
          // can wait for more media bytes and turn a ready source into failure.
          if (position > Duration.zero && position < candidate.value.duration) {
            await candidate
                .seekTo(position)
                .timeout(_mediaAttemptTime(mediaDeadline));
          }
          await candidate
              .setVolume(_muted ? 0 : 1)
              .timeout(_mediaAttemptTime(mediaDeadline));
          await candidate
              .setPlaybackSpeed(_speed)
              .timeout(_mediaAttemptTime(mediaDeadline));
          break;
        } catch (error) {
          await _retireEpisodePlayer(
            candidate,
          ).timeout(const Duration(seconds: 8));
          candidate = null;
          if (!canContinue() ||
              attempt == sourceOrder.last ||
              !DateTime.now().isBefore(mediaDeadline) ||
              (stage != 'initialize-media' && error is! TimeoutException)) {
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
      previous.removeListener(_onPlayerChanged);
      oldEngagement?.removeListener(_onEngagementChanged);
      oldEngagement?.dispose();
      oldEngagement?.operations.dispose();
      _loadEpoch++;
      setState(() {
        _session = next;
        _controller = candidate;
        _sourceIndex = sourceIndex;
        _failed = false;
        _loading = false;
        _commentsOpened = false;
        _commentsSelected = false;
        _descriptionExpanded = false;
        _tagsExpanded = false;
        _lastSavedSecond = -1;
        _resumePosition = position;
        _resumePlaying = returned?.playing ?? oldState.playing;
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
      if (_resumePlaying && _foreground && !_verificationRequired) {
        await candidate.play();
      }
    } catch (error) {
      _episodeFailureStage = stage;
      _episodeFailureType = error.runtimeType.toString();
      if (kDebugMode) {
        debugPrint(
          'Episode switch failed: $_episodeFailureStage ($_episodeFailureType)',
        );
      }
      if (mounted && !committed) {
        // The hidden document may already be the failed target. Restore its
        // identity before releasing actions bound to the retained old video.
        var restoredSession = oldSession;
        {
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
            _resumePlaying = oldState.playing;
            final restoredIndex = restoredSession.sources.indexWhere(
              (source) => source.label == sourceLabel,
            );
            await _loadSource(
              restoredIndex < 0 ? 0 : restoredIndex,
              forcePlay: oldState.playing,
            );
            _episodeCancelled =
                cancelled || !_foreground || _verificationRequired;
          }
        } else if (mounted &&
            oldState.playing &&
            _foreground &&
            !_verificationRequired) {
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
      _episodeWaitTimer?.cancel();
      if (mounted) {
        if (identical(_engagement, oldEngagement)) oldEngagement?.hold(false);
        setState(() {
          _episodeLoading = false;
          _showEpisodeWait = false;
        });
        _releaseControls('episode-switch');
      }
    }
  }

  VideoPlayerController _createPlayer(NativePlaybackSource source) =>
      VideoPlayerController.networkUrl(
        source.url,
        httpHeaders: source.headers,
        // The host owns pause/resume in both initial playback and manual
        // replacement. Do not let video_player independently auto-resume a
        // replacement when returning from the background.
        videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
      );

  Duration _mediaAttemptTime(DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      throw TimeoutException('Media source deadline');
    }
    const attempt = Duration(seconds: 25);
    return remaining < attempt ? remaining : attempt;
  }

  Future<void> _loadSource(
    int index, {
    bool forcePlay = false,
    Set<int> attempted = const {},
    DateTime? mediaDeadline,
  }) async {
    if (!mounted) return;
    if (_episodeLoading) _episodeCancelled = true;
    _cancelEpisodeRead();
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
        forcePlay ||
        (previous == null ? _resumePlaying : previous.value.isPlaying);
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
    final controller = _createPlayer(source);
    _controller = controller;
    var initializing = true;
    bool isCurrent() => mounted && epoch == _loadEpoch;
    Future<void> prepare() async {
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
        if (target > Duration.zero) await controller.seekTo(target);
      }
      if (!isCurrent()) return;
      await controller.setVolume(_muted ? 0 : 1);
      await controller.setPlaybackSpeed(_speed);
      if (!isCurrent()) return;
      if (shouldPlay && _foreground && !_verificationRequired) {
        await controller.play();
      }
    }

    try {
      // Bound the complete setup, including resume seeking and native play,
      // rather than timing only metadata initialization.
      await prepare().timeout(_mediaAttemptTime(deadline));
      if (!isCurrent()) return;
      setState(() => _loading = false);
      _scheduleControlsHide();
    } catch (error) {
      if (!isCurrent()) return;
      final failedEpoch = ++_loadEpoch;
      _controller = null;
      controller.removeListener(_onPlayerChanged);
      await _retireEpisodePlayer(
        controller,
      ).timeout(const Duration(seconds: 5)).catchError((_) {});
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
        );
        return;
      }
      setState(() {
        _loading = false;
        _quickSection = null;
        _controlInteractions.remove('quick-settings');
        _failed = true;
        _controlsVisible = true;
        _locked = false;
      });
    }
  }

  Future<void> _retryPlayback({int? nextSource}) async {
    if (_retrying || _loading || _episodeLoading || !mounted) return;
    _retrying = true;
    try {
      if (nextSource != null) {
        await _loadSource(nextSource, forcePlay: true);
        return;
      }
      final refresh = widget.refreshSession;
      if (refresh != null) {
        setState(() {
          _loading = true;
          _failed = false;
          _verificationRequired = false;
          _controlsVisible = true;
        });
        try {
          final session = await refresh().timeout(const Duration(seconds: 25));
          if (!mounted) return;
          if (session.watchUrl != _session.watchUrl) {
            throw const FormatException('Playback identity changed');
          }
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
          if (mounted) {
            try {
              await _controller?.pause().timeout(const Duration(seconds: 2));
            } catch (_) {
              // A failed platform player must not prevent human verification.
            }
            if (!mounted) return;
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
          // An expired source may still be temporarily unavailable. The user
          // can switch source or continue in the website player.
        }
      }
      if (mounted) await _loadSource(_sourceIndex, forcePlay: true);
    } finally {
      _retrying = false;
    }
  }

  void _onPlayerChanged() {
    if (!mounted) return;
    if (!_foreground && _controller?.value.isPlaying == true) {
      unawaited(_controller?.pause());
      return;
    }
    if (_controller?.value.hasError == true && !_failed) {
      // Platform errors may replace the value with an uninitialized value
      // at 00:00. Keep the last good position captured before that error.
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
      return;
    }
    final value = _controller?.value;
    if (value?.isPlaying != true || value?.isBuffering == true) {
      _hideTimer?.cancel();
      _controlsVisible = true;
    }
    if (value?.isInitialized == true && !_loading) {
      _resumePosition = value!.position;
      _resumePlaying = value.isPlaying;
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

  void _showControls() {
    if (!mounted) return;
    _hideTimer?.cancel();
    setState(() => _controlsVisible = true);
    _scheduleControlsHide();
  }

  void _holdControls(String interaction) {
    _controlInteractions.add(interaction);
    _hideTimer?.cancel();
    if (mounted) setState(() => _controlsVisible = true);
  }

  void _releaseControls(String interaction) {
    // A recognizer can cancel before its drag ever starts. Such a cancellation
    // must not reveal controls ahead of the pending single-tap callback, which
    // would then toggle those freshly revealed controls off again.
    if (!_controlInteractions.remove(interaction)) return;
    if (mounted) _showControls();
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
      if (!await _runPlayerCommand(controller, controller.play)) return;
      _resumePlaying = true;
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
          ? const Alignment(-0.7, 0)
          : const Alignment(0.7, 0);
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
      if (!enabled) _showControls();
    } catch (_) {
      if (mounted) setState(() => _holdingFastForward = false);
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
    if (mounted) Navigator.of(context).pop(true);
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
    _episodeWaitTimer?.cancel();
    _cancelEpisodeRead();
    widget.siteVerification?.removeListener(_onSiteVerification);
    VideoPlaybackPreferences.changes.removeListener(_onPreferencesChanged);
    _preferenceReadEpoch++;
    _engagement?.removeListener(_onEngagementChanged);
    _engagement?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _feedbackTimer?.cancel();
    _loadEpoch++;
    unawaited(_persistProgress());
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
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
    if (_engagement == null) return [];
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
          trackHeight: 2,
          trackShape: centered
              ? const RoundedRectSliderTrackShape()
              : const VideoTimelineTrackShape(),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
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
          activeColor: Theme.of(context).colorScheme.primary,
          inactiveColor: Colors.white24,
          secondaryActiveColor: Colors.white54,
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
                            onPressed: _episodeLoading
                                ? null
                                : _relatedAction(widget.onOpenCreator),
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
                    onPressed: _episodeLoading
                        ? null
                        : () => unawaited(_portraitComments()),
                  ),
                ),
                _fullscreenActions(subtle: true).last,
              ],
            ),
          if (portrait &&
              _session.episodes.isNotEmpty &&
              (widget.loadEpisode != null || widget.onOpenVideo != null))
            Row(
              children: [
                NativeVideoTextButton(
                  label: t.videoPlayback.episodes,
                  tooltip: t.videoPlayback.episodes,
                  onPressed: _episodeLoading
                      ? null
                      : () => _openQuickSettings(VideoQuickSection.episodes),
                ),
                if (_episodeSequence.items.length <= 1)
                  const Spacer()
                else
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        _episodeSequence.indexOf(_session.watchUrl) < 0
                            ? t.videoPlayback.episodeOrderUnavailable
                            : '${_episodeSequence.indexOf(_session.watchUrl) + 1}/${_episodeSequence.items.length}',
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: Colors.white70),
                      ),
                    ),
                  ),
                if (_episodeSequence.items.length > 1)
                  for (final direction in [-1, 1])
                    NativeVideoIconButton(
                      tooltip: direction < 0
                          ? t.videoPlayback.previousEpisode
                          : t.videoPlayback.nextEpisode,
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
                      _session.episodes.isNotEmpty &&
                      widget.onOpenVideo != null)
                    NativeVideoTextButton(
                      maxWidth: 100,
                      label: t.videoPlayback.episodes,
                      tooltip: t.videoPlayback.episodes,
                      onPressed: () =>
                          _openQuickSettings(VideoQuickSection.episodes),
                    ),
                  speed,
                  if (wide && _session.sources.length > 1)
                    NativeVideoTextButton(
                      maxWidth: 100,
                      label: videoSourceLabel(
                        _session.sources[_sourceIndex],
                        _sourceIndex,
                      ),
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
    final availableWidth = constraints.maxWidth;
    final width = side
        ? (availableWidth * .44).clamp(340.0, 420.0).clamp(0.0, availableWidth)
        : availableWidth;
    final height = side
        ? constraints.maxHeight
        : !_fullscreen
        ? constraints.maxHeight -
              padding.top -
              _inlinePlayerHeight(constraints.maxWidth)
        : constraints.maxHeight * .72;
    final darkColors = ColorScheme.fromSeed(
      seedColor: Theme.of(context).colorScheme.primary,
      brightness: Brightness.dark,
    );
    final dark = ThemeData.from(
      colorScheme: darkColors,
      textTheme: Theme.of(context).textTheme.apply(
        bodyColor: darkColors.onSurface,
        displayColor: darkColors.onSurface,
      ),
    );
    return Align(
      alignment: side ? Alignment.centerRight : Alignment.bottomCenter,
      child: SizedBox(
        width: width,
        height: height.clamp(0.0, constraints.maxHeight),
        child: Theme(
          data: dark,
          child: PageStorage(
            bucket: _quickStorage,
            child: VideoPlaybackQuickPanel(
              episodePicker: VideoEpisodePicker(
                sequence: _episodeSequence,
                current: _session.watchUrl,
                onChanged: (next) {
                  setState(() => _episodeSequence = next);
                },
                onSelected:
                    widget.onOpenVideo != null || widget.loadEpisode != null
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
              onWebsite: () {
                _closeQuickSettings();
                unawaited(_backToWeb());
              },
              onEpisode: _selectEpisode,
            ),
          ),
        ),
      ),
    );
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
            !ready ||
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
                        : () {
                            _hideTimer?.cancel();
                            if (controlsShown) {
                              setState(() => _controlsVisible = false);
                            } else {
                              _showControls();
                            }
                          },
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
                          ? const Duration(milliseconds: 80)
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
                                  referrer: _session.watchUrl,
                                ),
                              )
                            : const SizedBox.expand(),
                      ),
                    ),
                  ),
                  if (_episodeRetryTarget case final retryTarget?)
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
                                onPressed: () => _selectEpisode(retryTarget),
                                child: Text(t.common.retry),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_showEpisodeWait)
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 130,
                      child: IgnorePointer(
                        child: Semantics(
                          liveRegion: true,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_showEpisodeWait)
                                const LinearProgressIndicator(minHeight: 2),
                              const SizedBox(height: 8),
                              Text(
                                t.videoPlayback.episodeWaiting,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (_loading)
                    Center(
                      child: Semantics(
                        label: t.videoPlayback.buffering,
                        child: const CircularProgressIndicator(),
                      ),
                    ),
                  if (ready && value!.isBuffering && !_failed)
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
                  if (_failed)
                    Center(
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
                              TextButton(
                                onPressed: () => unawaited(_backToWeb()),
                                child: Text(t.videoPlayback.backToWeb),
                              ),
                              TextButton(
                                onPressed: () => unawaited(_retryPlayback()),
                                child: Text(t.common.retry),
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
                        ],
                      ),
                    ),
                  if (_holdingFastForward && !_failed)
                    Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          child: Text(
                            t.videoPlayback.fastForwardRate(
                              rate: _preferences.holdSpeed,
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
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
                        child: Text(
                          _seekFeedback!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
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
            key: PageStorageKey('video-row.${_session.watchUrl}.$episodes'),
            scrollDirection: Axis.horizontal,
            itemCount: videos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, index) {
              final card = videos[index],
                  current =
                      episodes && videos[index].isCurrent(_session.watchUrl);
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
                          : () => widget.onOpenVideo!(card.watchUrl),
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

  Widget _inlineTools() {
    if (_editingComments) return const SizedBox.shrink();
    final episodes = _session.episodes.isNotEmpty && widget.onOpenVideo != null;
    final sources = _session.sources.length > 1;
    if (!episodes && !sources) return const SizedBox.shrink();
    final current = _session.episodes
        .where((card) => card.isCurrent(_session.watchUrl))
        .firstOrNull;
    final theme = Theme.of(context), colors = theme.colorScheme;
    Widget tool({
      required String label,
      required String value,
      required IconData icon,
      required VideoQuickSection section,
    }) => TextButton(
      key: ValueKey('video-inline.${section.name}'),
      style: TextButton.styleFrom(
        foregroundColor: colors.onSurface,
        minimumSize: const Size(44, 48),
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      onPressed: () => _openQuickSettings(section),
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (_, constraints) {
        final one =
            MediaQuery.textScalerOf(context).scale(14) > 22 ||
            constraints.maxWidth < 340;
        final available = constraints.maxWidth - 8;
        final width = one || !episodes || !sources
            ? available
            : (available - 8) / 2;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (episodes)
                SizedBox(
                  width: width,
                  child: tool(
                    label: t.videoPlayback.episodes,
                    value: current?.episodeLabel.isNotEmpty == true
                        ? current!.episodeLabel
                        : t.videoPlayback.episodeCount(
                            count: _session.episodes.length,
                          ),
                    icon: Icons.playlist_play_rounded,
                    section: VideoQuickSection.episodes,
                  ),
                ),
              if (sources)
                SizedBox(
                  width: width,
                  child: tool(
                    label: t.videoPlayback.source,
                    value: videoSourceLabel(
                      _session.sources[_sourceIndex],
                      _sourceIndex,
                    ),
                    icon: Icons.video_settings_outlined,
                    section: VideoQuickSection.sources,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailContent() {
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
              _inlineTools(),
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
              Expanded(
                child: IndexedStack(
                  index: _commentsSelected ? 1 : 0,
                  children: [
                    ListView(
                      key: PageStorageKey('video-detail.${_session.watchUrl}'),
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      children: [
                        if (_session.creatorName.isNotEmpty ||
                            _engagement != null) ...[
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
                                      : _episodeLoading
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
                        if (widget.onOpenCreatorWorks != null &&
                            _session.creator != null)
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton(
                              onPressed: _episodeLoading
                                  ? null
                                  : _relatedAction(widget.onOpenCreatorWorks),
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
                        if (_engagement case final engagement?) ...[
                          const SizedBox(height: 8),
                          VideoEngagement(
                            publicMetadata: _session.metadata,
                            controller: engagement,
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
                            t.videoPlayback.episodes,
                            _episodeSequence.items,
                            episodes: true,
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
          return Row(
            children: [
              Expanded(flex: 3, child: _playerSurface()),
              Expanded(flex: 2, child: _detailContent()),
            ],
          );
        }
        return Column(
          children: [
            // Edge controls fit within the video's natural aspect ratio.
            SizedBox(
              height: _editingComments
                  ? 0
                  : _inlinePlayerHeight(constraints.maxWidth),
              child: _editingComments
                  ? const SizedBox.shrink()
                  : _playerSurface(),
            ),
            Expanded(child: _detailContent()),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return VideoControlAppearance(
      systemControls: _preferences.controlsStyle == 'system',
      child: PopScope(
        canPop: !_fullscreen && _quickSection == null,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            final value = _controller?.value;
            final ready = value?.isInitialized == true && !value!.hasError;
            widget.onPlaybackExit?.call((
              position: ready ? value.position : _resumePosition,
              playing: ready ? value.isPlaying : _resumePlaying,
            ));
            return;
          }
          if (_quickSection != null) {
            _closeQuickSettings();
          } else if (_fullscreen) {
            unawaited(_setFullscreen(false));
          }
        },
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: LayoutBuilder(
              builder: (context, constraints) => Stack(
                fit: StackFit.expand,
                children: [
                  SafeArea(
                    top: !_fullscreen,
                    bottom: !_fullscreen,
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
