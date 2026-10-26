import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/video/video_browse_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_search_filters.dart';
import 'package:zephyr/page/video/video_search_history.dart';
import 'package:zephyr/page/video/video_interaction.dart';

class VideoSearchEntry extends StatelessWidget {
  const VideoSearchEntry({
    super.key,
    required this.query,
    required this.onTap,
    this.hint,
  });
  final String query;
  final VoidCallback onTap;
  final String? hint;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: t.videoPlayback.search,
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const ValueKey('video-search.entry'),
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    query.isEmpty ? hint ?? t.videoSearch.hint : query,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
  });
  final String source;
  final VideoSearchFilters initial;
  final bool authorEnabled;
  final String? hint;

  @override
  State<VideoSearchPage> createState() => _VideoSearchPageState();
}

class _VideoSearchPageState extends State<VideoSearchPage> {
  late final _query = TextEditingController(text: widget.initial.query);
  late bool _author = widget.initial.author;
  List<String> _recent = [];
  bool _failed = false,
      _loaded = false,
      _editingHistory = false,
      _submitted = false;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    try {
      final words = await VideoSearchHistory.read(
        widget.source,
      ).timeout(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _recent = words;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _remove(String? word) async {
    if (_editingHistory) return;
    setState(() => _editingHistory = true);
    try {
      if (word == null) {
        await VideoSearchHistory.clear(widget.source);
      } else {
        await VideoSearchHistory.remove(widget.source, word);
      }
      if (mounted) {
        setState(() {
          _recent = word == null
              ? []
              : _recent.where((x) => x != word).toList();
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _editingHistory = false);
    }
  }

  void _submit([String? recent]) {
    final query = VideoSearchHistory.clean(recent ?? _query.text);
    if (query.isEmpty || _submitted) return;
    _submitted = true;
    FocusScope.of(context).unfocus();
    Navigator.of(
      context,
    ).pop(widget.initial.copyWith(query: query, author: _author, page: 1));
  }

  void _cancel() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: videoBrowseTheme(Theme.of(context)),
    child: Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: SourceBackButton(
          tooltip: t.videoSearch.cancel,
          onPressed: _cancel,
        ),
        title: TextField(
          key: const ValueKey('video-search.input'),
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          maxLength: 300,
          buildCounter:
              (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
          decoration: InputDecoration(
            hintText: widget.hint ?? t.videoSearch.submit,
            filled: true,
            isDense: true,
            suffixIcon: ValueListenableBuilder(
              valueListenable: _query,
              builder: (_, value, _) => value.text.isEmpty
                  ? const SizedBox(width: 44)
                  : IconButton(
                      tooltip: t.videoSearch.clearQuery,
                      onPressed: _query.clear,
                      icon: const Icon(Icons.cancel_rounded, size: 20),
                    ),
            ),
          ),
          onSubmitted: (_) => _submit(),
        ),
        actions: [
          ValueListenableBuilder(
            valueListenable: _query,
            builder: (_, value, _) => IconButton(
              tooltip: t.videoSearch.submit,
              onPressed: VideoSearchHistory.clean(value.text).isEmpty
                  ? null
                  : _submit,
              icon: const Icon(Icons.search_rounded),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(16),
              children: [
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
                  const SizedBox(height: 24),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.videoSearch.recent,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: t.videoSearch.clearRecent,
                      onPressed: _recent.isEmpty || _editingHistory
                          ? null
                          : () => _remove(null),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
                Text(
                  t.videoSearch.localOnly,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_loaded && !_failed && _recent.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      t.videoSearch.noRecent,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                if (_failed)
                  Semantics(
                    liveRegion: true,
                    child: Text(t.videoSearch.recentFailed),
                  ),
                for (final word in _recent)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history_rounded),
                    title: Text(
                      word,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _submit(word),
                    trailing: IconButton(
                      tooltip: t.videoSearch.removeRecent,
                      onPressed: _editingHistory ? null : () => _remove(word),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
