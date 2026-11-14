import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/pull_refresh_feedback.dart';
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/omofun_account_page.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/video_library_folder_picker.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/source_video_list_header.dart';
import 'package:zephyr/page/search/widget/search_keyboard.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_selection_toolbar.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_floating_selection_actions.dart';
import 'package:zephyr/page/bookshelf/models/shelf_facets.dart';
import 'package:zephyr/page/bookshelf/service/shelf_facet_adapters.dart';
import 'package:zephyr/page/bookshelf/service/video_bookshelf_index.dart';
import 'package:zephyr/page/bookshelf/widgets/shelf_filter_sheet.dart';

class OmoSiteFavoritesPage extends StatefulWidget {
  const OmoSiteFavoritesPage({
    super.key,
    required this.client,
    required this.source,
    required this.onOpen,
    required this.active,
    this.collectionActive,
    this.importing = false,
    this.onImportMode,
    this.onImported,
    this.onNotice,
    this.loadDetail,
    this.onDetailLoaded,
    this.store,
    this.mode = ApiVideoView.grid,
    this.standalone = false,
    this.onToggleView,
  });
  final VoidCallback? onToggleView;
  final bool standalone;
  final OmoSiteClient client;
  final ApiVideoView mode;
  final String source;
  final bool active;

  /// The collection tab can remain visible after import switches to local.
  final bool? collectionActive;
  final bool importing;
  final ValueChanged<bool>? onImportMode;
  final VoidCallback? onImported;
  final ValueChanged<String>? onNotice;
  final Future<ApiVideoItem> Function(ApiVideoItem)? loadDetail;
  final ValueChanged<ApiVideoItem>? onDetailLoaded;
  final VideoLibraryStore? store;
  final Future<void> Function(ApiVideoItem) onOpen;
  @override
  State<OmoSiteFavoritesPage> createState() => _OmoSiteFavoritesPageState();
}

class _OmoSiteFavoritesPageState extends State<OmoSiteFavoritesPage> {
  List<OmoFavorite> _items = [];
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  bool _managing = false, _searching = false;
  String _sort = 'recent';
  late ApiVideoView _mode = widget.mode;
  ShelfFacetSelection _facets = const ShelfFacetSelection();
  bool _openingFilters = false;
  int _offset = 0, _epoch = 0, _unmapped = 0;
  bool _loading = false, _more = false, _writing = false, _loaded = false;
  String? _identity;
  Object? _error;
  final _selected = <String>{};
  String? _notice;
  Timer? _noticeTimer;
  int _noticeEpoch = 0;
  bool get _feedbackActive => widget.collectionActive ?? widget.active;
  VideoLibraryStore get _store => widget.store ?? VideoLibraryStore.shared;
  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_focusChanged);
    if (widget.active) _load();
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant OmoSiteFavoritesPage old) {
    super.didUpdateWidget(old);
    final scopeChanged =
        old.client != widget.client || old.source != widget.source;
    if (scopeChanged) {
      _epoch++;
      _readTask = null;
      _pullTask = null;
      _pullRefreshing = false;
      _loading = false;
      _error = null;
      _identity = null;
      _clearCollection();
    }
    if (widget.active && (!old.active || scopeChanged)) _load();
    if (old.mode != widget.mode) _mode = widget.mode;
    if (widget.importing != old.importing) {
      _selected.clear();
      _managing = false;
    }
    if (!widget.active && old.active) _managing = false;
    if (!_feedbackActive && (old.collectionActive ?? old.active)) {
      _closeNotice(afterFrame: true);
    }
  }

  @override
  void dispose() {
    _closeNotice(afterFrame: true);
    _epoch++;
    _search.dispose();
    _searchFocus.removeListener(_focusChanged);
    _searchFocus.dispose();
    super.dispose();
  }

  void _message(String value) {
    if (!mounted || !_feedbackActive) return;
    if (widget.onNotice != null) {
      widget.onNotice!(value);
      return;
    }
    _noticeTimer?.cancel();
    final epoch = ++_noticeEpoch;
    setState(() => _notice = value);
    _noticeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && epoch == _noticeEpoch) setState(() => _notice = null);
    });
  }

  void _closeNotice({bool afterFrame = false}) {
    _noticeTimer?.cancel();
    final epoch = ++_noticeEpoch;
    void close() {
      if (mounted && epoch == _noticeEpoch) setState(() => _notice = null);
    }

    if (afterFrame) {
      WidgetsBinding.instance.addPostFrameCallback((_) => close());
    } else {
      close();
    }
  }

  Future<PullRefreshResult>? _readTask, _pullTask;
  bool _pullRefreshing = false;

  Future<PullRefreshResult> _load({bool append = false}) {
    final task = _loadNow(append: append);
    if (!append) _readTask = task;
    return task.whenComplete(() {
      if (identical(_readTask, task)) {
        _readTask = null;
      }
    });
  }

  Future<PullRefreshResult> _refreshFromPull() {
    if (!widget.active || _writing) {
      return Future.value(PullRefreshResult.ignored);
    }
    final pending = _pullTask;
    if (pending != null) {
      return pending;
    }
    setState(() => _pullRefreshing = true);
    final task = _readTask ?? _load();
    _pullTask = task;
    return task.whenComplete(() {
      if (identical(_pullTask, task)) {
        _pullTask = null;
        if (mounted) setState(() => _pullRefreshing = false);
      }
    });
  }

  void _clearCollection() {
    _items = [];
    _offset = 0;
    _unmapped = 0;
    _more = false;
    _loaded = false;
    _selected.clear();
  }

  Future<PullRefreshResult> _loadNow({bool append = false}) async {
    if (append && (_loading || !_more || _writing)) {
      return PullRefreshResult.ignored;
    }
    final epoch = ++_epoch;
    final client = widget.client;
    setState(() {
      _loading = true;
      _error = null;
      if (client.account?.id != _identity) {
        _identity = null;
        _clearCollection();
      }
    });
    try {
      final account = await client.readAccount();
      if (!mounted || epoch != _epoch) return PullRefreshResult.ignored;
      if (account == null) throw const OmoSiteException('signedOut');
      if (_identity != account.id) {
        _clearCollection();
        _search.clear();
        _facets = const ShelfFacetSelection();
        _searching = false;
        _identity = account.id;
        append = false;
      }
      final page = await client.favorites(offset: append ? _offset : 0);
      if (!mounted || epoch != _epoch) return PullRefreshResult.ignored;
      final feedback = append
          ? PullRefreshResult.updated
          : _compareRefresh(page);
      setState(() {
        _items = {
          if (append)
            for (final item in _items) item.item.id: item,
          for (final item in page.items) item.item.id: item,
        }.values.toList();
        _offset = page.nextOffset;
        _more = page.hasMore;
        _unmapped = (append ? _unmapped : 0) + page.unmappedCount;
        _loaded = true;
        _selected.retainAll(_items.map((e) => e.item.id));
        if (_items.isEmpty) _managing = false;
      });
      return feedback;
    } catch (error) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _error = error;
          if (widget.client.account?.id != _identity ||
              error is OmoSiteException && error.kind == 'signedOut') {
            _identity = null;
            _clearCollection();
          }
        });
      }
      // The collection already presents failures beside its retry action.
      return PullRefreshResult.ignored;
    } finally {
      if (mounted && epoch == _epoch) setState(() => _loading = false);
    }
  }

  PullRefreshResult _compareRefresh(OmoFavoritePage page) {
    if (!_loaded) return PullRefreshResult.updated;
    if (page.hasMore || page.unmappedCount > 0)
      return PullRefreshResult.checked;
    if (_more ||
        _offset != page.nextOffset ||
        _unmapped != page.unmappedCount ||
        _items.length != page.items.length)
      return PullRefreshResult.updated;
    for (var index = 0; index < _items.length; index++) {
      final before = _items[index], after = page.items[index];
      if (before.recordId != after.recordId ||
          before.vodId != after.vodId ||
          !before.item.hasSameCatalogSummary(after.item)) {
        return PullRefreshResult.updated;
      }
    }
    return PullRefreshResult.unchanged;
  }

  Future<void> _website({bool login = false}) async {
    if (login) {
      await openOmoAccountDetails(
        context,
        widget.client,
        source: widget.source,
      );
    } else {
      await openOmoSitePage(
        context,
        widget.client,
        title: t.videoSource.siteFavorites,
        path: '/user/favorites',
      );
    }
    if (mounted) await _load();
  }

  Future<void> _unfollowSelected() async {
    if (_writing || _loading || _selected.isEmpty) return;
    final targets = _items
        .where((item) => _selected.contains(item.item.id))
        .toList();
    final client = widget.client, identity = widget.client.account?.id;
    var revision = widget.client.revision;
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(t.videoSource.unfollowSite),
        content: Text(t.videoSource.unfollowHint),
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
    if (yes != true ||
        !mounted ||
        client != widget.client ||
        revision != client.revision ||
        identity != client.account?.id)
      return;
    setState(() => _writing = true);
    try {
      for (final favorite in targets) {
        if (!mounted ||
            client != widget.client ||
            revision != client.revision ||
            identity != client.account?.id)
          return;
        await client.setFavorite(favorite.vodId, false);
        if (!mounted) return;
        // setFavorite advances one revision after its authoritative readback.
        // Any extra transition belongs to another account/session action.
        if (client != widget.client ||
            client.revision != revision + 1 ||
            identity != client.account?.id) {
          await _load();
          return;
        }
        revision = client.revision;
        _selected.remove(favorite.item.id);
      }
      if (mounted) {
        setState(() => _managing = false);
        await _load();
      }
    } catch (error) {
      if (mounted) {
        _message(omoSiteError(error));
        await _load();
      }
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  ShelfFacetEntry _facet(OmoFavorite favorite) => shelfFacetEntryFromVideo(
    VideoBookshelfRow(
      key: favorite.item.id,
      source: widget.source,
      item: favorite.item,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    ),
  );
  KeywordSearchScope _keywordScope = KeywordSearchScope.all;

  Widget _keywordMenu() => KeywordScopeMenu(
    scope: _keywordScope,
    compact: true,
    onChanged: (scope) => setState(() => _keywordScope = scope),
  );

  bool _matchesQuery(
    OmoFavorite row,
    bool Function(Iterable<String>) matches,
  ) =>
      _search.text.trim().isEmpty ||
      (_keywordScope == KeywordSearchScope.title
          ? matches([row.item.title, row.item.alternateTitle])
          : matches([_facet(row).searchText]));

  Future<void> _editFilters() async {
    if (_openingFilters || _writing || _loading) return;
    _openingFilters = true;
    final client = widget.client, revision = widget.client.revision;
    final query = _search.text, scope = _keywordScope;
    final matches = keywordTitleMatcher(query);
    _searchFocus.unfocus();
    try {
      final result = await showShelfFilterSheet(
        context,
        entries: _items
            .where((item) => _matchesQuery(item, matches))
            .map(_facet)
            .toList(),
        initial: _facets,
        preferenceKey: 'omo.site-favorites.${widget.source}',
        scopeLabel: _more
            ? t.videoSource.searchLoaded
            : t.videoSource.siteFavorites,
        currentFolder: null,
        hierarchical: false,
      );
      if (result != null &&
          mounted &&
          widget.client == client &&
          client.revision == revision &&
          _search.text == query &&
          scope == _keywordScope) {
        setState(() => _facets = result);
      }
    } finally {
      _openingFilters = false;
    }
  }

  Future<void> _import() async {
    if (_writing || _loading || _selected.isEmpty) return;
    final items = _items
        .where((e) => _selected.contains(e.item.id))
        .map((e) => e.item)
        .toList();
    final identity = _identity;
    setState(() => _writing = true);
    try {
      if (!mounted || identity != widget.client.account?.id) return;
      ({int added, int existing})? result;
      final saved = await showVideoFolderPicker(
        context,
        source: widget.source,
        importItems: items,
        store: _store,
        onImportSaved: (value) => result = value,
      );
      if (saved == true && mounted) {
        widget.onImported?.call();
        _message(
          t.videoSource.importResult(
            added: result!.added,
            existing: result!.existing,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        _message(videoLibraryError(error));
      }
    } finally {
      if (mounted) setState(() => _writing = false);
    }
  }

  void _toggle(String id) => setState(() {
    _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
  });

  void _cancelImport() {
    if (_writing) return;
    FocusScope.of(context).unfocus();
    setState(() => _selected.clear());
    widget.onImportMode?.call(false);
  }

  bool get _signedOut =>
      _error is OmoSiteException &&
      (_error as OmoSiteException).kind == 'signedOut';

  Widget _emptyState() {
    if (_signedOut) {
      return ApiVideoEmpty(
        title: t.videoSource.loginRequired,
        icon: Icons.person_outline_rounded,
        action: FilledButton.tonalIcon(
          onPressed: () => _website(login: true),
          icon: const Icon(Icons.login_rounded, size: 20),
          label: Text(t.videoSource.login),
        ),
      );
    }
    if (_error != null) {
      return ApiVideoEmpty(
        title: omoSiteError(_error),
        icon: Icons.cloud_off_outlined,
        action: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.tonalIcon(
              onPressed: _loading ? null : () => _load(),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: Text(t.common.retry),
            ),
            TextButton(
              onPressed: () => _website(),
              child: Text(t.videoLibrary.openWebsite),
            ),
          ],
        ),
      );
    }
    return ApiVideoEmpty(
      title: _search.text.trim().isEmpty
          ? t.videoSource.noSiteFavorites
          : t.videoLibrary.noResults,
      icon: Icons.favorite_border_rounded,
    );
  }

  Widget _collectionHeader(List<OmoFavorite> visible) => Column(
    children: [
      SourceVideoResultsToolbar(
        count: _loading && _items.isEmpty
            ? t.common.loading
            : _error != null && _items.isEmpty
            ? t.videoSource.readFailed
            : _more
            ? t.videoSource.loadedFollows(count: _items.length)
            : t.videoLibrary.results(count: visible.length),
        keyPrefix: 'omo-favorites',
        sort: _sort,
        sortOptions: {
          'recent': t.videoSource.sourceOrder,
          'title': t.videoLibrary.titleOrder,
        },
        onSort: _writing || _items.isEmpty
            ? null
            : (value) {
                _searchFocus.unfocus();
                setState(() => _sort = value);
              },
        gridView: _mode == ApiVideoView.grid,
        onToggleView: _writing
            ? null
            : () {
                _searchFocus.unfocus();
                setState(
                  () => _mode = _mode == ApiVideoView.grid
                      ? ApiVideoView.list
                      : ApiVideoView.grid,
                );
                widget.onToggleView?.call();
              },
        filter: SourceFilterIconButton(
          key: const ValueKey('omo-favorites.filter'),
          bare: false,
          tooltip: _facets.isActive
              ? t.videoFilters.active
              : t.bookshelf.facets.title,
          onPressed: _writing || _items.isEmpty ? null : _editFilters,
          active: _facets.isActive,
        ),
      ),
      if (_facets.isActive)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () =>
                  setState(() => _facets = const ShelfFacetSelection()),
              child: Text(t.common.clear),
            ),
          ),
        ),
    ],
  );

  Widget _buildSearchRow(BuildContext context, List<OmoFavorite> visible) {
    if (widget.importing || _managing)
      return SafeArea(
        top: widget.standalone,
        bottom: false,
        child: Column(
          children: [
            BookshelfSelectionToolbar(
              keyPrefix: 'omo-favorites.selection',
              selectedCount: _selected.length,
              allSelected:
                  visible.isNotEmpty &&
                  _selected.containsAll(visible.map((item) => item.item.id)),
              privacyAction: IconButton(
                key: const ValueKey('omo-favorites.search-toggle'),
                tooltip: _searching ? t.common.close : t.common.search,
                icon: Icon(
                  _searching ? Icons.close_rounded : Icons.search_rounded,
                ),
                onPressed: _writing
                    ? null
                    : () {
                        setState(() => _searching = !_searching);
                        if (_searching)
                          requestSearchKeyboard(
                            _searchFocus,
                            isCurrent: () =>
                                mounted && widget.active && _searching,
                          );
                        else
                          _searchFocus.unfocus();
                      },
              ),
              onCancel: _writing
                  ? null
                  : () {
                      _searchFocus.unfocus();
                      if (widget.importing)
                        _cancelImport();
                      else
                        setState(() {
                          _managing = false;
                          _selected.clear();
                        });
                    },
              onToggleAll: _writing || visible.isEmpty
                  ? null
                  : () => setState(() {
                      final ids = visible.map((item) => item.item.id).toSet();
                      _selected.containsAll(ids)
                          ? _selected.removeAll(ids)
                          : _selected.addAll(ids);
                    }),
            ),
            if (_searching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: SearchQueryField(
                        query: _search.text,
                        inline: true,
                        focusNode: _searchFocus,
                        closeOnSubmit: false,
                        hintText: _more
                            ? t.videoSource.searchLoaded
                            : t.videoSource.searchFollows,
                        onChanged: (value) =>
                            setState(() => _search.text = value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _keywordMenu(),
                    const CollectionCoverPrivacyButton(),
                  ],
                ),
              ),
          ],
        ),
      );
    return SafeArea(
      top: widget.standalone,
      bottom: false,
      child: SourceVideoListHeader(
        keyPrefix: 'omo-favorites',
        leading: widget.standalone ? const SourceBackButton() : null,
        title: _search.text.isEmpty
            ? t.videoSource.siteFavorites
            : _search.text,
        searching: _searching,
        searchScope: _keywordMenu(),
        searchField: SearchQueryField(
          query: _search.text,
          inline: true,
          focusNode: _searchFocus,
          closeOnSubmit: false,
          hintText: _more
              ? t.videoSource.searchLoaded
              : t.videoSource.searchFollows,
          onChanged: (value) => setState(() => _search.text = value),
        ),
        onSearch: _writing
            ? null
            : () {
                setState(() => _searching = !_searching);
                if (_searching)
                  requestSearchKeyboard(
                    _searchFocus,
                    isCurrent: () => mounted && widget.active && _searching,
                  );
                else
                  _searchFocus.unfocus();
              },
        options: {
          if (_items.isNotEmpty) 'manage': t.videoSource.manage,
          if (_items.isNotEmpty && widget.onImportMode != null)
            'import': t.videoSource.importLocal,
        },
        onMore: (action) {
          if (_writing) return;
          if (action == 'import' && widget.onImportMode != null) {
            _searchFocus.unfocus();
            widget.onImportMode!(true);
          } else {
            _searchFocus.unfocus();
            setState(() {
              _managing = true;
              _searching = false;
              _selected.clear();
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matches = keywordTitleMatcher(_search.text);
    final visible = _items
        .where(
          (r) =>
              _matchesQuery(r, matches) &&
              shelfFacetMatches(_facet(r), _facets, currentFolder: null),
        )
        .toList();
    if (_sort == 'title')
      visible.sort((a, b) => a.item.title.compareTo(b.item.title));
    return CollectionCoverPrivacyScope(
      child: BookshelfFloatingSelectionActions(
        selecting: widget.importing || _managing,
        selectedCount: _selected.length,
        busy: _writing,
        keyPrefix: 'omo-favorites.selection',
        actions: [
          if (!widget.importing)
            BookshelfBatchAction(
              id: 'unfollow',
              label: t.videoSource.unfollowSite,
              icon: Icons.favorite_border_rounded,
              symbol: 'heart.slash',
              onPressed: _selected.isEmpty || _writing
                  ? null
                  : _unfollowSelected,
            ),
          BookshelfBatchAction(
            id: 'import',
            label: t.videoSource.chooseImportFolder,
            icon: Icons.folder_outlined,
            symbol: 'folder',
            onPressed: _selected.isEmpty || _writing ? null : _import,
          ),
        ],
        child: PopScope(
          canPop:
              !widget.active ||
              (!widget.importing &&
                  !_managing &&
                  !_writing &&
                  !_searchFocus.hasFocus),
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) {
              _closeNotice();
            } else if (widget.active && !_writing) {
              if (_searchFocus.hasFocus) {
                _searchFocus.unfocus();
              } else if (widget.importing) {
                _cancelImport();
              } else if (_managing) {
                setState(() => _managing = false);
              }
            }
          },
          child: Column(
            children: [
              _buildSearchRow(context, visible),
              if (_error != null && _items.isNotEmpty)
                Padding(
                  key: const ValueKey('omo-favorites.retained-error'),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(child: Text(omoSiteError(_error))),
                      TextButton(
                        onPressed: _loading || _writing ? null : () => _load(),
                        child: Text(t.common.retry),
                      ),
                    ],
                  ),
                ),
              if (_feedbackActive && widget.onNotice == null && _notice != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: VideoActionNotice(
                    message: _notice!,
                    onClose: _closeNotice,
                  ),
                ),
              SizedBox(
                height: 4,
                child:
                    (_loading && !_pullRefreshing) ||
                        (_writing && !widget.importing)
                    ? MediaQuery.disableAnimationsOf(context)
                          ? const LinearProgressIndicator(value: .5)
                          : const LinearProgressIndicator()
                    : null,
              ),
              Expanded(
                child: PullRefreshFeedback.indicator(
                  active: widget.active && _feedbackActive,
                  scope: (
                    widget.client,
                    widget.source,
                    _identity,
                    widget.client.revision,
                    widget.importing,
                  ),
                  notificationPredicate: (notice) =>
                      !_writing && notice.depth == 0,
                  onRefresh: _refreshFromPull,
                  child: ApiVideoCollection(
                    loadDetail: widget.loadDetail,
                    onDetailLoaded: widget.onDetailLoaded,
                    detailsActive:
                        widget.active && !widget.importing && !_managing,
                    items: visible.map((favorite) => favorite.item).toList(),
                    mode: _mode,
                    selected: _selected,
                    contentBottomPadding: widget.importing || _managing
                        ? BookshelfFloatingSelectionActions.contentBottomPadding
                        : 0,
                    selecting: widget.importing || _managing,
                    editing: _managing,
                    editLabel: t.videoSource.manage,
                    loading: _loading && _items.isEmpty && !_pullRefreshing,
                    storageKey: '${widget.source}.site-favorites.$_identity',
                    header: widget.importing || _managing
                        ? null
                        : _collectionHeader(visible),
                    emptyState: _emptyState(),
                    onOpen: (item) {
                      if (_writing) return;
                      final favorite = _items
                          .where((favorite) => favorite.item.id == item.id)
                          .firstOrNull;
                      if (favorite == null) return;
                      if (widget.importing) {
                        _toggle(item.id);
                      } else if (_managing) {
                        _toggle(item.id);
                      } else {
                        unawaited(widget.onOpen(item));
                      }
                    },
                    onLongPress: widget.importing
                        ? null
                        : (item) {
                            if (_writing) return;
                            final favorite = _items
                                .where(
                                  (favorite) => favorite.item.id == item.id,
                                )
                                .firstOrNull;
                            if (favorite != null)
                              setState(() {
                                _managing = true;
                                _selected.add(favorite.item.id);
                              });
                          },
                    footer: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_unmapped > 0)
                          ListTile(
                            title: Text(t.videoSource.siteListFallback),
                            onTap: () => _website(),
                            trailing: const Icon(Icons.open_in_browser_rounded),
                          ),
                        if (_more)
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: TextButton(
                              onPressed: _loading || _writing
                                  ? null
                                  : () => _load(append: true),
                              child: Text(t.common.nextPage),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
