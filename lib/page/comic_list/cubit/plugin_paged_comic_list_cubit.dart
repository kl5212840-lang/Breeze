import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/network/http/plugin/unified_plugin_envelope.dart';
import 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_state.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/util/json/json_dispose.dart';
import 'package:zephyr/util/json/json_value.dart';
import 'package:zephyr/widgets/comic_entry/models/models.dart';

typedef PluginPageCoreBuilder = Map<String, dynamic> Function(int page);
typedef PluginPageExternBuilder = Map<String, dynamic> Function(int page);
typedef PluginPageRequest =
    Future<Map<String, dynamic>> Function(
      String pluginId,
      String fnPath,
      Map<String, dynamic> core,
      Map<String, dynamic> extern,
    );

Future<Map<String, dynamic>> _requestPluginPage(
  String pluginId,
  String fnPath,
  Map<String, dynamic> core,
  Map<String, dynamic> extern,
) => callUnifiedComicPlugin(
  pluginId: pluginId,
  fnPath: fnPath,
  core: core,
  extern: extern,
);

Map<String, dynamic> _sanitizePluginItemMap(dynamic item) {
  return asJsonMap(replaceNestedNullList(asJsonMap(item)));
}

bool pluginListPageHasReachedMax({
  required Map<String, dynamic> data,
  required int page,
  required bool isEmpty,
}) {
  final paging = asJsonMap(data['paging']);
  final pageCount = (paging['pages'] as num?)?.toInt() ?? 0;
  return data['hasReachedMax'] == true ||
      paging['hasReachedMax'] == true ||
      (pageCount > 0 && page >= pageCount) ||
      isEmpty;
}

class PluginPagedComicListCubit extends Cubit<PluginPagedComicListState> {
  PluginPagedComicListCubit({
    required this.pluginId,
    required this.fnPath,
    required this.coreBuilder,
    required this.externBuilder,
    PluginPageRequest? requestPage,
  }) : _requestPage = requestPage ?? _requestPluginPage,
       super(const PluginPagedComicListState());

  final String pluginId;
  final String fnPath;
  final PluginPageCoreBuilder coreBuilder;
  final PluginPageExternBuilder externBuilder;
  final PluginPageRequest _requestPage;
  int _requestEpoch = 0;

  Future<void> loadInitial() async {
    final epoch = ++_requestEpoch;
    _safeEmit(
      state.copyWith(
        status: PluginPagedComicListStatus.initial,
        list: const <UnifiedComicListItem>[],
        hasReachedMax: false,
        page: 1,
        result: '',
      ),
    );
    await _fetchPage(page: 1, append: false, epoch: epoch);
  }

  Future<void> loadMore() async {
    if (state.hasReachedMax ||
        state.status != PluginPagedComicListStatus.success) {
      return;
    }

    _safeEmit(state.copyWith(status: PluginPagedComicListStatus.loadingMore));
    await _fetchPage(page: state.page + 1, append: true, epoch: _requestEpoch);
  }

  Future<void> retryLoadMore() async {
    if (state.status != PluginPagedComicListStatus.loadingMoreFailure ||
        state.hasReachedMax) {
      return;
    }
    _safeEmit(state.copyWith(status: PluginPagedComicListStatus.loadingMore));
    await _fetchPage(page: state.page + 1, append: true, epoch: _requestEpoch);
  }

  Future<void> _fetchPage({
    required int page,
    required bool append,
    required int epoch,
  }) async {
    final currentList = append ? state.list : const <UnifiedComicListItem>[];
    final resolvedFnPath = fnPath.trim();

    try {
      if (resolvedFnPath.isEmpty) {
        throw StateError('插件列表请求缺少 fnPath: pluginId=$pluginId');
      }
      final pluginResponse = await _requestPage(
        pluginId,
        resolvedFnPath,
        coreBuilder(page),
        externBuilder(page),
      );
      if (isClosed || epoch != _requestEpoch) return;
      final envelope = UnifiedPluginEnvelope.fromMap(pluginResponse);
      final data = asJsonMap(envelope.data);
      final source = envelope.source.trim().isNotEmpty
          ? envelope.source.trim()
          : pluginId;
      final items = asJsonList(
        data['items'],
      ).map(_sanitizePluginItemMap).toList();
      final raw = replaceNestedNullList(asJsonMap(data['raw']));
      final listLikeKeys = ['content', 'list'];

      List<UnifiedComicListItem> nextItems = items
          .map((item) => unifiedComicFromPluginListMap(item, source: source))
          .toList();
      if (nextItems.isEmpty) {
        for (final key in listLikeKeys) {
          final rawList = asJsonList(
            raw[key],
          ).map(_sanitizePluginItemMap).toList();
          if (rawList.isNotEmpty) {
            nextItems = rawList
                .map(
                  (item) => unifiedComicFromPluginListMap(item, source: source),
                )
                .toList();
            break;
          }
        }
      }

      final mergedList = [...currentList, ...nextItems];
      final hasReachedMax = pluginListPageHasReachedMax(
        data: data,
        page: page,
        isEmpty: nextItems.isEmpty,
      );

      _safeEmit(
        state.copyWith(
          status: PluginPagedComicListStatus.success,
          list: mergedList,
          hasReachedMax: hasReachedMax,
          page: page,
          result: page.toString(),
        ),
      );
    } catch (e, stackTrace) {
      if (isClosed || epoch != _requestEpoch) return;
      logger.e(e, stackTrace: stackTrace);

      _safeEmit(
        state.copyWith(
          status: currentList.isNotEmpty
              ? PluginPagedComicListStatus.loadingMoreFailure
              : PluginPagedComicListStatus.failure,
          list: currentList,
          result: normalizeSearchErrorMessage(e),
        ),
      );
    }
  }

  void _safeEmit(PluginPagedComicListState nextState) {
    if (isClosed) {
      return;
    }
    emit(nextState);
  }
}
