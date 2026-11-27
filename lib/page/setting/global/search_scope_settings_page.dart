import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/method/search_scope_preferences.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/page/video/video_source_action.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/util/json/json_value.dart';

const searchScopeSettingsRouteName = 'breeze.settings.search';

Future<void> openSearchScopeSettings(BuildContext context, {String? source}) =>
    Navigator.of(context).push<void>(
      videoPageRoute<void>(
        settings: const RouteSettings(name: searchScopeSettingsRouteName),
        matchAutoRouteTransition: true,
        builder: (_) => SearchScopeSettingsPage(source: source),
      ),
    );

Map<String, List<KeywordSearchScope>> searchScopeSettingsOptions(
  String source,
  Map<String, dynamic>? info,
) {
  if (info == null) return const {};
  final experience = asJsonMap(info['breezeExperience']);
  final actions = asJsonList(info['functions'] ?? info['function'])
      .map((function) => asJsonMap(asJsonMap(function)['action']))
      .where((action) => action.isNotEmpty);
  final video = videoSourceActions(info);
  // Classic comic plugins expose search through the host even when their
  // getInfo lists only browse functions. Pure website/video sources use their
  // own route and need a declared native video search entry.
  final comic =
      experience['aggregateMedia'] == 'comic' ||
      actions.any(
        (action) => const {
          'openComicList',
          'openPluginFunction',
          'openSearch',
        }.contains(action['type']),
      ) ||
      actions.isEmpty && video.isEmpty;
  final comicScopes = comic
      ? sourceKeywordSearchScopes(source, info)
      : const <KeywordSearchScope>[];
  final hasVideo = video.any((action) {
    final payload = asJsonMap(action['payload']);
    final url = apiVideoHttps(payload['url']);
    if (payload['nativeSearch'] != true ||
        url == null ||
        (url.hasPort && url.port != 443) ||
        [
          'catalogFnPath',
          'detailFnPath',
          'playbackFnPath',
        ].any((key) => apiVideoText(payload[key], 120).isEmpty)) {
      return false;
    }
    if (action['type'] == 'openVideoCatalog') return true;
    if (!const {1, 2}.contains(payload['protocol'])) return false;
    final caps = ApiVideoCapabilities.fromJson(
      asJsonMap(payload['capabilities']),
    );
    return caps.usesRemoteKeywordScope;
  });
  return {
    if (comicScopes.length > 1) SearchScopePreferences.comic: comicScopes,
    if (hasVideo) SearchScopePreferences.video: defaultKeywordSearchScopes,
  };
}

class SearchScopeSettingsPage extends StatelessWidget {
  const SearchScopeSettingsPage({super.key, this.source});

  final String? source;

  @override
  Widget build(BuildContext context) {
    final registry = PluginRegistryService.I;
    return SettingPageShell(
      grouped: true,
      title: t.search.title,
      child: StreamBuilder<Map<String, PluginRuntimeState>>(
        stream: registry.stream,
        initialData: registry.snapshot,
        builder: (context, snapshot) {
          final plugins = [
            for (final plugin in (snapshot.data ?? registry.snapshot).values)
              if (plugin.isActive &&
                  !registry.isLocallyRemoved(plugin.uuid) &&
                  (source == null || source == plugin.uuid))
                plugin,
          ]..sort((a, b) => (a.sortOrder ?? 0).compareTo(b.sortOrder ?? 0));
          final sections = <Widget>[];
          for (final plugin in plugins) {
            final info = registry.getCachedPluginInfo(plugin.uuid);
            final options = searchScopeSettingsOptions(plugin.uuid, info);
            if (options.isEmpty) continue;
            final title = info?['name'];
            sections.add(
              SettingSection(
                key: ValueKey(('search-settings.plugin', plugin.uuid)),
                title: title is String && title.trim().isNotEmpty
                    ? title
                    : plugin.uuid,
                children: [
                  for (final entry in options.entries)
                    _ScopeSetting(
                      key: ValueKey((plugin.uuid, entry.key)),
                      source: plugin.uuid,
                      surface: entry.key,
                      title: entry.key == SearchScopePreferences.comic
                          ? t.bookshelf.mediaComics
                          : t.bookshelf.mediaVideos,
                      scopes: entry.value,
                    ),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (source == null)
                SettingSection(
                  title: t.search.aggregateHistory,
                  children: [
                    _ScopeSetting(
                      surface: SearchScopePreferences.aggregate,
                      title: t.search.defaultScope,
                      scopes: defaultKeywordSearchScopes,
                    ),
                  ],
                ),
              ...sections,
              if (sections.isEmpty) SettingNote(t.search.noScopeSources),
            ],
          );
        },
      ),
    );
  }
}

class _ScopeSetting extends StatefulWidget {
  const _ScopeSetting({
    super.key,
    this.source,
    required this.surface,
    required this.title,
    required this.scopes,
  });

  final String? source;
  final String surface, title;
  final List<KeywordSearchScope> scopes;

  @override
  State<_ScopeSetting> createState() => _ScopeSettingState();
}

class _ScopeSettingState extends State<_ScopeSetting> {
  late Future<String?> _value = _read();
  bool _saving = false;
  String? _error, _savedValue;

  Future<String?> _read() => SearchScopePreferences.read(
    source: widget.source,
    surface: widget.surface,
  );

  Future<void> _save(KeywordSearchScope scope) async {
    if (_saving || !widget.scopes.contains(scope)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await SearchScopePreferences.save(
        source: widget.source,
        surface: widget.surface,
        value: scope.name,
        supported: widget.scopes.map((scope) => scope.name),
      );
      if (mounted) setState(() => _savedValue = scope.name);
    } catch (_) {
      if (mounted) setState(() => _error = t.error.saveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _value,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ListTile(
          title: Text(widget.title),
          subtitle: Text(t.common.loadingFailed),
          trailing: TextButton(
            onPressed: () => setState(() => _value = _read()),
            child: Text(t.common.retry),
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done &&
          !snapshot.hasData) {
        return ListTile(
          title: Text(widget.title),
          trailing: const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
      final stored = parseSourceKeywordSearchScope(
        _savedValue ?? snapshot.data,
      );
      final selected = widget.scopes.contains(stored)
          ? stored!
          : KeywordSearchScope.all;
      return SettingChoiceTile<KeywordSearchScope>(
        title: widget.title,
        value: selected,
        items: {
          for (final option in widget.scopes)
            option: keywordSearchScopeLabel(
              option,
              copyTopics: widget.source == copyComicSourceId,
            ),
        },
        onChanged: (value) {
          if (value != selected) _save(value);
        },
        enabled: !_saving,
        stableTrailing: true,
        error: _error,
      );
    },
  );
}
