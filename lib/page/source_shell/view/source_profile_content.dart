import 'package:auto_route/auto_route.dart' show AutoRoutePage;
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/service/read_recovery.dart';
import 'package:zephyr/widgets/read_recovery_scope.dart';
import 'package:zephyr/widgets/pull_refresh_feedback.dart';
import 'dart:async';
import 'package:zephyr/page/comic_list/cubit/jm_collection_snapshots.dart';
import 'package:zephyr/page/source_shell/view/jm_collection_toolbar.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/service/plugin_account_profiles.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/page/account/plugin_saved_accounts_page.dart';
import 'package:zephyr/page/account/plugin_account_avatar_button.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/source_shell/models/source_video_module.dart';
import 'package:zephyr/page/source_shell/view/source_profile_video_records.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/page/bookshelf/cubit/bookshelf_search_cubit.dart';
import 'package:zephyr/page/bookshelf/cubit/search_status.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/widgets/folder_shelf_page.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_layout.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/source_shell/models/source_cloud_favorites.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/page/source_shell/source_website.dart';
import 'package:zephyr/page/source_shell/models/source_checkin_status.dart';
import 'package:zephyr/page/source_shell/models/source_profile_avatar.dart';
import 'package:zephyr/page/source_shell/models/source_profile_records.dart';
import 'package:zephyr/page/source_shell/view/source_profile_records_view.dart';
import 'package:zephyr/page/source_shell/view/source_notifications_view.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/widgets/local_appearance_image_picker.dart';
import 'package:zephyr/widgets/user_image_editor.dart';

enum _ProfileAccountAction { avatar, bio, website, switchAccount }

/// Lets the source shell treat profile subviews as navigation destinations.
class SourceProfileBackController extends ChangeNotifier {
  final jmHeader = JmCollectionHeaderController();
  @override
  void dispose() {
    jmHeader.dispose();
    super.dispose();
  }

  ValueGetter<String>? _backLabel;
  ValueGetter<String>? _title;
  VoidCallback? _onBack;

  String? get backLabel => _backLabel?.call();
  String? get title => _title?.call();
  bool get canGoBack => _onBack != null;

  void update({
    ValueGetter<String>? backLabel,
    ValueGetter<String>? title,
    VoidCallback? onBack,
  }) {
    _backLabel = backLabel;
    _title = title;
    _onBack = onBack;
    notifyListeners();
  }

  void goBack() => _onBack?.call();
}

class SourceProfileContent extends StatelessWidget {
  const SourceProfileContent({
    super.key,
    required this.source,
    this.sourceName = '',
    this.videoModules = const [],
    this.accountSettingsEnabled = true,
    this.cloudFavoriteFunction = '',
    this.legacySources = const [],
    this.avatarUploadFunction = '',
    this.bioUpdateFunction = '',
    this.profileKind = '',
    this.checkinFunction = '',
    this.notificationsFunction = '',
    this.checkinStatusFunction = '',
    this.checkinStatusSource = 'serverCalendar',
    this.markNotificationReadFunction = '',
    this.markNotificationsReadFunction = '',
    this.backController,
    required this.onLogin,
    this.onAddAccount,
    required this.onSettings,
    required this.onCloudFavorite,
  });

  final String source;
  final String sourceName;
  final List<SourceVideoModule> videoModules;
  final bool accountSettingsEnabled;
  final String cloudFavoriteFunction;
  final List<String> legacySources;
  final String avatarUploadFunction;
  final String bioUpdateFunction;
  final String profileKind;
  final String checkinFunction;
  final String notificationsFunction;
  final String checkinStatusFunction;
  final String checkinStatusSource;
  final String markNotificationReadFunction;
  final String markNotificationsReadFunction;
  final SourceProfileBackController? backController;
  final Future<void> Function() onLogin;
  final Future<void> Function()? onAddAccount;
  final Future<void> Function() onSettings;
  final Future<void> Function() onCloudFavorite;

  @override
  Widget build(BuildContext context) {
    final search = SearchStatusState(
      sources: {source, ...legacySources}.toList(),
    );
    return BlocProvider(
      create: (_) => BookshelfSearchCubit(
        favorite: search,
        history: search,
        download: search,
      ),
      child: _ProfileBody(
        key: ValueKey(source),
        source: source,
        sourceName: sourceName,
        videoModules: videoModules,
        accountSettingsEnabled: accountSettingsEnabled,
        cloudFavoriteFunction: cloudFavoriteFunction,
        sources: search.sources,
        avatarUploadFunction: avatarUploadFunction,
        bioUpdateFunction: bioUpdateFunction,
        profileKind: profileKind,
        checkinFunction: checkinFunction,
        notificationsFunction: notificationsFunction,
        checkinStatusFunction: checkinStatusFunction,
        checkinStatusSource: checkinStatusSource,
        markNotificationReadFunction: markNotificationReadFunction,
        markNotificationsReadFunction: markNotificationsReadFunction,
        backController: backController,
        onLogin: onLogin,
        onAddAccount: onAddAccount ?? onLogin,
        onSettings: onSettings,
        onCloudFavorite: onCloudFavorite,
      ),
    );
  }
}

class _Account {
  const _Account(
    this.name,
    this.level,
    this.title,
    this.slogan,
    this.avatarUrl,
    this.avatarPath,
    this.coin,
    this.experience,
    this.nextLevelExperience,
    this.id,
    this.avatarChangeNotice,
  );
  final String name;
  final int? level;
  final String title;
  final String slogan;
  final String avatarUrl;
  final String avatarPath;
  final String coin;
  final String experience;
  final String nextLevelExperience;
  final String id;
  final String avatarChangeNotice;

  factory _Account.fromResponse(Map<String, dynamic> response) {
    final data = asJsonMap(response['data']);
    final extern = asJsonMap(data['extern']);
    final avatar = asJsonMap(data['avatar']);
    final lines = asJsonList(data['lines']);
    final fallbackName = lines.isEmpty
        ? ''
        : lines.first.toString().split(' (').first;
    return _Account(
      (extern['name']?.toString() ?? fallbackName).trim(),
      extern['level'] is num
          ? (extern['level'] as num).toInt()
          : int.tryParse(extern['level']?.toString() ?? ''),
      (extern['title']?.toString() ?? '').trim(),
      (extern['slogan'] is String ? extern['slogan'] as String : '').trim(),
      (avatar['url']?.toString() ?? '').trim(),
      (avatar['path']?.toString() ?? '').trim(),
      (extern['coin']?.toString() ?? '').trim(),
      (extern['experience']?.toString() ?? '').trim(),
      (extern['nextLevelExperience']?.toString() ?? '').trim(),
      (extern['accountId']?.toString() ??
              extern['userId']?.toString() ??
              extern['id']?.toString() ??
              '')
          .trim(),
      (extern['avatarChangeNotice']?.toString() ?? '').trim(),
    );
  }
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({
    super.key,
    required this.source,
    required this.sourceName,
    required this.videoModules,
    required this.accountSettingsEnabled,
    required this.cloudFavoriteFunction,
    required this.sources,
    required this.avatarUploadFunction,
    required this.bioUpdateFunction,
    required this.profileKind,
    required this.checkinFunction,
    required this.notificationsFunction,
    required this.checkinStatusFunction,
    required this.checkinStatusSource,
    required this.markNotificationReadFunction,
    required this.markNotificationsReadFunction,
    required this.backController,
    required this.onLogin,
    required this.onAddAccount,
    required this.onSettings,
    required this.onCloudFavorite,
  });
  final String source;
  final String sourceName;
  final List<SourceVideoModule> videoModules;
  final bool accountSettingsEnabled;
  final String cloudFavoriteFunction;
  final List<String> sources;
  final String avatarUploadFunction;
  final String bioUpdateFunction;
  final String profileKind;
  final String checkinFunction;
  final String notificationsFunction;
  final String checkinStatusFunction;
  final String checkinStatusSource;
  final String markNotificationReadFunction;
  final String markNotificationsReadFunction;
  final SourceProfileBackController? backController;
  final Future<void> Function() onLogin;
  final Future<void> Function() onAddAccount;
  final Future<void> Function() onSettings;
  final Future<void> Function() onCloudFavorite;
  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  final FolderShelfBackController _folderBackController =
      FolderShelfBackController();
  _Account? _account;
  ShelfPageMode? _mode;
  bool _showVideoRecords = false;
  bool _managingFolders = false;
  SourceProfileRecords _records = const SourceProfileRecords(
    favorites: [],
    history: [],
    downloads: [],
  );
  String? _recordsError;
  List<UnifiedComicListItem> _cloudFavorites = const [];
  int? _cloudTotal;
  int _cloudEpoch = 0;
  bool _cloudReadActive = false;
  bool _profileNeedsIdentityRead = true;
  bool _endpointRefreshPending = false;
  Future<void>? _cloudTask;
  String? _cloudTaskScope;
  String? _cloudTaskOwner;
  String _cloudReadOwner() =>
      '${JmCollectionSnapshots.instance.accountScope(widget.source)}|'
      '${_account?.id}|${pluginSessionWriteFence.generation(widget.source)}';
  late final ReadRecoveryController _cloudRecovery = ReadRecoveryController(
    source: widget.source,
    retry: () => _profileNeedsIdentityRead
        ? _refreshRemoteProfile(automatic: true)
        : _loadCloudFavorites(automatic: true),
  );

  void _setCloudReadActive(bool active) {
    final becameVisible = active && !_cloudReadActive;
    _cloudReadActive = active;
    _cloudRecovery.setActive(active);
    if (active && _endpointRefreshPending) {
      _refreshChangedEndpoint();
      return;
    }
    if (becameVisible &&
        !_loading &&
        !_accountSignedOut &&
        _cloudError == null &&
        !JmCollectionSnapshots.instance.isFresh(
          _cloudSnapshotKey,
          widget.source,
        )) {
      _cloudRecovery.invalidate();
    }
  }

  StreamSubscription<PluginSessionBoundary>? _cloudSessionSubscription;
  StreamSubscription<String>? _endpointSubscription;
  StreamSubscription<JmCollectionCommit>? _cloudCommitSubscription;
  StreamSubscription<JmCollectionSnapshotChange>? _cloudSnapshotSubscription;
  String get _cloudSnapshotKey => SourceCloudFavoriteQuery(
    widget.source,
    jmProfile: widget.profileKind == 'jm',
    functionPath: widget.cloudFavoriteFunction,
  ).key;

  void _applyCloudSnapshot(JmCollectionSnapshotChange event) {
    if (!mounted ||
        _accountSignedOut ||
        event.key != _cloudSnapshotKey ||
        !event.mutation ||
        event.observation)
      return;
    _cloudEpoch++;
    if (!JmCollectionSnapshots.instance.requiresRebuild(event.key))
      _cloudRecovery.succeeded();
    setState(() {
      _cloudFavorites = event.state.list
          .take(_cloudFavorites.length > 0 ? _cloudFavorites.length : 20)
          .toList();
      _cloudTotal = event.state.knownTotal;
      _cloudError = null;
      _cloudLoading = false;
    });
  }

  void _onCloudSession(PluginSessionBoundary event) {
    if (!mounted || event.source != widget.source) return;
    _cloudEpoch++;
    _accountEpoch++;
    _profileRefreshEpoch++;
    _noticeEpoch++;
    _profileNeedsIdentityRead = true;
    _endpointRefreshPending = false;
    _cloudTask = null;
    _cloudTaskOwner = null;
    _cloudRecovery.succeeded();
    _setNotificationState(() {
      _account = null;
      _accountSignedOut = false;
      _cloudFavorites = const [];
      _cloudTotal = null;
      _cloudError = null;
      _cloudLoading = true;
      _loading = true;
      _notices = const [];
      _noticeAccountId = null;
      _unreadCount = null;
      _noticeTotal = null;
      _noticeLoading = false;
      _noticeError = null;
      _markingNotices = false;
      _checkinEvidence = null;
      _checkinEvidenceDate = null;
      _checkinStatus = SourceCheckinStatus.forAccount('');
    });
    if (!event.changing) _cloudRecovery.invalidate();
  }

  void _onEndpointChanged(String source) {
    if (!mounted || source != widget.source) return;
    _accountEpoch++;
    _profileRefreshEpoch++;
    _cloudEpoch++;
    _cloudTask = null;
    _cloudTaskOwner = null;
    _profileNeedsIdentityRead = true;
    _cloudRecovery.reset();
    _endpointRefreshPending = true;
    _refreshChangedEndpoint();
  }

  void _refreshChangedEndpoint() {
    if (!_cloudReadActive) return;
    scheduleMicrotask(() {
      if (!mounted ||
          !_cloudReadActive ||
          !_endpointRefreshPending ||
          pluginSessionWriteFence.isChanging(widget.source))
        return;
      _endpointRefreshPending = false;
      unawaited(_refreshRemoteProfile());
    });
  }

  void _onCloudCommit(JmCollectionCommit event) {
    final snapshots = JmCollectionSnapshots.instance;
    if (!mounted ||
        event.source != widget.source ||
        event.generation != pluginSessionWriteFence.generation(widget.source) ||
        event.account != snapshots.accountScope(widget.source) ||
        _accountSignedOut)
      return;
    if (snapshots.read(_cloudSnapshotKey, widget.source) == null ||
        snapshots.requiresRebuild(_cloudSnapshotKey))
      _cloudRecovery.invalidate();
  }

  int _profileRefreshEpoch = 0;
  bool _accountSignedOut = false;
  bool _cloudLoading = true;
  String? _cloudError;
  bool _loading = true;
  bool _openingLogin = false;
  bool _editing = false;
  bool _choosingAvatar = false;
  bool _appearanceBusy = false;
  bool _profileSheetOpen = false;
  bool _checkingIn = false;
  int _accountEpoch = 0;
  SourceCheckinStatus _checkinStatus = SourceCheckinStatus.forAccount('');
  bool get _checkedInToday =>
      _checkinStatus.merge(null, accountId: _account?.id ?? '').checkedIn ==
      true;
  bool _notificationsOpen = false;
  final _notificationChanges = ValueNotifier<int>(0);
  bool _noticeLoading = false;
  String? _noticeError;
  int _noticeEpoch = 0;
  bool _markingNotices = false;
  String? _noticeAccountId;
  int? _unreadCount, _noticeTotal;
  bool _noticesComplete = false;
  List<SourceNotice> _notices = const [];
  bool _checkingStatus = false;
  String Function()? _checkinEvidence;
  String? _checkinEvidenceDate;

  bool _loadFailed = false;
  int _avatarRevision = 0;
  bool get _canOpenAccount =>
      widget.accountSettingsEnabled &&
      !_openingLogin &&
      !_editing &&
      !_choosingAvatar &&
      !_profileSheetOpen &&
      (!_loading || _account != null);

  bool get _brandHero =>
      widget.profileKind == 'bika' ||
      widget.source == 'e9f18928-3ba8-4d86-a12e-b53a62f47933' &&
          widget.profileKind != 'generic' &&
          widget.profileKind != 'jm';
  bool get _genericProfile => !_brandHero && widget.profileKind != 'jm';
  // profileKind is parsed from this source's declared breezeExperience.
  bool get _jmCollections => widget.profileKind == 'jm';
  bool get _copyAvatarPolicy =>
      widget.source == PluginAccountAuthenticationService.copy &&
      widget.avatarUploadFunction.isNotEmpty;
  bool get _profileCheckinSource =>
      widget.checkinStatusSource == 'serverProfile';

  bool _validCheckinVerification(Map<String, dynamic> data, String today) {
    final verification = asJsonMap(data['verification']);
    return data['accountId']?.toString() == _account?.id &&
        verification['source'] == widget.checkinStatusSource &&
        verification['date'] == today &&
        (!_profileCheckinSource ||
            (verification['dateBasis'] == 'observedUtc8' &&
                data['checkinDateBasis'] == 'observedUtc8' &&
                data['profileDataSource'] == 'serverProfile'));
  }

  void _applyCheckinPayload(Map<String, dynamic> data) {
    final accountId = _account?.id ?? '';
    final today = sourceCheckinDate(DateTime.now());
    if (_profileCheckinSource) {
      // Profile booleans are fresh observations, not day-long receipts. A new
      // false/unknown observation must not retain an earlier true value.
      if (!_validCheckinVerification(data, today)) {
        _checkinStatus = SourceCheckinStatus.forAccount(accountId);
        _checkinEvidence = () => t.sourceProfile.websiteCheckinUnavailable;
        _checkinEvidenceDate = today;
        return;
      }
      final verification = asJsonMap(data['verification']);
      _checkinStatus = SourceCheckinStatus.forAccount(accountId);
      if (verification['status'] == 'confirmed' &&
          verification['signed'] == true) {
        _checkinStatus = _checkinStatus.merge(data, accountId: accountId);
        if (_checkinStatus.checkedIn == true) {
          _checkinEvidence = () =>
              t.sourceProfile.websiteCheckedIn(date: today);
        }
      } else if (verification['status'] == 'notSigned' &&
          verification['signed'] == false &&
          data['checkedIn'] == false) {
        _checkinEvidence = () =>
            t.sourceProfile.websiteNotCheckedIn(date: today);
      } else {
        _checkinEvidence = () => t.sourceProfile.websiteCheckinUnknown;
      }
      _checkinEvidenceDate = today;
      return;
    }
    final proof = asJsonMap(data['checkinProof']);
    if (_checkinEvidence == null &&
        data['accountId'] == accountId &&
        proof['date'] == today &&
        data['checkedIn'] == true) {
      _checkinEvidence = () => t.sourceProfile.storedCheckin(date: today);
      _checkinEvidenceDate = today;
    }
    _checkinStatus = _checkinStatus.merge(data, accountId: accountId);
  }

  bool _needsLogin(Object error) {
    try {
      return parseUnauthorizedPayload(error, fallbackPluginId: widget.source) !=
          null;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _folderBackController.addListener(_syncBackController);
    _cloudSessionSubscription = pluginSessionWriteFence.changes.listen(
      _onCloudSession,
    );
    _endpointSubscription = pluginEndpointChanges.listen(_onEndpointChanged);
    _cloudCommitSubscription = JmCollectionSnapshots.instance.commits.listen(
      _onCloudCommit,
    );
    _cloudSnapshotSubscription = JmCollectionSnapshots.instance.changes.listen(
      _applyCloudSnapshot,
    );
    if (_brandHero) _loadAppearance();
    _syncBackController();
    _refreshRemoteProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshRecords();
    });
  }

  Future<void> _loadAppearance() async {
    try {
      await LocalAppearanceImages.instance.load();
    } catch (_) {
      // The existing brand background remains usable if local storage fails.
    }
  }

  @override
  void didUpdateWidget(covariant _ProfileBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backController != widget.backController) {
      oldWidget.backController?.update();
      _syncBackController();
    }
    if (oldWidget.profileKind != widget.profileKind &&
        oldWidget.backController == widget.backController)
      _syncBackController();
  }

  @override
  void dispose() {
    _accountEpoch++;
    _cloudSessionSubscription?.cancel();
    _endpointSubscription?.cancel();
    _cloudCommitSubscription?.cancel();
    _cloudSnapshotSubscription?.cancel();
    _cloudRecovery.dispose();
    _folderBackController.removeListener(_syncBackController);
    _folderBackController.dispose();
    _notificationChanges.dispose();
    widget.backController?.update();
    super.dispose();
  }

  void _syncBackController() {
    final mode = _mode;
    if (_managingFolders) {
      widget.backController?.update(
        backLabel: () => _folderBackController.canGoBack
            ? t.sourceProfile.backToParent
            : t.sourceProfile.backToRecords,
        onBack: _goBackInProfile,
      );
    } else if (mode != null) {
      widget.backController?.update(
        backLabel: () => t.sourceProfile.backToProfile,
        title: _jmCollections ? () => sourceProfileRecordLabel(mode) : null,
        onBack: _goBackInProfile,
      );
    } else {
      widget.backController?.update();
    }
  }

  void _goBackInProfile() {
    if (_managingFolders) {
      if (_folderBackController.canGoBack) {
        _folderBackController.goBack();
        return;
      }
      _refreshRecords();
      setState(() => _managingFolders = false);
    } else if (_mode != null) {
      _refreshRecords();
      setState(() => _mode = null);
    }
    _syncBackController();
  }

  PullRefreshResult _refreshRecords([ShelfPageMode? mode]) {
    final previous = _records;
    try {
      final loaded = loadSourceProfileRecords(widget.sources);
      if (mounted) {
        setState(() {
          _records = loaded;
          _recordsError = null;
        });
        return mode != null && listEquals(previous.of(mode), loaded.of(mode))
            ? PullRefreshResult.unchanged
            : PullRefreshResult.updated;
      }
    } catch (_) {
      if (mounted) {
        setState(() => _recordsError = t.sourceProfile.recordsUnavailable);
      }
    }
    return PullRefreshResult.ignored;
  }

  Future<void> _refreshPage() async {
    _refreshRecords();
    await _refreshRemoteProfile();
  }

  Future<void> _refreshRemoteProfile({bool automatic = false}) async {
    final epoch = ++_profileRefreshEpoch;
    // Resolve identity before accepting private records from the new session.
    await _loadAccount(refreshCloudOnIdentityChange: false);
    if (!mounted ||
        epoch != _profileRefreshEpoch ||
        _profileNeedsIdentityRead && _loadFailed)
      return;
    await _loadCloudFavorites(automatic: automatic);
    if (mounted &&
        epoch == _profileRefreshEpoch &&
        widget.notificationsFunction.isNotEmpty) {
      await _loadNotifications();
    }
  }

  Future<void> _loadCloudFavorites({bool automatic = false}) {
    if (!mounted) return Future.value();
    if (!_cloudReadActive) {
      _cloudRecovery.invalidate();
      return Future.value();
    }
    if (_profileNeedsIdentityRead)
      return _refreshRemoteProfile(automatic: automatic);
    final owner = _cloudReadOwner();
    final scope =
        '$owner|${JmCollectionSnapshots.instance.revision(widget.source)}';
    final pending = _cloudTask;
    // The same account/query joins its in-flight read, including manual pulls.
    // A committed newer revision waits for that physical read to finish, then
    // coalesces one follow-up; _cloudEpoch already hides the superseded result.
    if (pending != null && _cloudTaskScope == scope) return pending;
    if (pending != null && _cloudTaskOwner == owner) {
      return pending.then<void>((_) {
        if (!mounted || _cloudReadOwner() != owner) return Future<void>.value();
        return _loadCloudFavorites(automatic: automatic);
      });
    }
    final task = _readCloudFavorites();
    _cloudTask = task;
    _cloudTaskScope = scope;
    _cloudTaskOwner = owner;
    return task.whenComplete(() {
      if (identical(_cloudTask, task)) _cloudTask = null;
    });
  }

  Future<void> _readCloudFavorites() async {
    if (!mounted) return;
    final epoch = ++_cloudEpoch;
    if (_accountSignedOut) {
      _cloudRecovery.succeeded();
      setState(() {
        _cloudFavorites = const [];
        _cloudTotal = null;
        _cloudLoading = false;
        _cloudError = t.sourceProfile.signInForFavorites;
      });
      return;
    }
    if (mounted) setState(() => _cloudLoading = true);
    try {
      final preview = await loadSourceCloudFavoritePreview(
        widget.source,
        jmProfile: widget.profileKind == 'jm',
        functionPath: widget.cloudFavoriteFunction,
      );
      if (!mounted || epoch != _cloudEpoch) return;
      if (preview.pendingConfirmation) {
        _cloudRecovery.failed(StateError(t.sourceProfile.dataNotRefreshed));
      } else {
        _cloudRecovery.succeeded();
      }
      setState(() {
        _cloudFavorites = preview.items;
        _cloudTotal = preview.total;
        _cloudError = null;
      });
    } catch (error) {
      if (error is SourceCloudFavoriteReadSuperseded) return;
      if (mounted && epoch == _cloudEpoch) {
        _cloudRecovery.failed(error);
        setState(() {
          final signedOut = _needsLogin(error);
          if (signedOut) {
            _cloudFavorites = const [];
            _cloudTotal = null;
          }
          _cloudError = signedOut
              ? t.sourceProfile.signInForFavorites
              : userFacingErrorMessage(error);
        });
      }
    } finally {
      if (mounted && epoch == _cloudEpoch) {
        setState(() => _cloudLoading = false);
      }
    }
  }

  Future<void> _loadAccount({bool refreshCloudOnIdentityChange = true}) async {
    final epoch = ++_accountEpoch;
    final generation = pluginSessionWriteFence.generation(widget.source);
    final endpoint = pluginEndpointRevision(widget.source);
    bool current() =>
        mounted &&
        epoch == _accountEpoch &&
        pluginSessionWriteFence.generation(widget.source) == generation &&
        pluginEndpointRevision(widget.source) == endpoint;
    var identityChanged = false;
    if (mounted) setState(() => _loading = true);
    try {
      var response = await callUnifiedComicPlugin(
        from: widget.source,
        fnPath: 'getUserInfoBundle',
        core: const <String, dynamic>{},
        notifyUnauthorized: false,
      );
      if (!current()) return;
      final authentication = PluginAccountAuthenticationService(widget.source);
      if (authentication.hasApiVerification) {
        final proof = widget.source == PluginAccountAuthenticationService.jm
            ? PluginAccountIdentities.current(widget.source) ??
                  await authentication.verify()
            : authentication.fromServerResponse(response);
        if (!current()) return;
        PluginAccountIdentities.confirm(
          widget.source,
          proof,
          generation: generation,
        );
        final data = asJsonMap(response['data']),
            extern = asJsonMap(asJsonMap(response['data'])['extern']);
        final candidate = _Account.fromResponse(response);
        response =
            candidate.id.isNotEmpty && candidate.id != proof.serverIdentity
            ? {...response, 'data': proof.toUserInfo()}
            : {
                ...response,
                'data': {
                  ...data,
                  'extern': {
                    ...extern,
                    'accountId': proof.serverIdentity,
                    if (proof.label.isNotEmpty) 'name': proof.label,
                  },
                },
              };
      }
      _setNotificationState(() {
        final previousId = _account?.id;
        _account = _Account.fromResponse(response);
        _accountSignedOut = false;
        if (previousId != _account?.id) {
          if (previousId != null) {
            identityChanged = true;
            _cloudEpoch++;
            _cloudFavorites = const [];
            _cloudTotal = null;
            _cloudError = null;
            _cloudLoading = true;
          }
          _noticeEpoch++;
          _notices = const [];
          _noticeAccountId = null;
          _unreadCount = null;
          _noticeTotal = null;
          _noticesComplete = false;
          _noticeError = null;
          _noticeLoading = false;
          _markingNotices = false;
          _checkinEvidence = null;
          _checkinEvidenceDate = null;
        }
        final extra = asJsonMap(asJsonMap(response['data'])['extern']);
        if (_checkinEvidenceDate != sourceCheckinDate(DateTime.now())) {
          _checkinEvidence = null;
          _checkinEvidenceDate = null;
        }
        _applyCheckinPayload(extra);
        _loadFailed = false;
        _profileNeedsIdentityRead = false;
      });
    } catch (error) {
      if (current()) {
        if (_profileNeedsIdentityRead) _cloudRecovery.failed(error);
        _setNotificationState(() {
          if (_needsLogin(error)) {
            PluginAccountIdentities.reject(
              widget.source,
              generation: generation,
            );
            _accountSignedOut = true;
            _profileNeedsIdentityRead = false;
            _cloudEpoch++;
            _cloudFavorites = const [];
            _cloudTotal = null;
            _cloudLoading = false;
            _cloudError = t.sourceProfile.signInForFavorites;
            _noticeEpoch++;
            _notices = const [];
            _noticeAccountId = null;
            _unreadCount = null;
            _noticeTotal = null;
            _noticeLoading = false;
            _markingNotices = false;
            _checkinEvidence = null;
            _checkinEvidenceDate = null;
            _account = null;
            _checkinStatus = SourceCheckinStatus.forAccount('');
            _loadFailed = false;
          } else {
            _loadFailed = true;
            if (_profileNeedsIdentityRead) {
              _cloudLoading = false;
              _cloudError = userFacingErrorMessage(error);
            }
          }
        });
      }
    } finally {
      if (mounted && epoch == _accountEpoch) setState(() => _loading = false);
    }
    if (refreshCloudOnIdentityChange &&
        identityChanged &&
        mounted &&
        epoch == _accountEpoch) {
      await _loadCloudFavorites();
    }
  }

  Future<void> _loginAndReload({bool savedAccounts = false}) async {
    if (_openingLogin || _editing || _choosingAvatar) return;
    _accountEpoch++;
    _profileRefreshEpoch++;
    _cloudEpoch++;
    setState(() => _openingLogin = true);
    try {
      if (savedAccounts) {
        await openPluginSavedAccounts(
          context,
          source: widget.source,
          onAddAccount: widget.onAddAccount,
        );
      } else {
        await widget.onLogin();
      }
      if (!mounted) return;
      // Login may have switched accounts. Do not reuse the previous account's
      // private preview if the new request fails, or let an older request win.
      _setNotificationState(() {
        _noticeEpoch++;
        _notices = const [];
        _noticeAccountId = null;
        _unreadCount = null;
        _noticeTotal = null;
        _noticeLoading = false;
        _markingNotices = false;
        _noticeError = null;
        _account = null;
        _accountSignedOut = false;
        _checkinEvidence = null;
        _checkinEvidenceDate = null;
        _checkinStatus = SourceCheckinStatus.forAccount('');
        _cloudEpoch++;
        _cloudFavorites = const [];
        _cloudTotal = null;
        _cloudError = null;
      });
      await _refreshPage();
    } finally {
      if (mounted) setState(() => _openingLogin = false);
    }
  }

  void _applyNotificationSnapshot(Map<String, dynamic> data) {
    _notices = asJsonList(
      data['items'],
    ).map((item) => SourceNotice.fromMap(asJsonMap(item))).toList();
    _noticeAccountId = data['accountId']?.toString() == _account?.id
        ? _account?.id
        : null;
    _noticesComplete = data['complete'] == true;
    final total = data['total'];
    _noticeTotal = data['totalKnown'] == true && total is int && total >= 0
        ? total
        : null;
    final summary = asJsonMap(data['unreadSummary']);
    final count = summary['total'];
    _unreadCount =
        summary['accountId']?.toString() == _account?.id &&
            summary['countsKnown'] == true &&
            count is int &&
            count >= 0
        ? count
        : _noticesComplete && _notices.every((item) => item.read != null)
        ? _notices.where((item) => item.read == false).length
        : null;
  }

  Future<void> _loadNotifications() async {
    if (_markingNotices ||
        widget.notificationsFunction.isEmpty ||
        _account == null) {
      return;
    }
    final epoch = ++_noticeEpoch, accountEpoch = _accountEpoch;
    final accountId = _account!.id;
    _setNotificationState(() => _noticeLoading = true);
    try {
      final response = await callUnifiedComicPlugin(
        from: widget.source,
        fnPath: widget.notificationsFunction,
        core: const <String, dynamic>{},
      );
      if (!mounted ||
          epoch != _noticeEpoch ||
          accountEpoch != _accountEpoch ||
          _account?.id != accountId) {
        return;
      }
      final data = asJsonMap(response['data']);
      if (data['items'] is! List ||
          data['accountId'] != null &&
              data['accountId']?.toString() != accountId) {
        throw StateError(t.sourceNotices.stateUnavailable);
      }
      _setNotificationState(() {
        _applyNotificationSnapshot(data);
        _noticeError = null;
      });
    } catch (error) {
      if (mounted &&
          epoch == _noticeEpoch &&
          accountEpoch == _accountEpoch &&
          _account?.id == accountId) {
        _setNotificationState(
          () => _noticeError = userFacingErrorMessage(error),
        );
      }
    } finally {
      if (mounted && epoch == _noticeEpoch) {
        _setNotificationState(() => _noticeLoading = false);
      }
    }
  }

  Future<void> _markNotifications(
    List<SourceNotice> items, {
    bool single = false,
  }) async {
    if (_markingNotices ||
        _noticeLoading ||
        _account == null ||
        _noticeAccountId != _account!.id) {
      return;
    }
    final function = single
        ? widget.markNotificationReadFunction
        : widget.markNotificationsReadFunction;
    if (function.isEmpty) return;
    final ids = items
        .where((item) => item.canMarkRead)
        .map((item) => item.id)
        .toSet();
    if (ids.isEmpty) return;
    final accountId = _account!.id,
        accountEpoch = _accountEpoch,
        epoch = ++_noticeEpoch;
    _setNotificationState(() {
      _markingNotices = true;
      _noticeError = null;
    });
    try {
      final response = await callUnifiedComicPlugin(
        from: widget.source,
        fnPath: function,
        core: {
          'accountId': accountId,
          if (single) 'id': ids.single else 'ids': ids.toList(),
        },
      );
      if (!mounted ||
          epoch != _noticeEpoch ||
          accountEpoch != _accountEpoch ||
          _account?.id != accountId) {
        return;
      }
      final data = asJsonMap(response['data']);
      if (data['accountId']?.toString() != accountId ||
          data['scope'] != 'requestedLoadedItems') {
        throw StateError(t.sourceNotices.stateUnconfirmed);
      }
      final confirmed = asJsonList(
        data['confirmedIds'],
      ).whereType<String>().where(ids.contains).toSet();
      final unknown = asJsonList(
        data['unknownIds'],
      ).whereType<String>().where(ids.contains).toSet()..removeAll(confirmed);
      _setNotificationState(() {
        // Only server-verified requested IDs become read. Explicitly unknown
        // outcomes must be refreshed before offering another write.
        // A failed or partial batch
        // cannot turn other notices read or erase an earlier confirmed result.
        _notices = [
          for (final item in _notices)
            if (confirmed.contains(item.id))
              item.withRead(true)
            else if (unknown.contains(item.id))
              item.withRead(null)
            else
              item,
        ];
        final summary = asJsonMap(data['unreadSummary']);
        final count = summary['total'];
        _unreadCount =
            summary['accountId']?.toString() == accountId &&
                summary['countsKnown'] == true &&
                count is int &&
                count >= 0
            ? count
            : null;
        _noticeError = confirmed.length == ids.length
            ? null
            : t.sourceNotices.partialMarked(
                confirmed: confirmed.length,
                pending: ids.length - confirmed.length,
              );
      });
    } catch (error) {
      if (mounted &&
          epoch == _noticeEpoch &&
          accountEpoch == _accountEpoch &&
          _account?.id == accountId) {
        _setNotificationState(() {
          _notices = [
            for (final item in _notices)
              if (ids.contains(item.id)) item.withRead(null) else item,
          ];
          _unreadCount = null;
          _noticeError = userFacingErrorMessage(error);
        });
      }
    } finally {
      if (mounted && epoch == _noticeEpoch) {
        _setNotificationState(() => _markingNotices = false);
      }
    }
  }

  Future<void> _verifyCheckin() async {
    if (_checkingStatus ||
        _checkingIn ||
        _openingLogin ||
        _loading ||
        _account == null ||
        widget.checkinStatusFunction.isEmpty) {
      return;
    }
    final accountId = _account!.id, epoch = _accountEpoch;
    setState(() => _checkingStatus = true);
    try {
      final response = await callUnifiedComicPlugin(
        from: widget.source,
        fnPath: widget.checkinStatusFunction,
        core: const {},
      );
      if (!mounted || epoch != _accountEpoch || _account?.id != accountId) {
        return;
      }
      final data = asJsonMap(response['data']);
      final verification = asJsonMap(data['verification']);
      final today = sourceCheckinDate(DateTime.now());
      if (!_validCheckinVerification(data, today) ||
          verification['status'] == 'confirmed' &&
              (data['checkedIn'] != true || data['checkedInDate'] != today)) {
        throw StateError(t.sourceProfile.checkinIdentityChanged);
      }
      setState(() {
        if (_profileCheckinSource) {
          _applyCheckinPayload(data);
        } else if (verification['status'] == 'confirmed' &&
            verification['signed'] == true) {
          _checkinStatus = _checkinStatus.merge(data, accountId: accountId);
          _checkinEvidence = () =>
              t.sourceProfile.calendarCheckedIn(date: today);
        } else if (verification['status'] == 'notSigned' &&
            verification['signed'] == false) {
          _checkinEvidence = () =>
              t.sourceProfile.calendarNotCheckedIn(date: today);
        } else {
          _checkinEvidence = () => t.sourceProfile.calendarCheckinRetained;
        }
        _checkinEvidenceDate = today;
      });
    } catch (error) {
      if (mounted && epoch == _accountEpoch && _account?.id == accountId) {
        setState(
          () =>
              _checkinEvidence = () =>
                  t.sourceProfile.calendarCheckinUnavailable,
        );
      }
    } finally {
      if (mounted) setState(() => _checkingStatus = false);
    }
  }

  Future<void> _openCloudFavorites() async {
    if (_genericProfile && !_loading && !_loadFailed && _account == null) {
      await _loginAndReload();
      if (!mounted || _account == null) return;
    }
    await widget.onCloudFavorite();
    if (mounted) await _loadCloudFavorites();
  }

  Future<void> _checkIn() async {
    if (_checkingIn ||
        _checkingStatus ||
        _openingLogin ||
        _loading ||
        _checkedInToday ||
        _account == null ||
        _account!.id.isEmpty ||
        widget.checkinFunction.isEmpty) {
      return;
    }
    final accountId = _account!.id;
    final requestedDay = sourceCheckinDate(DateTime.now());
    final epoch = _accountEpoch;
    setState(() => _checkingIn = true);
    try {
      final result = await callUnifiedComicPlugin(
        from: widget.source,
        fnPath: widget.checkinFunction,
        core: const <String, dynamic>{},
      );
      final data = asJsonMap(result['data']);
      if (!mounted || epoch != _accountEpoch || _account?.id != accountId) {
        return;
      }
      if (data['ok'] != true) {
        throw StateError(
          data['message']?.toString() ?? t.sourceProfile.checkinFailed,
        );
      }
      if (data['accountId']?.toString() != accountId ||
          data['checkedIn'] != true ||
          data['checkedInDate'] != requestedDay ||
          requestedDay != sourceCheckinDate(DateTime.now()) ||
          (_profileCheckinSource &&
              (!_validCheckinVerification(data, requestedDay) ||
                  asJsonMap(data['verification'])['status'] != 'confirmed' ||
                  asJsonMap(data['verification'])['signed'] != true))) {
        throw StateError(t.sourceProfile.checkinUnconfirmed);
      }
      setState(() {
        _checkinStatus = _checkinStatus.merge(data, accountId: accountId);
      });
      showSuccessToast(
        data['message']?.toString() ?? t.sourceProfile.checkedIn,
      );
      await _loadAccount();
    } catch (error) {
      if (mounted && epoch == _accountEpoch && _account?.id == accountId) {
        showErrorToast(userFacingErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  Widget _cloudPreview() => SourceProfileComicPreviewCard(
    previewKey: const ValueKey('profile-preview-cloud'),
    jmCollection: _jmCollections,
    compactLayout: true,
    source: widget.source,
    title: t.videoCommunity.siteFavorite,
    icon: Icons.cloud_outlined,
    entries: _cloudFavorites,
    countLabel: _cloudTotal?.toString(),
    type: ComicEntryType.normal,
    emptyMessage: t.sourceProfile.cloudFavoritesEmpty,
    loading: _cloudLoading,
    error: _cloudError,
    onRetry: _loadCloudFavorites,
    onViewAll: _openCloudFavorites,
    onReturned: _loadCloudFavorites,
  );

  List<Widget> _recordPreviews() {
    final result = <Widget>[];
    final emptyModes = <ShelfPageMode>[];
    const inset = BookshelfContentLayout.horizontalPadding;
    void flushEmpty() {
      if (emptyModes.isEmpty) return;
      result.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(inset, 0, inset, 8),
          child: Column(
            children: [
              for (final mode in emptyModes)
                ListTile(
                  key: ValueKey('profile-empty-${mode.name}'),
                  minLeadingWidth: 20,
                  horizontalTitleGap: 8,
                  minVerticalPadding: 0,
                  minTileHeight: 44,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Icon(sourceProfileRecordIcon(mode), size: 20),
                  title: Text(sourceProfileRecordLabel(mode)),
                  trailing: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('0'),
                      SizedBox(width: 8),
                      Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => _openRecords(mode),
                ),
            ],
          ),
        ),
      );
      emptyModes.clear();
    }

    for (final mode in const [
      ShelfPageMode.favorite,
      ShelfPageMode.history,
      ShelfPageMode.download,
    ]) {
      final entries = _records.of(mode);
      if (entries.isEmpty && !_jmCollections) {
        emptyModes.add(mode);
      } else {
        flushEmpty();
        result.add(
          SourceProfilePreviewSection(
            jmCollection: _jmCollections,
            compactLayout: true,
            source: widget.source,
            mode: mode,
            entries: entries,
            onViewAll: () => _openRecords(mode),
            onReturned: _refreshRecords,
          ),
        );
      }
    }
    flushEmpty();
    return result;
  }

  @override
  Widget build(BuildContext context) => ReadRecoveryHost(
    onActiveChanged: (active) =>
        _setCloudReadActive(active && _mode == null && !_notificationsOpen),
    child: _buildProfile(context),
  );

  Widget _buildProfile(BuildContext context) {
    if (_mode != null) return _localRecords();
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _refreshPage,
      child: ListView(
        key: PageStorageKey('source-profile-overview-${widget.source}'),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _genericProfile
              ? _genericHero(colors)
              : widget.profileKind == 'jm'
              ? _jmHero(colors)
              : _hero(colors),
          if (widget.profileKind != 'jm' &&
              _account != null &&
              widget.checkinFunction.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                SettingSection.horizontalInsetOf(context),
                12,
                SettingSection.horizontalInsetOf(context),
                0,
              ),
              child: _checkinControls(colors, showAccountSwitch: false),
            ),
          if (widget.notificationsFunction.isNotEmpty)
            _notificationsEntry(colors),
          SizedBox(height: _brandHero ? 18 : 8),
          _cloudPreview(),
          _sectionLabel(t.videoSource.localHistory),
          if (widget.videoModules.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                SettingSection.horizontalInsetOf(context),
                0,
                SettingSection.horizontalInsetOf(context),
                12,
              ),
              child: NativeVideoSegmentedControl(
                key: const ValueKey('profile-record-media'),
                options: {
                  'comic': t.bookshelf.mediaComics,
                  'video': t.bookshelf.mediaVideos,
                },
                selected: _showVideoRecords ? 'video' : 'comic',
                onSelected: (value) =>
                    setState(() => _showVideoRecords = value == 'video'),
              ),
            ),
          if (_showVideoRecords && widget.videoModules.isNotEmpty)
            SourceProfileVideoRecords(modules: widget.videoModules)
          else if (_recordsError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextButton.icon(
                onPressed: _refreshRecords,
                icon: const Icon(Icons.refresh),
                label: Text('$_recordsError · ${t.common.retry}'),
              ),
            )
          else
            ..._recordPreviews(),
          SettingSection(
            title: '',
            backgroundColor: Colors.transparent,
            children: [
              ListTile(
                key: const ValueKey('profile-plugin-settings'),
                leading: const Icon(Icons.tune_outlined),
                title: Text(t.plugin.pluginSettings),
                trailing: const Icon(Icons.chevron_right),
                onTap: widget.onSettings,
              ),
            ],
          ),
          SizedBox(height: NativeNavigationInset.scrollBottom(context) + 12),
        ],
      ),
    );
  }

  Widget _notificationsEntry(ColorScheme colors) {
    final unread = _unreadCount;
    final inset = SettingSection.horizontalInsetOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(inset, 10, inset, 0),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Badge(
            isLabelVisible: unread != null && unread > 0,
            label: Text('$unread'),
            child: Icon(Icons.notifications_outlined, color: colors.primary),
          ),
          title: Text(t.sourceNotices.entry),
          subtitle: Text(
            _noticeLoading
                ? t.sourceNotices.syncing
                : _noticeError != null
                ? t.sourceNotices.unavailableRetry
                : unread != null && unread > 0
                ? t.sourceNotices.unreadCount(count: unread)
                : t.sourceNotices.entryHint,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            if (_account == null) {
              _loginAndReload();
              return;
            }
            unawaited(_openNotifications());
          },
        ),
      ),
    );
  }

  // Requests and account fences stay owned by this profile; the pushed page
  // only observes presentation changes and never creates a second feed.
  void _setNotificationState(VoidCallback change) {
    setState(change);
    _notificationChanges.value++;
  }

  Future<void> _openNotifications() async {
    if (_notificationsOpen) return;
    setState(() => _notificationsOpen = true);
    final origin = context;
    final navigator = Navigator.of(context);
    try {
      if (_noticeError != null) unawaited(_loadNotifications());
      await navigator.push<void>(
        videoPageRoute<void>(
          settings: const RouteSettings(name: 'breeze.source.notifications'),
          matchAutoRouteTransition:
              ModalRoute.of(origin)?.settings is AutoRoutePage,
          builder: (routeContext) => InheritedTheme.captureAll(
            origin,
            SourceExperienceBoundary(
              source: widget.source,
              builder: (_) => Scaffold(
                appBar: AppBar(
                  leading: SourceBackButton(
                    onPressed: () => navigator.maybePop(),
                  ),
                  title: Text(t.sourceNotices.title),
                ),
                body: SafeArea(
                  top: false,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _notificationChanges,
                    builder: (_, _, _) =>
                        _notificationsView(onBack: () => navigator.maybePop()),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _notificationsOpen = false);
    }
  }

  Widget _notificationsView({required VoidCallback onBack}) =>
      SourceNotificationsView(
        notices: _notices,
        loading: _noticeLoading,
        marking: _markingNotices,
        error: _noticeError,
        unreadCount: _unreadCount,
        complete: _noticesComplete,
        total: _noticeTotal,
        onRefresh: _loadNotifications,
        onOpen: _showNoticeDetail,
        showHeading: false,
        onBack: onBack,
        onMarkRead:
            widget.markNotificationReadFunction.isEmpty ||
                _noticeAccountId != _account?.id
            ? null
            : (item) => _markNotifications([item], single: true),
        onMarkLoadedRead:
            widget.markNotificationsReadFunction.isEmpty ||
                _noticeAccountId != _account?.id
            ? null
            : () => _markNotifications(_notices),
      );

  Future<void> _showNoticeDetail(SourceNotice notice) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          notice.displayTitle,
                          style: Theme.of(sheetContext).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: t.common.close,
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                if (notice.time.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text(
                      formatSourceNoticeTime(notice.time),
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                  ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: SelectionArea(
                      child: Text(
                        notice.content.isEmpty
                            ? t.oldHome.empty
                            : notice.content,
                        style: Theme.of(sheetContext).textTheme.bodyLarge,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _genericHero(ColorScheme colors) {
    final account = _account;
    return Container(
      key: const ValueKey('profile-account-card'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _accountAvatar(account, colors.primary, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account?.name.isNotEmpty == true
                          ? account!.name
                          : widget.sourceName.isEmpty
                          ? t.sourceShell.account
                          : t.sourceProfile.accountName(
                              name: widget.sourceName,
                            ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _loading
                          ? t.sourceProfile.readingAccount
                          : _loadFailed
                          ? t.sourceProfile.profileUnavailable
                          : account == null
                          ? t.sourceProfile.signInForFavorites
                          : t.videoSource.signedIn,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                key: const ValueKey('profile-account-action'),
                onPressed: !_canOpenAccount
                    ? null
                    : account == null
                    ? _loginAndReload
                    : () => _loginAndReload(savedAccounts: true),
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                icon: Icon(
                  account == null ? Icons.login : Icons.switch_account_outlined,
                ),
                label: Text(
                  account == null
                      ? t.plugin.accountLogin
                      : t.plugin.switchAccount,
                ),
              ),
              if (account != null && widget.avatarUploadFunction.isNotEmpty)
                TextButton.icon(
                  key: const ValueKey('profile-edit-action'),
                  onPressed: _canOpenAccount ? _changeAvatar : null,
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(
                    _editing
                        ? t.sourceProfile.uploadingAvatar
                        : t.sourceShell.changeAvatar,
                  ),
                ),
              if (_loadFailed)
                TextButton.icon(
                  onPressed: _loading || _openingLogin ? null : _refreshPage,
                  style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                  icon: const Icon(Icons.refresh),
                  label: Text(t.sourceProfile.retryProfile),
                ),
            ],
          ),
          if (account != null && _copyAvatarPolicy)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                t.sourceProfile.copyAvatarInterval,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }

  Widget _checkinControls(
    ColorScheme colors, {
    bool showAccountSwitch = true,
    bool compact = false,
  }) {
    final account = _account;
    final checkin = FilledButton.tonalIcon(
      key: const ValueKey('profile-checkin-action'),
      style: compact
          ? FilledButton.styleFrom(minimumSize: const Size(44, 44))
          : null,
      onPressed: account == null
          ? _loginAndReload
          : widget.checkinFunction.isEmpty ||
                _checkingIn ||
                _checkingStatus ||
                _loading ||
                _openingLogin ||
                account.id.isEmpty ||
                _checkedInToday
          ? null
          : _checkIn,
      icon: _checkingIn
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              account == null ? Icons.login : Icons.event_available_outlined,
            ),
      label: Text(
        account == null
            ? t.plugin.accountLogin
            : _checkingIn
            ? t.sourceProfile.checkingIn
            : _checkedInToday
            ? t.sourceProfile.checkedIn
            : t.sourceProfile.checkIn,
      ),
    );
    final switchAccount = OutlinedButton.icon(
      key: const ValueKey('profile-account-action'),
      style: compact
          ? OutlinedButton.styleFrom(minimumSize: const Size(44, 44))
          : null,
      onPressed: _canOpenAccount && !_checkingIn
          ? () => _loginAndReload(savedAccounts: true)
          : null,
      icon: const Icon(Icons.switch_account_outlined),
      label: Text(t.plugin.switchAccount),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: checkin),
            if (account != null && showAccountSwitch) ...[
              const SizedBox(width: 10),
              Expanded(child: switchAccount),
            ],
          ],
        ),
        if (account != null &&
            !_jmCollections &&
            !isBikaExperienceSource(widget.source) &&
            widget.checkinStatusFunction.isNotEmpty)
          Row(
            children: [
              Expanded(
                child: Text(
                  _checkinEvidence?.call() ??
                      (_profileCheckinSource
                          ? t.sourceProfile.checkWebsite
                          : t.sourceProfile.checkCalendar),
                  key: const ValueKey('profile-checkin-evidence'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                key: const ValueKey('profile-checkin-verify'),
                onPressed:
                    _checkingStatus || _checkingIn || _loading || _openingLogin
                    ? null
                    : _verifyCheckin,
                icon: _checkingStatus
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.fact_check_outlined, size: 18),
                label: Text(
                  _checkingStatus
                      ? t.sourceProfile.checking
                      : t.sourceProfile.check,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _jmHero(ColorScheme colors) {
    final account = _account;
    final secondary = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant);
    final details = <String>[
      if (account?.level != null) 'Lv.${account!.level}',
      if (account != null && account.title.isNotEmpty) account.title,
      if (account != null && account.coin.isNotEmpty)
        t.sourceProfile.coins(amount: account.coin),
      if (account != null && account.experience.isNotEmpty)
        t.sourceShell.bikaExperience(
          value:
              '${account.experience}${account.nextLevelExperience.isEmpty ? '' : '/${account.nextLevelExperience}'}',
        ),
    ];
    return Container(
      key: const ValueKey('profile-account-card'),
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                key: const ValueKey('profile-account-avatar'),
                child: _accountAvatar(account, colors.primary, size: 64),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account?.name.isNotEmpty == true
                          ? account!.name
                          : t.sourceProfile.jmAccount,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (account == null)
                      Text(
                        _loading
                            ? t.sourceProfile.readingAccount
                            : t.sourceProfile.jmSignInHint,
                        style: secondary,
                      )
                    else if (details.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        children: [
                          for (final value in details)
                            Text(value, style: secondary),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _checkinControls(colors, compact: true),
          if (_loadFailed)
            TextButton(
              onPressed: _refreshPage,
              child: Text(t.sourceProfile.retryUnavailableProfile),
            ),
        ],
      ),
    );
  }

  Widget _hero(ColorScheme colors) {
    return ValueListenableBuilder<Map<String, String>>(
      valueListenable: LocalAppearanceImages.instance.paths,
      builder: (context, paths, _) {
        final path = _brandHero ? paths['profile:${widget.source}'] : null;
        final account = _account;
        final heroColor = Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF8F405F)
            : const Color(0xFFE58EB6);
        const foreground = Colors.white;
        final content = Container(
          width: double.infinity,
          color: heroColor,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed:
                      _editing ||
                          _choosingAvatar ||
                          _appearanceBusy ||
                          _profileSheetOpen
                      ? null
                      : _openAppearanceMenu,
                  icon: Icon(
                    Icons.wallpaper_outlined,
                    size: 18,
                    color: foreground,
                  ),
                  label: Text(
                    t.coverPrivacy.wallpaper,
                    style: TextStyle(color: foreground),
                  ),
                ),
              ),
              Text(
                account?.level == null
                    ? t.sourceProfile.bikaAccount
                    : 'Lv. ${account!.level}',
                style: TextStyle(
                  color: foreground,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Stack(
                children: [
                  _accountAvatar(account, foreground, size: 108, ring: true),
                  if (account != null && widget.avatarUploadFunction.isNotEmpty)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: SizedBox.square(
                        dimension: 44,
                        child: IconButton(
                          key: const ValueKey('profile-avatar-camera'),
                          tooltip: t.sourceShell.changeAvatar,
                          onPressed: _canOpenAccount ? _changeAvatar : null,
                          icon: CircleAvatar(
                            radius: 15,
                            backgroundColor: colors.surface,
                            child: Icon(
                              Icons.camera_alt_outlined,
                              size: 17,
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 13),
              if (_loading && account == null)
                Text(t.common.loading, style: TextStyle(color: foreground))
              else if (account == null) ...[
                Text(
                  _loadFailed
                      ? t.sourceProfile.profileUnavailable
                      : t.videoSource.notSignedIn,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: _loadFailed ? _refreshPage : _loginAndReload,
                  child: Text(
                    _loadFailed
                        ? t.sourceProfile.retryProfile
                        : t.sourceProfile.bikaSignIn,
                    style: TextStyle(color: foreground),
                  ),
                ),
                if (_loadFailed)
                  TextButton(
                    onPressed: _loginAndReload,
                    child: Text(
                      t.sourceProfile.signInAgain,
                      style: TextStyle(color: foreground),
                    ),
                  ),
              ] else ...[
                Text(
                  account.name,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (account.title.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 4,
                      ),
                      child: Text(
                        account.title,
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                if (account.slogan.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Text(
                    account.slogan,
                    key: const ValueKey('profile-slogan'),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: foreground.withValues(alpha: 0.87)),
                  ),
                ],
              ],
              if (_loadFailed && account != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _refreshPage,
                  child: Text(
                    t.sourceProfile.profileLoadFailedRetry,
                    style: TextStyle(color: foreground),
                  ),
                ),
              ],
            ],
          ),
        );
        if (path == null) return content;
        return ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => ColoredBox(color: heroColor),
                ),
              ),
              const Positioned.fill(
                child: ColoredBox(color: Color(0x99000000)),
              ),
              // Keep all account text, avatar and edit controls above the tint.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: content.child,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _accountAvatar(
    _Account? account,
    Color foreground, {
    required double size,
    bool ring = false,
  }) => PluginAccountAvatarButton(
    key: const ValueKey('profile-own-avatar'),
    size: size,
    label: account == null ? t.plugin.accountLogin : t.videoSiteAccount.title,
    onPressed: _canOpenAccount ? _openAccountDetails : null,
    child: ring
        ? ColoredBox(
            color: foreground.withValues(alpha: .25),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: ClipOval(child: _avatar(account, foreground)),
            ),
          )
        : _avatar(account, foreground),
  );

  Widget _avatar(_Account? account, Color foreground) {
    if (account == null ||
        (account.avatarUrl.isEmpty && account.avatarPath.isEmpty)) {
      return ColoredBox(
        color: Colors.white.withValues(alpha: 0.22),
        child: Icon(Icons.person_outline, color: foreground, size: 48),
      );
    }
    return CoverWidget(
      key: ValueKey(
        '${account.avatarUrl}:${account.avatarPath}:$_avatarRevision',
      ),
      fileServer: account.avatarUrl,
      path: account.avatarPath,
      id: 'profile_avatar',
      pictureType: PictureType.user,
      from: widget.source,
      roundedCorner: false,
      width: 100,
      height: 100,
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: EdgeInsets.fromLTRB(
      _brandHero ? SettingSection.horizontalInsetOf(context) + 16 : 12,
      _brandHero ? 16 : 8,
      _brandHero ? SettingSection.horizontalInsetOf(context) + 16 : 12,
      usesCupertinoSettings(context) ? 6 : 8,
    ),
    child: Text(label, style: SettingSection.headingStyleOf(context)),
  );

  bool _openingRecords = false;
  Future<void> _openRecords(ShelfPageMode mode) async {
    if (_openingRecords) return;
    _openingRecords = true;
    _refreshRecords();
    final origin = context;
    try {
      await Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'breeze.source.comic.records'),
          builder: (routeContext) => InheritedTheme.captureAll(
            origin,
            SourceExperienceBoundary(
              source: widget.source,
              builder: (_) => BlocProvider(
                create: (_) {
                  final scope = SearchStatusState(sources: widget.sources);
                  return BookshelfSearchCubit(
                    favorite: scope,
                    history: scope,
                    download: scope,
                  );
                },
                child: _SourceComicRecordsDestination(
                  source: widget.source,
                  sourceName: widget.sourceName,
                  mode: mode,
                  jmCollection: _jmCollections,
                  read: () => loadSourceProfileRecords(widget.sources).of(mode),
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      _openingRecords = false;
      if (mounted) _refreshRecords();
    }
  }

  Widget _localRecords() {
    final mode = _mode!;
    if (!_managingFolders) {
      return SourceProfileRecordsView(
        key: ValueKey(mode),
        mode: mode,
        entries: _records.of(mode),
        onBack: _goBackInProfile,
        onRefreshWithResult: () => _refreshRecords(mode),
        error: _recordsError,
        source: widget.source,
        sourceName: widget.sourceName,
        jmCollection: _jmCollections,
        compactLayout: true,
        jmHeaderController: _jmCollections
            ? widget.backController?.jmHeader
            : null,
        showBackButton: widget.backController == null,
        onManageFolders: mode == ShelfPageMode.history
            ? null
            : () {
                setState(() => _managingFolders = true);
                _syncBackController();
              },
      );
    }
    return Column(
      children: [
        ListTile(
          leading: widget.backController == null
              ? const Icon(Icons.arrow_back)
              : null,
          title: Text(
            t.sourceProfile.folderTitle(label: sourceProfileRecordLabel(mode)),
          ),
          onTap: widget.backController == null ? _goBackInProfile : null,
        ),
        const Divider(height: 1),
        Expanded(
          child: FolderShelfPage(
            key: ValueKey(mode),
            mode: mode,
            backController: _folderBackController,
            handleRouteBack: false,
          ),
        ),
      ],
    );
  }

  Future<void> _openAccountDetails() async {
    if (!_canOpenAccount) return;
    final account = _account;
    if (account == null) {
      await _loginAndReload();
      return;
    }
    final accountEpoch = _accountEpoch;
    final source = widget.source;
    final generation = pluginSessionWriteFence.generation(source);
    // The JM web header links to /user/. Use the site account entry without
    // treating its app API's read-only useredit response as an upload API.
    final canUpload = widget.avatarUploadFunction.isNotEmpty;
    final website =
        !canUpload && source == PluginAccountAuthenticationService.jm
        ? Uri.https('18comic.ink', '/user/')
        : null;
    final action = await _showProfileActions<_ProfileAccountAction>(
      title: t.videoSiteAccount.title,
      rows: (sheetContext) => [
        ListTile(
          leading: SizedBox.square(
            dimension: 44,
            child: ClipOval(
              child: _avatar(
                account,
                Theme.of(sheetContext).colorScheme.primary,
              ),
            ),
          ),
          title: Text(
            account.name.isEmpty ? t.videoSource.signedIn : account.name,
          ),
          subtitle: account.slogan.isEmpty ? null : Text(account.slogan),
        ),
        ListTile(
          key: const ValueKey('profile-account-avatar-action'),
          leading: const Icon(Icons.photo_camera_outlined),
          title: Text(
            canUpload ? t.sourceShell.changeAvatar : t.videoSiteAccount.photo,
          ),
          subtitle: canUpload
              ? _copyAvatarPolicy
                    ? Text(t.sourceProfile.copyAvatarInterval)
                    : null
              : Text(
                  website == null
                      ? t.sourceProfile.avatarReadOnlyHint
                      : t.sourceProfile.avatarWebsiteHint,
                ),
          trailing: canUpload ? const Icon(Icons.chevron_right) : null,
          onTap: canUpload
              ? () => Navigator.pop(sheetContext, _ProfileAccountAction.avatar)
              : null,
        ),
        if (widget.bioUpdateFunction.isNotEmpty)
          ListTile(
            key: const ValueKey('profile-account-bio-action'),
            leading: const Icon(Icons.edit_note_outlined),
            title: Text(t.sourceProfile.editBio),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pop(sheetContext, _ProfileAccountAction.bio),
          ),
        if (website != null)
          ListTile(
            key: const ValueKey('profile-account-website-action'),
            leading: const Icon(Icons.open_in_new_rounded),
            title: Text(t.sourceProfile.openWebsiteAccount),
            onTap: () =>
                Navigator.pop(sheetContext, _ProfileAccountAction.website),
          ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.switch_account_outlined),
          title: Text(t.plugin.switchAccount),
          trailing: const Icon(Icons.chevron_right),
          onTap: () =>
              Navigator.pop(sheetContext, _ProfileAccountAction.switchAccount),
        ),
      ],
    );
    if (!mounted ||
        widget.source != source ||
        accountEpoch != _accountEpoch ||
        pluginSessionWriteFence.generation(source) != generation) {
      return;
    }
    switch (action) {
      case _ProfileAccountAction.avatar:
        await _changeAvatar();
      case _ProfileAccountAction.bio:
        await _editBio();
      case _ProfileAccountAction.website:
        await openSourceOfficialWebsite(context, website!);
      case _ProfileAccountAction.switchAccount:
        await _loginAndReload(savedAccounts: true);
      case null:
        break;
    }
  }

  Future<void> _openAppearanceMenu() async {
    final path =
        LocalAppearanceImages.instance.paths.value['profile:${widget.source}'];
    final remove = await _showProfileActions<bool>(
      title: t.omoAccount.localAppearance,
      rows: (sheetContext) => [
        ListTile(
          leading: const Icon(Icons.wallpaper_outlined),
          title: Text(t.coverPrivacy.wallpaper),
          onTap: () => Navigator.pop(sheetContext, false),
        ),
        if (path != null)
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(t.coverPrivacy.wallpaperRemove),
            onTap: () => Navigator.pop(sheetContext, true),
          ),
      ],
    );
    if (mounted && remove != null) await _changeWallpaper(remove: remove);
  }

  Future<T?> _showProfileActions<T>({
    required String title,
    required List<Widget> Function(BuildContext) rows,
  }) async {
    if (_profileSheetOpen) return null;
    setState(() => _profileSheetOpen = true);
    ModalRoute<T>? route;
    try {
      final action = await showVideoTaskSheet<T>(
        context: context,
        builder: (sheetContext) {
          route = ModalRoute.of<T>(sheetContext);
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(title),
                  trailing: IconButton(
                    tooltip: t.common.close,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ),
                ...rows(sheetContext),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      );
      await route?.completed;
      return action;
    } finally {
      if (mounted) setState(() => _profileSheetOpen = false);
    }
  }

  Future<void> _changeWallpaper({bool remove = false}) async {
    if (!_brandHero || _appearanceBusy || _editing || _choosingAvatar) return;
    final source = widget.source;
    final epoch = _accountEpoch;
    setState(() => _appearanceBusy = true);
    try {
      if (remove) {
        final key = 'profile:$source';
        final previous = LocalAppearanceImages.instance.paths.value[key];
        if (previous == null) return;
        final confirmed = await confirmLocalAppearanceImageRemoval(
          context,
          title: t.coverPrivacy.wallpaperRemoveConfirmTitle,
          description: t.coverPrivacy.wallpaperRemoveConfirm,
        );
        if (!confirmed ||
            !mounted ||
            widget.source != source ||
            epoch != _accountEpoch) {
          return;
        }
        await LocalAppearanceImages.instance.removeIfUnchanged(key, previous);
      } else {
        await pickLocalAppearanceImage(
          context,
          imageKey: 'profile:$source',
          title: t.coverPrivacy.wallpaper,
          aspectRatio: 16 / 9,
          canCommit: () =>
              mounted && widget.source == source && epoch == _accountEpoch,
        );
      }
    } catch (_) {
      if (mounted) showErrorToast(t.coverPrivacy.imageSaveFailed);
    } finally {
      if (mounted) setState(() => _appearanceBusy = false);
    }
  }

  Future<void> _invalidateAvatarCache(Set<String> paths) async {
    final dimension = (100 * MediaQuery.devicePixelRatioOf(context) * 1.2)
        .round();
    for (final path in paths) {
      if (path.isEmpty) continue;
      try {
        final cached = await DownloadAssetStore(
          from: widget.source,
          path: path,
          cartoonId: 'profile_avatar',
          chapterId: '',
          pictureType: PictureType.user,
        ).findCanonicalCache();
        if (cached != null) {
          await createCoverImageProvider(
            cached.path,
            width: dimension,
            height: dimension,
          ).evict();
          await FileImage(File(cached.path)).evict();
          await File(cached.path).delete();
        }
      } catch (_) {
        // Cache cleanup is best-effort; it cannot establish an upload result.
      }
    }
  }

  Future<void> _changeAvatar() async {
    final previous = _account;
    final source = widget.source;
    final upload = widget.avatarUploadFunction;
    if (_editing || _choosingAvatar || previous == null || upload.isEmpty)
      return;
    final accountEpoch = _accountEpoch;
    final generation = pluginSessionWriteFence.generation(source);
    bool sameSession() =>
        mounted &&
        widget.source == source &&
        _account?.id == previous.id &&
        !pluginSessionWriteFence.isChanging(source) &&
        pluginSessionWriteFence.generation(source) == generation;
    bool canSubmit() =>
        sameSession() &&
        _accountEpoch == accountEpoch &&
        widget.avatarUploadFunction == upload;
    setState(() => _choosingAvatar = true);
    try {
      final bytes = await pickUserImageBytes();
      if (bytes == null || !canSubmit()) return;
      final prepared = await prepareUserImageForEditing(bytes);
      if (!canSubmit()) return;
      final edited = await showUserImageEditor(
        context,
        bytes: prepared,
        title: t.sourceShell.changeAvatar,
        aspectRatio: 1,
        circularPreview: true,
        notice: _copyAvatarPolicy
            ? t.sourceProfile.copyAvatarRules
            : previous.avatarChangeNotice.isNotEmpty
            ? previous.avatarChangeNotice
            : null,
        confirmLabel: t.common.upload,
      );
      if (edited == null || !canSubmit()) return;
      final jpeg = await compute(prepareSourceAvatar, edited);
      var retry = true;
      while (retry && canSubmit()) {
        setState(() => _editing = true);
        try {
          final response = await callUnifiedComicPlugin(
            from: source,
            fnPath: upload,
            core: {'jpegBase64': base64Encode(jpeg)},
          );
          if (!canSubmit()) return;
          if (response['submitted'] == true) {
            showErrorToast(
              response['message']?.toString() ??
                  t.sourceProfile.avatarUnconfirmed,
            );
            // Some services replace bytes at the same URL. A submitted result
            // still needs a fresh image, but must never be promoted to success.
            await _invalidateAvatarCache({previous.avatarPath});
            if (!canSubmit()) return;
            setState(() => _avatarRevision++);
            await _loadAccount();
            return;
          }
          if (_copyAvatarPolicy && response['ok'] != true) {
            final restriction = switch (response['avatarRestriction']) {
              'cooldown' => t.sourceProfile.copyAvatarInterval,
              'rateLimit' => t.sourceProfile.avatarRateLimited,
              'image' => t.sourceProfile.avatarImageRejected,
              'signIn' => t.sourceProfile.avatarSignInRequired,
              'rejected' => t.sourceProfile.avatarRejected,
              _ => null,
            };
            if (restriction != null) {
              showErrorToast(restriction);
              return;
            }
          }
          if (response['ok'] != true) {
            throw StateError(
              response['message']?.toString() ??
                  t.sourceProfile.avatarUploadFailed,
            );
          }
          // Copy returns the profile built from its independent official read.
          // Other sources must refresh successfully before reporting an update.
          final returnedProfile = asJsonMap(response['profile']);
          late final _Account updated;
          if (response['confirmed'] == true && returnedProfile.isNotEmpty) {
            final verified = _Account.fromResponse(returnedProfile);
            if (previous.id.isEmpty ||
                verified.id != previous.id ||
                verified.avatarUrl.isEmpty ||
                (verified.avatarUrl == previous.avatarUrl &&
                    verified.avatarPath == previous.avatarPath)) {
              showErrorToast(t.imageEditor.avatarUnconfirmed);
              return;
            }
            updated = verified;
          } else {
            await _loadAccount();
            if (!sameSession()) return;
            if (_loadFailed ||
                _account == null ||
                (_account!.avatarUrl == previous.avatarUrl &&
                    _account!.avatarPath == previous.avatarPath)) {
              final refreshEpoch = _accountEpoch;
              await _invalidateAvatarCache({previous.avatarPath});
              if (!sameSession() || refreshEpoch != _accountEpoch) {
                return;
              }
              setState(() => _avatarRevision++);
              showErrorToast(t.imageEditor.avatarUnconfirmed);
              return;
            }
            updated = _account!;
          }
          final verifiedEpoch = _accountEpoch;
          // A widget key alone cannot invalidate resized FileImage entries.
          await _invalidateAvatarCache({
            previous.avatarPath,
            updated.avatarPath,
          });
          if (!sameSession() || verifiedEpoch != _accountEpoch) {
            return;
          }
          setState(() {
            _account = updated;
            _avatarRevision++;
          });
          showSuccessToast(t.sourceProfile.avatarUpdated);
          return;
        } catch (error) {
          if (!canSubmit()) return;
          setState(() => _editing = false);
          retry = await _askAvatarRetry(userFacingErrorMessage(error));
        }
      }
    } catch (error) {
      if (canSubmit()) showErrorToast(userFacingErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() {
          _editing = false;
          _choosingAvatar = false;
        });
      }
    }
  }

  Future<bool> _askAvatarRetry(String reason) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.sourceProfile.avatarUploadFailed),
        content: Text(reason),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.sourceProfile.tryLater),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.sourceProfile.retryUpload),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _editBio() async {
    final source = widget.source;
    final update = widget.bioUpdateFunction;
    if (_editing || _choosingAvatar || _account == null || update.isEmpty)
      return;
    final accountId = _account!.id;
    final accountEpoch = _accountEpoch;
    final generation = pluginSessionWriteFence.generation(source);
    bool sameSession() =>
        mounted &&
        widget.source == source &&
        _account?.id == accountId &&
        !pluginSessionWriteFence.isChanging(source) &&
        pluginSessionWriteFence.generation(source) == generation;
    String? submittedValue;
    var draft = _account?.slogan ?? '';
    var saving = false;
    String? saveError;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            scrollable: true,
            title: Row(
              children: [
                Expanded(child: Text(t.sourceProfile.editBio)),
                IconButton(
                  tooltip: t.common.close,
                  icon: const Icon(Icons.close),
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  initialValue: draft,
                  onChanged: (value) => draft = value,
                  autofocus: true,
                  maxLength: 100,
                  maxLines: 2,
                  enabled: !saving,
                  decoration: InputDecoration(
                    hintText: t.sourceProfile.bioHint,
                  ),
                ),
                if (saveError != null)
                  Text(
                    saveError!,
                    style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.error,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: saving
                    ? null
                    : () => Navigator.pop(dialogContext, false),
                child: Text(t.common.cancel),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!sameSession() ||
                            _accountEpoch != accountEpoch ||
                            widget.bioUpdateFunction != update) {
                          Navigator.pop(dialogContext, false);
                          return;
                        }
                        final value = draft.trim();
                        if (value.isEmpty) {
                          setDialogState(
                            () => saveError = t.sourceProfile.bioRequired,
                          );
                          return;
                        }
                        setDialogState(() {
                          saving = true;
                          saveError = null;
                        });
                        try {
                          final response = await callUnifiedComicPlugin(
                            from: source,
                            fnPath: update,
                            core: {'value': value},
                          );
                          if (response['ok'] != true) {
                            throw StateError(
                              t.sourceShell.profileBioSaveFailed,
                            );
                          }
                          submittedValue = value;
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (error) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              saving = false;
                              saveError = userFacingErrorMessage(error);
                            });
                          }
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(t.common.save),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != true || !sameSession() || accountEpoch != _accountEpoch) {
      return;
    }
    final refreshEpoch = _accountEpoch + 1;
    await _loadAccount();
    if (!sameSession() || refreshEpoch != _accountEpoch) {
      return;
    }
    if (accountId.isNotEmpty &&
        !_loadFailed &&
        _account?.slogan == submittedValue) {
      showSuccessToast(t.sourceShell.profileBioUpdated);
    } else {
      showErrorToast(t.sourceShell.profileBioUnconfirmed);
    }
  }
}

/// A records destination belongs to the root navigator, above both the source
/// shell and the app's tabs. Its header and Back action are owned by this page.
class _SourceComicRecordsDestination extends StatefulWidget {
  const _SourceComicRecordsDestination({
    required this.source,
    required this.sourceName,
    required this.mode,
    required this.jmCollection,
    required this.read,
  });
  final String source, sourceName;
  final ShelfPageMode mode;
  final bool jmCollection;
  final List<UnifiedComicListItem> Function() read;
  @override
  State<_SourceComicRecordsDestination> createState() =>
      _SourceComicRecordsDestinationState();
}

class _SourceComicRecordsDestinationState
    extends State<_SourceComicRecordsDestination> {
  List<UnifiedComicListItem> _entries = const [];
  String? _error;
  @override
  void initState() {
    super.initState();
    _read();
  }

  void _read() {
    try {
      _entries = widget.read();
      _error = null;
    } catch (_) {
      _error = t.sourceProfile.recordsUnavailable;
    }
  }

  PullRefreshResult _refresh() {
    if (!mounted) return PullRefreshResult.ignored;
    final previous = _entries;
    setState(_read);
    if (_error != null) return PullRefreshResult.ignored;
    return listEquals(previous, _entries)
        ? PullRefreshResult.unchanged
        : PullRefreshResult.updated;
  }

  Future<void> _folders() async {
    final search = context.read<BookshelfSearchCubit>();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(
          name: 'breeze.source.comic.record-folders',
        ),
        builder: (_) => BlocProvider.value(
          value: search,
          child: Scaffold(
            appBar: AppBar(title: Text(sourceProfileRecordLabel(widget.mode))),
            body: FolderShelfPage(mode: widget.mode),
          ),
        ),
      ),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SourceProfileRecordsView(
        mode: widget.mode,
        source: widget.source,
        sourceName: widget.sourceName,
        entries: _entries,
        error: _error,
        compactLayout: true,
        jmCollection: widget.jmCollection,
        onBack: () => Navigator.of(context).pop(),
        onRefreshWithResult: _refresh,
        onManageFolders: widget.mode == ShelfPageMode.history ? null : _folders,
      ),
    ),
  );
}
