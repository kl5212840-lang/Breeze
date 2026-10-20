import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart' hide SearchBar;
import 'package:zephyr/config/global/global_setting.dart';
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
    HistoryWidget.cancelPendingKeywordSync();
    onSearch(context, trimmed, aggregateMode: false);
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空搜索历史？'),
        content: const Text('搜索历史由所有漫画来源共用。清空后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    context.read<GlobalSettingCubit>().updateState(
      (current) => current.copyWith(searchHistory: []),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<GlobalSettingCubit>().state.searchHistory;
    final textTheme = Theme.of(context).textTheme;
    final chipMaxWidth = MediaQuery.sizeOf(context).width - 32;
    return Column(
      children: [
        const SearchBar(aggregateMode: false),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                children: [
                  Text(
                    '搜索历史 · 所有来源',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (history.isNotEmpty)
                    IconButton(
                      tooltip: '清空所有来源的搜索历史',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => _confirmClearHistory(context),
                    ),
                ],
              ),
              if (history.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '暂无记录',
                    style: textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final keyword in history.take(20))
                        Tooltip(
                          message: keyword,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: chipMaxWidth),
                            child: ActionChip(
                              label: Text(
                                keyword,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onPressed: () => _submit(context, keyword),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 28),
              Text(
                '热门搜索',
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
                        const Text('热搜暂不可用'),
                        TextButton(
                          onPressed: () =>
                              context.read<PluginFunctionCubit>().load(
                                from: source,
                                functionId: hotSearchFunction,
                              ),
                          child: const Text('重试'),
                        ),
                      ],
                    );
                  }
                  final items = asJsonList(state.data['items']);
                  if (items.isEmpty) return const Text('暂无热搜');
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
