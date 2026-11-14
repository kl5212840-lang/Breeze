import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:objectbox/objectbox.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/page/search_result/view/source_list_categories.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';

/// Source settings own the minimum exclusions. Page preferences can add to
/// these, never remove them or save them back as a settings edit.
class SourceCategorySettingsScope extends StatefulWidget {
  const SourceCategorySettingsScope({
    super.key,
    required this.source,
    required this.builder,
  });
  final String source;
  final Widget Function(BuildContext, Set<String>) builder;
  @override
  State<SourceCategorySettingsScope> createState() =>
      _SourceCategorySettingsScopeState();
}

class _SourceCategorySettingsScopeState
    extends State<SourceCategorySettingsScope> {
  Query<PluginConfig>? _query;
  StreamSubscription<List<Type>>? _watch;
  Set<String> _blocked = const {};
  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(SourceCategorySettingsScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) _bind();
  }

  void _bind() {
    unawaited(_watch?.cancel());
    _query?.close();
    _query = null;
    _blocked = const {};
    // Only this source declares this setting today. Unknown plugins must not
    // acquire an invented config field or inherit another source's categories.
    if (!isBikaExperienceSource(widget.source)) return;
    _query = objectbox.pluginConfigBox
        .query(PluginConfig_.name.equals(widget.source))
        .build();
    _blocked = _read();
    _watch = objectbox.store.entityChanges.listen((types) {
      if (!mounted || !types.contains(PluginConfig)) return;
      final next = _read();
      if (!setEquals(next, _blocked)) setState(() => _blocked = next);
    });
  }

  Set<String> _read() {
    try {
      final config = jsonDecode(_query?.findFirst()?.config ?? '{}');
      return config is Map
          ? blockedCategoryNames(config['search.blockedCategories'])
          : const {};
    } catch (_) {
      return _blocked;
    }
  }

  @override
  void dispose() {
    unawaited(_watch?.cancel());
    _query?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _blocked);
}
