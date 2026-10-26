import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/router/router.gr.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_detail_page.dart';
import 'package:zephyr/page/video/api_video_favorites.dart';
import 'package:zephyr/page/video/api_video_history.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_browse_theme.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/page/video/video_playback_settings_page.dart';
import 'package:zephyr/page/video/video_search_filters.dart';
import 'package:zephyr/page/video/video_search_history.dart';
import 'package:zephyr/page/video/video_search_page.dart';

class ApiVideoLibraryPage extends StatefulWidget {
  const ApiVideoLibraryPage({
    super.key,
    required this.repository,
    required this.title,
    this.initialQuery = '',
  });
  final ApiVideoRepository repository;
  final String title, initialQuery;
  @override
  State<ApiVideoLibraryPage> createState() => _ApiVideoLibraryPageState();
}

class _ApiVideoLibraryPageState extends State<ApiVideoLibraryPage> {
  ApiVideoView _mode = ApiVideoView.grid;
  late String _query = widget.initialQuery;
  int _tab = 0;
  bool _savingView = false;
  String get _viewKey =>
      'breeze.video.library.view.${widget.repository.source}';
  @override
  void initState() {
    super.initState();
    _readView();
  }

  Future<void> _readView() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted && !_savingView) {
        setState(
          () => _mode = prefs.getString(_viewKey) == 'list'
              ? ApiVideoView.list
              : ApiVideoView.grid,
        );
      }
    } catch (_) {
      // A missing preference must not prevent browsing the source.
    }
  }

  Future<void> _toggleView() async {
    if (_savingView) return;
    final old = _mode;
    setState(() {
      _savingView = true;
      _mode = old == ApiVideoView.grid ? ApiVideoView.list : ApiVideoView.grid;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_viewKey, _mode.name)) {
        throw StateError('save');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _mode = old);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.videoLibrary.saveFailed)));
      }
    } finally {
      if (mounted) setState(() => _savingView = false);
    }
  }

  Future<void> _search() async {
    final result = await Navigator.of(context).push<VideoSearchFilters>(
      videoPageRoute(
        builder: (_) => VideoSearchPage(
          source: widget.repository.source,
          initial: VideoSearchFilters(query: _query),
          authorEnabled: false,
          hint: t.videoLibrary.searchHint,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _query = result.query;
      _tab = 0;
    });
    unawaited(
      VideoSearchHistory.add(widget.repository.source, result.query).catchError(
        (Object _) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(t.videoSearch.historyWriteFailed)),
            );
          }
        },
      ),
    );
  }

  Future<void> _open(ApiVideoItem item, {Uri? resume}) async {
    await Navigator.of(context).push<void>(
      videoPageRoute(
        builder: (_) => ApiVideoDetailPage(
          repository: widget.repository,
          initialItem: item,
          resume: resume,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: videoBrowseTheme(Theme.of(context)),
    child: Scaffold(
      appBar: AppBar(
        leading: const SourceBackButton(),
        titleSpacing: 0,
        title: _tab == 0
            ? VideoSearchEntry(
                query: _query,
                hint: t.videoLibrary.searchHint,
                onTap: _search,
              )
            : Text(widget.title),
        actions: [
          const SizedBox(width: 8),
          SourceChromeIconButton(
            tooltip: _mode == ApiVideoView.grid
                ? t.videoLibrary.detailList
                : t.videoLibrary.grid,
            symbol: _mode == ApiVideoView.grid
                ? 'list.bullet'
                : 'square.grid.2x2',
            icon: _mode == ApiVideoView.grid
                ? Icons.view_agenda_outlined
                : Icons.grid_view_outlined,
            onPressed: _savingView ? null : _toggleView,
          ),
          SourceMoreButton(
            source: widget.repository.source,
            actions: [
              SourceMenuAction(
                id: 'play',
                label: t.videoLibrary.playSettings,
                icon: Icons.play_circle_outline,
                symbol: 'play.rectangle',
                onSelected: () => Navigator.of(context).push<void>(
                  videoPageRoute(
                    builder: (_) => const VideoPlaybackSettingsPage(),
                  ),
                ),
              ),
              SourceMenuAction(
                id: 'plugin',
                label: t.videoLibrary.sourceSettings,
                icon: Icons.tune_outlined,
                symbol: 'slider.horizontal.3',
                onSelected: () => context.pushRoute(
                  PluginSettingsRoute(
                    from: widget.repository.source,
                    pluginUuid: widget.repository.source,
                    pluginRuntimeName: widget.repository.source,
                    pluginDisplayName: widget.title,
                    insideSource: true,
                  ),
                ),
              ),
              SourceMenuAction(
                id: 'sync',
                label: t.videoLibrary.syncSettings,
                icon: Icons.cloud_sync_outlined,
                symbol: 'arrow.triangle.2.circlepath.icloud',
                onSelected: () => context.pushRoute(const SyncSettingRoute()),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          _ApiCatalog(
            repository: widget.repository,
            mode: _mode,
            query: _query,
            onOpen: _open,
            onClearQuery: () => setState(() => _query = ''),
            onResume: (item, resume) => _open(item, resume: resume),
          ),
          ApiVideoFavorites(
            source: widget.repository.source,
            mode: _mode,
            onOpen: _open,
            repository: widget.repository,
            active: _tab == 1,
            compact: MediaQuery.viewInsetsOf(context).bottom > 0,
          ),
          ApiVideoHistory(
            source: widget.repository.source,
            home: widget.repository.home,
            mode: _mode,
            onOpen: (item, resume) => _open(item, resume: resume),
          ),
        ],
      ),
      bottomNavigationBar: VideoNativeNavigation(
        currentIndex: _tab,
        onTap: (value) => setState(() => _tab = value),
        symbols: const ['film', 'star', 'clock'],
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.video_library_outlined),
            label: t.videoLibrary.library,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.star_border_rounded),
            label: t.videoLibrary.favorites,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history_rounded),
            label: t.videoLibrary.history,
          ),
        ],
      ),
    ),
  );
}

class _ApiCatalog extends StatefulWidget {
  const _ApiCatalog({
    required this.repository,
    required this.mode,
    required this.query,
    required this.onOpen,
    required this.onClearQuery,
    required this.onResume,
  });
  final ApiVideoRepository repository;
  final ApiVideoView mode;
  final String query;
  final Future<void> Function(ApiVideoItem) onOpen;
  final VoidCallback onClearQuery;
  final Future<void> Function(ApiVideoItem, Uri) onResume;
  @override
  State<_ApiCatalog> createState() => _ApiCatalogState();
}

class _ApiCatalogState extends State<_ApiCatalog> {
  List<ApiVideoItem> _items = [];
  List<ApiVideoCategory> _categories = [];
  String _type = '', _year = '';
  Map<String, dynamic>? _cursor;
  int _page = 0, _pageCount = 0, _total = 0, _epoch = 0;
  bool _loading = true, _failed = false, _appendFailed = false;
  bool _recent = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ApiCatalog old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query) {
      if (old.query.isEmpty) {
        _type = '';
        _year = '';
      }
      _load();
    }
  }

  @override
  void dispose() {
    _epoch++;
    super.dispose();
  }

  Future<void> _load({bool append = false, bool refresh = false}) async {
    if (append && (_loading || _appendFailed || _page >= _pageCount)) return;
    final epoch = append ? _epoch : ++_epoch, next = append ? _page + 1 : 1;
    setState(() {
      _loading = true;
      _failed = false;
      _appendFailed = false;
      if (!append && !refresh) _items = [];
    });
    try {
      final result = await widget.repository.page(
        query: widget.query,
        typeId: _type,
        year: _year,
        page: next,
        cursor: append ? _cursor : null,
        refresh: refresh,
        recentHours: _recent ? 24 : 0,
      );
      if (!mounted || epoch != _epoch) return;
      if (result.page != next) throw const FormatException('Wrong result page');
      setState(() {
        _items = {
          if (append)
            for (final item in _items) item.id: item,
          for (final item in result.items) item.id: item,
        }.values.toList();
        _categories = result.categories;
        _page = result.page;
        _pageCount = result.pageCount;
        _total = result.total;
        _cursor = result.nextCursor;
        _loading = false;
      });
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(() {
          _loading = false;
          if (append) {
            _appendFailed = true;
          } else {
            _failed = true;
          }
        });
      }
    }
  }

  void _typeSelected(String id) {
    if (id == _type) return;
    setState(() => _type = id);
    _load();
  }

  Future<void> _allCategories() async {
    final result = await showVideoTaskSheet<String>(
      context: context,
      builder: (_) => _CategoryPicker(categories: _categories, selected: _type),
    );
    if (result != null && mounted) _typeSelected(result);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _categories.where((c) => c.id == _type).firstOrNull;
    final major = _categories
        .where(
          (c) =>
              c.parentId == '0' &&
              const {'1', '2', '3', '4', '40'}.contains(c.id),
        )
        .toList();
    final parent = selected == null
        ? ''
        : selected.parentId == '0'
        ? selected.id
        : selected.parentId;
    final children = parent.isEmpty
        ? <ApiVideoCategory>[]
        : _categories.where((c) => c.parentId == parent).toList();
    Widget category(String id, String name) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(name),
        selected: id == _type || id.isNotEmpty && id == parent,
        chipAnimationStyle: VideoMotion.chip(context),
        onSelected: (_) => _typeSelected(id),
      ),
    );
    return Column(
      children: [
        if (widget.query.isEmpty && _type.isEmpty && _year.isEmpty && !_recent)
          ApiVideoContinueEntry(
            source: widget.repository.source,
            home: widget.repository.home,
            onOpen: widget.onResume,
          ),
        if (_categories.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                category('', t.videoLibrary.all),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(t.videoLibrary.recent24Hours),
                    selected: _recent,
                    onSelected: (value) {
                      setState(() => _recent = value);
                      _load();
                    },
                    chipAnimationStyle: VideoMotion.chip(context),
                  ),
                ),
                for (final type in major) category(type.id, type.name),
                ActionChip(
                  label: Text(t.videoLibrary.moreCategories),
                  onPressed: _allCategories,
                ),
              ],
            ),
          ),
        if (children.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                for (final type in children) category(type.id, type.name),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.query.isEmpty
                      ? t.videoLibrary.updatedFirst
                      : t.videoLibrary.results(count: _total),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              NativeVideoMenu(
                label: _year.isEmpty ? t.videoLibrary.year : _year,
                tooltip: t.videoLibrary.year,
                selected: _year,
                width: 90,
                options: {
                  '': t.videoLibrary.allYears,
                  for (var year = DateTime.now().year; year >= 1940; year--)
                    '$year': '$year',
                },
                onSelected: (value) {
                  if (value == _year) return;
                  setState(() => _year = value);
                  _load();
                },
              ),
              if (_type.isNotEmpty || _year.isNotEmpty || _recent)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _type = '';
                      _year = '';
                      _recent = false;
                    });
                    _load();
                  },
                  child: Text(t.videoLibrary.clearFilters),
                ),
              IconButton(
                tooltip: t.common.refresh,
                onPressed: _loading ? null : () => _load(refresh: true),
                icon: const Icon(Icons.refresh_rounded, size: 22),
              ),
            ],
          ),
        ),
        if (widget.query.isNotEmpty || _year.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (widget.query.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InputChip(
                      label: Text(widget.query),
                      onDeleted: widget.onClearQuery,
                    ),
                  ),
                if (_year.isNotEmpty)
                  InputChip(
                    label: Text(_year),
                    onDeleted: () {
                      setState(() => _year = '');
                      _load();
                    },
                  ),
              ],
            ),
          ),
        SizedBox(
          height: 2,
          child: _loading && _items.isNotEmpty
              ? const LinearProgressIndicator()
              : null,
        ),
        Expanded(
          child: _failed && _items.isEmpty
              ? ApiVideoEmpty(
                  title: t.common.loadingFailed,
                  action: TextButton(
                    onPressed: _load,
                    child: Text(t.common.retry),
                  ),
                )
              : _loading && _items.isEmpty
              ? const _CatalogSkeleton()
              : _items.isEmpty
              ? ApiVideoEmpty(
                  title: t.videoLibrary.noResults,
                  message: t.videoLibrary.noResultsHint,
                )
              : ApiVideoCollection(
                  key: ValueKey(
                    'library.${widget.query}.$_type.$_year.$_recent',
                  ),
                  items: _items,
                  mode: widget.mode,
                  storageKey:
                      '${widget.repository.source}.library.${widget.query}.$_type.$_year.$_recent',
                  onOpen: (item) => unawaited(widget.onOpen(item)),
                  onNearEnd: () => _load(append: true),
                  footer: _appendFailed
                      ? TextButton.icon(
                          onPressed: () {
                            setState(() => _appendFailed = false);
                            _load(append: true);
                          },
                          icon: const Icon(Icons.refresh),
                          label: Text(t.videoLibrary.appendFailed),
                        )
                      : _loading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : _failed
                      ? TextButton(
                          onPressed: () => _load(refresh: true),
                          child: Text(t.common.retry),
                        )
                      : null,
                ),
        ),
      ],
    );
  }
}

class _CatalogSkeleton extends StatelessWidget {
  const _CatalogSkeleton();
  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: 4,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      childAspectRatio: .6,
      crossAxisSpacing: 12,
      mainAxisSpacing: 16,
    ),
    itemBuilder: (_, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 14,
          width: 120,
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
        const SizedBox(height: 6),
        Container(
          height: 10,
          width: 70,
          color: Theme.of(context).colorScheme.surfaceContainerLow,
        ),
      ],
    ),
  );
}

class _CategoryPicker extends StatefulWidget {
  const _CategoryPicker({required this.categories, required this.selected});
  final List<ApiVideoCategory> categories;
  final String selected;
  @override
  State<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<_CategoryPicker> {
  String _query = '';
  late String _group =
      widget.categories
          .where((c) => c.id == widget.selected)
          .map((c) => c.parentId == '0' ? c.id : c.parentId)
          .firstOrNull ??
      '1';
  @override
  Widget build(BuildContext context) {
    final parents = widget.categories.where((c) => c.parentId == '0').toList();
    final group = widget.categories.where((c) => c.id == _group).firstOrNull;
    final values = _query.isEmpty
        ? widget.categories.where((c) => c.parentId == _group)
        : widget.categories.where(
            (c) => c.name.toLowerCase().contains(_query.toLowerCase()),
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.videoLibrary.moreCategories,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: t.common.close,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: t.videoLibrary.searchCategoriesHint,
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 12),
          if (_query.isEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final p in parents)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(p.name),
                        selected: p.id == _group,
                        onSelected: (_) => setState(() => _group = p.id),
                      ),
                    ),
                ],
              ),
            ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_query.isEmpty && group != null)
                    ChoiceChip(
                      label: Text('${t.videoLibrary.all} ${group.name}'),
                      selected: widget.selected == group.id,
                      onSelected: (_) => Navigator.pop(context, group.id),
                    ),
                  for (final value in values)
                    ChoiceChip(
                      label: Text(value.name),
                      selected: value.id == widget.selected,
                      onSelected: (_) => Navigator.pop(context, value.id),
                    ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text(t.videoLibrary.allTypes),
          ),
        ],
      ),
    );
  }
}
