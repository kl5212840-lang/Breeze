import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_cubit.dart';
import 'package:zephyr/page/comic_list/cubit/plugin_paged_comic_list_state.dart';

Map<String, dynamic> _page(String id) => {
  'source': 'refresh-contract',
  'data': {
    'paging': {'page': 1, 'pages': 2},
    'items': [
      if (id.isNotEmpty)
        {
          'source': 'refresh-contract',
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
    'refresh waits for this request, keeps old data and coalesces duplicates',
    () async {
      final gate = Completer<Map<String, dynamic>>();
      final requests = <Map<String, dynamic>>[];
      final cubit = PluginPagedComicListCubit(
        pluginId: 'refresh-contract',
        fnPath: 'vendor.list',
        coreBuilder: (page) => {'page': page, 'folder': 'kept'},
        externBuilder: (_) => {'sort': 'vendor-order'},
        requestPage: (_, _, core, extern) async {
          requests.add({...core, ...extern});
          return requests.length == 1 ? _page('old') : gate.future;
        },
      );
      addTearDown(cubit.close);
      await cubit.loadInitial();
      var finished = false;
      final refresh = cubit.refresh().then((value) {
        finished = true;
        return value;
      });
      final duplicate = cubit.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(finished, isFalse);
      expect(cubit.state.list.single.id, 'old');
      expect(cubit.state.status, PluginPagedComicListStatus.success);
      expect(requests, [
        {'page': 1, 'folder': 'kept', 'sort': 'vendor-order'},
        {'page': 1, 'folder': 'kept', 'sort': 'vendor-order'},
      ]);
      gate.complete(_page('new'));
      expect(await refresh, isTrue);
      expect(await duplicate, isTrue);
      expect(cubit.state.list.single.id, 'new');
    },
  );

  test(
    'failed refresh retains old range, exposes retry and accepts fresh empty',
    () async {
      var fail = false;
      var empty = false;
      final cubit = PluginPagedComicListCubit(
        pluginId: 'refresh-contract',
        fnPath: 'vendor.list',
        coreBuilder: (page) => {'page': page},
        externBuilder: (_) => {},
        requestPage: (_, _, _, _) async {
          if (fail) throw StateError('offline fixture');
          return _page(empty ? '' : 'retained');
        },
      );
      addTearDown(cubit.close);
      await cubit.loadInitial();
      fail = true;
      expect(await cubit.refresh(), isFalse);
      expect(cubit.state.list.single.id, 'retained');
      expect(cubit.refreshError, isNotEmpty);
      fail = false;
      empty = true;
      expect(await cubit.refresh(), isTrue);
      expect(cubit.state.list, isEmpty);
      expect(cubit.state.hasReachedMax, isTrue);
      expect(cubit.refreshError, isNull);
    },
  );

  test(
    'refresh distinguishes invalid replies from an explicit empty page',
    () async {
      var response = _page('retained');
      final cubit = PluginPagedComicListCubit(
        pluginId: 'refresh-contract',
        fnPath: 'vendor.list',
        coreBuilder: (page) => {'page': page},
        externBuilder: (_) => const {},
        requestPage: (_, _, _, _) async => response,
      );
      addTearDown(cubit.close);
      await cubit.loadInitial();

      for (final invalid in <Map<String, dynamic>>[
        {'ok': false, ..._page('')},
        {
          'data': {'items': 'temporary upstream error'},
        },
        {
          'data': {
            'items': [null],
          },
        },
        {
          'data': {
            'paging': {'pages': 2},
          },
        },
      ]) {
        response = invalid;
        expect(await cubit.refresh(), isFalse);
        expect(cubit.state.list.single.id, 'retained');
        expect(cubit.refreshError, isNotNull);
      }

      final legacy = _page('legacy')['data']['items'];
      response = {
        'data': {
          'raw': {'content': legacy},
        },
      };
      expect(await cubit.refresh(), isTrue);
      expect(cubit.state.list.single.id, 'legacy');
      response = _page('');
      expect(await cubit.refresh(), isTrue);
      expect(cubit.state.list, isEmpty);
    },
  );

  test(
    'a late old page cannot overwrite the committed refresh range',
    () async {
      final pendingPage = Completer<Map<String, dynamic>>();
      var calls = 0;
      final cubit = PluginPagedComicListCubit(
        pluginId: 'refresh-contract',
        fnPath: 'vendor.list',
        coreBuilder: (page) => {'page': page},
        externBuilder: (_) => {},
        requestPage: (_, _, core, _) async {
          calls++;
          return core['page'] == 2
              ? pendingPage.future
              : _page(calls == 1 ? 'old' : 'fresh');
        },
      );
      addTearDown(cubit.close);
      await cubit.loadInitial();
      final oldPage = cubit.loadMore();
      expect(await cubit.refresh(), isTrue);
      pendingPage.complete(_page('late'));
      await oldPage;
      expect(cubit.state.list.single.id, 'fresh');
      expect(cubit.state.page, 1);
    },
  );
}
