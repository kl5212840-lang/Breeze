import 'dart:async';

import 'package:auto_route/auto_route.dart' show AutoRoutePage;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/task_dialog.dart';
import 'package:zephyr/widgets/collection_results_row.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/page/comic_info/models/plugin_action_login.dart';
import 'package:zephyr/page/comic_info/view/comic_info.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/search_result/view/search_result_page.dart';
import 'package:zephyr/page/setting/common/setting_page_route.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/widgets/breeze_switch.dart';
import 'package:zephyr/page/source_shell/models/jm_account_read_cache.dart';
import 'package:zephyr/service/read_recovery.dart';
import 'package:zephyr/widgets/read_recovery_scope.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/page/video/video_interaction.dart'
    show videoOverlayMedia;
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/page_read_tasks.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/widgets/short_alert.dart';

enum JmAccountCollection {
  follows(Icons.notifications_active_outlined),
  tags(Icons.label_outline),
  comic(Icons.bookmarks_outlined);

  const JmAccountCollection(this.icon);

  String get title => switch (this) {
    follows => t.sourceProfile.jmFollowCollection,
    tags => t.sourceProfile.jmTagCollection,
    comic => t.sourceProfile.jmAccountFavorites,
  };
  final IconData icon;
}

Future<void> openJmAccountCollection(
  BuildContext context, {
  required String source,
  required JmAccountCollection collection,
  String? accountId,
  String? comicId,
  List<String> comicTags = const [],
}) => Navigator.of(context).push<void>(
  videoPageRoute<void>(
    settings: RouteSettings(name: 'breeze.source.jm.${collection.name}'),
    matchAutoRouteTransition: ModalRoute.of(context)?.settings is AutoRoutePage,
    builder: (_) => InheritedTheme.captureAll(
      context,
      SourceExperienceBoundary(
        source: source,
        builder: (_) => _JmAccountCollectionPage(
          source: source,
          collection: collection,
          accountId: accountId,
          comicId: comicId,
          comicTags: comicTags,
        ),
      ),
    ),
  ),
);

class _JmAccountCollectionPage extends StatefulWidget {
  const _JmAccountCollectionPage({
    required this.source,
    required this.collection,
    required this.accountId,
    required this.comicId,
    required this.comicTags,
  });

  final String source;
  final JmAccountCollection collection;
  final String? accountId;
  final String? comicId;
  final List<String> comicTags;

  @override
  State<_JmAccountCollectionPage> createState() => _JmAccountCollectionState();
}

typedef _Follow = ({String id, String title});
typedef _AccountRows = ({
  List<_Follow> follows,
  List<String> tags,
  int page,
  int? total,
  bool hasMore,
});

class _JmAccountCollectionState extends State<_JmAccountCollectionPage> {
  late final StreamSubscription<PluginSessionBoundary> _sessionChanges;
  static final _cache = JmAccountReadCache<_AccountRows>();
  late final ReadRecoveryController _readRecovery;
  final _reads = PageReadTasks();
  Future<void>? _loadTask;
  bool _retryMore = false, _pendingMore = false, _followCursorInvalid = false;
  int _loadEpoch = 0;
  int? _followTotal;
  final _removedFollows = <String>{};

  bool get _cacheable => widget.collection != JmAccountCollection.comic;

  void _remember(int epoch) {
    if (!_cacheable || _follows.length > 120) return;
    _cache.write(widget.source, _accountId, widget.collection.name, (
      follows: List.unmodifiable(_follows),
      tags: List.unmodifiable(_tags),
      page: _page,
      total: _followTotal,
      hasMore: _hasMore,
    ), epoch);
  }

  String? _accountId;
  List<_Follow> _follows = [];
  List<String> _tags = [];
  bool? _enabled;
  String? _error;
  bool _needsLogin = false;
  bool _accountChanged = false;
  bool _loading = false;
  bool _hasMore = false;
  bool _managingTags = false;
  int _page = 1;
  String? _writing;

  @override
  void initState() {
    super.initState();
    _readRecovery = ReadRecoveryController(
      source: widget.source,
      retry: () => _load(more: _retryMore),
    );
    _sessionChanges = pluginSessionWriteFence.changes.listen((change) {
      if (change.source != widget.source || !mounted) return;
      _readRecovery.reset();
      _loadEpoch++;
      unawaited(_reads.cancel());
      _loadTask = null;
      _retryMore = false;
      _followCursorInvalid = false;
      _followTotal = null;
      _removedFollows.clear();
      setState(() {
        _accountChanged = widget.accountId != null;
        _accountId = null;
        _follows = [];
        _tags = [];
        _enabled = null;
        _error = _accountChanged ? '禁漫账号已变化，请返回个人页后重开' : null;
        _needsLogin = false;
        _loading = false;
        _hasMore = false;
        _managingTags = false;
        _page = 1;
        _writing = null;
      });
      if (!_accountChanged && !change.changing) unawaited(_load());
    });
    final saved = _cacheable
        ? _cache.read(widget.source, widget.accountId, widget.collection.name)
        : null;
    if (saved == null) {
      unawaited(_load());
    } else {
      _accountId = widget.accountId;
      _follows = [...saved.data.follows];
      _tags = [...saved.data.tags];
      _page = saved.data.page;
      _followTotal = saved.data.total;
      _hasMore = saved.data.hasMore;
      if (DateTime.now().difference(saved.time) >= const Duration(seconds: 45))
        _readRecovery.invalidate();
    }
  }

  @override
  void dispose() {
    _readRecovery.dispose();
    _loadEpoch++;
    unawaited(_reads.cancel());
    unawaited(_sessionChanges.cancel());
    super.dispose();
  }

  bool _isCurrent(int generation) =>
      mounted &&
      !pluginSessionWriteFence.isChanging(widget.source) &&
      pluginSessionWriteFence.generation(widget.source) == generation;

  Future<Map<String, dynamic>> _request(
    Map<String, dynamic> core, {
    bool write = false,
    String? taskGroupKey,
  }) async {
    final expected = _accountId ?? widget.accountId;
    final response = await callUnifiedComicPlugin(
      from: widget.source,
      fnPath: write ? 'setJmAccountCollection' : 'getJmAccountCollection',
      core: {...core, 'accountId': ?expected},
      notifyUnauthorized: false,
      taskGroupKey: taskGroupKey,
    );
    final data = asJsonMap(response['data']);
    final actual = data['accountId'];
    if (response['source'] != widget.source ||
        actual is! String ||
        actual.isEmpty ||
        (expected != null && expected != actual)) {
      throw const PluginSessionChanged();
    }
    return data;
  }

  List<String> _tagList(Map<String, dynamic> data) {
    final tags = data['tags'];
    if (tags is! List || tags.any((tag) => tag is! String)) {
      throw const FormatException();
    }
    return tags.cast<String>();
  }

  void _report(Object error, {String? message}) {
    final unsigned =
        error is PluginLoginRequiredException ||
        pluginActionLoginRequirement(
              error.toString(),
              pluginId: widget.source,
            ) !=
            null;
    if (unsigned || error is PluginSessionChanged) {
      _cache.remove(widget.source, _accountId, widget.collection.name);
    }
    setState(() {
      _needsLogin = unsigned;
      _error = unsigned ? '请登录禁漫账号' : message ?? '暂时无法确认账号收藏，请刷新后重试';
      if (unsigned || error is PluginSessionChanged) {
        _accountId = null;
        _follows = [];
        _tags = [];
        _enabled = null;
        _hasMore = false;
      }
    });
  }

  Future<void> _load({bool more = false}) {
    final pending = _loadTask;
    if (pending != null && (more || !_pendingMore)) return pending;
    if (pending != null) unawaited(_reads.cancel());
    final epoch = ++_loadEpoch;
    final append = more && !_followCursorInvalid;
    _pendingMore = append;
    final task = _fetch(more: append, epoch: epoch);
    _loadTask = task;
    return task.whenComplete(() {
      if (identical(_loadTask, task)) _loadTask = null;
    });
  }

  Future<void> _fetch({required bool more, required int epoch}) async {
    final generation = pluginSessionWriteFence.generation(widget.source);
    final cacheGeneration = _cache.generation;
    bool current() => epoch == _loadEpoch && _isCurrent(generation);
    if (_accountChanged || _writing != null || !current()) return;
    var page = more ? _page + 1 : 1;
    final targetPage = more ? page : _page;
    final elapsed = Stopwatch()..start();
    Future<Map<String, dynamic>> read(int page) {
      final remaining = const Duration(seconds: 22) - elapsed.elapsed;
      if (remaining <= Duration.zero)
        throw TimeoutException(t.common.loadingFailed);
      return _reads
          .run(
            widget.source,
            (group) => _request({
              'collection': widget.collection.name,
              'comicId': ?widget.comicId,
              if (widget.collection == JmAccountCollection.follows)
                'page': page,
            }, taskGroupKey: group),
          )
          .timeout(remaining);
    }

    setState(() {
      _loading = true;
      if (!isAutomaticReadRecovery) _error = null;
    });
    try {
      var data = await read(page);
      if (!current()) return;
      var follows = <_Follow>[if (more) ..._follows];
      final tags = <String>[];
      bool? enabled;
      bool hasMore = false;
      int? total = more ? _followTotal : null;
      switch (widget.collection) {
        case JmAccountCollection.follows:
          final seen = {for (final follow in follows) follow.id};
          while (true) {
            final rows = data['items'];
            final reportedPage = data['page'];
            if (rows is! List ||
                data['hasMore'] is! bool ||
                reportedPage != null &&
                    reportedPage != page &&
                    reportedPage != '$page') {
              throw const FormatException();
            }
            final incomingTotal = data['total'];
            if (incomingTotal is int && incomingTotal >= 0) {
              if (total != null && total != incomingTotal) {
                if (more) _followCursorInvalid = true;
                throw const FormatException();
              }
              total = incomingTotal;
            }
            for (final row in rows) {
              final item = asJsonMap(row);
              final id = item['id'], title = item['title'];
              if (id is! String || title is! String)
                throw const FormatException();
              if (_removedFollows.contains(id)) throw StateError('网络数据尚未更新');
              if (!seen.add(id)) {
                if (more) _followCursorInvalid = true;
                throw const FormatException();
              }
              follows.add((id: id, title: title));
            }
            hasMore = data['hasMore'] == true;
            if (total != null &&
                (!hasMore && follows.length != total ||
                    follows.length > total)) {
              if (more) _followCursorInvalid = true;
              throw const FormatException();
            }
            if (!hasMore || page >= targetPage) break;
            data = await read(++page);
            if (!current()) return;
          }
        case JmAccountCollection.tags:
          tags.addAll(_tagList(data));
        case JmAccountCollection.comic:
          tags.addAll(_tagList(data));
          final value = data['enabled'];
          if (value is! bool) throw const FormatException();
          enabled = value;
      }
      setState(() {
        _accountId = data['accountId'] as String;
        _follows = follows;
        _tags = tags;
        _enabled = enabled;
        _hasMore = hasMore;
        _followTotal = total;
        _followCursorInvalid = false;
        _removedFollows.clear();
        _needsLogin = false;
        _error = null;
        _page = page;
      });
      _retryMore = false;
      _readRecovery.succeeded();
      _remember(cacheGeneration);
    } catch (error) {
      if (current()) {
        if (error is TimeoutException) unawaited(_reads.cancel());
        _retryMore = more && !_followCursorInvalid;
        _readRecovery.failed(error);
        _report(error, message: t.common.loadingFailed);
      }
    } finally {
      if (current()) setState(() => _loading = false);
    }
  }

  Future<bool> _change(
    String key,
    bool desired, {
    String? tag,
    String? comic,
  }) async {
    final generation = pluginSessionWriteFence.generation(widget.source);
    if (!_canWrite || !_isCurrent(generation)) {
      return false;
    }
    setState(() {
      _writing = key;
      _error = null;
    });
    try {
      final data = await _request({
        'collection': tag == null ? 'follows' : 'tags',
        'enabled': desired,
        'comicId': ?comic,
        if (tag != null) ...{
          'tags': [tag],
          if (!desired && _tags.contains(tag)) 'tagWasPresent': true,
        },
      }, write: true);
      if (!_isCurrent(generation)) return false;
      if (tag != null) {
        final tags = _tagList(data);
        if (tags.contains(tag) != desired) throw const FormatException();
        setState(() => _tags = tags);
      } else {
        if (data['enabled'] != desired) throw const FormatException();
        if (widget.collection == JmAccountCollection.comic) {
          setState(() => _enabled = desired);
        } else {
          setState(() {
            _follows.removeWhere((follow) => follow.id == comic);
            if (comic != null) _removedFollows.add(comic);
            _followCursorInvalid = true;
            _followTotal = null;
          });
        }
      }
      final kind = tag == null
          ? JmAccountCollection.follows
          : JmAccountCollection.tags;
      _cache.remove(widget.source, _accountId, kind.name);
      if (widget.collection == JmAccountCollection.tags) {
        _remember(_cache.generation);
      }
    } catch (error) {
      if (_isCurrent(generation)) {
        _report(
          error,
          message: widget.collection == JmAccountCollection.tags
              ? t.sourceProfile.jmTagWriteFailed
              : null,
        );
      }
      return false;
    } finally {
      if (_isCurrent(generation)) setState(() => _writing = null);
    }
    // Removing a row shifts later pages. Restart paging after the confirmed change.
    if (_isCurrent(generation) &&
        _error == null &&
        widget.collection == JmAccountCollection.follows) {
      await _load();
    }
    return true;
  }

  Future<void> _openComic(String id) => openSettingPage(
    context,
    route: ComicInfoRoute(
      comicId: id,
      from: widget.source,
      type: ComicEntryType.normal,
    ),
    builder: (_) => ComicInfoPage(
      comicId: id,
      from: widget.source,
      type: ComicEntryType.normal,
    ),
  );

  Future<void> _openTag(String tag) {
    final search = SearchEvent().copyWith(
      searchStates: SearchStates.initial().copyWith(
        from: widget.source,
        searchKeyword: tag,
        pluginExtern: const {'main_tag': 3},
      ),
    );
    return openSettingPage(
      context,
      route: SearchResultRoute(searchEvent: search),
      builder: (context) =>
          SearchResultPage(searchEvent: search).wrappedRoute(context),
    );
  }

  Future<void> _confirmTagRemoval(String tag, String title) async {
    final generation = pluginSessionWriteFence.generation(widget.source);
    if (!_canWrite || !_isCurrent(generation)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ShortAlert(
        title: Text(t.sourceProfile.jmRemoveTagConfirm(name: title)),
        actions: [
          ShortAlertAction(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(t.common.cancel),
          ),
          ShortAlertAction(
            destructive: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t.common.remove),
          ),
        ],
      ),
    );
    if (confirmed != true || !_isCurrent(generation) || !_tags.contains(tag)) {
      return;
    }
    if (await _change(tag, false, tag: tag) && _isCurrent(generation)) {
      _tagNotice(t.sourceProfile.jmTagRemoved);
    }
  }

  Future<void> _addTag() async {
    final generation = pluginSessionWriteFence.generation(widget.source);
    if (!_canWrite || !_isCurrent(generation)) return;
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => MediaQuery(
        data: videoOverlayMedia(MediaQuery.of(context)),
        child: _AddJmTagDialog(
          save: (tag) async {
            if (!_isCurrent(generation))
              return t.sourceProfile.jmTagWriteFailed;
            if (_error != null && !_needsLogin) await _load();
            if (!_isCurrent(generation) || !_canWrite) {
              return t.sourceProfile.jmTagWriteFailed;
            }
            if (_tags.contains(tag)) return t.sourceProfile.jmTagExists;
            return await _change(tag, true, tag: tag)
                ? null
                : t.sourceProfile.jmTagWriteFailed;
          },
        ),
      ),
    );
    if (added == true && _isCurrent(generation)) {
      _tagNotice(t.sourceProfile.jmTagAdded);
    }
  }

  void _tagNotice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  bool get _busy => _loading || _writing != null;
  bool get _canWrite => !_busy && _error == null && _accountId != null;

  Widget _removeButton(String key, String label, VoidCallback remove) =>
      _writing == key
      ? const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        )
      : IconButton(
          tooltip: label,
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: _canWrite ? remove : null,
        );

  Widget _status(String message, {Widget? action}) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 8), action],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => ReadRecoveryHost(
    onActiveChanged: _readRecovery.setActive,
    child: _buildPage(context),
  );

  Widget _buildPage(BuildContext context) {
    final display = watchChineseDisplayConverter(context);
    final contents = <Widget>[
      if (widget.collection == JmAccountCollection.comic && _loading)
        const LinearProgressIndicator(),
      if (_error case final error?)
        _status(
          display(error),
          action: _accountChanged
              ? null
              : TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          if (_needsLogin) {
                            await openPluginActionLogin(
                              context,
                              source: widget.source,
                              refresh: _load,
                            );
                          } else {
                            _readRecovery.reset();
                            await _load(more: _retryMore);
                          }
                        },
                  child: Text(
                    _needsLogin ? t.navigation.goLogin : t.common.retry,
                  ),
                ),
        ),
    ];
    switch (widget.collection) {
      case JmAccountCollection.follows:
        if (_follows.isEmpty && _error == null && !_loading) {
          contents.add(_status(display(t.sourceProfile.jmFollowsEmpty)));
        }
        contents.addAll([
          for (final follow in _follows)
            ListTile(
              key: ValueKey(follow.id),
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(display(follow.title)),
              onTap: () async {
                await _openComic(follow.id);
                if (mounted) await _load();
              },
              trailing: _removeButton(
                follow.id,
                display('取消连载追踪'),
                () => _change(follow.id, false, comic: follow.id),
              ),
            ),
          if (_hasMore)
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => _load(more: true),
                child: Text(display('加载更多')),
              ),
            ),
        ]);
      case JmAccountCollection.tags:
        if (_tags.isEmpty && _error == null && !_loading) {
          contents.add(
            _status(
              display(t.sourceProfile.jmTagsEmpty),
              action: !_managingTags && _canWrite
                  ? TextButton.icon(
                      onPressed: _addTag,
                      icon: const Icon(Icons.add),
                      label: Text(t.sourceProfile.jmAddTag),
                    )
                  : null,
            ),
          );
        }
        contents.addAll([
          if (_managingTags)
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(t.sourceProfile.jmAddTag),
              onTap: _canWrite ? _addTag : null,
            ),
          for (final tag in _tags)
            ListTile(
              key: ValueKey(tag),
              leading: const Icon(Icons.label_outline),
              title: Text(
                display(tag),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: _managingTags ? null : () => _openTag(tag),
              trailing: !_managingTags
                  ? Icon(
                      Directionality.of(context) == TextDirection.rtl
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                    )
                  : _writing == tag
                  ? const SizedBox.square(
                      dimension: 48,
                      child: Center(
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : IconButton(
                      tooltip: t.sourceProfile.jmRemoveTag,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _canWrite
                          ? () => _confirmTagRemoval(tag, display(tag))
                          : null,
                    ),
            ),
        ]);
      case JmAccountCollection.comic:
        if (_enabled case final enabled?) {
          contents.add(
            SettingSection(
              children: [
                BreezeSwitchListTile(
                  SwitchListTile(
                    secondary: Icon(JmAccountCollection.follows.icon),
                    title: Text(display(t.sourceProfile.jmFollowSeries)),
                    value: enabled,
                    thumbIcon: settingSwitchThumbIcon(context),
                    onChanged: _canWrite
                        ? (value) => _change('', value, comic: widget.comicId)
                        : null,
                  ),
                ),
              ],
            ),
          );
          final tags = {
            for (final tag in widget.comicTags)
              if (tag.trim().isNotEmpty && !tag.contains(',')) tag.trim(),
          };
          if (tags.isNotEmpty) {
            contents.add(
              SettingSection(
                title: display(t.sourceProfile.jmFavoriteTags),
                hasLeading: false,
                children: [
                  for (final tag in tags)
                    CheckboxListTile(
                      key: ValueKey(tag),
                      controlAffinity: ListTileControlAffinity.trailing,
                      title: Text(display(tag)),
                      value: _tags.contains(tag),
                      onChanged: _canWrite
                          ? (value) => _change(tag, value == true, tag: tag)
                          : null,
                    ),
                ],
              ),
            );
          }
        }
    }
    final body = SafeArea(
      top: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          padding: widget.collection == JmAccountCollection.comic
              ? const EdgeInsets.only(bottom: 24)
              : null,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: contents.length,
          itemBuilder: (_, index) => contents[index],
        ),
      ),
    );
    if (widget.collection == JmAccountCollection.comic) {
      return SettingPageShell(
        grouped: true,
        title: display(widget.collection.title),
        child: body,
      );
    }
    return Scaffold(
      appBar: sourceSecondaryAppBar(
        context,
        title: display(widget.collection.title),
        actions: [
          if (widget.collection == JmAccountCollection.tags &&
              _accountId != null)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() => _managingTags = !_managingTags),
              style: TextButton.styleFrom(
                minimumSize: Size.square(
                  CollectionToolbarMetrics.actionExtentOf(context),
                ),
              ),
              child: Text(_managingTags ? t.common.done : t.bookshelf.manage),
            ),
        ],
      ),
      body: Column(
        children: [
          CollectionResultsRow(
            countLabel: _loading && _follows.isEmpty && _tags.isEmpty
                ? t.common.loading
                : _error != null && _follows.isEmpty && _tags.isEmpty
                ? ''
                : t.videoLibrary.results(
                    count: widget.collection == JmAccountCollection.tags
                        ? _tags.length
                        : _followTotal ?? _follows.length,
                  ),
          ),
          SizedBox(
            height: 2,
            child: _loading ? const LinearProgressIndicator() : null,
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _AddJmTagDialog extends StatefulWidget {
  const _AddJmTagDialog({required this.save});

  final Future<String?> Function(String tag) save;

  @override
  State<_AddJmTagDialog> createState() => _AddJmTagDialogState();
}

class _AddJmTagDialogState extends State<_AddJmTagDialog> {
  final _input = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final tag = _input.text.trim();
    if (_saving || tag.isEmpty) return;
    if (RegExp(r'[,\x00-\x1f\x7f]').hasMatch(tag)) {
      setState(() => _error = t.sourceProfile.jmTagInvalid);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.save(tag);
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    if (error == null) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _saving = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: TaskDialog(
      title: t.sourceProfile.jmAddTag,
      content: TextField(
        controller: _input,
        readOnly: _saving,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: t.sourceProfile.jmTagName,
          errorText: _error,
          errorMaxLines: 3,
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(t.common.cancel),
        ),
        ValueListenableBuilder(
          valueListenable: _input,
          builder: (_, value, _) => TextButton(
            onPressed: _saving || value.text.trim().isEmpty ? null : _submit,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.common.add),
          ),
        ),
      ],
    ),
  );
}
