import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/page/bookshelf/cubit/bookshelf_search_cubit.dart';
import 'package:zephyr/page/bookshelf/cubit/search_status.dart';
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/bookshelf/widgets/folder_shelf_page.dart';
import 'package:zephyr/page/source_shell/models/source_cloud_favorites.dart';
import 'package:zephyr/page/source_shell/models/source_profile_avatar.dart';
import 'package:zephyr/page/source_shell/models/source_profile_records.dart';
import 'package:zephyr/page/source_shell/view/source_profile_records_view.dart';
import 'package:zephyr/service/download/download_asset_store.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';
import 'package:zephyr/widgets/toast.dart';

enum _ProfileEditAction { avatar, bio }

class SourceProfileContent extends StatelessWidget {
  const SourceProfileContent({
    super.key,
    required this.source,
    this.legacySources = const [],
    this.avatarUploadFunction = '',
    this.bioUpdateFunction = '',
    this.profileKind = '',
    this.checkinFunction = '',
    this.notificationsFunction = '',
    required this.onLogin,
    required this.onSettings,
    required this.onBreezeSettings,
    required this.onCloudFavorite,
  });

  final String source;
  final List<String> legacySources;
  final String avatarUploadFunction;
  final String bioUpdateFunction;
  final String profileKind;
  final String checkinFunction;
  final String notificationsFunction;
  final Future<void> Function() onLogin;
  final Future<void> Function() onSettings;
  final Future<void> Function() onBreezeSettings;
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
        source: source,
        sources: search.sources,
        avatarUploadFunction: avatarUploadFunction,
        bioUpdateFunction: bioUpdateFunction,
        profileKind: profileKind,
        checkinFunction: checkinFunction,
        notificationsFunction: notificationsFunction,
        onLogin: onLogin,
        onSettings: onSettings,
        onBreezeSettings: onBreezeSettings,
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
  );
  final String name;
  final int level;
  final String title;
  final String slogan;
  final String avatarUrl;
  final String avatarPath;
  final String coin;
  final String experience;
  final String nextLevelExperience;

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
      (extern['level'] as num?)?.toInt() ?? 0,
      (extern['title']?.toString() ?? '').trim(),
      (extern['slogan']?.toString() ?? '').trim(),
      (avatar['url']?.toString() ?? '').trim(),
      (avatar['path']?.toString() ?? '').trim(),
      (extern['coin']?.toString() ?? '').trim(),
      (extern['experience']?.toString() ?? '').trim(),
      (extern['nextLevelExperience']?.toString() ?? '').trim(),
    );
  }
}

class _SourceNotice {
  const _SourceNotice({
    required this.title,
    required this.content,
    required this.time,
    required this.type,
    required this.read,
  });

  final String title;
  final String content;
  final String time;
  final String type;
  final bool read;

  factory _SourceNotice.fromMap(Map<String, dynamic> data) => _SourceNotice(
    title: data['title']?.toString() ?? '通知',
    content: (data['content']?.toString() ?? '')
        .replaceAll(RegExp(r'\n\s*\n+'), '\n')
        .trim(),
    time: data['time']?.toString() ?? '',
    type: data['type']?.toString() ?? '',
    read: data['read'] == true,
  );

  bool get isTracking =>
      type.contains('track') || type.contains('comic_follow');
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({
    required this.source,
    required this.sources,
    required this.avatarUploadFunction,
    required this.bioUpdateFunction,
    required this.profileKind,
    required this.checkinFunction,
    required this.notificationsFunction,
    required this.onLogin,
    required this.onSettings,
    required this.onBreezeSettings,
    required this.onCloudFavorite,
  });
  final String source;
  final List<String> sources;
  final String avatarUploadFunction;
  final String bioUpdateFunction;
  final String profileKind;
  final String checkinFunction;
  final String notificationsFunction;
  final Future<void> Function() onLogin;
  final Future<void> Function() onSettings;
  final Future<void> Function() onBreezeSettings;
  final Future<void> Function() onCloudFavorite;
  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  _Account? _account;
  ShelfPageMode? _mode;
  bool _managingFolders = false;
  SourceProfileRecords _records = const SourceProfileRecords(
    favorites: [],
    history: [],
    downloads: [],
  );
  String? _recordsError;
  List<UnifiedComicListItem> _cloudFavorites = const [];
  bool _cloudLoading = true;
  String? _cloudError;
  bool _loading = true;
  bool _editing = false;
  bool _checkingIn = false;
  bool _showNotifications = false;
  bool _noticeLoading = false;
  String? _noticeError;
  int _noticeFilter = 0;
  List<_SourceNotice> _notices = const [];
  bool _loadFailed = false;
  int _avatarRevision = 0;
  bool get _canEdit =>
      widget.avatarUploadFunction.isNotEmpty ||
      widget.bioUpdateFunction.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadAccount();
    _loadCloudFavorites();
    if (widget.notificationsFunction.isNotEmpty) _loadNotifications();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshRecords();
    });
  }

  void _refreshRecords() {
    try {
      final loaded = loadSourceProfileRecords(widget.sources);
      if (mounted) {
        setState(() {
          _records = loaded;
          _recordsError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _recordsError = '本地记录暂时无法读取');
      }
    }
  }

  Future<void> _refreshPage() async {
    _refreshRecords();
    await Future.wait([
      _loadAccount(),
      _loadCloudFavorites(),
      if (widget.notificationsFunction.isNotEmpty) _loadNotifications(),
    ]);
  }

  Future<void> _loadCloudFavorites() async {
    if (mounted) setState(() => _cloudLoading = true);
    try {
      final items = await loadSourceCloudFavoritePreview(
        widget.source,
        jmProfile: widget.profileKind == 'jm',
      );
      if (!mounted) return;
      setState(() {
        _cloudFavorites = items;
        _cloudError = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _cloudFavorites = const [];
          _cloudError = userFacingErrorMessage(error);
        });
      }
    } finally {
      if (mounted) setState(() => _cloudLoading = false);
    }
  }

  Future<void> _loadAccount() async {
    if (mounted) setState(() => _loading = true);
    try {
      final response = await callUnifiedComicPlugin(
        from: widget.source,
        fnPath: 'getUserInfoBundle',
        core: const <String, dynamic>{},
      );
      if (!mounted) return;
      setState(() {
        _account = _Account.fromResponse(response);
        _loadFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginAndReload() async {
    await widget.onLogin();
    if (mounted) await _refreshPage();
  }

  Future<void> _loadNotifications() async {
    if (mounted) setState(() => _noticeLoading = true);
    try {
      final response = await callUnifiedComicPlugin(
        from: widget.source,
        fnPath: widget.notificationsFunction,
        core: const <String, dynamic>{},
      );
      if (!mounted) return;
      final data = asJsonMap(response['data']);
      setState(() {
        _notices = asJsonList(
          data['items'],
        ).map((item) => _SourceNotice.fromMap(asJsonMap(item))).toList();
        _noticeError = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _noticeError = userFacingErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _noticeLoading = false);
    }
  }

  Future<void> _openCloudFavorites() async {
    await widget.onCloudFavorite();
    if (mounted) await _loadCloudFavorites();
  }

  Future<void> _checkIn() async {
    if (_checkingIn) return;
    setState(() => _checkingIn = true);
    try {
      final result = await callUnifiedComicPlugin(
        from: widget.source,
        fnPath: widget.checkinFunction,
        core: const <String, dynamic>{},
      );
      final data = asJsonMap(result['data']);
      if (data['ok'] != true) {
        throw StateError(data['message']?.toString() ?? '签到失败，请稍后重试');
      }
      showSuccessToast(data['message']?.toString() ?? '今日已签到');
      await _loadAccount();
    } catch (error) {
      if (mounted) showErrorToast(userFacingErrorMessage(error));
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  Widget _cloudPreview() => SourceProfileComicPreviewCard(
    previewKey: const ValueKey('profile-preview-cloud'),
    title: '云端收藏',
    icon: Icons.cloud_outlined,
    entries: _cloudFavorites,
    type: ComicEntryType.normal,
    emptyMessage: '云端还没有收藏的漫画',
    loading: _cloudLoading,
    error: _cloudError,
    onRetry: _loadCloudFavorites,
    onViewAll: _openCloudFavorites,
    onReturned: _loadCloudFavorites,
  );

  @override
  Widget build(BuildContext context) {
    if (_mode != null) return _localRecords();
    if (_showNotifications) return _notificationsView();
    final colors = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _refreshPage,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          widget.profileKind == 'jm' ? _jmHero(colors) : _hero(colors),
          if (widget.notificationsFunction.isNotEmpty)
            _notificationsEntry(colors),
          const SizedBox(height: 18),
          if (widget.profileKind == 'jm') ...[
            _sectionLabel('云端与本地'),
            _cloudPreview(),
          ] else
            _sectionLabel('我的记录'),
          if (_recordsError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextButton.icon(
                onPressed: _refreshRecords,
                icon: const Icon(Icons.refresh),
                label: Text('$_recordsError · 重试'),
              ),
            )
          else ...[
            for (final mode in [
              ShelfPageMode.download,
              ShelfPageMode.history,
              ShelfPageMode.favorite,
            ])
              SourceProfilePreviewSection(
                mode: mode,
                entries: _records.of(mode),
                onViewAll: () => _openRecords(mode),
                onReturned: _refreshRecords,
              ),
          ],
          if (widget.profileKind != 'jm') _cloudPreview(),
          const SizedBox(height: 20),
          _sectionLabel('设置'),
          _group(colors, [
            _entry(
              Icons.tune_outlined,
              widget.profileKind == 'jm' ? '禁漫设置' : '哔咔设置',
              '账号与线路',
              widget.onSettings,
            ),
            _entry(
              Icons.settings_outlined,
              'Breeze 设置',
              '阅读与应用',
              widget.onBreezeSettings,
            ),
          ]),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _notificationsEntry(ColorScheme colors) {
    final unread = _notices.where((item) => !item.read).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Icon(Icons.notifications_outlined, color: colors.primary),
          title: const Text('站内消息与追漫通知'),
          subtitle: Text(
            _noticeLoading
                ? '正在同步消息…'
                : _noticeError != null
                ? '消息暂不可用 · 点此重试'
                : unread > 0
                ? '$unread 条未读'
                : '查看站内与追漫更新',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            if (_account == null) {
              _loginAndReload();
              return;
            }
            setState(() => _showNotifications = true);
            if (_noticeError != null) _loadNotifications();
          },
        ),
      ),
    );
  }

  Widget _notificationsView() {
    final colors = Theme.of(context).colorScheme;
    final visible = _notices
        .where(
          (notice) => switch (_noticeFilter) {
            1 => notice.isTracking,
            2 => !notice.isTracking,
            _ => true,
          },
        )
        .toList();
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.arrow_back),
          title: const Text('站内消息'),
          trailing: IconButton(
            tooltip: '刷新消息',
            onPressed: _noticeLoading ? null : _loadNotifications,
            icon: const Icon(Icons.refresh),
          ),
          onTap: () => setState(() => _showNotifications = false),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              for (final (index, label) in [
                (0, '全部'),
                (1, '追漫'),
                (2, '站内'),
              ]) ...[
                if (index > 0) const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(label),
                  selected: _noticeFilter == index,
                  onSelected: (_) => setState(() => _noticeFilter = index),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _noticeLoading && _notices.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _noticeError != null && _notices.isEmpty
              ? Center(
                  child: TextButton.icon(
                    onPressed: _loadNotifications,
                    icon: const Icon(Icons.refresh),
                    label: Text('$_noticeError · 重试'),
                  ),
                )
              : visible.isEmpty
              ? Center(
                  child: Text(
                    '暂无消息',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, index) {
                      final notice = visible[index];
                      return ListTile(
                        onTap: () => _showNoticeDetail(notice),
                        leading: Icon(
                          notice.isTracking
                              ? Icons.bookmark_added_outlined
                              : Icons.notifications_none_outlined,
                          color: notice.read
                              ? colors.onSurfaceVariant
                              : colors.primary,
                        ),
                        title: Text(
                          notice.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (notice.content.isNotEmpty)
                              Text(
                                notice.content,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (notice.time.isNotEmpty)
                              Text(
                                notice.time,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        isThreeLine: notice.content.isNotEmpty,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _showNoticeDetail(_SourceNotice notice) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          notice.title,
                          style: Theme.of(sheetContext).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭消息',
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
                      notice.time,
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                  ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: SelectionArea(
                      child: Text(
                        notice.content.isEmpty ? '暂无内容' : notice.content,
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

  Widget _jmHero(ColorScheme colors) {
    final account = _account;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child: _avatar(account, colors.primary),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account?.name.isNotEmpty == true ? account!.name : '禁漫账号',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      account == null
                          ? (_loading ? '正在读取账号…' : '登录后同步收藏与签到')
                          : 'Lv.${account.level}'
                                '${account.title.isEmpty ? '' : ' · ${account.title}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    if (account != null && account.coin.isNotEmpty)
                      Text(
                        '硬币 ${account.coin}'
                        '${account.experience.isEmpty ? '' : '  ·  经验 ${account.experience}${account.nextLevelExperience.isEmpty ? '' : '/${account.nextLevelExperience}'}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: account == null
                      ? _loginAndReload
                      : widget.checkinFunction.isEmpty || _checkingIn
                      ? null
                      : _checkIn,
                  icon: _checkingIn
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          account == null
                              ? Icons.login
                              : Icons.event_available_outlined,
                        ),
                  label: Text(account == null ? '登录账号' : '今日签到'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onSettings,
                  icon: const Icon(Icons.tune_outlined),
                  label: const Text('账号与线路'),
                ),
              ),
            ],
          ),
          if (_loadFailed) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: _loadAccount,
              child: const Text('资料暂不可用 · 重试'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _hero(ColorScheme colors) {
    final account = _account;
    final heroColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF8F405F)
        : const Color(0xFFE58EB6);
    const foreground = Colors.white;
    return Container(
      width: double.infinity,
      color: heroColor,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: account == null || _editing || !_canEdit
                  ? null
                  : _editMenu,
              icon: Icon(Icons.edit_outlined, size: 18, color: foreground),
              label: Text('编辑', style: TextStyle(color: foreground)),
            ),
          ),
          Text(
            account == null ? '哔咔账号' : 'Lv. ${account.level}',
            style: TextStyle(
              color: foreground,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: account == null
                ? (_loadFailed ? _loadAccount : _loginAndReload)
                : (_canEdit ? _editMenu : null),
            customBorder: const CircleBorder(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 108,
                  height: 108,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: foreground.withValues(alpha: 0.25),
                  ),
                  child: ClipOval(child: _avatar(account, foreground)),
                ),
                if (account != null && widget.avatarUploadFunction.isNotEmpty)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 15,
                      backgroundColor: colors.surface,
                      child: Icon(
                        Icons.camera_alt_outlined,
                        size: 17,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 13),
          if (_loading && account == null)
            Text('加载中…', style: TextStyle(color: foreground))
          else if (account == null) ...[
            Text(
              _loadFailed ? '资料暂不可用' : '未登录',
              style: TextStyle(
                color: foreground,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: _loadFailed ? _loadAccount : _loginAndReload,
              child: Text(
                _loadFailed ? '重试加载资料' : '登录哔咔',
                style: TextStyle(color: foreground),
              ),
            ),
            if (_loadFailed)
              TextButton(
                onPressed: _loginAndReload,
                child: Text('重新登录', style: TextStyle(color: foreground)),
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
              onPressed: _loadAccount,
              child: Text('资料加载失败 · 重试', style: TextStyle(color: foreground)),
            ),
          ],
        ],
      ),
    );
  }

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
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 9),
    child: Text(
      label,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _group(ColorScheme colors, List<Widget> children) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(15),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: 54, color: colors.outlineVariant),
            children[i],
          ],
        ],
      ),
    ),
  );

  Widget _entry(
    IconData icon,
    String label,
    String detail,
    Future<void> Function() onTap,
  ) => ListTile(
    leading: Icon(icon, size: 22),
    title: Text(label),
    subtitle: detail.isEmpty
        ? null
        : Text(detail, style: const TextStyle(fontSize: 12)),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );

  void _openRecords(ShelfPageMode mode) {
    _refreshRecords();
    setState(() {
      _mode = mode;
      _managingFolders = false;
    });
  }

  Widget _localRecords() {
    final mode = _mode!;
    if (!_managingFolders) {
      return SourceProfileRecordsView(
        key: ValueKey(mode),
        mode: mode,
        entries: _records.of(mode),
        onBack: () {
          _refreshRecords();
          setState(() => _mode = null);
        },
        onRefresh: _refreshRecords,
        source: widget.source,
        onManageFolders: mode == ShelfPageMode.history
            ? null
            : () => setState(() => _managingFolders = true),
      );
    }
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.arrow_back),
          title: Text('${sourceProfileRecordLabel(mode)} · 文件夹'),
          onTap: () {
            _refreshRecords();
            setState(() => _managingFolders = false);
          },
        ),
        const Divider(height: 1),
        Expanded(
          child: FolderShelfPage(key: ValueKey(mode), mode: mode),
        ),
      ],
    );
  }

  Future<void> _editMenu() async {
    if (_account == null) return;
    ModalRoute<dynamic>? editSheetRoute;
    final action = await showModalBottomSheet<_ProfileEditAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        editSheetRoute = ModalRoute.of(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('编辑资料'),
                trailing: IconButton(
                  tooltip: '关闭',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(sheetContext),
                ),
              ),
              if (widget.avatarUploadFunction.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('更换头像'),
                  onTap: () =>
                      Navigator.pop(sheetContext, _ProfileEditAction.avatar),
                ),
              if (widget.bioUpdateFunction.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.edit_note_outlined),
                  title: const Text('修改简介'),
                  onTap: () =>
                      Navigator.pop(sheetContext, _ProfileEditAction.bio),
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
    // Wait for the sheet's reverse transition before opening another modal.
    await editSheetRoute?.completed;
    if (!mounted) return;
    switch (action) {
      case _ProfileEditAction.avatar:
        await _changeAvatar();
      case _ProfileEditAction.bio:
        await _editBio();
      case null:
        break;
    }
  }

  Future<void> _changeAvatar() async {
    try {
      final file = Platform.isIOS || Platform.isAndroid
          ? await ImagePicker().pickImage(
              source: ImageSource.gallery,
              maxWidth: 1200,
              maxHeight: 1200,
              imageQuality: 85,
              requestFullMetadata: false,
            )
          : await openFile(
              acceptedTypeGroups: [
                const XTypeGroup(
                  label: '图片',
                  extensions: ['jpg', 'jpeg', 'png', 'webp'],
                  uniformTypeIdentifiers: ['public.image'],
                ),
              ],
            );
      if (file == null || !mounted) return;
      final jpeg = await compute(prepareSourceAvatar, await file.readAsBytes());
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('更换头像'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: Image.memory(
                  jpeg,
                  width: 160,
                  height: 160,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
              const Text('将上传这张头像'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('上传'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      var retry = true;
      while (retry && mounted) {
        setState(() => _editing = true);
        try {
          final response = await callUnifiedComicPlugin(
            from: widget.source,
            fnPath: widget.avatarUploadFunction,
            core: {'jpegBase64': base64Encode(jpeg)},
          );
          if (response['ok'] == false) {
            throw StateError(response['message']?.toString() ?? '头像上传失败');
          }
          final oldPath = _account?.avatarPath ?? '';
          if (oldPath.isNotEmpty) {
            try {
              final cache = DownloadAssetStore(
                from: widget.source,
                path: oldPath,
                cartoonId: 'profile_avatar',
                chapterId: '',
                pictureType: PictureType.user,
              );
              final cached = await cache.findCanonicalCache();
              if (cached != null) await File(cached.path).delete();
            } catch (_) {
              // Upload succeeded; cache cleanup must not turn it into failure.
            }
          }
          if (mounted) setState(() => _avatarRevision++);
          showSuccessToast('头像已更新');
          await _loadAccount();
          return;
        } catch (error) {
          debugPrint('Avatar upload failed: $error');
          if (!mounted) return;
          setState(() => _editing = false);
          retry = await _askAvatarRetry(userFacingErrorMessage(error));
        }
      }
    } catch (error) {
      if (mounted) showErrorToast(userFacingErrorMessage(error));
    } finally {
      if (mounted) setState(() => _editing = false);
    }
  }

  Future<bool> _askAvatarRetry(String reason) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('头像上传失败'),
        content: Text(reason),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('稍后再试'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('重试上传'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _editBio() async {
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
            title: Row(
              children: [
                const Expanded(child: Text('修改简介')),
                IconButton(
                  tooltip: '关闭',
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
                  decoration: const InputDecoration(hintText: '写点什么…'),
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
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final value = draft.trim();
                        if (value.isEmpty) {
                          setDialogState(() => saveError = '简介不能为空');
                          return;
                        }
                        setDialogState(() {
                          saving = true;
                          saveError = null;
                        });
                        try {
                          await callUnifiedComicPlugin(
                            from: widget.source,
                            fnPath: widget.bioUpdateFunction,
                            core: {'value': value},
                          );
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
                    : const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != true || !mounted) return;
    showSuccessToast('简介已更新');
    await _loadAccount();
  }
}
