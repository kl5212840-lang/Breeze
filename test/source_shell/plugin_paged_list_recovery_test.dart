import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_cubit.dart';
import 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_state.dart';

Map<String, dynamic> _page(String id, int page) => {
  'source': 'test',
  'data': {
    'paging': {'page': page, 'pages': 3},
    'items': [
      {
        'source': 'test',
        'id': id,
        'title': id,
        'subtitle': '',
        'finished': false,
        'likesCount': 0,
        'viewsCount': 0,
        'updatedAt': '',
        'cover': {'id': id, 'url': '', 'path': '', 'extern': {}},
        'metadata': <dynamic>[],
        'raw': <String, dynamic>{},
        'extern': <String, dynamic>{},
      },
    ],
  },
};

void main() {
  test(
    'failed pagination waits for explicit retry and repeats only that page',
    () async {
      final requestedPages = <int>[];
      var failSecondPage = true;
      final cubit = PluginPagedComicListCubit(
        pluginId: 'test',
        fnPath: 'getList',
        coreBuilder: (page) => {'page': page},
        externBuilder: (_) => {},
        requestPage: (_, _, core, _) async {
          final page = core['page'] as int;
          requestedPages.add(page);
          if (page == 2 && failSecondPage) {
            failSecondPage = false;
            throw StateError('temporary network failure');
          }
          return _page('comic-$page', page);
        },
      );
      addTearDown(cubit.close);

      await cubit.loadInitial();
      await cubit.loadMore();
      expect(cubit.state.status, PluginPagedComicListStatus.loadingMoreFailure);
      await cubit.loadMore();
      expect(requestedPages, [1, 2]);

      await cubit.retryLoadMore();
      expect(requestedPages, [1, 2, 2]);
      expect(cubit.state.list.map((item) => item.id), ['comic-1', 'comic-2']);
    },
  );

  test('refresh ignores an older page response', () async {
    final pending = <Completer<Map<String, dynamic>>>[];
    final cubit = PluginPagedComicListCubit(
      pluginId: 'test',
      fnPath: 'getList',
      coreBuilder: (page) => {'page': page},
      externBuilder: (_) => {},
      requestPage: (_, _, _, _) {
        final request = Completer<Map<String, dynamic>>();
        pending.add(request);
        return request.future;
      },
    );
    addTearDown(cubit.close);

    final initial = cubit.loadInitial();
    pending[0].complete(_page('old-first', 1));
    await initial;
    final olderNextPage = cubit.loadMore();
    final refresh = cubit.loadInitial();
    pending[2].complete(_page('new-first', 1));
    await refresh;
    pending[1].complete(_page('old-second', 2));
    await olderNextPage;

    expect(cubit.state.status, PluginPagedComicListStatus.success);
    expect(cubit.state.list.map((item) => item.id), ['new-first']);
  });
}
