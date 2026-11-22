import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/page/search/widget/search_toolbar_scope.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/main.dart' show eventBus;
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart'
    show normalizePluginId;
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/method/on_search.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/search/widget/source_select_dialog.dart';
import 'package:zephyr/page/search_result/view/source_search_capabilities.dart';
import 'package:zephyr/page/search_result/view/source_search_scope_control.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/util/event/event.dart' show NeedLogin;
import 'dart:convert';
import 'package:zephyr/page/search/widget/advanced_search_dialog.dart';
import 'package:zephyr/widgets/toast.dart';

class SearchBar extends StatefulWidget {
  const SearchBar({super.key, this.aggregateMode = true});

  final bool aggregateMode;

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  final _draft = ValueNotifier('');
  SearchCubit? _searchCubit;
  String? _schemeKey;
  Future<PluginAdvancedSearchScheme?>? _schemeFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cubit = context.read<SearchCubit>();
    if (identical(cubit, _searchCubit)) return;
    _searchCubit?.queryRevision.removeListener(_restoreDraft);
    _searchCubit = cubit;
    _restoreDraft();
    cubit.queryRevision.addListener(_restoreDraft);
  }

  void _restoreDraft() {
    _draft.value = _searchCubit?.state.searchKeyword ?? '';
  }

  @override
  void dispose() {
    _searchCubit?.queryRevision.removeListener(_restoreDraft);
    _draft.dispose();
    super.dispose();
  }

  Future<PluginAdvancedSearchScheme?> _schemeFor(SearchStates state) {
    final key = jsonEncode([
      state.from,
      state.pluginExtern,
      pluginSessionWriteFence.generation(normalizePluginId(state.from)),
    ]);
    if (_schemeKey != key) {
      _schemeKey = key;
      _schemeFuture = _loadAdvancedSearchScheme(state.from, state.pluginExtern);
    }
    return _schemeFuture!;
  }

  bool _openingAdvancedSearch = false;

  void _submit(String keyword) {
    if (ModalRoute.of(context)?.isCurrent == false) return;
    onSearch(context, keyword, aggregateMode: widget.aggregateMode);
  }

  bool _useCompactSubmit(BuildContext context, double width) {
    final extent = CollectionToolbarMetrics.actionExtentOf(context);
    final painter = TextPainter(
      text: TextSpan(
        text: t.common.search,
        style: Theme.of(context).textTheme.labelLarge,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final labelWidth = (painter.width + 16).clamp(extent, double.infinity);
    painter.dispose();
    return width -
            extent -
            2 * CollectionToolbarMetrics.searchControlGap -
            labelWidth <
        160;
  }

  List<({String pluginId, String title})> _sourceOptions(BuildContext context) {
    final pluginStates = context.read<PluginRegistryCubit>().state;
    final states = PluginRegistryService.I.sortPlugins(
      pluginStates.values.where((state) => state.isEnabled && !state.isDeleted),
    );
    return states.map((state) {
      final info = PluginRegistryService.I.getCachedPluginInfo(state.uuid);
      final title = info?['name']?.toString().trim().isNotEmpty == true
          ? info!['name'].toString().trim()
          : state.uuid;
      return (pluginId: state.uuid, title: title);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final searchCubit = context.read<SearchCubit>();
    return BlocBuilder<SearchCubit, SearchStates>(
      builder: (context, state) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: CollectionToolbarMetrics.contentPaddingOf(
              context,
              top: 8,
              bottom: 8,
            ),
            child: SearchToolbarScope(
              extent: SearchToolbarScope.fieldExtent(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) => Row(
                      key: const ValueKey('comic-search.input-row'),
                      spacing: CollectionToolbarMetrics.searchControlGap,
                      children: [
                        SourceChromeIconButton(
                          key: const ValueKey('comic-search.back'),
                          tooltip: t.common.back,
                          icon: Icons.arrow_back_ios_new_rounded,
                          symbol: 'chevron.left',
                          bare: true,
                          onPressed: () => context.maybePop(),
                        ),
                        Expanded(
                          child: ValueListenableBuilder<int>(
                            valueListenable: searchCubit.queryRevision,
                            builder: (context, revision, _) => SearchQueryField(
                              query: searchCubit.state.searchKeyword,
                              queryRevision: revision,
                              autoExpand: true,
                              inline: true,
                              hintText: t.search.searchHint,
                              semanticLabel: t.search.title,
                              onChanged: (value) => _draft.value = value,
                              onSubmitted: _submit,
                            ),
                          ),
                        ),
                        ValueListenableBuilder<String>(
                          valueListenable: _draft,
                          builder: (context, value, _) {
                            final onPressed = value.trim().isEmpty
                                ? null
                                : () => _submit(value);
                            const key = ValueKey('comic-search.submit');
                            if (_useCompactSubmit(
                              context,
                              constraints.maxWidth,
                            )) {
                              return SourceChromeIconButton(
                                key: key,
                                tooltip: t.common.search,
                                icon: Icons.search_rounded,
                                symbol: 'magnifyingglass',
                                bare: true,
                                onPressed: onPressed,
                              );
                            }
                            final extent =
                                CollectionToolbarMetrics.actionExtentOf(
                                  context,
                                );
                            return TextButton(
                              key: key,
                              style: TextButton.styleFrom(
                                minimumSize: Size.square(extent),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              onPressed: onPressed,
                              child: Text(t.common.search),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    key: const ValueKey('comic-search.options-row'),
                    spacing: CollectionToolbarMetrics.searchControlGap,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: SourceSearchScopeControl(
                            aggregate: widget.aggregateMode,
                          ),
                        ),
                      ),
                      if (widget.aggregateMode)
                        SourceChromeIconButton(
                          tooltip: t.search.sourceFilter,
                          icon: Icons.layers_outlined,
                          symbol: 'square.stack.3d.up',
                          bare: true,
                          onPressed: () async {
                            final selected = await showSourceSelectDialog(
                              context,
                              initial: searchCubit.state.aggregateSources,
                              sourceOptions: _sourceOptions(context),
                            );
                            if (selected != null && mounted) {
                              searchCubit.update(
                                searchCubit.state.copyWith(
                                  aggregateSources: Map<String, bool>.from(
                                    selected,
                                  ),
                                ),
                              );
                            }
                          },
                        )
                      else if (state.from.trim().isNotEmpty)
                        FutureBuilder<PluginAdvancedSearchScheme?>(
                          key: ValueKey(
                            jsonEncode([state.from, state.pluginExtern]),
                          ),
                          future: _schemeFor(state),
                          builder: (context, snapshot) =>
                              snapshot.connectionState ==
                                      ConnectionState.done &&
                                  snapshot.data != null
                              ? SourceChromeIconButton(
                                  tooltip: t.search.advancedSearchOptions,
                                  icon: Icons.tune_rounded,
                                  symbol: 'slider.horizontal.3',
                                  bare: true,
                                  onPressed: () =>
                                      _showSingleSourceAdvancedSearch(context),
                                )
                              : snapshot.connectionState ==
                                    ConnectionState.waiting
                              ? SizedBox(
                                  width:
                                      CollectionToolbarMetrics.actionExtentOf(
                                        context,
                                      ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      if (!widget.aggregateMode && state.from.trim().isNotEmpty)
                        SourceMoreButton(source: state.from),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSingleSourceAdvancedSearch(BuildContext context) async {
    if (_openingAdvancedSearch) return;
    final searchCubit = context.read<SearchCubit>();
    final state = searchCubit.state;
    final source = normalizePluginId(state.from);

    if (source.isEmpty) {
      showWarningToast(t.search.advancedSearchNotSupported);
      return;
    }
    final route = ModalRoute.of(context);
    final owner = pluginSessionWriteFence.generation(source);
    final revision = searchCubit.queryRevision.value;
    bool ownsQuery() =>
        mounted &&
        searchCubit.state.from == state.from &&
        searchCubit.state.searchKeyword == state.searchKeyword &&
        searchCubit.queryRevision.value == revision &&
        pluginSessionWriteFence.generation(source) == owner &&
        !pluginSessionWriteFence.isChanging(source);
    if (!ownsQuery()) return;
    _openingAdvancedSearch = true;
    try {
      final scheme = await _schemeFor(state);
      if (!context.mounted || !ownsQuery() || route?.isCurrent == false) return;
      if (scheme == null) {
        showWarningToast(t.search.advancedSearchNotSupported);
        return;
      }
      final current = searchCubit.state;
      _mergeExternValues(scheme.fields, current.pluginExtern, scheme.values);
      final changes = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => PluginAdvancedSearchDialog(
          initialSort: current.sortBy,
          scheme: scheme,
        ),
      );
      if (changes == null || !ownsQuery() || route?.isCurrent == false) return;
      final latest = searchCubit.state;
      searchCubit.update(
        latest.copyWith(
          sortBy: int.tryParse('${changes['sortBy']}') ?? latest.sortBy,
          pluginExtern: {...latest.pluginExtern, ...changes},
        ),
      );
    } on PluginLoginRequiredException catch (error) {
      if (context.mounted &&
          ownsQuery() &&
          ModalRoute.of(context)?.isCurrent != false) {
        eventBus.fire(
          NeedLogin(
            from: error.payload.pluginId,
            message: error.payload.message,
          ),
        );
      }
    } finally {
      _openingAdvancedSearch = false;
    }
  }

  Future<PluginAdvancedSearchScheme?> _loadAdvancedSearchScheme(
    String source,
    Map<String, dynamic> extern,
  ) async {
    try {
      final response = await callUnifiedComicPlugin(
        pluginId: source,
        fnPath: 'getAdvancedSearchScheme',
        core: const <String, dynamic>{},
        extern: keywordSearchRequestExtern(source, extern),
        notifyUnauthorized: false,
      );
      final scheme = Map<String, dynamic>.from(
        (response['scheme'] as Map?) ?? const <String, dynamic>{},
      );
      final data = Map<String, dynamic>.from(
        (response['data'] as Map?) ?? const <String, dynamic>{},
      );
      final fields = uniqueAdvancedFields(
        source,
        ((scheme['fields'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
      );

      if (fields.isEmpty) {
        return null;
      }

      final values = Map<String, dynamic>.from(
        (data['values'] as Map?) ?? const <String, dynamic>{},
      );
      _mergeExternValues(fields, extern, values);
      return PluginAdvancedSearchScheme(
        source: response['source']?.toString() ?? source,
        fields: fields,
        values: values,
      );
    } on PluginLoginRequiredException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  void _mergeExternValues(
    List<Map<String, dynamic>> fields,
    Map<String, dynamic> extern,
    Map<String, dynamic> values,
  ) {
    for (final field in fields) {
      final key = field['key']?.toString() ?? '';
      if (key.isEmpty || !extern.containsKey(key)) {
        continue;
      }
      final externValue = extern[key];
      if (externValue is Map) {
        values[key] = externValue.entries
            .where((entry) => entry.value == true)
            .map((entry) => entry.key.toString())
            .toList();
      } else {
        values[key] = externValue;
      }
    }
  }
}
