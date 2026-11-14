import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/source_shell/bika_access_lines.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/widgets/action_feedback.dart';

/// Server image quality, separate from Flutter's local scaling filter.
/// Older plugin bundles without this field keep their existing behavior.
class BikaImageQualitySetting extends StatefulWidget {
  const BikaImageQualitySetting({
    super.key,
    required this.source,
    this.enabled = true,
    this.call = callBikaAccessLines,
  });
  final String source;
  final bool enabled;
  final BikaLineCall call;

  @override
  State<BikaImageQualitySetting> createState() =>
      _BikaImageQualitySettingState();
}

class _BikaImageQualitySettingState extends State<BikaImageQualitySetting> {
  static const _key = 'image.quality';
  static const _values = {'original', 'high', 'medium', 'low'};
  String _value = 'original', _error = '';
  bool _loading = true, _available = false, _saving = false;
  int _epoch = 0;
  StreamSubscription? _updates;
  String _bundle = '';
  String get _currentBundle {
    final plugin = PluginRegistryService.I.getByUuid(widget.source);
    return '${plugin?.version}:${plugin?.originScript.hashCode}';
  }

  @override
  void initState() {
    super.initState();
    _bundle = _currentBundle;
    _updates = PluginRegistryService.I.stream.listen((_) {
      if (!mounted || _bundle == _currentBundle) return;
      _bundle = _currentBundle;
      unawaited(_load());
    });
    unawaited(_load());
  }

  @override
  void dispose() {
    _epoch++;
    unawaited(_updates?.cancel());
    super.dispose();
  }

  @override
  void didUpdateWidget(BikaImageQualitySetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source || oldWidget.call != widget.call) {
      _bundle = _currentBundle;
      unawaited(_load());
    }
  }

  bool _applyBundle(Map<String, dynamic> result) {
    final sections = asJsonList(asJsonMap(result['scheme'])['sections']);
    final supported = sections
        .map(asJsonMap)
        .any(
          (section) => asJsonList(section['fields'])
              .map(asJsonMap)
              .any(
                (field) => field['key'] == _key && field['kind'] == 'select',
              ),
        );
    final value = asJsonMap(asJsonMap(result['data'])['values'])[_key];
    _available = supported && _values.contains(value);
    if (_available) _value = value as String;
    return _available;
  }

  Future<void> _load() async {
    final epoch = ++_epoch, source = widget.source;
    setState(() {
      _loading = true;
      // A new bundle supersedes both the previous read and its pending save.
      // The old save's finally block is fenced out by the new epoch.
      _saving = false;
      _available = false;
      _error = '';
    });
    try {
      final result = await widget.call(source, 'getSettingsBundle', {});
      if (!mounted || epoch != _epoch) return;
      setState(() {
        if (!_applyBundle(result) &&
            supportsBikaImageQuality(
              widget.source,
              PluginRegistryService.I.getCachedPluginInfo(widget.source),
            )) {
          _error = t.sourceShell.bikaImageRenderingUnavailable;
        }
      });
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(() => _error = t.sourceShell.bikaImageRenderingUnavailable);
      }
    } finally {
      if (mounted && epoch == _epoch) setState(() => _loading = false);
    }
  }

  Future<void> _save(String value) async {
    if (!widget.enabled ||
        !_available ||
        _saving ||
        value == _value ||
        !_values.contains(value))
      return;
    final epoch = _epoch, source = widget.source;
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      final result = await widget.call(source, 'saveSettings', {
        'values': {_key: value},
      });
      if (!mounted || epoch != _epoch) return;
      if (result['ok'] != true) throw StateError('Image quality was not saved');
      final actual = await widget.call(source, 'getSettingsBundle', {});
      if (!mounted || epoch != _epoch) return;
      setState(() => _applyBundle(actual));
      if (_available && _value == value) {
        showActionFeedback(context, t.common.saved);
      } else {
        setState(() => _error = t.sourceShell.bikaImageRenderingNotUpdated);
      }
    } catch (_) {
      if (mounted && epoch == _epoch) {
        setState(() => _error = t.sourceShell.bikaImageRenderingSaveFailed);
      }
    } finally {
      if (mounted && epoch == _epoch) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && !_available && _error.isEmpty)
      return const SizedBox.shrink();
    final zh = Localizations.localeOf(context).languageCode == 'zh';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingChoiceTile<String>(
          key: const ValueKey('bika-image-quality'),
          leading: const Icon(Icons.image_outlined),
          title: zh ? '图片质量' : 'Image quality',
          enabled: widget.enabled && !_loading && _available && !_saving,
          value: _value,
          error: _error.isEmpty ? null : _error,
          items: zh
              ? const {
                  'original': '原图',
                  'high': '高清',
                  'medium': '推荐',
                  'low': '极度压缩',
                }
              : const {
                  'original': 'Original',
                  'high': 'High definition',
                  'medium': 'Recommended',
                  'low': 'Maximum compression',
                },
          onChanged: (value) => unawaited(_save(value)),
        ),
        if (_error.isNotEmpty && !_available)
          TextButton(
            onPressed: widget.enabled && !_loading && !_saving ? _load : null,
            child: Text(t.common.retry),
          ),
      ],
    );
  }
}
