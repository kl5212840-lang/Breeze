import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/plugin_config_merge.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/page/search_result/view/source_list_categories.dart';
import 'package:zephyr/page/source_shell/source_experience_preferences.dart';
import 'package:zephyr/page/source_shell/source_list_block_preferences.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';

const bikaSearchBlockedCategoriesKey = 'search.blockedCategories';
const _importedBikaSearchBlocks = 'breeze.search.importedPageBlocks';

/// The receipt and the merged rules are saved in one transaction. Keeping
/// the receipt lets backups include the legacy preference without reviving
/// categories the user has since removed in settings.
Future<void> migrateBikaSearchBlocks(String source) async {
  if (!isBikaExperienceSource(source)) return;
  final generation = pluginSessionWriteFence.generation(bikaPlusSourceId);
  final legacy = {
    ...?await SourceListBlockPreferences.read('$bikaPlusSourceId|search'),
    if (source != bikaPlusSourceId)
      ...?await SourceListBlockPreferences.read('$source|search'),
  };
  if (legacy.isEmpty ||
      pluginSessionWriteFence.isChanging(bikaPlusSourceId) ||
      generation != pluginSessionWriteFence.generation(bikaPlusSourceId)) {
    return;
  }
  final box = objectbox.pluginConfigBox;
  final query = box.query(PluginConfig_.name.equals(bikaPlusSourceId)).build();
  try {
    objectbox.store.runInTransaction(TxMode.write, () {
      final entity =
          query.findFirst() ??
          PluginConfig(name: bikaPlusSourceId, config: '{}');
      final config = jsonDecode(entity.config) as Map<String, dynamic>;
      final imported = blockedCategoryNames(config[_importedBikaSearchBlocks]);
      final additions = legacy.difference(imported);
      if (additions.isEmpty) return;
      final merged = updatePluginConfigField(
        config,
        bikaSearchBlockedCategoriesKey,
        {
          ...blockedCategoryNames(config[bikaSearchBlockedCategoriesKey]),
          ...additions,
        }.toList(),
      );
      entity.config = jsonEncode(
        updatePluginConfigField(
          merged,
          _importedBikaSearchBlocks,
          {...imported, ...additions}.toList(),
        ),
      );
      box.put(entity);
    });
  } finally {
    query.close();
  }
}

/// Observes the persisted source rule independently of page search filters.
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
        .query(PluginConfig_.name.equals(bikaPlusSourceId))
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
          ? blockedCategoryNames(config[bikaSearchBlockedCategoriesKey])
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
