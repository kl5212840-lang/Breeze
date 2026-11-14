import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'package:zephyr/page/search/widget/search_field_decoration.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/video/video_browse_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';
import 'package:zephyr/widgets/breeze_switch.dart';

const videoPlaybackSettingsRouteName = 'breeze.video.playback-settings';

class VideoSettingsEntry {
  const VideoSettingsEntry({
    required this.key,
    required this.title,
    required this.group,
    required this.child,
  });
  final String key, title, group;
  final Widget child;
}

class VideoPlaybackSettingsPage extends StatefulWidget {
  const VideoPlaybackSettingsPage({
    super.key,
    this.readPreferences,
    this.source,
    this.sourceName,
    this.title,
    this.includeSourcePreferences = false,
    this.additionalEntries = const [],
    this.readSourceBundle,
    this.saveSourcePreference,
    this.savePreference,
  });

  final String? source, sourceName;
  final String? title;
  final bool includeSourcePreferences;
  final List<VideoSettingsEntry> additionalEntries;
  final Future<Map<String, dynamic>> Function()? readSourceBundle;
  final Future<void> Function(String, Object)? saveSourcePreference;
  final Future<VideoPlaybackPreferences> Function()? readPreferences;
  final Future<void> Function(String, Object)? savePreference;

  @override
  State<VideoPlaybackSettingsPage> createState() =>
      _VideoPlaybackSettingsPageState();
}

class _VideoPlaybackSettingsPageState extends State<VideoPlaybackSettingsPage> {
  VideoPlaybackPreferences? _preferences;
  bool _loadFailed = false;
  bool _saving = false;
  final _search = TextEditingController();
  String _query = '';
  List<Map<String, dynamic>> _sourceFields = [];
  Map<String, dynamic> _sourceValues = {};
  bool _sourceFailed = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _readSource() async {
    if (!widget.includeSourcePreferences) return;
    if (widget.source == null && widget.readSourceBundle == null) return;
    try {
      final bundle =
          await (widget.readSourceBundle?.call() ??
                  callUnifiedComicPlugin(
                    from: widget.source!,
                    fnPath: 'getSettingsBundle',
                    core: const {},
                  ))
              .timeout(const Duration(seconds: 5));
      final scheme = asJsonMap(bundle['scheme']);
      final fields = <Map<String, dynamic>>[];
      for (final section in asJsonList(scheme['sections'])) {
        for (final raw in asJsonList(asJsonMap(section)['fields'])) {
          final field = asJsonMap(raw);
          if ((field['key']?.toString() ?? '').startsWith('video.') &&
              ['select', 'switch'].contains(field['kind']) &&
              (field['fnPath']?.toString().trim() ?? '').isEmpty &&
              field['persist'] != false) {
            fields.add(field);
          }
        }
      }
      if (mounted) {
        setState(() {
          _sourceFields = fields;
          _sourceValues = asJsonMap(asJsonMap(bundle['data'])['values']);
          _sourceFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _sourceFailed = true);
    }
  }

  @override
  void initState() {
    super.initState();
    _read();
    _readSource();
  }

  Future<void> _read() async {
    try {
      final preferences =
          await (widget.readPreferences ?? VideoPlaybackPreferences.read)()
              .timeout(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _preferences = preferences;
          _loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _save(String key, Object value) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (key.startsWith('video.')) {
        final field = _sourceFields.where((f) => f['key'] == key).firstOrNull;
        if (field == null) throw StateError('Unknown source setting');
        if (widget.saveSourcePreference != null) {
          await widget.saveSourcePreference!(key, value).timeout(
            const Duration(seconds: 5),
          );
        } else {
          await savePluginConfigValue(
            widget.source!,
            key,
            value,
          ).timeout(const Duration(seconds: 5));
        }
        await _readSource();
      } else {
        await (widget.savePreference ?? VideoPlaybackPreferences.save)(
          key,
          value,
        ).timeout(const Duration(seconds: 5));
        await _read();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.videoPlayback.settingsSaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _choice(
    String title,
    String key,
    Object value,
    Map<Object, String> choices,
  ) => SettingChoiceTile<Object>(
    title: title,
    value: value,
    items: choices,
    enabled: !_saving,
    onChanged: (next) async {
      if (next != value) await _save(key, next);
    },
  );

  @override
  Widget build(BuildContext context) {
    final p = _preferences;
    final entries =
        <
          ({
            String key,
            String title,
            String group,
            String aliases,
            Widget control,
          })
        >[];
    void item(
      String key,
      String title,
      String group,
      String aliases,
      Widget control,
    ) => entries.add((
      key: key,
      title: title,
      group: group,
      aliases: aliases,
      control: control,
    ));
    void toggle(
      String key,
      String title,
      String group,
      bool value, {
      String aliases = '',
      String? note,
      bool enabled = true,
    }) => item(
      key,
      title,
      group,
      aliases,
      TouchHoverIntent(
        identity: (widget.source, key),
        builder: (context, hover) => BreezeSwitchListTile(
          SwitchListTile.adaptive(
            hoverColor: hover.hoverColor(),
            key: ValueKey('video-setting.$key'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            title: Text(title),
            subtitle: note == null ? null : Text(note),
            value: value,
            onChanged: enabled ? (v) => _save(key, v) : null,
          ),
        ),
      ),
    );
    void choice(
      String key,
      String title,
      String group,
      Object value,
      Map<Object, String> options, {
      String aliases = '',
    }) => item(key, title, group, aliases, _choice(title, key, value, options));
    if (p != null) {
      final play = t.videoPlayback.playbackGroup,
          gestures = t.videoPlayback.gestureSettings,
          history = t.videoPlayback.historyGroup;
      toggle(
        'autoplay',
        t.videoPlayback.autoplay,
        play,
        p.autoplay,
        aliases: '自动播放 autoplay',
      );
      choice(
        'defaultSpeed',
        t.videoPlayback.defaultSpeed,
        play,
        p.defaultSpeed,
        {
          for (final v in [.75, 1.0, 1.25, 1.5, 2.0]) v: '$v×',
        },
        aliases: '倍速 speed',
      );
      choice(
        'fullscreenOrientation',
        t.videoPlayback.defaultFullscreenOrientation,
        play,
        p.fullscreenOrientation,
        {
          'landscape': t.videoPlayback.landscapeFullscreen,
          'portrait': t.videoPlayback.portraitFullscreen,
        },
        aliases: '横屏 竖屏 fullscreen',
      );
      toggle(
        'cover',
        t.videoPlayback.coverVideo,
        play,
        p.cover,
        note: t.videoPlayback.coverVideoNote,
        aliases: '画面 裁剪 fit',
      );
      choice(
        'hideSeconds',
        t.videoPlayback.controlsTimeout,
        play,
        p.hideSeconds,
        {
          for (final v in [3, 5, 8]) v: t.videoPlayback.seconds(value: v),
        },
        aliases: '隐藏 时间 hide',
      );
      choice(
        'doubleTap',
        t.videoPlayback.doubleTapAction,
        gestures,
        p.doubleTap,
        {
          'seek': t.videoPlayback.doubleTapSeekShort,
          'playPause': t.videoPlayback.doubleTapPlay,
          'off': t.common.disabled,
        },
        aliases: '双击 快进 快退 double tap',
      );
      choice('holdSpeed', t.videoPlayback.holdSpeed, gestures, p.holdSpeed, {
        0.0: t.common.disabled,
        for (final v in [1.5, 2.0, 3.0]) v: '$v×',
      }, aliases: '长按 临时倍速 hold');
      toggle(
        'swipeSeek',
        t.videoPlayback.swipeSeek,
        gestures,
        p.swipeSeek,
        note: t.videoPlayback.swipeSeekNote,
        aliases: '横滑 滑动 进度 seek',
      );
      toggle(
        'recordHistory',
        t.videoPlayback.recordHistory,
        history,
        p.recordHistory,
        note: t.videoPlayback.recordHistoryNote,
        aliases: '记录 历史 history',
      );
      toggle(
        'resumeProgress',
        t.videoPlayback.resumeProgress,
        history,
        p.resumeProgress,
        enabled: p.recordHistory,
        note: p.recordHistory ? null : t.videoPlayback.resumeRequiresHistory,
        aliases: '续播 返回 恢复 resume',
      );
      for (final field in _sourceFields) {
        final key = field['key'].toString(),
            title = field['label']?.toString() ?? key;
        final group =
            '${t.videoPlayback.settingsScopeSource}${widget.sourceName == null ? '' : ' · ${widget.sourceName}'}';
        if (field['kind'] == 'switch') {
          toggle(
            key,
            title,
            group,
            _sourceValues[key] == true,
            aliases: '图源 site source 刷新 广告',
          );
        } else {
          choice(key, title, group, _sourceValues[key] ?? '', {
            for (final raw in asJsonList(field['options']))
              asJsonMap(raw)['value'] as Object: asJsonMap(
                raw,
              )['label'].toString(),
          }, aliases: '图源 site source 解析 等待 清晰度 线路');
        }
      }
    }
    for (final entry in widget.additionalEntries) {
      item(entry.key, entry.title, entry.group, '', entry.child);
    }
    final query = _query.trim().toLowerCase();
    final results = entries
        .where(
          (e) =>
              query.isEmpty ||
              '${e.title} ${e.group} ${e.aliases}'.toLowerCase().contains(
                query,
              ),
        )
        .toList();
    String? previous;
    var controls = <Widget>[];
    final rows = <Widget>[];
    void addGroup() {
      if (controls.isEmpty) return;
      rows.add(
        SettingSection(
          title: previous ?? '',
          hasLeading: false,
          children: controls,
        ),
      );
      controls = <Widget>[];
    }

    for (final e in results) {
      if (previous != e.group) {
        addGroup();
        previous = e.group;
      }
      controls.add(e.control);
    }
    addGroup();
    return Theme(
      data: videoBrowseTheme(Theme.of(context)),
      child: PopScope(
        canPop: !_saving,
        child: SettingPageShell(
          title: widget.title ?? t.videoPlayback.playbackSettings,
          grouped: true,
          child: Column(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: SearchFieldSurface(
                      child: TextField(
                        controller: _search,
                        onChanged: (v) => setState(() => _query = v),
                        decoration: searchFieldDecoration(
                          context,
                          hintText: t.videoPlayback.settingsSearch,
                          suffixIcon: query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: t.common.close,
                                  onPressed: () {
                                    _search.clear();
                                    setState(() => _query = '');
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _loadFailed
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(t.videoPlayback.settingsLoadFailed),
                            TextButton(
                              onPressed: _read,
                              child: Text(t.common.retry),
                            ),
                          ],
                        ),
                      )
                    : p == null
                    ? const Center(child: CircularProgressIndicator())
                    : IgnorePointer(
                        ignoring: _saving,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: ListView(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              children: [
                                SizedBox(
                                  height: 2,
                                  child: _saving
                                      ? const LinearProgressIndicator()
                                      : null,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    t.videoPlayback.hostSettingsScope,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                                if (results.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      t.videoPlayback.settingsSearchEmpty,
                                    ),
                                  ),
                                ...rows,
                                if (_sourceFailed)
                                  ListTile(
                                    title: Text(
                                      t.videoPlayback.settingsLoadFailed,
                                    ),
                                    trailing: TouchHoverIntent(
                                      identity: (widget.source, 'retry'),
                                      builder: (context, hover) {
                                        const style = ButtonStyle();
                                        return TextButton(
                                          style: style.copyWith(
                                            overlayColor: hover.overlayColor(
                                              style.overlayColor,
                                            ),
                                          ),
                                          onPressed: _readSource,
                                          child: Text(t.common.retry),
                                        );
                                      },
                                    ),
                                  ),
                                const SizedBox(height: 24),
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
    );
  }
}
