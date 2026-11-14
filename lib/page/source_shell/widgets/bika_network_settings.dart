import 'package:zephyr/page/source_shell/bika_access_lines.dart';
import 'package:zephyr/page/source_shell/widgets/bika_access_lines_page.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/page/plugin_function/cubit/plugin_function_cubit.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/page/source_shell/source_loading_indicator.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/widgets/action_feedback.dart';

class BikaAccessLinesSettingTile extends StatelessWidget {
  const BikaAccessLinesSettingTile({
    super.key,
    required this.source,
    this.enabled = true,
  });
  final String source;
  final bool enabled;
  @override
  Widget build(BuildContext context) => ListTile(
    key: const ValueKey('bika-settings-network'),
    leading: const Icon(Icons.dns_outlined),
    title: Text(
      supportsBikaAccessLines(
            source,
            PluginRegistryService.I.getCachedPluginInfo(source),
          )
          ? t.sourceShell.bikaAccessLines
          : t.sourceShell.bikaNetworkTitle,
    ),
    trailing: const Icon(Icons.chevron_right),
    onTap: !enabled
        ? null
        : () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => BikaNetworkSettingsPage(source: source),
            ),
          ),
  );
}

/// Existing settings calls remain source scoped and never change accounts.
Future<Map<String, dynamic>> callBikaNetworkSetting(
  String source,
  String function,
  Map<String, dynamic> core,
) => callUnifiedComicPlugin(
  from: source,
  fnPath: function,
  core: core,
  notifyUnauthorized: false,
);

class BikaNetworkSettingsPage extends StatefulWidget {
  const BikaNetworkSettingsPage({
    super.key,
    required this.source,
    this.call = callBikaNetworkSetting,
  });
  final String source;
  final Future<Map<String, dynamic>> Function(
    String source,
    String function,
    Map<String, dynamic> core,
  )
  call;
  @override
  State<BikaNetworkSettingsPage> createState() =>
      _BikaNetworkSettingsPageState();
}

class _BikaNetworkSettingsPageState extends State<BikaNetworkSettingsPage> {
  List<Map<String, dynamic>> _fields = [];
  Map<String, dynamic> _values = {};
  bool _loading = true, _saving = false;
  String _error = '';
  int _generation = 0, _loadEpoch = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(BikaNetworkSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source || oldWidget.call != widget.call) {
      _generation++;
      _saving = false;
      _fields = [];
      _values = {};
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _generation++;
    _loadEpoch++;
    super.dispose();
  }

  Future<void> _load() async {
    final generation = _generation, epoch = ++_loadEpoch;
    final source = widget.source, accessLines = _accessLines;
    setState(() {
      _loading = _fields.isEmpty;
      _error = '';
    });
    try {
      final result = await widget.call(source, 'getSettingsBundle', {});
      if (!mounted || generation != _generation || epoch != _loadEpoch) return;
      final sections = asJsonList(
        asJsonMap(result['scheme'])['sections'],
      ).map(asJsonMap);
      final fields = sections
          .where((s) => s['id'] == 'network')
          .expand((s) => asJsonList(s['fields']).map(asJsonMap))
          .where(
            (f) =>
                (accessLines
                    ? f['key'] == 'network.proxy'
                    : const {
                        'network.apiBase',
                        'network.proxy',
                      }.contains(f['key'])) &&
                f['kind'] == 'select',
          )
          .toList();
      if (fields.isEmpty)
        throw FormatException(t.sourceShell.bikaNetworkUnavailable);
      if (!mounted) return;
      setState(() {
        _fields = fields;
        _values = asJsonMap(asJsonMap(result['data'])['values']);
      });
    } catch (e) {
      if (mounted && generation == _generation && epoch == _loadEpoch)
        setState(() => _error = pluginFunctionErrorMessage(e));
    } finally {
      if (mounted && generation == _generation && epoch == _loadEpoch)
        setState(() => _loading = false);
    }
  }

  Future<void> _save(String key, String value) async {
    if (_saving || _values[key]?.toString() == value) return;
    final generation = _generation, source = widget.source;
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      final result = await widget.call(source, 'saveSettings', {
        'values': {key: value},
      });
      if (!mounted || generation != _generation) return;
      if (result['ok'] != true)
        throw StateError(t.sourceShell.bikaNetworkSaveFailed);
      if (!mounted) return;
      await _load();
      if (mounted && generation == _generation && _error.isEmpty) {
        if (_values[key]?.toString() == value)
          showActionFeedback(context, t.common.saved);
        else
          setState(() => _error = t.sourceShell.bikaNetworkNotUpdated);
      }
    } catch (e) {
      if (mounted && generation == _generation)
        setState(() => _error = pluginFunctionErrorMessage(e));
    } finally {
      if (mounted && generation == _generation) setState(() => _saving = false);
    }
  }

  bool get _accessLines => supportsBikaAccessLines(
    widget.source,
    PluginRegistryService.I.getCachedPluginInfo(widget.source),
  );

  @override
  Widget build(BuildContext context) => _accessLines
      ? BikaAccessLinesPage(
          source: widget.source,
          call: widget.call,
          trailing: _loading
              ? const SizedBox.shrink()
              : Column(
                  children: [
                    if (_error.isNotEmpty && _fields.isEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(_error),
                      ),
                      TextButton(onPressed: _load, child: Text(t.common.retry)),
                    ],
                    for (final field in _fields.where(
                      (f) => f['key'] == 'network.proxy',
                    ))
                      SettingChoiceTile<String>(
                        title: t.sourceShell.bikaImageChannel,
                        enabled: !_saving,
                        value: _values[field['key']]?.toString() ?? '3',
                        items: {
                          for (final raw in asJsonList(field['options']))
                            asJsonMap(raw)['value']?.toString() ?? '':
                                asJsonMap(raw)['label']?.toString() ?? '',
                        },
                        error: _error.isEmpty ? null : _error,
                        onChanged: (value) =>
                            unawaited(_save('network.proxy', value)),
                      ),
                  ],
                ),
        )
      : SourceExperienceBoundary(
          source: widget.source,
          builder: (context) => Scaffold(
            appBar: AppBar(
              leading: const SourceBackButton(),
              title: Text(t.sourceShell.bikaNetworkTitle),
            ),
            body: _loading
                ? Center(child: SourceLoadingIndicator(source: widget.source))
                : SettingListView(
                    children: [
                      for (final field in _fields)
                        SettingChoiceTile<String>(
                          key: ValueKey('bika-network-${field['key']}'),
                          title: field['key'] == 'network.apiBase'
                              ? t.sourceShell.bikaApiServer
                              : t.sourceShell.bikaChannel,
                          enabled: !_saving,
                          value: _values[field['key']]?.toString() ?? '',
                          items: {
                            for (final raw in asJsonList(field['options']))
                              asJsonMap(raw)['value']?.toString() ?? '':
                                  asJsonMap(raw)['label']?.toString() ?? '',
                          },
                          onChanged: (value) =>
                              unawaited(_save(field['key'].toString(), value)),
                        ),
                      if (_error.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text(_error),
                              TextButton(
                                onPressed: _saving ? null : _load,
                                child: Text(t.common.retry),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        );
}
