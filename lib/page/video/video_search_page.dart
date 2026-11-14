import 'package:zephyr/page/search/widget/search_toolbar_scope.dart';
import 'package:zephyr/page/search/widget/search_field_decoration.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';
import 'package:zephyr/page/search/widget/search_keyboard.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/search/widget/search_history_section.dart';
import 'package:zephyr/page/search/widget/search_tool_glyph.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/video_browse_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_search_filters.dart';
import 'package:zephyr/page/video/video_search_history.dart';
import 'package:zephyr/page/video/video_interaction.dart';

/// The catalog's only keyword field. Editing and results share this entry.
class VideoSearchEntry extends StatelessWidget {
  const VideoSearchEntry({
    super.key,
    required this.query,
    required this.onTap,
    this.onSubmitted,
    this.onClear,
    this.focusNode,
    this.queryRevision = 0,
    this.hint,
  });
  final String query;
  final VoidCallback onTap;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final FocusNode? focusNode;
  final int queryRevision;
  final String? hint;

  @override
  Widget build(BuildContext context) => SearchQueryField(
    key: const ValueKey('video-search.entry'),
    query: query,
    queryRevision: queryRevision,
    hintText: hint ?? t.videoSearch.hint,
    semanticLabel: t.videoPlayback.search,
    focusNode: focusNode,
    inline: onSubmitted != null,
    showSubmit: onSubmitted != null,
    onTap: onTap,
    onSubmitted: onSubmitted,
    onClear: onClear,
  );
}

/// Draws the existing history below an editing catalog header, leaving the
/// list mounted so cancelling preserves its results and scroll position.
class CatalogSearchOverlay extends StatelessWidget {
  const CatalogSearchOverlay({
    super.key,
    required this.source,
    required this.onSubmit,
    this.onClose,
    this.controls,
    this.hint,
    this.inPage = false,
  });

  final String source;
  final ValueChanged<String> onSubmit;
  final VoidCallback? onClose;
  final Widget? controls;
  final String? hint;
  final bool inPage;

  @override
  Widget build(BuildContext context) {
    final history = _buildHistory(context);
    if (inPage) return history;
    return Stack(
      children: [
        if (onClose != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              onTap: onClose,
            ),
          ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: double.infinity,
              child: Material(
                elevation: 2,
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                child: history,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistory(BuildContext context) => SingleChildScrollView(
    primary: false,
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controls != null || onClose != null)
          Row(
            children: [
              Expanded(child: controls ?? const SizedBox.shrink()),
              if (onClose != null)
                IconButton(
                  tooltip: t.videoSearch.cancel,
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
        if (hint case final text?)
          Text(text, style: settingNoteTextStyle(context)),
        VideoSearchHistoryPanel(source: source, onSubmit: onSubmit),
      ],
    ),
  );
}

class VideoSearchPage extends StatefulWidget {
  const VideoSearchPage({
    super.key,
    required this.source,
    required this.initial,
    this.authorEnabled = true,
    this.hint,
    this.scopeHint,
    this.initialScope = KeywordSearchScope.all,
    this.onSubmitScope,
    this.filterBuilder,
  });
  final String source;
  final VideoSearchFilters initial;
  final bool authorEnabled;
  final String? hint, scopeHint;
  final KeywordSearchScope initialScope;
  final ValueChanged<KeywordSearchScope>? onSubmitScope;
  final Widget Function(BuildContext, VideoSearchFilters)? filterBuilder;

  @override
  State<VideoSearchPage> createState() => _VideoSearchPageState();
}

class _VideoSearchPageState extends State<VideoSearchPage> {
  late final _query = TextEditingController(text: widget.initial.query);
  final _focus = FocusNode();
  late bool _author = widget.initial.author;
  late KeywordSearchScope _scope = widget.initialScope;
  late VideoSearchFilters _draft = widget.initial;
  bool _submitted = false;
  bool _editingFilters = false;

  @override
  void initState() {
    super.initState();
    _showKeyboard();
  }

  @override
  void didUpdateWidget(covariant VideoSearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _query.text = widget.initial.query;
      _draft = widget.initial;
      _author = widget.initial.author;
      _scope = widget.initialScope;
      _submitted = false;
    }
  }

  void _showKeyboard() => requestSearchKeyboard(
    _focus,
    isCurrent: () => mounted && ModalRoute.of(context)?.isCurrent != false,
  );

  Future<void> _editFilters() async {
    final builder = widget.filterBuilder;
    if (builder == null || _editingFilters || _submitted) return;
    final source = widget.source;
    _editingFilters = true;
    _focus.unfocus();
    try {
      final result = await showVideoTaskSheet<VideoSearchFilters>(
        context: context,
        builder: (context) => builder(context, _draft),
      );
      if (mounted && source == widget.source && result != null) {
        setState(() => _draft = result);
      }
    } finally {
      _editingFilters = false;
    }
  }

  void _submit([String? recent]) {
    final query = VideoSearchHistory.clean(recent ?? _query.text);
    if (query.isEmpty || _submitted || _editingFilters) return;
    _submitted = true;
    FocusScope.of(context).unfocus();
    if (!_author) widget.onSubmitScope?.call(_scope);
    Navigator.of(
      context,
    ).pop(_draft.copyWith(query: query, author: _author, page: 1));
  }

  void _cancel() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: videoBrowseTheme(Theme.of(context)),
    child: Scaffold(
      appBar: SearchToolbarScope.appBar(
        context,
        (height) => AppBar(
          toolbarHeight: height,
          leadingWidth: height == null ? null : 56,
          titleSpacing: 0,
          leading: SourceBackButton(
            tooltip: t.videoSearch.cancel,
            onPressed: _cancel,
          ),
          title: SearchFieldSurface(
            child: TextField(
              key: const ValueKey('video-search.input'),
              controller: _query,
              focusNode: _focus,
              onTapAlwaysCalled: true,
              onTap: _showKeyboard,
              textInputAction: TextInputAction.search,
              textAlignVertical: TextAlignVertical.center,
              maxLength: 300,
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              decoration: searchFieldDecoration(
                context,
                hintText: widget.hint ?? t.videoSearch.submit,
                prefixIcon: ValueListenableBuilder(
                  valueListenable: _query,
                  builder: (_, value, _) => IconButton(
                    tooltip: t.videoSearch.submit,
                    visualDensity: VisualDensity.standard,
                    onPressed: VideoSearchHistory.clean(value.text).isEmpty
                        ? null
                        : _submit,
                    icon: const SearchToolGlyph(SearchTool.search, size: 22),
                  ),
                ),
                suffixIcon: ValueListenableBuilder(
                  valueListenable: _query,
                  builder: (_, value, _) => value.text.isEmpty
                      ? const SizedBox(width: 44)
                      : IconButton(
                          tooltip: t.videoSearch.clearQuery,
                          onPressed: _query.clear,
                          icon: const SearchToolGlyph(
                            SearchTool.clear,
                            size: 20,
                          ),
                        ),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          actions: [
            if (height != null && widget.onSubmitScope != null && !_author)
              const SizedBox(width: 4),
            if (widget.onSubmitScope != null && !_author)
              KeywordScopeMenu(
                compact: MediaQuery.sizeOf(context).width < 352,
                scope: _scope,
                onChanged: (value) => setState(() => _scope = value),
              ),
            if (widget.filterBuilder != null) ...[
              const SizedBox(width: 8),
              Badge(
                isLabelVisible: _draft.activeCount != 0,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: SourceFilterIconButton(
                  key: const ValueKey('video-search.filters'),
                  tooltip: _draft.activeCount == 0
                      ? t.videoFilters.title
                      : '${t.videoFilters.title} · ${t.videoFilters.selected(count: _draft.activeCount)}',
                  active: _draft.activeCount != 0,
                  bare: false,
                  onPressed: _editFilters,
                ),
              ),
            ],
            const SizedBox(width: 12),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (widget.scopeHint case final hint?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(hint, style: settingNoteTextStyle(context)),
                  ),
                if (widget.authorEnabled) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final author in [false, true])
                        ChoiceChip(
                          label: Text(
                            author
                                ? t.videoFilters.authors
                                : t.videoFilters.videos,
                          ),
                          selected: _author == author,
                          chipAnimationStyle: VideoMotion.chip(context),
                          onSelected: (_) => setState(() => _author = author),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                VideoSearchHistoryPanel(
                  key: ValueKey('video-history.${widget.source}'),
                  source: widget.source,
                  onSubmit: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class VideoSearchHistoryPanel extends StatefulWidget {
  const VideoSearchHistoryPanel({
    super.key,
    required this.source,
    required this.onSubmit,
  });

  final String source;
  final ValueChanged<String> onSubmit;

  @override
  State<VideoSearchHistoryPanel> createState() =>
      _VideoSearchHistoryPanelState();
}

class _VideoSearchHistoryPanelState extends State<VideoSearchHistoryPanel> {
  List<String> _recent = [];
  int _historyEpoch = 0;
  bool _failed = false, _loaded = false;

  @override
  void initState() {
    super.initState();
    _read();
  }

  @override
  void didUpdateWidget(covariant VideoSearchHistoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _recent = [];
      _loaded = false;
      _failed = false;
      _read();
    }
  }

  Future<void> _read() async {
    final epoch = ++_historyEpoch, source = widget.source;
    try {
      final words = await VideoSearchHistory.read(
        source,
      ).timeout(const Duration(seconds: 3));
      if (mounted && epoch == _historyEpoch && source == widget.source) {
        setState(() {
          _recent = words;
          _loaded = true;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted && epoch == _historyEpoch && source == widget.source) {
        setState(() {
          _failed = true;
          _loaded = true;
        });
      }
    }
  }

  Future<void> _removeHistory(Set<String> words) async {
    final source = widget.source;
    await VideoSearchHistory.removeMany(source, words);
    if (mounted && source == widget.source) await _read();
  }

  @override
  Widget build(BuildContext context) => SearchHistorySection(
    words: _recent,
    scopeLabel: t.videoSearch.localOnly,
    compact: true,
    onSubmit: widget.onSubmit,
    onRemove: _removeHistory,
    loading: !_loaded,
    readFailed: _failed,
    onRetry: _read,
  );
}
