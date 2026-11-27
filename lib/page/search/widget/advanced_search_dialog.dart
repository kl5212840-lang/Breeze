import 'package:zephyr/widgets/breeze_switch.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/type/pipe.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/widgets/task_dialog.dart';
import 'package:zephyr/widgets/year_filter_picker.dart';

class AdvancedSearchDialog extends StatefulWidget {
  final SearchStates initialState;
  final bool allowSourceSwitch;

  const AdvancedSearchDialog({
    super.key,
    required this.initialState,
    this.allowSourceSwitch = true,
  });

  @override
  State<AdvancedSearchDialog> createState() => _AdvancedSearchDialogState();
}

class _AdvancedSearchDialogState extends State<AdvancedSearchDialog> {
  late SearchStates _tempState;

  @override
  void initState() {
    super.initState();
    _tempState = widget.initialState.copyWith();
  }

  @override
  Widget build(BuildContext context) {
    return TaskDialog(
      title: t.search.advancedSearchOptions,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.allowSourceSwitch) ...[
            _buildSectionTitle(t.search.dataSource),
            _buildSourceRow(),
          ],

          const SizedBox(height: 16),
          _buildSectionTitle(t.search.sortBy),
          _buildSortRow(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_tempState),
          child: Text(t.common.apply),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSourceRow() {
    final pluginStates = context.watch<PluginRegistryCubit>().state;
    final sources = PluginRegistryService.I.sortPlugins(
      pluginStates.values.where(
        (plugin) => plugin.isEnabled && !plugin.isDeleted,
      ),
    );

    return Wrap(
      spacing: 8,
      children: sources.map((plugin) {
        final info = PluginRegistryService.I.getCachedPluginInfo(plugin.uuid);
        final name = info?['name']?.toString().trim();
        return ChoiceChip(
          label: Text(
            (name?.isNotEmpty == true ? name! : plugin.uuid).let(
              convertChineseForDisplay,
            ),
          ),
          selected: _tempState.from == plugin.uuid,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _tempState = _tempState.copyWith(from: plugin.uuid);
              });
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildSortRow() {
    final Map<int, String> sortOptions = {
      1: t.search.newestToOldest,
      2: t.search.oldestToNewest,
      3: t.search.mostLikes,
      4: t.search.mostViews,
    };

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: sortOptions.entries.map((entry) {
        return ChoiceChip(
          label: Text(entry.value.let(convertChineseForDisplay)),
          selected: _tempState.sortBy == entry.key,
          onSelected: (selected) {
            if (selected) {
              setState(() {
                _tempState = _tempState.copyWith(sortBy: entry.key);
              });
            }
          },
        );
      }).toList(),
    );
  }
}

class PluginAdvancedSearchScheme {
  const PluginAdvancedSearchScheme({
    this.source = '',
    required this.fields,
    required this.values,
  });

  final String source;
  final List<Map<String, dynamic>> fields;
  final Map<String, dynamic> values;
}

class PluginAdvancedSearchDialog extends StatefulWidget {
  const PluginAdvancedSearchDialog({
    super.key,
    required this.initialSort,
    required this.scheme,
  });

  final int initialSort;
  final PluginAdvancedSearchScheme scheme;

  @override
  State<PluginAdvancedSearchDialog> createState() =>
      _PluginAdvancedSearchDialogState();
}

class _PluginAdvancedSearchDialogState
    extends State<PluginAdvancedSearchDialog> {
  late final Map<String, dynamic> _values;

  @override
  void initState() {
    super.initState();
    _values = Map<String, dynamic>.from(widget.scheme.values);
    _values['sortBy'] ??= widget.initialSort;
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.scheme.fields;
    final dateFields = fields
        .where(
          (field) =>
              field['optionLayout'] == 'menu' &&
              (field['key'] == 'y' || field['key'] == 'm'),
        )
        .toList();
    final otherFields = fields.where((field) => !dateFields.contains(field));
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dateFields.isNotEmpty) _buildDateFields(context, dateFields),
        for (final field in otherFields) _buildField(context, field),
      ],
    );
    return TaskDialog(
      title: dateFields.isNotEmpty && otherFields.isEmpty
          ? t.search.jmDateFilter
          : t.search.advancedSearchOptions,
      content: content,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        FilledButton(onPressed: _apply, child: Text(t.common.apply)),
      ],
    );
  }

  void _apply() {
    final nextExtern = <String, dynamic>{};
    for (final field in widget.scheme.fields) {
      final key = field['key']?.toString() ?? '';
      final kind = field['kind']?.toString() ?? '';
      if (key.isEmpty) continue;
      if (kind == 'choice') {
        final parent = field['requiresOption'];
        nextExtern[key] =
            parent is String && (_values[parent]?.toString() ?? '').isEmpty
            ? ''
            : _values[key];
      } else if (kind == 'multiChoice') {
        nextExtern[key] = _multiValues(key);
      } else if (kind == 'switch') {
        nextExtern[key] = _switchValue(key);
      } else if (kind == 'text') {
        nextExtern[key] = _textValue(key);
      }
    }
    Navigator.of(context).pop(nextExtern);
  }

  Widget _buildDateFields(
    BuildContext context,
    List<Map<String, dynamic>> fields,
  ) {
    return LayoutBuilder(
      builder: (context, limits) {
        final wheels = [for (final field in fields) _buildDateWheel(field)];
        final stack =
            limits.maxWidth < MediaQuery.textScalerOf(context).scale(170);
        return stack
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: wheels,
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [for (final wheel in wheels) Expanded(child: wheel)],
              );
      },
    );
  }

  Widget _buildDateWheel(Map<String, dynamic> field) {
    final key = field['key'] as String;
    final label = field['label']?.toString() ?? '';
    final parent = field['requiresOption'];
    final enabled =
        parent is! String || (_values[parent]?.toString() ?? '').isNotEmpty;
    final choices = {
      for (final row
          in (field['options'] as List? ?? const []).whereType<Map>())
        row['value']?.toString() ?? '': row,
    };
    if (choices.isEmpty) return const SizedBox.shrink();
    return Semantics(
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : .45,
        child: YearFilterPicker(
          key: ValueKey('advanced-search.$key'),
          keyPrefix: 'advanced-search.$key',
          label: label,
          options: {
            for (final option in choices.entries)
              option.key: option.value['label']?.toString() ?? option.key,
          },
          selected: enabled ? _values[key]?.toString() ?? '' : '',
          enabled: enabled,
          showAllShortcut: false,
          onSelected: (value) => setState(() {
            _values[key] = choices[value]?['value'];
            if (value.isEmpty) {
              for (final dependent in widget.scheme.fields) {
                if (dependent['requiresOption'] == key) {
                  _values[dependent['key']] = '';
                }
              }
            }
          }),
        ),
      ),
    );
  }

  Widget _buildField(BuildContext context, Map<String, dynamic> field) {
    final key = field['key']?.toString() ?? '';
    final label = field['label']?.toString() ?? key;
    final kind = field['kind']?.toString() ?? 'choice';
    if (key.isEmpty) {
      return const SizedBox.shrink();
    }

    if (kind == 'switch') {
      final current = _switchValue(key);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: BreezeSwitchListTile(
          SwitchListTile.adaptive(
            value: current,
            title: Text(label),
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              setState(() {
                _values[key] = value;
              });
            },
          ),
        ),
      );
    }

    if (kind == 'text') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          initialValue: _textValue(key),
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (value) {
            _values[key] = value;
          },
        ),
      );
    }

    final options = ((field['options'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (options.isEmpty) {
      return const SizedBox.shrink();
    }
    if (kind == 'multiChoice') {
      final selected = _multiValues(key);
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: options.map((option) {
                final value = option['value']?.toString() ?? '';
                return FilterChip(
                  label: Text(option['label']?.toString() ?? value),
                  selected: selected.contains(value),
                  onSelected: (enabled) => setState(() {
                    final next = selected.toSet();
                    if (enabled) {
                      next.add(value);
                    } else {
                      next.remove(value);
                    }
                    _values[key] = next.toList();
                  }),
                );
              }).toList(),
            ),
          ],
        ),
      );
    }

    if (kind != 'choice') {
      return const SizedBox.shrink();
    }

    final current = _values[key]?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final value = option['value']?.toString() ?? '';
              final text = option['label']?.toString() ?? value;
              return ChoiceChip(
                showCheckmark: false,
                label: Text(text),
                selected: current == value,
                onSelected: (selected) {
                  if (!selected) {
                    return;
                  }
                  setState(() {
                    _values[key] = option['value'];
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  List<String> _multiValues(String key) {
    final value = _values[key];
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    if (value is Map) {
      return value.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const <String>[];
  }

  bool _switchValue(String key) {
    final value = _values[key];
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final text = value?.toString().toLowerCase();
    return text == 'true' || text == '1';
  }

  String _textValue(String key) {
    final value = _values[key];
    return value == null ? '' : value.toString();
  }
}
