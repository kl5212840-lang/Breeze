import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search_result/view/source_search_capabilities.dart';
import 'package:zephyr/util/text/chinese_convert.dart';

class SourceSearchScopeControl extends StatelessWidget {
  const SourceSearchScopeControl({
    super.key,
    required this.options,
    this.onChanged,
  });
  final Map<String, String> options;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    final state = context.watch<SearchCubit>().state;
    final requested = state.pluginExtern['q_type']?.toString() ?? '';
    final selected = options.containsKey(requested)
        ? requested
        : options.keys.first;
    return PopupMenuButton<String>(
      tooltip: t.comicList.scope,
      initialValue: selected,
      onSelected: (value) {
        final cubit = context.read<SearchCubit>();
        final current = cubit.state;
        if ((current.pluginExtern['q_type']?.toString() ?? '') == value) return;
        cubit.update(
          current.copyWith(
            pluginExtern: {...current.pluginExtern, 'q_type': value},
          ),
        );
        onChanged?.call();
      },
      itemBuilder: (_) => [
        for (final entry in options.entries)
          CheckedPopupMenuItem(
            value: entry.key,
            checked: selected == entry.key,
            child: Text(convertChineseForDisplay(entry.value)),
          ),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, maxWidth: 180),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '${t.comicList.scope} · ${convertChineseForDisplay(options[selected] ?? options.values.first)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// On the landing page the choice only edits the draft. Results trigger a
/// new first-page request through their existing debounced search workflow.
class SourceSearchScopeBar extends StatelessWidget {
  const SourceSearchScopeBar({super.key});

  @override
  Widget build(BuildContext context) {
    final source = context.watch<SearchCubit>().state.from;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: sourceAdvancedFields(source),
      builder: (context, snapshot) {
        final options = sourceSearchScopeOptions(snapshot.data ?? const []);
        if (options.isEmpty) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 4),
            child: SourceSearchScopeControl(options: options),
          ),
        );
      },
    );
  }
}
