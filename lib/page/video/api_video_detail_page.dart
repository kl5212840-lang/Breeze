import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/page/video/video_detail_sections.dart';
import 'package:zephyr/page/video/video_playback_download_adapter.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'package:zephyr/page/video/video_playback_identity.dart';
import 'package:zephyr/page/video/omo_network.dart';
import 'package:zephyr/page/video/video_network_scope.dart';
import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/network/playback_trace.dart';
import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart' show AsyncCallback;
import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:zephyr/page/video/api_video_playback_diagnostics.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/native_video_page.dart';
import 'package:zephyr/page/video/video_episode_sequence.dart';
import 'package:zephyr/page/video/video_episode_picker.dart';
import 'package:zephyr/page/video/video_episode_download_picker.dart';
import 'package:zephyr/page/video/api_video_episode_download.dart';
import 'package:zephyr/page/video/video_selection_panel.dart';
import 'package:zephyr/page/video/video_side_panel.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/page/video/video_library_folder_picker.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_system_share.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/page/video/video_downloaded_details.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/video_browse_theme.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';
import 'package:zephyr/page/video/video_cover_overlay.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/omofun_account_page.dart'
    show openOmoSitePage;
import 'package:zephyr/page/video/omofun_discussion_panel.dart';

class ApiVideoDetailPage extends StatefulWidget {
  const ApiVideoDetailPage({
    super.key,
    required this.repository,
    required this.initialItem,
    this.resume,
    this.requireExactResume = false,
    this.forDownloadRecovery = false,
    this.store,
    this.siteClient,
    this.initialLocalSession,
  });
  final ApiVideoRepository repository;
  final ApiVideoItem initialItem;
  final Uri? resume;
  final bool requireExactResume;
  final bool forDownloadRecovery;
  final VideoLibraryStore? store;
  final OmoSiteClient? siteClient;
  final NativePlaybackSession? initialLocalSession;
  @override
  State<ApiVideoDetailPage> createState() => _ApiVideoDetailPageState();
}

/// The description/comments surface must not enter the arena at route edges.
/// Ignoring an edge drag after acceptance would already steal iOS back.
class _ApiVideoDetailPageState extends State<ApiVideoDetailPage>
    with WidgetsBindingObserver {
  late final ApiVideoRepository _repository;
  Future<OmoNetworkContext?>? _ownedNetwork;
  Future<SourceNetworkLease>? _ownedLease;
  late ApiVideoItem _item = widget.initialItem;
  VideoLibraryStore get _store => widget.store ?? VideoLibraryStore.shared;
  VideoLibrarySnapshot? _library;
  late final Future<void> _initialLibraryRead;
  static const _firstActionReadTimeout = Duration(seconds: 2);
  bool _detailsPresented = false;
  bool get _initialDetailPending =>
      !_detailsPresented && widget.initialLocalSession == null;
  NativePlaybackSession? _initialSession;
  Uri? _currentWatch;
  Uri? _initialProgressWatch;
  Uri? _pendingWatch;
  VideoEpisodeSequence? _initialEpisodeSequence;
  Completer<void>? _initialPickerGate;
  final _detailScroll = ScrollController();
  final _expandedCreditRoles = <String>{};
  final _candidateItems = <Uri, ApiVideoItem>{};
  ApiVideoItem? _playbackItem;
  bool _failed = false, _expanded = false, _saving = false;
  bool _episodeDownloadOpen = false;
  bool _detailsLoading = true, _detailsFailed = false, _preparing = false;
  bool _openingInitialLink = false;
  bool _initialCancelled = false;
  bool _preparingControlsVisible = true;
  int _initialAttempt = 0, _initialTotal = 0;
  String _initialLineLabel = '';
  String? _actionNotice;
  Timer? _actionNoticeTimer;
  bool _commentTab = false, _commentsMounted = false;
  int _epoch = 0, _libraryEpoch = 0;
  final _lineChanges = ValueNotifier<int>(0);
  final _lineAttempts = <Uri, ({Duration elapsed, bool success})>{};
  final _resolvingLines = <Uri>{};
  final _resolutionErrors = <Uri, String>{};
  final _resolutionRequests = <Uri, int>{};
  int _resolutionEpoch = 0;
  final _explicitOnlineEpisodes = <Uri>{};
  Set<Uri> get _localEpisodeSnapshot => {
    if (widget.initialLocalSession case final session?) ...[
      session.watchUrl,
      ...session.episodes.map((card) => card.watchUrl),
    ],
  };
  final _playbackTrace = PlaybackTrace();
  @override
  void initState() {
    super.initState();
    final original = widget.repository;
    _initialSession = widget.initialLocalSession;
    _currentWatch = _initialSession?.watchUrl;
    if (original.network == null &&
        SourceNetworkPolicies.supports(original.source)) {
      final lease = _ownedLease = SourceNetworkPolicies.acquire(
        original.source,
      );
      final network = _ownedNetwork = lease.then(
        (_) => OmoNetworkContext.open(
          null,
          source: original.source,
          siteOrigins: [original.home],
        ),
      );
      unawaited(network.then<void>((_) {}, onError: (Object _) {}));
      _repository = original.withNetwork(network);
    } else {
      _repository = original;
    }
    WidgetsBinding.instance.addObserver(this);
    _store.addListener(_readLibrary);
    _initialLibraryRead = _readLibrary();
    _load();
  }

  @override
  void dispose() {
    unawaited(
      _ownedNetwork?.then<void>(
            (value) async => value?.close(),
            onError: (Object _) {},
          ) ??
          Future<void>.value(),
    );
    unawaited(
      _ownedLease?.then<void>(
            (lease) => lease.close(),
            onError: (Object _) {},
          ) ??
          Future<void>.value(),
    );
    WidgetsBinding.instance.removeObserver(this);
    _epoch++;
    _libraryEpoch++;
    _store.removeListener(_readLibrary);
    _detailScroll.dispose();
    _lineChanges.dispose();
    _initialPickerGate?.complete();
    _initialPickerGate = null;
    _actionNoticeTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden) &&
        _preparing) {
      _cancelInitial();
    }
  }

  void _cancelInitial() {
    _epoch++;
    setState(() {
      _preparing = false;
      _resolvingLines.clear();
      _initialCancelled = true;
      _failed = true;
    });
  }

  Future<void> _readLibrary() async {
    final epoch = ++_libraryEpoch;
    try {
      final library = await _store.read().timeout(_firstActionReadTimeout);
      if (mounted && epoch == _libraryEpoch) setState(() => _library = library);
    } catch (_) {
      // Keep the last confirmed snapshot when a later local read fails.
    }
  }

  Future<void> _readPublicPreview(int epoch) async {
    final summary = _item;
    // A useful list preview or a complete route input already paints the details.
    if (summary.description.isNotEmpty && summary.coverUrl != null ||
        summary.lines.isNotEmpty ||
        summary.related.isNotEmpty ||
        summary.credits.isNotEmpty ||
        summary.discussionUrl != null) {
      return;
    }
    try {
      final known = await VideoDownloadedDetails.readKnownItems(
        _repository.source,
        [summary],
      ).timeout(_firstActionReadTimeout);
      final cached = known[summary.id];
      if (cached == null ||
          !mounted ||
          epoch != _epoch ||
          !identical(_item, summary)) {
        return;
      }
      final preview = summary.toLibraryJson();
      if (summary.vodId.isNotEmpty) preview['vodId'] = summary.vodId;
      final stored = cached.toLibraryJson();
      var changed = false;
      for (final key in const [
        'coverUrl',
        'description',
        'genres',
        'typeName',
        'year',
        'area',
        'language',
        'releaseDate',
        'actors',
        'directors',
        'writers',
      ]) {
        final value = preview[key], previous = stored[key];
        if ((value == null || value == '') &&
            previous is String &&
            previous.isNotEmpty) {
          preview[key] = previous;
          changed = true;
        }
      }
      if (changed) {
        setState(
          () => _item = ApiVideoItem.fromJson(preview, home: _repository.home),
        );
      }
    } catch (_) {
      // A preview failure is independent of the authoritative detail request.
    }
  }

  Future<void> _load({bool refresh = false}) async {
    final epoch = ++_epoch;
    final initial = _initialDetailPending;
    setState(() {
      _detailsLoading = true;
      _detailsFailed = false;
      _failed = false;
    });
    try {
      final item = await _repository.item(
        _item.id,
        refresh: refresh,
        snapshot: _item,
      );
      if (!mounted || epoch != _epoch) return;
      // Resolve the first action state before publishing the detail body.
      // Later refreshes keep the last committed body on screen.
      if (initial) {
        await _initialLibraryRead;
        if (!mounted || epoch != _epoch) return;
      }
      final resume = widget.resume;
      setState(() {
        _item = item;
        _detailsLoading = false;
        _detailsPresented = true;
        if (widget.forDownloadRecovery && _initialSession == null) {
          _pendingWatch =
              item.lines.any(
                (line) =>
                    line.episodes.any((episode) => episode.watchUrl == resume),
              )
              ? resume
              : null;
        }
      });
      unawaited(
        VideoDownloadedDetails.saveItem(
          _repository.source,
          item,
        ).catchError((Object _) {}),
      );
      unawaited(
        _store
            .observeDetails(_repository.source, [item])
            .catchError((Object _) {}),
      );
      if (widget.initialLocalSession == null && !widget.forDownloadRecovery) {
        unawaited(_beginPlayback(item, epoch));
      }
    } catch (_) {
      if (!mounted || epoch != _epoch) return;
      if (initial) {
        await Future.wait([_initialLibraryRead, _readPublicPreview(epoch)]);
      }
      if (mounted && epoch == _epoch) {
        setState(() {
          _detailsLoading = false;
          _detailsFailed = true;
          _detailsPresented = true;
        });
      }
    }
  }

  bool _historyEpisodeUnavailable = false;

  Future<void> _beginPlayback(ApiVideoItem item, int epoch) async {
    try {
      if (widget.requireExactResume) {
        final exact = widget.resume;
        if (exact == null ||
            exact.origin != item.detailUrl.origin ||
            exact.path != item.detailUrl.path ||
            !item.lines.any(
              (line) =>
                  line.id == exact.queryParameters['line'] &&
                  line.episodes.any(
                    (episode) => episode.id == exact.queryParameters['episode'],
                  ),
            )) {
          _historyEpisodeUnavailable = true;
          throw const FormatException('History episode unavailable');
        }
        if (!mounted || epoch != _epoch) return;
        await _prepareInitial(exact);
        return;
      }
      if (item.lines.isEmpty) return;
      final line = item.lines.first;
      Uri target = VideoEpisodeSequence(
        item.episodeCards(line.id),
      ).items.first.watchUrl;
      try {
        final recent =
            widget.resume ??
            (await VideoWatchHistory.read(
                  _repository.source,
                ).timeout(_firstActionReadTimeout))
                .where(
                  (r) =>
                      r.watchUrl.path == item.detailUrl.path &&
                      r.watchUrl.origin == item.detailUrl.origin,
                )
                .map((r) => r.watchUrl)
                .firstOrNull;
        if (recent != null &&
            item.lines.any(
              (l) =>
                  l.id == recent.queryParameters['line'] &&
                  l.episodes.any(
                    (e) => e.id == recent.queryParameters['episode'],
                  ),
            )) {
          target = recent;
        }
      } catch (_) {
        /* Optional local history never blocks a real source. */
      }
      if (!mounted || epoch != _epoch) return;
      await _prepareInitial(target);
    } catch (_) {
      // Retain the independent detail, comments, account and poster state.
      if (mounted && epoch == _epoch) {
        setState(() {
          _preparing = false;
          _failed = true;
        });
      }
    }
  }

  Future<NativePlaybackSession?> _downloadedSession(Uri target) async {
    final rows = await VideoLocalResources.read(fresh: true);
    final row = rows
        .where(
          (row) =>
              row['source'] == _repository.source &&
              row['available'] == true &&
              videoPlaybackIdentity(Uri.parse(row['url'] as String)) == target,
        )
        .firstOrNull;
    if (row == null) return null;
    final local = await VideoLocalResources.playback(
      row['resourceId'] as String,
    );
    return NativePlaybackSession(
      title: _item.title,
      watchUrl: local.watchUrl,
      sources: local.sources,
      description: _item.description,
      tags: _item.genres.isEmpty ? const [] : [_item.genres],
      coverUrl: _item.coverUrl ?? local.coverUrl,
      episodes: widget.initialLocalSession?.episodes ?? const [],
      metadata: widget.initialLocalSession?.metadata ?? local.metadata,
    );
  }

  Future<({ApiVideoItem item, NativePlaybackSession session})> _resolve(
    Uri target, {
    bool refresh = false,
    bool rawHlsRecovery = false,
  }) async {
    if (widget.initialLocalSession != null) {
      final local = await _downloadedSession(target);
      if (local != null) return (item: _item, session: local);
      if (_localEpisodeSnapshot.contains(target) ||
          !_explicitOnlineEpisodes.contains(target)) {
        throw StateError('Downloaded episode is no longer available');
      }
    }
    final clock = Stopwatch()..start();
    final pageEpoch = _epoch, requestEpoch = ++_resolutionEpoch;
    final lineIndex =
        _item.lines.indexWhere(
          (line) => line.id == target.queryParameters['line'],
        ) +
        1;
    _playbackTrace.add(
      'resolution',
      'attempt=$requestEpoch; line=$lineIndex; refresh=$refresh; rawHls=$rawHlsRecovery',
    );
    _resolutionRequests[target] = requestEpoch;
    setState(() => _resolvingLines.add(target));
    _lineChanges.value++;
    bool current() =>
        mounted &&
        pageEpoch == _epoch &&
        _resolutionRequests[target] == requestEpoch;
    try {
      final value = await _playbackTrace.run(
        _repository.source,
        () => _repository.session(
          _item.id,
          lineId: target.queryParameters['line'],
          episodeId: target.queryParameters['episode'],
          refresh: refresh,
          rawHlsRecovery: rawHlsRecovery,
          snapshot: _item,
        ),
      );
      _playbackTrace.add(
        'resolution',
        'attempt=$requestEpoch; resolved in ${clock.elapsedMilliseconds}ms',
      );
      if (!current()) throw StateError('Resolution was cancelled');
      if (value.session.watchUrl != target) {
        throw const FormatException('Wrong episode returned');
      }
      if (current()) {
        setState(() {
          _resolutionErrors.remove(target);
          _lineAttempts[target] = (elapsed: clock.elapsed, success: true);
        });
      }
      if (widget.initialLocalSession != null) {
        final session = value.session;
        return (
          item: value.item,
          session: NativePlaybackSession(
            title: session.title,
            watchUrl: session.watchUrl,
            sources: session.sources,
            description: session.description,
            tags: session.tags,
            coverUrl: session.coverUrl,
            episodes: const [],
            related: session.related,
            metadata: session.metadata,
          ),
        );
      }
      return value;
    } catch (error, stack) {
      _playbackTrace.failure(
        'resolution attempt=$requestEpoch; ${clock.elapsedMilliseconds}ms',
        error is ApiVideoStageFailure ? error.cause : error,
        stack,
      );
      if (current()) {
        setState(() {
          _resolutionErrors[target] = apiResolutionErrorSummary(error);
          _lineAttempts[target] = (elapsed: clock.elapsed, success: false);
        });
      }
      rethrow;
    } finally {
      if (current()) {
        setState(() => _resolvingLines.remove(target));
        _lineChanges.value++;
      }
    }
  }

  void _cancelResolution(Uri target) {
    if (!mounted) return;
    setState(() {
      _resolutionRequests[target] = ++_resolutionEpoch;
      _resolvingLines.remove(target);
    });
  }

  Future<void> _prepareInitial(Uri target, {bool automatic = true}) async {
    _historyEpisodeUnavailable = false;
    final epoch = ++_epoch;
    _clearActionNotice();
    setState(() {
      _pendingWatch = target;
      _resolvingLines.clear();
      _preparing = true;
      _initialCancelled = false;
      _initialAttempt = 0;
      _failed = false;
    });
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    final selectedLine = _item.lines
        .where((line) => line.id == target.queryParameters['line'])
        .firstOrNull;
    final selectedEpisode = selectedLine?.episodes
        .where((episode) => episode.id == target.queryParameters['episode'])
        .firstOrNull;
    final targets = <Uri>{
      target,
      if (automatic && selectedEpisode != null)
        for (final line in _item.lines.where(
          (line) => line.id != selectedLine?.id,
        ))
          if (_item.matchingEpisode(line, selectedEpisode) case final episode?)
            episode.watchUrl,
    };
    _initialTotal = targets.length;
    // Normal resolution already verifies any direct media supplied by the
    // source. Reserve explicit raw recovery for an actual playback failure.
    for (final candidate in targets) {
      if (!mounted || epoch != _epoch || !DateTime.now().isBefore(deadline)) {
        break;
      }
      setState(() {
        _pendingWatch = candidate;
        _initialAttempt = targets.toList().indexOf(candidate) + 1;
        _initialLineLabel =
            _item.lines
                .where((line) => line.id == candidate.queryParameters['line'])
                .firstOrNull
                ?.label ??
            '';
      });
      final attemptClock = Stopwatch()..start();
      try {
        final remaining = deadline.difference(DateTime.now());
        final playback = await _resolve(candidate).timeout(
          remaining < const Duration(seconds: 25)
              ? remaining
              : const Duration(seconds: 25),
        );
        // Keep recovery running while a picker is open, but do not replace
        // its underlying page until the user has dismissed or made a choice.
        final picker = _initialPickerGate;
        if (picker != null) await picker.future;
        if (!mounted || epoch != _epoch) return;
        setState(() {
          _playbackItem = playback.item;
          _initialSession = playback.session;
          _currentWatch = playback.session.watchUrl;
          _initialProgressWatch = candidate == target ? null : target;
          _preparing = false;
        });
        return;
      } catch (error) {
        if (mounted && epoch == _epoch && error is TimeoutException) {
          setState(() {
            _resolutionRequests[candidate] = ++_resolutionEpoch;
            _resolvingLines.remove(candidate);
            _resolutionErrors[candidate] = 'timeout';
            _lineAttempts[candidate] = (
              elapsed: attemptClock.elapsed,
              success: false,
            );
          });
        }
        // Only read operations are tried on another reliable same-episode line.
      }
    }
    if (mounted && epoch == _epoch) {
      setState(() {
        _failed = true;
        _preparing = false;
      });
    }
  }

  Future<NativeEpisodeLoad> _loadEpisode(
    Uri target, {
    bool refresh = false,
  }) async {
    if (target.origin != _repository.home.origin ||
        target.path != _item.detailUrl.path) {
      throw const FormatException('Episode outside this item');
    }
    final epoch = _epoch;
    if (widget.initialLocalSession != null &&
        !_localEpisodeSnapshot.contains(target) &&
        await _downloadedSession(target) == null &&
        !_explicitOnlineEpisodes.contains(target)) {
      if (!mounted || epoch != _epoch) throw StateError('Video page closed');
      final zh = Localizations.localeOf(context).languageCode == 'zh';
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          content: Text(
            zh
                ? '本集尚未下载，是否在线播放？这会使用网络流量。'
                : 'This episode is not downloaded. Play online using network data?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(t.common.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(t.common.confirm),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted || epoch != _epoch)
        throw StateError('Online playback cancelled');
      _explicitOnlineEpisodes.add(target);
    }
    final result = await _resolve(target, refresh: refresh);
    if (!mounted || epoch != _epoch) throw StateError('Video page closed');
    _candidateItems[result.session.watchUrl] = result.item;
    return (session: result.session, operations: null);
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

  Future<void> _editFavoriteFolders() async {
    if (_saving) return;
    await showVideoFolderPicker(
      context,
      source: _repository.source,
      item: _item,
      store: _store,
    );
    if (mounted) await _readLibrary();
  }

  Future<void> _favorite() async {
    if (_saving) return;
    _clearActionNotice();
    setState(() => _saving = true);
    try {
      final snapshot = await _store.read();
      await _store.setFavorite(
        _repository.source,
        _item,
        !snapshot.contains(_repository.source, _item.id),
      );
      await _readLibrary();
    } catch (error) {
      if (mounted) _showActionNotice(videoLibraryError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _hasEpisodeDownloads(ApiVideoItem item) =>
      ApiVideoEpisodeDownloads.supportsBatch(_repository) &&
      item.lines.fold<int>(0, (count, line) => count + line.episodes.length) >
          0;

  Future<void> _downloadEpisodes(
    BuildContext appearance, [
    NativePlaybackSession? current,
  ]) async {
    if (_episodeDownloadOpen) return;
    final item = _item;
    final episodes = [
      for (final line in item.lines) ...item.episodeCards(line.id),
    ];
    if (episodes.isEmpty) return;
    setState(() => _episodeDownloadOpen = true);
    try {
      await showVideoEpisodeDownloadPicker(
        appearance,
        systemStyle: AppInterfaceStyleScope.usesSystem(appearance),
        source: _repository.source,
        workId: item.id,
        namespace: _repository.capabilities.itemNamespace,
        episodes: episodes,
        currentWatch:
            current?.watchUrl ??
            _currentWatch ??
            _pendingWatch ??
            episodes.first.watchUrl,
        lineLabels: {for (final line in item.lines) line.id: line.label},
        onEnqueue: (episodes) =>
            ApiVideoEpisodeDownloads.enqueue(_repository, item, episodes),
        onRetry: (episode, row) =>
            ApiVideoEpisodeDownloads.retry(_repository, item, episode, row),
      );
    } catch (error) {
      if (mounted) _showActionNotice(videoLibraryError(error));
    } finally {
      if (mounted) setState(() => _episodeDownloadOpen = false);
    }
  }

  Future<void> _share(BuildContext anchorContext) async {
    if (!anchorContext.mounted) return;
    _clearActionNotice();
    final box = anchorContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final result = await VideoSystemShare.share(
      video: _item.detailUrl,
      title: _item.title,
      anchor: box.localToGlobal(Offset.zero) & box.size,
    );
    if (!mounted) return;
    if (result == VideoShareStatus.failed ||
        result == VideoShareStatus.unavailable) {
      _showActionNotice(t.videoCommunity.shareFailed);
    }
  }

  Future<void> _visit(
    AsyncCallback action,
    Future<void> Function(AsyncCallback)? navigate,
  ) async {
    if (navigate != null) {
      await navigate(action);
      return;
    }
    if (_openingInitialLink) return;
    setState(() => _openingInitialLink = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _openingInitialLink = false);
    }
  }

  Future<void> _comments(
    Uri watch, {
    bool work = false,
    Future<void> Function(AsyncCallback)? navigate,
    Future<void> Function(AsyncCallback)? hold,
  }) async {
    final client = widget.siteClient;
    final id = _item.vodId, episodeId = watch.queryParameters['episode'] ?? '';
    if (client == null || id.isEmpty || (!work && episodeId.isEmpty)) return;
    Future<void> open() async {
      final episode = _item.lines
          .where((l) => l.id == watch.queryParameters['line'])
          .expand((l) => l.episodes)
          .where((e) => e.id == episodeId)
          .firstOrNull;
      final website = episode?.webPlaybackUrls.firstOrNull ?? _item.detailUrl;
      final discussion =
          _item.discussionUrl ?? client.home.resolve('/square.html?vod_id=$id');
      final target = await showOmoDiscussionPanel(
        context,
        client: client,
        network: _repository.network,
        vodId: id,
        episodeId: episodeId,
        website: website,
        discussion: discussion,
        work: work,
      );
      if (target != null && mounted) {
        await _visit(
          () => openOmoSitePage(
            context,
            client,
            network: _repository.network,
            title: t.videoCommunity.comments,
            path: target.path + (target.hasQuery ? '?${target.query}' : ''),
          ),
          navigate,
        );
      }
    }

    if (hold != null) {
      await hold(open);
    } else {
      await open();
    }
  }

  Future<void> _related(ApiVideoItem item) => Navigator.of(context).push<void>(
    videoPageRoute(
      settings: videoDetailRouteSettings(_repository.source),
      networkSource: _repository.source,
      network: _repository.network,
      builder: (_) => ApiVideoDetailPage(
        repository: _repository,
        initialItem: item,
        store: _store,
        siteClient: widget.siteClient,
      ),
    ),
  );

  Future<void> _credit(ApiVideoCredit credit) =>
      Navigator.of(context).push<void>(
        videoPageRoute(
          networkSource: _repository.source,
          network: _repository.network,
          builder: (_) => ApiVideoLibraryPage(
            repository: _repository,
            title: credit.name,
            initialBrowseUrl: credit.url,
            siteClient: widget.siteClient,
          ),
        ),
      );

  ApiVideoItem _playbackDetails(Uri? watch) =>
      _candidateItems[watch] ??
      (watch != null && watch == _currentWatch ? _playbackItem : null) ??
      _item;

  ApiVideoEpisode? _episodeFor(NativePlaybackSession session) =>
      _playbackDetails(session.watchUrl).lines
          .where((line) => line.id == session.watchUrl.queryParameters['line'])
          .firstOrNull
          ?.episodes
          .where(
            (episode) =>
                episode.id == session.watchUrl.queryParameters['episode'],
          )
          .firstOrNull;

  String _lineDetail(Uri? target) {
    if (_resolvingLines.contains(target)) return t.videoSource.lineResolving;
    final result = _lineAttempts[target];
    if (result == null) return t.videoSource.lineUntested;
    final seconds = (result.elapsed.inMilliseconds / 1000).toStringAsFixed(1);
    return result.success
        ? t.videoSource.lineResolved(seconds: seconds)
        : t.videoSource.lineResolveFailed(seconds: seconds);
  }

  List<NativeVideoResourceLine> _resourceLines(NativePlaybackSession session) {
    final current = _episodeFor(session);
    return _item.lines.map((line) {
      final target = current == null
          ? null
          : _item.matchingEpisode(line, current);
      return NativeVideoResourceLine(
        id: line.id,
        label: line.label,
        current: line.id == session.watchUrl.queryParameters['line'],
        resolving: _resolvingLines.contains(target?.watchUrl),
        detail: current == null ? '' : _lineDetail(target?.watchUrl),
        target: _cardFor(target),
      );
    }).toList();
  }

  NativeVideoCard? _cardFor(ApiVideoEpisode? episode) => episode == null
      ? null
      : NativeVideoCard(
          title: episode.title,
          watchUrl: episode.watchUrl,
          coverUrl: _item.coverUrl,
          episodeLabel: episode.title,
        );

  Future<void> _resolutionAnalysis() => showApiResolutionAnalysis(
    context,
    source: _repository.source,
    lineCount: _item.lines.length,
    attempts: _resolutionReport(),
    trace: _playbackTrace,
    recheck: () async {
      final target =
          _currentWatch ??
          _pendingWatch ??
          _item.lines.firstOrNull?.episodes.firstOrNull?.watchUrl;
      if (target != null) {
        try {
          await _resolve(
            target,
            refresh: true,
          ).timeout(const Duration(seconds: 30));
        } catch (_) {}
      }
      return _resolutionReport();
    },
  );

  List<String> _resolutionReport() => [
    for (var i = 0; i < _item.lines.length; i++)
      for (final episode in _item.lines[i].episodes.where(
        (episode) => _lineAttempts.containsKey(episode.watchUrl),
      ))
        'line_${i + 1}: ${_lineDetail(episode.watchUrl)}; result: ${_resolutionErrors[episode.watchUrl] ?? 'resolved'}',
  ];

  Future<void> _website() async {
    final session = _initialSession;
    final episode = session == null ? null : _episodeFor(session);
    final selected =
        _item.lines
            .expand((line) => line.episodes)
            .where(
              (episode) => episode.watchUrl == (_currentWatch ?? _pendingWatch),
            )
            .firstOrNull ??
        episode;
    final target = selected?.webPlaybackUrls.firstOrNull ?? _item.detailUrl;
    await context.pushRoute(
      WebViewRoute(info: [_item.title, target.toString()]),
    );
  }

  Future<void> _webPlayers(
    BuildContext appearance,
    NativePlaybackSession session,
  ) async {
    final urls = _episodeFor(session)?.webPlaybackUrls ?? const <Uri>[];
    final target = await showVideoTaskSheet<Uri>(
      context: appearance,
      systemStyle: AppInterfaceStyleScope.usesSystem(appearance),
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(t.videoPlayback.webPlayers),
            subtitle: Text(t.videoPlayback.sameResource),
          ),
          for (var i = 0; i < urls.length; i++)
            ListTile(
              leading: const Icon(Icons.open_in_browser_outlined),
              title: Text(
                i == 0
                    ? t.videoPlayback.openWebsitePlayer
                    : t.videoPlayback.backupWebPlayer,
              ),
              subtitle: Text(urls[i].host),
              onTap: () => Navigator.of(sheet).pop(urls[i]),
            ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(t.videoLibrary.openWebsite),
            onTap: () => Navigator.of(sheet).pop(_item.detailUrl),
          ),
        ],
      ),
    );
    if (mounted && target != null) {
      await context.pushRoute(
        WebViewRoute(info: [_item.title, target.toString()]),
      );
    }
  }

  Future<void> _initialSelection(
    BuildContext appearance, {
    bool linesOnly = false,
  }) async {
    // Browsing or dismissing a picker does not take ownership of recovery.
    // Only an explicit target selection starts a new resolution generation.
    final current = _item.lines
        .expand((l) => l.episodes)
        .where((e) => e.watchUrl == _pendingWatch)
        .firstOrNull;
    final selectedLine =
        _item.lines
            .where((l) => l.id == _pendingWatch?.queryParameters['line'])
            .firstOrNull ??
        _item.lines.firstOrNull;
    if (selectedLine == null) return;
    var sequence =
        _initialEpisodeSequence?.reconciled(
          _item.episodeCards(selectedLine.id),
        ) ??
        VideoEpisodeSequence(_item.episodeCards(selectedLine.id));
    if (sequence.items.isEmpty || _initialPickerGate != null) return;
    final gate = _initialPickerGate = Completer<void>();
    Uri? target;
    try {
      target = await showVideoSelectionPanel<Uri>(
        context: appearance,
        purpose: linesOnly
            ? VideoPanelPurpose.sources
            : VideoPanelPurpose.episodes,
        systemStyle: AppInterfaceStyleScope.usesSystem(appearance),
        title: linesOnly ? t.videoPlayback.source : t.videoPlayback.episodes,
        builder: (sheet) => ValueListenableBuilder<int>(
          valueListenable: _lineChanges,
          builder: (_, _, _) => StatefulBuilder(
            builder: (_, update) => linesOnly
                ? ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 16),
                    children: [
                      for (final line in _item.lines)
                        Builder(
                          builder: (_) {
                            final episode = current == null
                                ? null
                                : _item.matchingEpisode(line, current);
                            return ListTile(
                              key: ValueKey('api-initial.line.${line.id}'),
                              title: Text(line.label),
                              selected:
                                  _pendingWatch?.queryParameters['line'] ==
                                  line.id,
                              trailing:
                                  _pendingWatch?.queryParameters['line'] ==
                                      line.id
                                  ? const Icon(Icons.check_rounded)
                                  : null,
                              subtitle: Text(
                                episode == null
                                    ? t.videoPlayback.episodeMissingOnLine
                                    : _lineDetail(episode.watchUrl),
                              ),
                              subtitleTextStyle: Theme.of(
                                sheet,
                              ).textTheme.bodySmall,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 2,
                              ),
                              onTap: episode == null
                                  ? null
                                  : () => Navigator.of(
                                      sheet,
                                    ).pop(episode.watchUrl),
                            );
                          },
                        ),
                    ],
                  )
                : VideoEpisodePicker(
                    sequence: sequence,
                    current: _pendingWatch ?? sequence.items.first.watchUrl,
                    onChanged: (next) {
                      update(() => sequence = next);
                      _initialEpisodeSequence = next;
                    },
                    onSelected: (card) =>
                        Navigator.of(sheet).pop(card.watchUrl),
                  ),
          ),
        ),
      );
      if (mounted && target != null) {
        unawaited(_prepareInitial(target, automatic: false));
      }
    } finally {
      if (identical(_initialPickerGate, gate)) _initialPickerGate = null;
      if (!gate.isCompleted) gate.complete();
    }
  }

  Widget _favoriteIcon({bool light = false}) => NativeVideoIconButton(
    light: light,
    tooltip: _library == null
        ? t.common.retry
        : _library?.contains(_repository.source, _item.id) == true
        ? t.videoLibrary.saved
        : t.videoLibrary.addFavorite,
    symbol: _library == null
        ? 'arrow.clockwise'
        : _library?.contains(_repository.source, _item.id) == true
        ? 'star.fill'
        : 'star',
    icon: _library == null
        ? Icons.refresh_rounded
        : _library?.contains(_repository.source, _item.id) == true
        ? Icons.star_rounded
        : Icons.star_outline_rounded,
    onPressed: _saving
        ? null
        : _library == null
        ? _readLibrary
        : _favorite,
  );
  @override
  Widget build(BuildContext context) => SourceExperienceBoundary(
    source: _repository.source,
    builder: (context) => VideoNetworkScope(
      source: _repository.source,
      network: _repository.network,
      child: _buildPage(context),
    ),
  );

  Widget _buildPage(BuildContext context) {
    final session = _initialSession;
    if (session == null || _openingInitialLink) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: VideoPageSafeArea(
          // Match Scaffold's body-before-native-AppBar paint order. The native
          // back view keeps its geometry/state and paints after all details,
          // so it cannot split the incoming Flutter body into a later slice.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final desiredHeight = (constraints.maxWidth * 9 / 16).clamp(
                MediaQuery.textScalerOf(context).scale(14) > 22 ? 240.0 : 0.0,
                double.infinity,
              );
              // A short landscape viewport must still leave a scrollable detail
              // area. Ordinary portrait keeps its natural 16:9 video height.
              final videoHeight = desiredHeight.clamp(
                0.0,
                constraints.maxHeight * .6,
              );
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    children: [
                      SizedBox(
                        height: videoHeight,
                        width: double.infinity,
                        child: ColoredBox(
                          color: Colors.black,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Positioned.fill(
                                child: GestureDetector(
                                  key: const ValueKey(
                                    'api-initial.gesture-surface',
                                  ),
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _initialDetailPending
                                      ? null
                                      : () => setState(
                                          () => _preparingControlsVisible =
                                              !_preparingControlsVisible,
                                        ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                              if (!_initialDetailPending)
                                Positioned.fill(
                                  top: 60,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onTap: () => setState(
                                      () => _preparingControlsVisible =
                                          !_preparingControlsVisible,
                                    ),
                                    child: Center(
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (_preparing ||
                                                _detailsLoading) ...[
                                              const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                              const SizedBox(height: 12),
                                            ],
                                            Text(
                                              _detailsFailed
                                                  ? t
                                                        .videoLibrary
                                                        .refreshDetails
                                                  : _failed
                                                  ? _initialCancelled
                                                        ? t
                                                              .videoSource
                                                              .lineCancelled
                                                        : _historyEpisodeUnavailable
                                                        ? (Localizations.localeOf(
                                                                    context,
                                                                  ).languageCode ==
                                                                  'zh'
                                                              ? '这条记录的剧集暂不可用'
                                                              : 'The episode for this record is unavailable.')
                                                        : t
                                                              .videoPlayback
                                                              .playFailed
                                                  : _preparing
                                                  ? t
                                                        .videoPlayback
                                                        .preparingMedia
                                                  : _detailsLoading
                                                  ? t.common.loading
                                                  : widget.forDownloadRecovery &&
                                                        _hasEpisodeDownloads(
                                                          _item,
                                                        )
                                                  ? t
                                                        .download
                                                        .downloadRecoverySelect
                                                  : t
                                                        .videoLibrary
                                                        .mediaUnavailable,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                            if (_preparing &&
                                                _initialTotal > 1) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                t.videoSource.autoSwitchAttempt(
                                                  line: _initialLineLabel,
                                                  current: _initialAttempt,
                                                  total: _initialTotal,
                                                ),
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ],
                                            if (_preparing &&
                                                _preparingControlsVisible)
                                              TextButton(
                                                key: const ValueKey(
                                                  'api-initial.cancel',
                                                ),
                                                onPressed: _cancelInitial,
                                                child: Text(t.common.cancel),
                                              ),
                                            if (_failed && !_initialCancelled)
                                              TextButton(
                                                key: const ValueKey(
                                                  'api-initial.analysis',
                                                ),
                                                onPressed: _resolutionAnalysis,
                                                child: Text(
                                                  t
                                                      .videoPlayback
                                                      .playbackAnalysis,
                                                ),
                                              ),
                                            if (_detailsFailed ||
                                                _failed ||
                                                (!_preparing &&
                                                    !_detailsLoading))
                                              Wrap(
                                                alignment: WrapAlignment.center,
                                                spacing: 12,
                                                children: [
                                                  if (_detailsFailed ||
                                                      _pendingWatch != null)
                                                    TextButton(
                                                      onPressed: _detailsFailed
                                                          ? () => _load(
                                                              refresh: true,
                                                            )
                                                          : () =>
                                                                _prepareInitial(
                                                                  _pendingWatch!,
                                                                ),
                                                      child: Text(
                                                        widget.forDownloadRecovery &&
                                                                !_detailsFailed &&
                                                                !_failed
                                                            ? t
                                                                  .videoPlayback
                                                                  .play
                                                            : t.common.retry,
                                                      ),
                                                    ),
                                                  TextButton(
                                                    onPressed: _website,
                                                    child: Text(
                                                      t
                                                          .videoLibrary
                                                          .openWebsite,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: ColoredBox(
                          color: Theme.of(context).colorScheme.surface,
                          child: _detailArea(
                            context,
                            null,
                            tools: _item.lines.isEmpty
                                ? null
                                : _detailPlaybackTools(
                                    context,
                                    openEpisodes: () =>
                                        _initialSelection(context),
                                    openSources: () => _initialSelection(
                                      context,
                                      linesOnly: true,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: IgnorePointer(
                      ignoring: !_preparingControlsVisible,
                      child: AnimatedOpacity(
                        opacity: _preparingControlsVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: NativeVideoIconButton(
                          key: const ValueKey('api-initial.back'),
                          light: true,
                          tooltip: t.common.back,
                          symbol: 'chevron.left',
                          icon: Icons.chevron_left_rounded,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    }
    return NativeVideoPage(
      key: ValueKey('api-player.${_item.id}'),
      initialControlsVisible: _preparingControlsVisible,
      session: session,
      initialEpisodeSequence: _initialEpisodeSequence,
      initialProgressWatch: _initialProgressWatch,
      networkContext: _repository.networkContext,
      playerFactory: _repository.networkContext == null
          ? null
          : (source) =>
                _repository.networkContext!.player(source.url, source.headers),
      source: _repository.source,
      downloadAdapter: VideoPlaybackDownloadAdapter.new,
      onDownloadEpisodes: _hasEpisodeDownloads(_item)
          ? (current) => _downloadEpisodes(context, current)
          : null,
      downloadSourceDuration: (current) {
        final item = _playbackDetails(current.watchUrl);
        final page = videoPublicPage(current.watchUrl);
        return page != null &&
                item.detailUrl.origin == page.origin &&
                item.detailUrl.path == page.path
            ? item.sourceDuration
            : null;
      },
      historyMetadata: (current) {
        final item = _playbackDetails(current.watchUrl);
        final page = videoPublicPage(current.watchUrl);
        return page != null &&
                item.detailUrl.origin == page.origin &&
                item.detailUrl.path == page.path
            ? VideoWatchRecord.metadataFromItem(item)
            : const {};
      },
      onOpenWebsite: _website,
      onPlaybackError: (error) {
        _playbackTrace.add('player_error', error);
        _clearActionNotice();
      },
      analyzePlayback: (context, current, error) => showApiPlaybackAnalysis(
        context,
        source: _repository.source,
        session: current,
        lineCount: _item.lines.length,
        network: _repository.networkContext,
        platformError: error,
        trace: _playbackTrace,
      ),
      autoResourceFallback: widget.initialLocalSession == null,
      onResolutionCancelled: _cancelResolution,
      recoverCurrentResource:
          widget.initialLocalSession == null &&
              _repository.capabilities.rawHlsRecovery
          ? (current) async => (await _resolve(
              current.watchUrl,
              refresh: true,
              rawHlsRecovery: true,
            )).session
          : null,
      resourceLines: _resourceLines,
      extraFailureActions: (context, current, select) => [
        if ((_episodeFor(current)?.webPlaybackUrls.length ?? 0) > 1)
          TextButton(
            onPressed: () => _webPlayers(context, current),
            child: Text(t.videoPlayback.webPlayers),
          ),
      ],
      loadEpisode: (target) => _loadEpisode(target),
      refreshSession: () async =>
          (await _loadEpisode(_currentWatch!, refresh: true)).session,
      onEpisodeChanged: (loaded) {
        if (mounted) {
          setState(() {
            _currentWatch = loaded.session.watchUrl;
            _playbackItem = _candidateItems.remove(_currentWatch);
          });
        }
      },
      extraPlayerActions: (context, current, navigate, hold) => [
        if (widget.siteClient != null && _item.vodId.isNotEmpty)
          NativeVideoIconButton(
            light: true,
            tooltip: t.videoCommunity.comments,
            symbol: 'text.bubble',
            icon: Icons.chat_bubble_outline_rounded,
            onPressed: () =>
                _comments(current.watchUrl, navigate: navigate, hold: hold),
          ),
        ListenableBuilder(
          listenable: _store,
          builder: (_, _) => _favoriteIcon(light: true),
        ),
        Builder(
          builder: (anchor) => NativeVideoIconButton(
            light: true,
            tooltip: t.videoCommunity.share,
            symbol: 'arrowshape.turn.up.right',
            icon: Icons.reply_rounded,
            mirrorFallbackIcon: true,
            onPressed: () => _share(anchor),
          ),
        ),
      ],
      detailToolsBuilder: (episodes, sources) => _detailPlaybackTools(
        context,
        openEpisodes: episodes,
        openSources: sources,
      ),
      detailBuilder: (context, current, navigate, hold, tools) => _detailArea(
        context,
        current,
        navigate: navigate,
        hold: hold,
        tools: _item.lines.isEmpty ? null : tools,
      ),
    );
  }

  Widget _detailPlaybackTools(
    BuildContext context, {
    required VoidCallback openEpisodes,
    required VoidCallback openSources,
  }) {
    final watch = _currentWatch ?? _pendingWatch;
    final line =
        _item.lines
            .where((line) => line.id == watch?.queryParameters['line'])
            .firstOrNull ??
        _item.lines.firstOrNull;
    if (line == null) return const SizedBox.shrink();
    final current = line.episodes
        .where((episode) => episode.watchUrl == watch)
        .firstOrNull;
    final theme = Theme.of(context);
    Widget button(
      String id,
      String label,
      String caption,
      IconData icon,
      VoidCallback press,
    ) => TextButton(
      key: ValueKey('api-initial.$id'),
      style: TextButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurface,
        minimumSize: const Size(44, 48),
        alignment: AlignmentDirectional.centerStart,
      ),
      onPressed: press,
      child: Row(
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: theme.textTheme.labelMedium),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    final episodes = button(
      'episodes',
      t.videoPlayback.episodes,
      current == null
          ? t.videoPlayback.episodeCount(count: line.episodes.length)
          : t.videoPlayback.currentOfTotal(
              current: current.title,
              total: line.episodes.length,
            ),
      Icons.playlist_play_rounded,
      openEpisodes,
    );
    if (_item.lines.length < 2) return episodes;
    final sources = button(
      'lines',
      t.videoPlayback.source,
      line.label,
      Icons.video_settings_outlined,
      openSources,
    );
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth < 340 ||
              MediaQuery.textScalerOf(context).scale(14) > 22
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [episodes, sources],
            )
          : Row(
              children: [
                Expanded(child: episodes),
                Expanded(child: sources),
              ],
            ),
    );
  }

  Widget _detailArea(
    BuildContext context,
    NativePlaybackSession? session, {
    Future<void> Function(AsyncCallback)? navigate,
    Future<void> Function(AsyncCallback)? hold,
    Widget? tools,
  }) {
    return Theme(
      data: videoBrowseTheme(Theme.of(context)),
      child: Builder(
        builder: (context) => _themedDetailArea(
          context,
          session,
          navigate: navigate,
          hold: hold,
          tools: tools,
        ),
      ),
    );
  }

  Widget _themedDetailArea(
    BuildContext context,
    NativePlaybackSession? session, {
    Future<void> Function(AsyncCallback)? navigate,
    Future<void> Function(AsyncCallback)? hold,
    Widget? tools,
  }) {
    if (_initialDetailPending) {
      return Center(
        key: const ValueKey('api-detail.initial-loading'),
        child: Text(
          t.common.loading,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    final client = widget.siteClient;
    if (client == null) {
      return _details(
        context,
        session,
        navigate: navigate,
        hold: hold,
        tools: tools,
      );
    }
    final current = session?.watchUrl ?? _currentWatch ?? _pendingWatch;
    final episodeId = current?.queryParameters['episode'] ?? '';
    final episode = session == null ? null : _episodeFor(session);
    return Column(
      children: [
        Row(
          children: [
            for (final (selected, label) in [
              (false, t.videoLibrary.synopsis),
              (true, t.videoCommunity.comments),
            ])
              Expanded(
                child: Semantics(
                  selected: _commentTab == selected,
                  child: TextButton(
                    key: ValueKey(
                      selected
                          ? 'api-detail.comments'
                          : 'api-detail.description',
                    ),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      foregroundColor: _commentTab == selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => _selectDetailTab(selected),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label),
                        const SizedBox(height: 5),
                        AnimatedContainer(
                          duration: VideoMotion.feedback(context),
                          curve: Curves.easeOutCubic,
                          height: 2,
                          width: 28,
                          color: _commentTab == selected
                              ? Theme.of(context).colorScheme.primary
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
          child: VideoDetailSections(
            commentsSelected: _commentTab,
            onSelected: _selectDetailTab,
            onPrepareComments: _prepareDetailComments,
            children: [
              _details(
                context,
                session,
                navigate: navigate,
                hold: hold,
                tools: tools,
              ),
              _commentsMounted && _item.vodId.isNotEmpty && episodeId.isNotEmpty
                  ? OmoDiscussionPanel(
                      client: client,
                      vodId: _item.vodId,
                      episodeId: episodeId,
                      website:
                          episode?.webPlaybackUrls.firstOrNull ??
                          _item.detailUrl,
                      discussion:
                          _item.discussionUrl ??
                          client.home.resolve(
                            '/square.html?vod_id=${_item.vodId}',
                          ),
                      embedded: true,
                      work: episodeId.isEmpty,
                      onWebsite: (url) => unawaited(
                        _visit(
                          () => openOmoSitePage(
                            context,
                            client,
                            network: _repository.network,
                            title: t.videoCommunity.comments,
                            path:
                                url.path +
                                (url.hasQuery ? '?${url.query}' : ''),
                          ),
                          navigate,
                        ),
                      ),
                    )
                  : _commentsMounted
                  ? Center(child: Text(t.videoCommunity.unsupported))
                  : const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }

  void _prepareDetailComments() {
    if (_commentsMounted || !mounted) return;
    setState(() => _commentsMounted = true);
  }

  void _selectDetailTab(bool comments) {
    if (_commentTab == comments || !mounted) return;
    setState(() {
      _commentTab = comments;
      if (comments) _commentsMounted = true;
    });
  }

  Widget _details(
    BuildContext context,
    NativePlaybackSession? session, {
    Future<void> Function(AsyncCallback)? navigate,
    Future<void> Function(AsyncCallback)? hold,
    Widget? tools,
  }) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    final saved = _library?.contains(_repository.source, _item.id) == true;
    const creditTextPadding = 12.0;
    Widget labeled(
      String label,
      Widget value, {
      bool interactive = false,
    }) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: MediaQuery.textScalerOf(context).scale(14) > 20
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                value,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 76,
                  // Name targets retain their full vertical padding. Match
                  // the label to the first text line, not the target's edge.
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: interactive ? creditTextPadding : 0,
                    ),
                    child: Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                Expanded(child: value),
              ],
            ),
    );
    Widget info(String label, String value) => labeled(
      label,
      SelectableText(value, style: theme.textTheme.bodyMedium),
    );
    String sourceDate(String value) {
      if (!RegExp(r'^\d{10}(?:\d{3})?$').hasMatch(value)) return value;
      final n = int.parse(value);
      return DateFormat('yyyy-MM-dd HH:mm').format(
        DateTime.fromMillisecondsSinceEpoch(value.length == 10 ? n * 1000 : n),
      );
    }

    Widget detailActionButton({
      required String id,
      required String label,
      required IconData icon,
      required VoidCallback? onPressed,
      String? hint,
      bool? selected,
      bool busy = false,
      VoidCallback? onLongPress,
    }) {
      final style = TextButton.styleFrom(
        minimumSize: const Size(44, 56),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        foregroundColor: selected == true
            ? colors.primary
            : colors.onSurfaceVariant,
      );
      return Semantics(
        selected: selected,
        hint: hint,
        child: TouchHoverIntent(
          key: ValueKey('api-detail.action-host.$id'),
          identity: id,
          builder: (context, hover) => TextButton(
            key: ValueKey('api-detail.$id'),
            style: style.copyWith(
              overlayColor: hover.overlayColor(style.overlayColor),
            ),
            onPressed: onPressed,
            onLongPress: onLongPress,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: busy
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : AnimatedSwitcher(
                          duration: VideoMotion.feedback(context),
                          child: Icon(icon, key: ValueKey(icon), size: 20),
                        ),
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        MediaQuery.textScalerOf(
                          context,
                        ).scale(theme.textTheme.labelMedium?.fontSize ?? 12) *
                        (theme.textTheme.labelMedium?.height ?? 1.4) *
                        2,
                  ),
                  child: Center(
                    child: DefaultTextStyle(
                      style: theme.textTheme.labelMedium!.copyWith(
                        color: selected == true
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                      child: VideoFeedbackLabel(label),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget detailAction({
      required String id,
      required String label,
      required IconData icon,
      required VoidCallback? onPressed,
      String? hint,
      bool? selected,
      bool busy = false,
      VoidCallback? onLongPress,
    }) => Expanded(
      child: detailActionButton(
        id: id,
        label: label,
        icon: icon,
        onPressed: onPressed,
        hint: hint,
        selected: selected,
        busy: busy,
        onLongPress: onLongPress,
      ),
    );

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
        ),
        if (_item.summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _item.summary.join(' · '),
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
        if (_item.remarks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_item.remarks, style: theme.textTheme.titleSmall),
          ),
      ],
    );
    Widget credits(String role, String title) {
      final people = _item.credits.where((c) => c.role == role).toList();
      final expanded = _expandedCreditRoles.contains(role);
      Widget names(Iterable<ApiVideoCredit> entries) => Wrap(
        spacing: 12,
        children: [
          for (final person in entries)
            TextButton(
              onPressed: () => _visit(() => _credit(person), navigate),
              style: TextButton.styleFrom(
                minimumSize: const Size(44, 44),
                alignment: AlignmentDirectional.topStart,
                padding: const EdgeInsets.symmetric(
                  vertical: creditTextPadding,
                ),
                textStyle: theme.textTheme.bodyMedium,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(person.name, textAlign: TextAlign.start),
            ),
        ],
      );
      return labeled(
        title,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              key: ValueKey('api-detail.credits.$role.names'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                names(people.take(6)),
                if (people.length > 6)
                  VideoDisclosureRegion(
                    expanded: expanded,
                    child: names(people.skip(6)),
                  ),
              ],
            ),
            if (people.length > 6)
              MergeSemantics(
                key: ValueKey('api-detail.credits.$role.toggle'),
                child: Semantics(
                  label: title,
                  expanded: expanded,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      if (expanded) {
                        _expandedCreditRoles.remove(role);
                      } else {
                        _expandedCreditRoles.add(role);
                      }
                    }),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      foregroundColor: colors.onSurfaceVariant,
                      textStyle: theme.textTheme.bodyMedium,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: VideoDisclosureIndicator(
                      expanded: expanded,
                      size: 18,
                    ),
                    label: Text(
                      expanded
                          ? t.videoLibrary.fewerCredits
                          : t.videoLibrary.moreCredits,
                    ),
                  ),
                ),
              ),
          ],
        ),
        interactive: true,
      );
    }

    final available =
        _item.lines
            .where(
              (line) =>
                  line.id ==
                  (session?.watchUrl ?? _pendingWatch)?.queryParameters['line'],
            )
            .firstOrNull
            ?.episodes
            .length ??
        0;
    return ListView(
      key: PageStorageKey('api-detail.${_item.id}'),
      controller: _detailScroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        if (_item.lines.length == 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              t.videoPlayback.singleResourceLine,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        if (_repository.capabilities.animePresentation &&
            _item.coverUrl != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 96,
                  child: VideoCoverOverlay(
                    durationText: videoCoverDurationText(
                      _item.sourceDuration,
                      clockFallback: _item.remarks,
                    ),
                    child: VideoThumbnail(
                      url: '${_item.coverUrl}',
                      referrer: _item.detailUrl,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: heading),
            ],
          )
        else
          heading,
        const SizedBox(height: 12),
        if (tools != null) ...[
          DecoratedBox(
            key: const ValueKey('api-detail.playback-tools'),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: tools,
          ),
          const SizedBox(height: 8),
        ],
        IntrinsicHeight(
          child: Row(
            key: const ValueKey('api-detail.actions'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              detailAction(
                id: 'favorite',
                label: _library == null
                    ? t.common.retry
                    : saved
                    ? t.videoLibrary.saved
                    : t.videoLibrary.addFavorite,
                hint: widget.siteClient != null
                    ? t.videoSource.localFavorites
                    : null,
                icon: _library == null
                    ? Icons.refresh_rounded
                    : saved
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                selected: _library == null ? null : saved,
                busy: _saving,
                onPressed: _saving
                    ? null
                    : _library == null
                    ? _readLibrary
                    : _favorite,
                onLongPress: _saving || _library == null
                    ? null
                    : () => unawaited(_editFavoriteFolders()),
              ),
              if (_hasEpisodeDownloads(_item))
                detailAction(
                  id: 'download',
                  label: t.videoDownload.title,
                  icon: Icons.download_outlined,
                  busy: _episodeDownloadOpen,
                  onPressed: _episodeDownloadOpen
                      ? null
                      : () => unawaited(_downloadEpisodes(context)),
                ),
              Expanded(
                child: Builder(
                  builder: (anchor) => detailActionButton(
                    id: 'share',
                    label: t.videoCommunity.share,
                    icon: Icons.ios_share_rounded,
                    onPressed: () => _share(anchor),
                  ),
                ),
              ),
            ],
          ),
        ),
        VideoSizeTransition(
          alignment: Alignment.topCenter,
          child: _actionNotice == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: VideoActionNotice(
                    message: _actionNotice!,
                    onClose: _clearActionNotice,
                  ),
                ),
        ),
        if (_item.sourceViews != null || _item.sourceRating != null) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              if (_item.sourceViews != null)
                Text(
                  _item.sourceViewsAreClicks
                      ? t.videoLibrary.sourceClicks(count: _item.sourceViews!)
                      : t.videoLibrary.sourceViews(count: _item.sourceViews!),
                  style: theme.textTheme.bodySmall,
                ),
              if (_item.sourceRating case final score?)
                Text(switch (_item.sourceRatingDisplayCount) {
                  final count? => t.videoLibrary.sourceRating(
                    score: score,
                    count: count,
                  ),
                  null => t.videoLibrary.sourceRatingOnly(score: score),
                }, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
        if (_item.doubanScore != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Tooltip(
              message: t.videoLibrary.ratingSourceHint,
              child: TextButton.icon(
                onPressed: () => _visit(
                  () => context.pushRoute(
                    WebViewRoute(
                      info: [
                        '豆瓣',
                        'https://movie.douban.com/subject/${_item.doubanId}/',
                      ],
                    ),
                  ),
                  navigate,
                ),
                icon: const Icon(Icons.star_rounded, size: 18),
                label: Text(
                  t.videoLibrary.doubanRating(score: _item.doubanScore!),
                ),
              ),
            ),
          ),
        const SizedBox(height: 20),
        Text(t.videoLibrary.synopsis, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        VideoSizeTransition(
          alignment: AlignmentDirectional.topStart,
          child: Text(
            _item.description.isEmpty
                ? (_detailsLoading
                      ? t.common.loading
                      : t.videoLibrary.noSynopsis)
                : _item.description,
            maxLines: _expanded ? null : 5,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ),
        if (_item.description.length > 140)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: VideoDisclosureIndicator(expanded: _expanded, size: 18),
              label: Text(
                _expanded
                    ? t.videoPlayback.collapseDescription
                    : t.videoPlayback.expandDescription,
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (_item.alternateTitle.isNotEmpty &&
            _item.alternateTitle != _item.title)
          info(t.videoLibrary.alternateTitle, _item.alternateTitle),
        if (_item.genres.isNotEmpty) info(t.videoLibrary.genres, _item.genres),
        if (_item.credits.any((c) => c.role == 'director'))
          credits('director', t.videoLibrary.director)
        else if (_item.directors.isNotEmpty)
          info(t.videoLibrary.director, _item.directors),
        if (_item.writers.isNotEmpty)
          info(t.videoLibrary.writers, _item.writers),
        if (_item.credits.any((c) => c.role == 'voice'))
          credits('voice', t.videoLibrary.voiceCast)
        else if (_item.actors.isNotEmpty)
          info(
            _repository.capabilities.animePresentation
                ? t.videoLibrary.voiceCast
                : t.videoLibrary.starring,
            _item.actors,
          ),
        if (_item.language.isNotEmpty)
          info(t.videoLibrary.language, _item.language),
        if (_item.sourceDuration.isNotEmpty)
          info(t.videoSource.sourceDuration, _item.sourceDuration),
        if (_item.sourceVersion.isNotEmpty)
          info(t.videoSource.sourceVersion, _item.sourceVersion),
        if (_item.sourceStatus.isNotEmpty &&
            _item.sourceStatus != _item.remarks)
          info(t.videoSource.sourceStatus, _item.sourceStatus),
        if (_item.sourceAddedAt.isNotEmpty)
          info(t.videoSource.sourceAddedAt, sourceDate(_item.sourceAddedAt)),
        if (_item.sourceCounters.isNotEmpty)
          info(
            t.videoSource.sourceCounters,
            [
              if (_item.sourceCounters['day'] case final day?)
                t.videoSource.dayViews(count: day),
              if (_item.sourceCounters['week'] case final week?)
                t.videoSource.weekViews(count: week),
              if (_item.sourceCounters['month'] case final month?)
                t.videoSource.monthViews(count: month),
            ].join(' · '),
          ),
        if (_item.releaseDate.isNotEmpty)
          info(t.videoLibrary.released, _item.releaseDate),
        if (_item.updatedAt.isNotEmpty)
          info(t.videoLibrary.resourceUpdated, _item.updatedAt),
        if (available > 0)
          info(
            t.videoLibrary.allEpisodes,
            [
              t.videoLibrary.availableEpisodes(count: available),
              if (_item.plannedEpisodes > available)
                t.videoLibrary.plannedEpisodes(count: _item.plannedEpisodes),
            ].join(' · '),
          ),
        if (_item.related.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(t.videoPlayback.related, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(14) > 20 ? 272 : 244,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _item.related.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, index) {
                final item = _item.related[index];
                return SizedBox(
                  width: 128,
                  child: InkWell(
                    onTap: () => _visit(() => _related(item), navigate),
                    borderRadius: BorderRadius.circular(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 128,
                            height: 192,
                            child: VideoCoverOverlay(
                              durationText: videoCoverDurationText(
                                item.sourceDuration,
                                clockFallback: item.remarks,
                              ),
                              child: VideoThumbnail(
                                url: item.coverUrl?.toString() ?? '',
                                referrer: item.detailUrl,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => _visit(
              () => context.pushRoute(
                WebViewRoute(info: [_item.title, _item.detailUrl.toString()]),
              ),
              navigate,
            ),
            icon: const Icon(Icons.open_in_browser, size: 20),
            label: Text(t.videoLibrary.openWebsite),
          ),
        ),
      ],
    );
  }
}
