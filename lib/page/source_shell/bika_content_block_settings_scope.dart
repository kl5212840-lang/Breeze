import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/page/source_shell/bika_content_block_rules.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';

class BikaContentBlockSettingsScope extends StatefulWidget {
  const BikaContentBlockSettingsScope({
    super.key,
    required this.source,
    required this.builder,
  });

  final String source;
  final Widget Function(BuildContext, BikaContentBlockRules) builder;

  @override
  State<BikaContentBlockSettingsScope> createState() =>
      _BikaContentBlockSettingsScopeState();
}

class _BikaContentBlockSettingsScopeState
    extends State<BikaContentBlockSettingsScope> {
  StreamSubscription<List<Type>>? _watch;
  var _rules = const BikaContentBlockRules.empty();

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(BikaContentBlockSettingsScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) _bind();
  }

  void _bind() {
    unawaited(_watch?.cancel());
    _watch = null;
    _rules = const BikaContentBlockRules.empty();
    if (!isBikaExperienceSource(widget.source)) return;
    _rules = _read();
    _watch = objectbox.store.entityChanges.listen((types) {
      if (!mounted || !types.contains(PluginConfig)) return;
      final next = _read();
      if (!next.sameAs(_rules)) setState(() => _rules = next);
    });
  }

  BikaContentBlockRules _read() => BikaContentBlockRules.fromConfig(
    readHostPluginConfiguration(widget.source),
  );

  @override
  void dispose() {
    unawaited(_watch?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _rules);
}
