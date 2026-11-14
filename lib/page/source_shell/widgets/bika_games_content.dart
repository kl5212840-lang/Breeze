import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:html/parser.dart' as html;
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zephyr/config/router/router.gr.dart' as app_routes;
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/page/plugin_function/cubit/plugin_function_cubit.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/page/source_shell/source_loading_indicator.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';

typedef BikaGameLoader =
    Future<Map<String, dynamic>> Function(
      String source,
      String function,
      Map<String, dynamic> core,
    );

Future<Map<String, dynamic>> loadBikaGameData(
  String source,
  String function,
  Map<String, dynamic> core,
) => callUnifiedComicPlugin(
  from: source,
  fnPath: function,
  core: core,
  // This destination presents the same login action locally. A details route
  // must not replace the retained source tab underneath it with another page.
  notifyUnauthorized: false,
);

/// Independent game data, never comic records, chapter downloads or a WebView.
/// The shell retains this state while switching its persistent destinations.
class BikaGamesContent extends StatefulWidget {
  const BikaGamesContent({
    super.key,
    required this.source,
    this.listFunction = 'getGameListBundle',
    this.detailFunction = 'getGameDetailsBundle',
    this.load = loadBikaGameData,
  });

  final String source, listFunction, detailFunction;
  final BikaGameLoader load;

  @override
  State<BikaGamesContent> createState() => _BikaGamesContentState();
}

class _BikaGamesContentState extends State<BikaGamesContent> {
  final _scroll = ScrollController();
  final _items = <Map<String, dynamic>>[];
  bool _loading = true, _busy = false, _hasMore = false;
  bool _loginRequired = false, _loadMoreFailed = false;
  bool _retryReset = true, _openingDetail = false;
  String _error = '';
  int _page = 0, _epoch = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    unawaited(_read(reset: true));
  }

  @override
  void didUpdateWidget(BikaGamesContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.listFunction != widget.listFunction) {
      _epoch++;
      _busy = false;
      _items.clear();
      _page = 0;
      unawaited(_read(reset: true));
    }
  }

  void _onScroll() {
    if (!_busy &&
        !_loadMoreFailed &&
        _hasMore &&
        _scroll.position.extentAfter < 320) {
      unawaited(_read());
    }
  }

  Future<void> _read({bool reset = false}) async {
    if (_busy) return;
    final epoch = ++_epoch;
    final source = widget.source;
    final requestedPage = reset ? 1 : _page + 1;
    setState(() {
      _busy = true;
      _loading = _items.isEmpty;
      _error = '';
      _loginRequired = false;
    });
    try {
      final response = await widget.load(source, widget.listFunction, {
        'page': requestedPage,
      });
      if (!mounted || epoch != _epoch || source != widget.source) return;
      final data = asJsonMap(response['data']);
      if (response['source'] != source ||
          data['items'] is! List ||
          data['page'] != requestedPage ||
          data['hasMore'] is! bool) {
        throw FormatException(t.sourceShell.gameListInvalid);
      }
      final next = asJsonList(data['items'])
          .map(asJsonMap)
          .where(
            (item) =>
                _gameText(item, 'id').isNotEmpty &&
                _gameText(item, 'title').isNotEmpty,
          );
      setState(() {
        if (reset) _items.clear();
        final ids = _items.map((item) => item['id']).toSet();
        _items.addAll(next.where((item) => ids.add(item['id'])));
        _page = requestedPage;
        _hasMore = data['hasMore'] == true;
        _loadMoreFailed = false;
      });
    } catch (error) {
      if (!mounted || epoch != _epoch || source != widget.source) return;
      setState(() {
        _loginRequired = pluginFunctionNeedsLogin(error);
        _error = pluginFunctionErrorMessage(error);
        _loadMoreFailed = true;
        _retryReset = reset;
        if (_loginRequired) {
          _items.clear();
          _page = 0;
          _hasMore = false;
        }
      });
    } finally {
      if (mounted && epoch == _epoch) {
        setState(() {
          _busy = false;
          _loading = false;
        });
      }
    }
  }

  Future<void> _login() async {
    await context.pushRoute(app_routes.LoginRoute(from: widget.source));
    if (mounted) await _read(reset: true);
  }

  Future<void> _open(Map<String, dynamic> game) async {
    if (_openingDetail) return;
    _openingDetail = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _BikaGameDetails(
            source: widget.source,
            game: game,
            function: widget.detailFunction,
            load: widget.load,
          ),
        ),
      );
    } finally {
      _openingDetail = false;
    }
  }

  @override
  void dispose() {
    _epoch++;
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return Center(child: SourceLoadingIndicator(source: widget.source));
    if (_items.isEmpty && (_error.isNotEmpty || _loginRequired)) {
      return _GameMessage(
        message: _loginRequired ? t.navigation.needLoginTitle : _error,
        label: _loginRequired ? t.navigation.goLogin : t.common.retry,
        onPressed: _loginRequired ? _login : () => _read(reset: true),
        login: _loginRequired,
      );
    }
    final list = RefreshIndicator(
      onRefresh: () => _read(reset: true),
      child: ListView.builder(
        key: const PageStorageKey('bika-games-scroll'),
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + NativeNavigationInset.scrollBottom(context),
        ),
        itemCount: _items.length + 2,
        itemBuilder: (context, index) {
          if (index == 0)
            return SizedBox(
              height: 4,
              child: _busy ? const LinearProgressIndicator() : null,
            );
          if (index <= _items.length) {
            final game = _items[index - 1];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _GameCard(
                source: widget.source,
                game: game,
                onTap: () => _open(game),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                if (_items.isEmpty) ...[
                  const BikaStatusArtwork(kind: BikaStatusKind.empty),
                  const SizedBox(height: 12),
                  Text(t.sourceShell.noGames),
                ],
                if (_error.isNotEmpty && !_retryReset)
                  Text(_error, textAlign: TextAlign.center),
                if (_hasMore && _error.isEmpty ||
                    _error.isNotEmpty && !_retryReset)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _read(
                            reset: _error.isNotEmpty ? _retryReset : _page == 0,
                          ),
                    child: Text(
                      _error.isNotEmpty
                          ? t.common.retry
                          : t.videoCommunity.loadMore,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
    return Column(
      children: [
        if (_items.isNotEmpty && _error.isNotEmpty && _retryReset)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _error,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _busy ? null : () => _read(reset: true),
                  child: Text(t.common.retry),
                ),
              ],
            ),
          ),
        Expanded(child: list),
      ],
    );
  }
}

String _gameText(Map<String, dynamic> game, String field) =>
    game[field] is String ? (game[field] as String).trim() : '';

Widget _gameCover(String source, Map<String, dynamic> game) {
  final cover = asJsonMap(game['cover']);
  final server = _gameText(cover, 'url'), path = _gameText(cover, 'path');
  if (server.isEmpty || path.isEmpty) {
    return const SizedBox(
      width: 96,
      height: 128,
      child: Icon(Icons.sports_esports_outlined),
    );
  }
  return CoverWidget(
    fileServer: server,
    path: path,
    id: _gameText(game, 'id'),
    pictureType: PictureType.cover,
    from: source,
    width: 96,
    height: 128,
    roundedCorner: true,
  );
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.source, required this.game, this.onTap});
  final String source;
  final Map<String, dynamic> game;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TouchHoverIntent(
      identity: game['id'],
      builder: (context, hover) => Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          overlayColor: hover.overlayColor(null),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _gameCover(source, game),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        convertChineseForDisplay(_gameText(game, 'title')),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (game['ios'] == true) const Text('iOS'),
                          if (game['android'] == true) const Text('Android'),
                          if (game['adult'] == true) const Text('18+'),
                        ],
                      ),
                      if (_gameText(game, 'publisher').isNotEmpty)
                        Text(
                          _gameText(game, 'publisher'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (_gameText(game, 'version').isNotEmpty)
                        Text(
                          _gameText(game, 'version'),
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (onTap != null) const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BikaGameDetails extends StatefulWidget {
  const _BikaGameDetails({
    required this.source,
    required this.game,
    required this.function,
    required this.load,
  });
  final String source, function;
  final Map<String, dynamic> game;
  final BikaGameLoader load;
  @override
  State<_BikaGameDetails> createState() => _BikaGameDetailsState();
}

class _BikaGameDetailsState extends State<_BikaGameDetails> {
  Map<String, dynamic>? _detail;
  String _error = '';
  bool _busy = false, _loginRequired = false;
  bool _openingLink = false;
  String _linkError = '';

  @override
  void initState() {
    super.initState();
    unawaited(_read());
  }

  Future<void> _read() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
      _loginRequired = false;
    });
    try {
      final response = await widget.load(widget.source, widget.function, {
        'id': widget.game['id'],
      });
      if (!mounted) return;
      final game = asJsonMap(asJsonMap(response['data'])['game']);
      if (response['source'] != widget.source ||
          game['id'] != widget.game['id'] ||
          _gameText(game, 'title').isEmpty)
        throw FormatException(t.sourceShell.gameDetailsInvalid);
      setState(() => _detail = game);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loginRequired = pluginFunctionNeedsLogin(error);
        _error = pluginFunctionErrorMessage(error);
        if (_loginRequired) _detail = null;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    await context.pushRoute(app_routes.LoginRoute(from: widget.source));
    if (mounted) await _read();
  }

  Future<void> _openLink(String raw) async {
    if (_openingLink) return;
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty)
      return;
    setState(() {
      _openingLink = true;
      _linkError = '';
    });
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted)
          setState(() => _linkError = t.sourceShell.bikaDownloadOpenFailed);
      }
    } catch (_) {
      if (mounted)
        setState(() => _linkError = t.sourceShell.bikaDownloadOpenFailed);
    } finally {
      if (mounted) setState(() => _openingLink = false);
    }
  }

  @override
  Widget build(BuildContext context) => SourceExperienceBoundary(
    source: widget.source,
    builder: (context) => Scaffold(
      appBar: AppBar(
        leading: SourceBackButton(
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(convertChineseForDisplay(_gameText(widget.game, 'title'))),
      ),
      body: _loginRequired
          ? _GameMessage(
              message: t.navigation.needLoginTitle,
              label: t.navigation.goLogin,
              onPressed: _login,
              login: true,
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _GameCard(source: widget.source, game: _detail ?? widget.game),
                const SizedBox(height: 20),
                if (_busy)
                  Center(child: SourceLoadingIndicator(source: widget.source)),
                if (_error.isNotEmpty)
                  _GameMessage(
                    message: _error,
                    label: t.common.retry,
                    onPressed: _read,
                  ),
                if (_detail != null)
                  SelectableText(
                    html
                            .parse(_gameText(_detail!, 'description'))
                            .body
                            ?.text
                            .trim() ??
                        '',
                  ),
                if (_detail != null &&
                    asJsonList(_detail!['downloadLinks']).isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(t.sourceShell.bikaDownloadOpenHint),
                  for (final raw in asJsonList(_detail!['downloadLinks']))
                    Builder(
                      builder: (context) {
                        final link = asJsonMap(raw),
                            url = _gameText(asJsonMap(raw), 'url');
                        final uri = Uri.tryParse(url);
                        if (uri == null ||
                            !const {'http', 'https'}.contains(uri.scheme) ||
                            uri.host.isEmpty)
                          return const SizedBox.shrink();
                        return ListTile(
                          leading: const Icon(Icons.open_in_new),
                          title: Text(
                            '${link['platform'] == 'ios' ? 'iOS' : 'Android'} · ${uri.host}',
                          ),
                          subtitle: Text(t.sourceShell.bikaOpenDownloadLink),
                          onTap: _openingLink ? null : () => _openLink(url),
                        );
                      },
                    ),
                  if (_linkError.isNotEmpty) Text(_linkError),
                ],
                if (_detail != null &&
                    asJsonList(_detail!['downloadLinks']).isEmpty) ...[
                  const SizedBox(height: 20),
                  Text(t.sourceShell.bikaDownloadLinksEmpty),
                ],
              ],
            ),
    ),
  );
}

class _GameMessage extends StatelessWidget {
  const _GameMessage({
    required this.message,
    required this.label,
    required this.onPressed,
    this.login = false,
  });
  final String message, label;
  final Future<void> Function() onPressed;
  final bool login;
  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (login)
              const Icon(Icons.lock_outline, size: 40)
            else
              const BikaStatusArtwork(kind: BikaStatusKind.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onPressed, child: Text(label)),
          ],
        ),
      ),
    ),
  );
}
