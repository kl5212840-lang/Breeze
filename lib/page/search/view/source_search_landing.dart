import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart' hide SearchBar;
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/plugin_function/cubit/plugin_function_cubit.dart';
import 'package:zephyr/page/search/method/on_search.dart';
import 'package:zephyr/page/search/widget/history.dart';
import 'package:zephyr/page/search/widget/search_bar.dart';
import 'package:zephyr/util/json/json_value.dart';

class SourceSearchLanding extends StatelessWidget {
  const SourceSearchLanding({
    super.key,
    required this.source,
    required this.hotSearchFunction,
  });

  final String source;
  final String hotSearchFunction;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          PluginFunctionCubit()
            ..load(from: source, functionId: hotSearchFunction),
      child: _SourceSearchLandingBody(
        source: source,
        hotSearchFunction: hotSearchFunction,
      ),
    );
  }
}

class _SourceSearchLandingBody extends StatelessWidget {
  const _SourceSearchLandingBody({
    required this.source,
    required this.hotSearchFunction,
  });

  final String source;
  final String hotSearchFunction;

  void _submit(BuildContext context, String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    onSearch(context, trimmed, aggregateMode: false);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final chipMaxWidth = MediaQuery.sizeOf(context).width - 32;
    return Column(
      children: [
        const SearchBar(aggregateMode: false),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              HistoryWidget(
                aggregateMode: false,
                source: source,
                embedded: true,
              ),
              const SizedBox(height: 28),
              Text(
                t.oldHome.hotSearch,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              BlocBuilder<PluginFunctionCubit, PluginFunctionState>(
                builder: (context, state) {
                  if (state.loading) {
                    return const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (state.error.isNotEmpty) {
                    return Row(
                      children: [
                        Expanded(child: Text(t.common.loadingFailed)),
                        TextButton(
                          onPressed: () =>
                              context.read<PluginFunctionCubit>().load(
                                from: source,
                                functionId: hotSearchFunction,
                              ),
                          child: Text(t.common.retry),
                        ),
                      ],
                    );
                  }
                  final items = asJsonList(state.data['items']);
                  if (items.isEmpty) return Text(t.oldHome.noHotSearch);
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in items)
                        if (asJsonMap(
                              item,
                            )['label']?.toString().trim().isNotEmpty ==
                            true)
                          Tooltip(
                            message: asJsonMap(item)['label'].toString(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: chipMaxWidth,
                              ),
                              child: ActionChip(
                                label: Text(
                                  asJsonMap(item)['label'].toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onPressed: () => _submit(
                                  context,
                                  asJsonMap(item)['label'].toString(),
                                ),
                              ),
                            ),
                          ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
