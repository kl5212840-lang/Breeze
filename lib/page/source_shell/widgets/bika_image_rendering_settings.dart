import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/widgets/action_feedback.dart';

Future<Object?> readBikaImageRendering(String source) async =>
    loadPluginConfigValue<Object?>(
      source,
      bikaImageFilterQualityKey,
      fallback: null,
    );

/// Retained for existing routes; the source settings tab embeds the same field.
class BikaImageRenderingSettingsPage extends StatelessWidget {
  const BikaImageRenderingSettingsPage({
    super.key,
    required this.source,
    this.read = readBikaImageRendering,
    this.save = savePluginConfigValue,
  });
  final String source;
  final Future<Object?> Function(String) read;
  final Future<void> Function(String, String, dynamic) save;
  @override
  Widget build(BuildContext context) => SourceExperienceBoundary(
    source: source,
    builder: (context) => Scaffold(
      appBar: AppBar(
        leading: const SourceBackButton(),
        title: Text(t.sourceShell.bikaImageRendering),
      ),
      body: SettingListView(
        children: [
          BikaImageRenderingSetting(source: source, read: read, save: save),
        ],
      ),
    ),
  );
}

class BikaImageRenderingSetting extends StatefulWidget {
  const BikaImageRenderingSetting({
    super.key,
    required this.source,
    this.enabled = true,
    this.read = readBikaImageRendering,
    this.save = savePluginConfigValue,
  });
  final String source;
  final bool enabled;
  final Future<Object?> Function(String) read;
  final Future<void> Function(String, String, dynamic) save;
  @override
  State<BikaImageRenderingSetting> createState() =>
      _BikaImageRenderingSettingState();
}

class _BikaImageRenderingSettingState extends State<BikaImageRenderingSetting> {
  FilterQuality _value = FilterQuality.medium;
  bool _loading = true, _saving = false, _available = false;
  String _error = '';
  int _generation = 0;
  bool get _supported => supportsBikaExperienceDeclaration(
    widget.source,
    PluginRegistryService.I.getCachedPluginInfo(widget.source),
  );
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(BikaImageRenderingSetting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _generation++;
      _saving = false;
      _value = FilterQuality.medium;
      unawaited(_load());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scoped = SourceExperienceScope.maybeOf(context);
    if (!_loading &&
        !_saving &&
        scoped != null &&
        scoped.source == widget.source &&
        scoped.enabled) {
      _value = scoped.imageFilterQuality;
    }
  }

  Future<void> _load() async {
    final generation = ++_generation, source = widget.source;
    setState(() {
      _loading = true;
      _error = '';
      _available = false;
    });
    try {
      if (!_supported) throw StateError('Unsupported source image setting');
      final value = parseBikaImageFilterQuality(await widget.read(source));
      if (!mounted || generation != _generation) return;
      if (!_supported) throw StateError('Source image setting changed');
      setState(() {
        _value = value;
        _available = true;
      });
    } catch (_) {
      if (mounted && generation == _generation)
        setState(() => _error = t.sourceShell.bikaImageRenderingUnavailable);
    } finally {
      if (mounted && generation == _generation)
        setState(() => _loading = false);
    }
  }

  Future<void> _save(FilterQuality value) async {
    if (!widget.enabled ||
        _saving ||
        !_available ||
        !_supported ||
        value == _value) {
      return;
    }
    final generation = _generation, source = widget.source;
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      await widget.save(source, bikaImageFilterQualityKey, value.name);
      if (!mounted || generation != _generation) return;
      if (!_supported) {
        setState(() {
          _available = false;
          _error = t.sourceShell.bikaImageRenderingUnavailable;
        });
        return;
      }
      final actual = parseBikaImageFilterQuality(await widget.read(source));
      if (!mounted || generation != _generation) return;
      if (!_supported) {
        setState(() {
          _available = false;
          _error = t.sourceShell.bikaImageRenderingUnavailable;
        });
        return;
      }
      setState(() => _value = actual);
      if (actual == value)
        showActionFeedback(context, t.common.saved);
      else
        setState(() => _error = t.sourceShell.bikaImageRenderingNotUpdated);
    } catch (_) {
      if (mounted && generation == _generation)
        setState(() => _error = t.sourceShell.bikaImageRenderingSaveFailed);
    } finally {
      if (mounted && generation == _generation) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SettingChoiceTile<FilterQuality>(
        key: const ValueKey('bika-image-filter-quality'),
        leading: const Icon(Icons.image_outlined),
        title: t.sourceShell.bikaImageRendering,
        value: _value,
        enabled:
            widget.enabled && !_loading && _available && !_saving && _supported,
        error: _error.isEmpty ? null : _error,
        items: {
          FilterQuality.none: t.sourceShell.bikaImageQualityNone,
          FilterQuality.low: t.sourceShell.bikaImageQualityLow,
          FilterQuality.medium: t.sourceShell.bikaImageQualityMedium,
          FilterQuality.high: t.sourceShell.bikaImageQualityHigh,
        },
        onChanged: (value) => unawaited(_save(value)),
      ),
      if (_error.isNotEmpty && !_available)
        TextButton(
          onPressed: !widget.enabled || _loading || _saving ? null : _load,
          child: Text(t.common.retry),
        ),
    ],
  );
}
