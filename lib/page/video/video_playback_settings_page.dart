import 'package:zephyr/page/video/video_browse_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';

class VideoPlaybackSettingsPage extends StatefulWidget {
  const VideoPlaybackSettingsPage({
    super.key,
    this.readPreferences,
    this.source,
    this.sourceName,
    this.onAccountSync,
    this.readSourceBundle,
    this.saveSourcePreference,
    this.savePreference,
  });

  final String? source, sourceName;
  final Future<void> Function()? onAccountSync;
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
  ) {
    final theme = Theme.of(context), colors = theme.colorScheme;
    Future<void> choose() async {
      final next = await showVideoTaskSheet<Object>(
        context: context,
        builder: (sheet) => SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title, style: theme.textTheme.titleMedium),
                    ),
                    IconButton(
                      tooltip: t.common.close,
                      onPressed: () => Navigator.of(sheet).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              if (key == 'controlsStyle')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    t.videoPlayback.controlsStyleNote,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 8),
                  children: [
                    for (final entry in choices.entries)
                      ListTile(
                        title: Text(entry.value),
                        selected: entry.key == value,
                        trailing: entry.key == value
                            ? const Icon(Icons.check_rounded)
                            : null,
                        onTap: () => Navigator.of(sheet).pop(entry.key),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      if (next != null && mounted && next != value) await _save(key, next);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final label = choices[value] ?? '';
        double measure(String text, TextStyle? style) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          final width = painter.width;
          painter.dispose();
          return width;
        }

        final inline =
            measure(title, theme.textTheme.bodyLarge) +
                measure(label, theme.textTheme.bodyMedium) +
                88 <=
            constraints.maxWidth;
        final current = Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        );
        return ListTile(
          minTileHeight: 44,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          title: Text(title),
          subtitle: inline ? null : current,
          trailing: inline
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    current,
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded, size: 20),
                  ],
                )
              : const Icon(Icons.chevron_right_rounded, size: 20),
          onTap: choose,
        );
      },
    );
  }

  Widget _section(String title, {bool first = false}) => Padding(
    padding: EdgeInsets.fromLTRB(16, first ? 16 : 20, 16, 4),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
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
      SwitchListTile.adaptive(
        key: ValueKey('video-setting.$key'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(title),
        subtitle: note == null ? null : Text(note),
        value: value,
        onChanged: enabled ? (v) => _save(key, v) : null,
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
          controls = t.videoPlayback.controlsGroup,
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
        'controlsStyle',
        t.videoPlayback.controlsStyle,
        controls,
        p.controlsStyle,
        {
          'system': t.videoPlayback.systemControls,
          'breeze': t.videoPlayback.breezeControls,
        },
        aliases: '液态玻璃 iOS Breeze UI 样式 style glass',
      );
      choice(
        'hideSeconds',
        t.videoPlayback.controlsTimeout,
        controls,
        p.hideSeconds,
        {
          for (final v in [3, 5, 8]) v: t.videoPlayback.seconds(value: v),
        },
        aliases: '隐藏 时间 hide',
      );
      item(
        'motion',
        t.videoPlayback.settingsMotion,
        controls,
        '动画 动效 强度 过渡 motion animation',
        ListTile(
          title: Text(t.videoPlayback.settingsMotion),
          subtitle: Text(t.videoPlayback.settingsMotionNote),
          trailing: Text(
            t.videoPlayback.settingsMotionValue,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
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
      if (widget.onAccountSync != null) {
        item(
          'accountSync',
          t.videoPlayback.accountBackup,
          t.videoPlayback.settingsScopeSource,
          '账号 云同步 会话 登录 account sync',
          ListTile(
            title: Text(t.videoPlayback.accountBackup),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: widget.onAccountSync,
          ),
        );
      }
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
    final rows = <Widget>[];
    for (final e in results) {
      if (previous != e.group) {
        rows.add(_section(e.group, first: previous == null));
        previous = e.group;
      }
      rows.add(e.control);
    }
    return Theme(
      data: videoBrowseTheme(Theme.of(context)),
      child: PopScope(
        canPop: !_saving,
        child: Scaffold(
          appBar: AppBar(title: Text(t.videoPlayback.playbackSettings)),
          body: Column(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: t.videoPlayback.settingsSearch,
                        prefixIcon: const Icon(Icons.search_rounded),
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
                                    trailing: TextButton(
                                      onPressed: _readSource,
                                      child: Text(t.common.retry),
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
