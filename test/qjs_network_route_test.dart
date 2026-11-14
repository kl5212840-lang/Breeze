import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/comic_read/method/get_plugin_read_snapshot.dart';
import 'package:zephyr/page/comic_read/bloc/page_bloc.dart';
import 'package:zephyr/page/search_result/bloc/search_bloc.dart';
import 'package:zephyr/page/search_result/method/get_plugin_result.dart';
import 'package:zephyr/page/search_result/models/bloc_state.dart';
import 'package:zephyr/page/search_result/view/source_search_capabilities.dart';
import 'package:zephyr/page/search_aggregate/aggregate_video_search.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cbor/simple.dart' as cbor;
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/util/event/event.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/http/plugin/qjs_download_runtime.dart';
import 'package:zephyr/network/http/plugin/qjs_network_route.dart';
import 'package:zephyr/network/http/plugin/unified_comic_plugin.dart';
import 'package:zephyr/network/source_network_policy.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/image_recovery.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/src/rust/qjs.dart';
import 'package:zephyr/type/enum.dart';

import 'test_helper.dart';

const _copy = 'b28da416-f2d4-4208-a85e-8b4c7c648e48';
const _omo = 'ccc2fe17-c0a8-4fd8-a596-835772686404';

PageEvent _readChapter(String source, String chapter) => PageEvent(
  'work',
  1,
  chapter,
  chapter,
  '',
  chapter,
  const {},
  source,
  ComicEntryType.normal,
);

Uint8List _readReply(String chapter, String name, {bool empty = false}) =>
    Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'data': {
            'comic': {'id': 'work'},
            'chapter': {
              'id': chapter,
              'name': name,
              'order': 1,
              'pages': [
                if (!empty)
                  {
                    'path': '$name.jpg',
                    'url': 'https://fixture.invalid/$name.jpg',
                  },
              ],
            },
          },
        }),
      ),
    );

class _Call {
  _Call(
    this.runtime,
    this.group,
    this.function,
    this.once,
    this.url, [
    this.args = '',
  ]);
  final String args;
  final String runtime, group, function;
  final bool once;
  final String? url;
}

/// Replaces the full native boundary; these tests never execute JS or do I/O.
class _RecordingApi extends RustLibApi {
  final builds = <QjsRuntimeBuildRequest>[];
  Future<Uint8List> Function(String runtime, String function)? invoke;
  Future<void> Function(String runtime)? beforeRuntimeReady;
  final cancellations = <String>[];
  final cancelledGroups = <String>[];
  final calls = <_Call>[];
  final runtimes = <String, QjsRuntimeBuildRequest>{};

  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async {
    await beforeRuntimeReady?.call(name);
    return runtimes.containsKey(name);
  }

  @override
  Future<void> crateApiQjsBuildQjsRuntime({
    required QjsRuntimeBuildRequest request,
  }) async {
    builds.add(request);
    runtimes[request.runtimeName] = request;
  }

  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode(runtimes[runtimeName]?.bundle?.bundleName);

  @override
  Future<bool> crateApiQjsQjsDropRuntime({required String runtimeName}) async =>
      runtimes.remove(runtimeName) != null;

  @override
  Future<Uint8List> crateApiQjsQjsTaskCall({
    required String runtimeName,
    required String taskGroupKey,
    required bool isOnce,
    String? bundleJs,
    String? bundleUrl,
    required String fnPath,
    required String argsJson,
  }) async {
    calls.add(
      _Call(runtimeName, taskGroupKey, fnPath, isOnce, bundleUrl, argsJson),
    );
    if (invoke != null) return invoke!(runtimeName, fnPath);
    return Uint8List.fromList(utf8.encode('{"ok":true}'));
  }

  @override
  Future<QjsCancelTasksByGroupResult> crateApiQjsQjsCancelTasksByGroup({
    required String runtimeName,
    required String taskGroupKey,
  }) async {
    cancellations.add(runtimeName);
    cancelledGroups.add(taskGroupKey);
    return const QjsCancelTasksByGroupResult(
      cancelled: 0,
      notFound: 1,
      failedRuntimeGroups: [],
    );
  }

  @override
  Future<Uint8List> crateApiQjsQjsFetchImage({
    required String runtimeName,
    required String taskGroupKey,
    required bool isOnce,
    String? bundleJs,
    String? bundleUrl,
    required String fnPath,
    required String argsJson,
  }) async {
    calls.add(
      _Call(runtimeName, taskGroupKey, fnPath, isOnce, bundleUrl, argsJson),
    );
    return Uint8List.fromList(
      cbor.cbor.encode({
        'version': 1,
        'bytes': Uint8List.fromList([0, 128, 255]),
        'statusCode': 200,
        'responseBodyLength': 3,
        'error': null,
      }),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected native API: ${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _RecordingApi api;
  late ProxySettingState global;

  Future<void> seed(String uuid, {bool debug = false, String? debugUrl}) async {
    final now = DateTime.now().toUtc();
    final existing = objectbox.pluginInfoBox
        .getAll()
        .where((row) => row.uuid == uuid)
        .firstOrNull;
    await PluginRegistryService.I.upsert(
      PluginInfo(
        id: existing?.id ?? 0,
        uuid: uuid,
        version: 'test',
        originScript: 'module.exports = {};',
        insertedAt: now,
        updatedAt: now,
        isEnabled: true,
        isDeleted: false,
        lastLoadSuccess: true,
        debug: debug,
        debugUrl: debugUrl,
      ),
    );
  }

  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    api = _RecordingApi();
    RustLib.initMock(api: api);
    await PluginRegistryService.I.init();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    global = const ProxySettingState(
      enabled: true,
      type: ProxyType.http,
      address: '127.0.0.1:18081',
    );
    SourceNetworkPolicies.initialize(() => global);
    api.calls.clear();
    api.builds.clear();
    api.cancelledGroups.clear();
    await seed(_copy);
    await seed(_omo);
  });

  test(
    'search retains only the latest replacement while a request is running',
    () async {
      final first = Completer<Uint8List>();
      final started = Completer<void>();
      var requests = 0;
      Uint8List response() => Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'source': _copy,
            'data': {
              'items': [],
              'paging': {
                'page': 1,
                'pages': 1,
                'total': 0,
                'hasReachedMax': true,
              },
            },
          }),
        ),
      );
      api.invoke = (_, function) async {
        if (function != 'searchComic') {
          return Uint8List.fromList(utf8.encode('{}'));
        }
        requests++;
        if (requests == 1) {
          started.complete();
          return first.future;
        }
        return response();
      };
      final bloc = SearchBloc();
      final successes = <SearchState>[];
      final subscription = bloc.stream.listen((state) {
        if (state.status == SearchStatus.success) successes.add(state);
      });
      addTearDown(() async {
        await subscription.cancel();
        await bloc.close();
        api.invoke = null;
      });
      const original = SearchEvent(
        searchStates: SearchStates(from: _copy, searchKeyword: 'original'),
      );
      bloc.add(original);
      await started.future;
      final originalGroup = api.calls
          .lastWhere((call) => call.function == 'searchComic')
          .group;
      final latest = bloc.stream.firstWhere(
        (state) =>
            state.status == SearchStatus.success &&
            state.searchEvent.searchStates.searchKeyword == 'latest',
      );
      bloc.add(
        original.copyWith(
          searchStates: original.searchStates.copyWith(
            searchKeyword: 'intermediate',
          ),
        ),
      );
      bloc.add(
        original.copyWith(
          searchStates: original.searchStates.copyWith(searchKeyword: 'latest'),
        ),
      );
      // Also simulate scroll callbacks against the old result during the change.
      bloc.add(original.copyWith(status: SearchStatus.loadingMore, page: 2));
      try {
        await latest.timeout(const Duration(seconds: 2));
      } finally {
        first.complete(response());
      }
      expect(api.cancelledGroups, [originalGroup]);
      expect(requests, 2);
      expect(
        successes.map((state) => state.searchEvent.searchStates.searchKeyword),
        ['latest'],
      );
    },
  );

  for (final failOld in [false, true]) {
    test(
      'search replacement survives an old ${failOld ? 'failure' : 'success'} and keeps paging serial',
      () async {
        final gate = Completer<Uint8List>(), started = Completer<void>();
        var calls = 0;
        final loginEvents = <NeedLogin>[];
        final loginSubscription = eventBus.on<NeedLogin>().listen(
          loginEvents.add,
        );
        addTearDown(loginSubscription.cancel);
        final unauthorized = PluginLoginRequiredException(
          const UnauthorizedPayload(pluginId: _copy, message: 'sign in'),
        );
        Uint8List response(int page) => Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'source': _copy,
              'data': {
                'items': [],
                'paging': {
                  'page': page,
                  'pages': 5,
                  'total': 0,
                  'hasReachedMax': false,
                },
              },
            }),
          ),
        );
        api.invoke = (_, function) async {
          if (function != 'searchComic') {
            return Uint8List.fromList(utf8.encode('{}'));
          }
          calls++;
          if (calls == 1) {
            started.complete();
            return gate.future;
          }
          if (calls == 4) throw unauthorized;
          return response(calls == 2 ? 1 : 2);
        };
        final bloc = SearchBloc();
        addTearDown(() async {
          await bloc.close();
          api.invoke = null;
        });
        const old = SearchEvent(
          searchStates: SearchStates(from: _copy, searchKeyword: 'old'),
        );
        final replacement = old.copyWith(
          searchStates: old.searchStates.copyWith(searchKeyword: 'replacement'),
        );
        bloc.add(old);
        await started.future;
        final accepted = bloc.stream.firstWhere(
          (s) => s.status == SearchStatus.success,
        );
        bloc.add(replacement);
        if (failOld) {
          gate.completeError(unauthorized);
        } else {
          gate.complete(response(1));
        }
        expect(
          (await accepted.timeout(
            const Duration(seconds: 2),
          )).searchEvent.searchStates.searchKeyword,
          'replacement',
        );
        final next = replacement.copyWith(
          status: SearchStatus.loadingMore,
          page: 2,
        );
        final paged = bloc.stream.firstWhere(
          (s) => s.status == SearchStatus.success && s.currentPage == 2,
        );
        bloc.add(next);
        bloc.add(next);
        await paged.timeout(const Duration(seconds: 2));
        // Duplicate scroll notification after completion must also be harmless.
        bloc.add(next);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(calls, 3);
        expect(bloc.blocState.pagesCount, 2);
        expect(
          loginEvents,
          isEmpty,
          reason: 'Obsolete requests must not navigate to sign in',
        );

        final failure = bloc.stream.firstWhere(
          (s) => s.status == SearchStatus.failure,
        );
        bloc.add(replacement);
        await failure.timeout(const Duration(seconds: 2));
        await Future<void>.delayed(Duration.zero);
        expect(loginEvents.map((event) => event.from), [_copy]);
      },
    );
  }

  test('search completion after close does not commit a cursor', () async {
    final gate = Completer<Uint8List>(), started = Completer<void>();
    api.invoke = (_, function) async {
      if (function != 'searchComic') {
        return Uint8List.fromList(utf8.encode('{}'));
      }
      started.complete();
      return gate.future;
    };
    final bloc = SearchBloc();
    addTearDown(() => api.invoke = null);
    bloc.add(const SearchEvent(searchStates: SearchStates(from: _copy)));
    await started.future;
    final group = api.calls
        .lastWhere((call) => call.function == 'searchComic')
        .group;
    expect(group, startsWith('page-read-'));
    final closed = bloc.close();
    gate.complete(
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'source': _copy,
            'data': {
              'items': [],
              'paging': {
                'page': 1,
                'pages': 1,
                'total': 0,
                'hasReachedMax': true,
              },
            },
          }),
        ),
      ),
    );
    await closed;
    expect(bloc.blocState.pagesCount, 0);
  });

  test(
    'a source account change reloads search before its old read returns',
    () async {
      const source = '1010f0d0-8d71-448d-b79e-1548404094aa';
      const unrelated = '8035bea6-0c5a-4a13-b8b3-6fe54814b316';
      await seed(source);
      final oldResponse = Completer<Uint8List>();
      final oldStarted = Completer<void>();
      var calls = 0;
      api.invoke = (_, function) async {
        if (function != 'searchComic')
          return Uint8List.fromList(utf8.encode('{}'));
        if (++calls == 1) {
          oldStarted.complete();
          return oldResponse.future;
        }
        return Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'source': source,
              'data': {
                'items': [],
                'paging': {
                  'page': 1,
                  'pages': 1,
                  'total': 9,
                  'hasReachedMax': true,
                },
              },
            }),
          ),
        );
      };
      final loginEvents = <NeedLogin>[];
      final loginSubscription = eventBus.on<NeedLogin>().listen(
        loginEvents.add,
      );
      final bloc = SearchBloc();
      addTearDown(() async {
        await loginSubscription.cancel();
        await bloc.close();
        api.invoke = null;
      });
      const event = SearchEvent(
        searchStates: SearchStates(from: source, searchKeyword: 'kept query'),
      );
      final reloaded = bloc.stream.firstWhere(
        (s) => s.status == SearchStatus.success,
      );
      bloc.add(event);
      await oldStarted.future;
      pluginSessionWriteFence.advance(unrelated);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);

      try {
        final owner = pluginSessionWriteFence.beginSessionChange(source);
        await Future<void>.delayed(Duration.zero);
        expect(calls, 1);
        pluginSessionWriteFence.seal(source, owner);
        final state = await reloaded.timeout(const Duration(seconds: 2));
        expect(state.searchEvent.searchStates.searchKeyword, 'kept query');
        expect(state.totalResults, 9);
      } finally {
        oldResponse.completeError(
          PluginLoginRequiredException(
            const UnauthorizedPayload(pluginId: source, message: 'old login'),
          ),
        );
      }
      await Future<void>.delayed(Duration.zero);
      expect(loginEvents, isEmpty);
      expect(calls, 2);
    },
  );

  test(
    'reader rejects fallback pages belonging to a different logical chapter',
    () async {
      addTearDown(() => api.invoke = null);
      var attempts = 0;
      api.invoke = (_, function) async {
        if (function != 'getReadSnapshot')
          return Uint8List.fromList(utf8.encode('{}'));
        final empty = attempts++ == 0;
        return Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'data': {
                'comic': {'id': 'work'},
                'chapter': {
                  'id': empty ? 'logical-2' : 'wrong-chapter',
                  'order': 2,
                  'pages': empty
                      ? []
                      : [
                          {
                            'path': 'wrong.jpg',
                            'url': 'https://fixture.invalid/wrong.jpg',
                          },
                        ],
                },
              },
            }),
          ),
        );
      };
      await expectLater(
        getPluginReadSnapshot(
          'work',
          2,
          _copy,
          null,
          'logical-2',
          'request-2',
          'logical-2',
          'shared-storage',
          const {},
        ),
        throwsFormatException,
      );
    },
  );

  for (final stale in ['success', 'unauthorized', 'empty']) {
    test('online reader rejects a superseded $stale and can retry', () async {
      const source = 'reader-session-fixture';
      await seed(source);
      final entered = Completer<void>(), response = Completer<Uint8List>();
      final loginEvents = <NeedLogin>[];
      final subscription = eventBus.on<NeedLogin>().listen(loginEvents.add);
      final hub = ImageRecoveryHub(listenToPlatform: false);
      final bloc = PageBloc(recoveryHub: hub);
      var reads = 0;
      api.invoke = (_, function) async {
        if (function != 'getReadSnapshot')
          return Uint8List.fromList(utf8.encode('{"ok":true}'));
        if (++reads == 1) {
          entered.complete();
          return response.future;
        }
        return _readReply('chapter', 'current');
      };
      addTearDown(() async {
        if (!response.isCompleted)
          response.complete(_readReply('chapter', 'old'));
        await bloc.close();
        await subscription.cancel();
        await hub.dispose();
        api.invoke = null;
      });

      final event = _readChapter(source, 'chapter');
      final old = bloc.stream.firstWhere(
        (state) => state.status != PageStatus.initial,
      );
      bloc.add(event);
      await entered.future.timeout(const Duration(seconds: 3));
      await executeQjsCall(
        pluginId: source,
        fnPath: 'loginWithPassword',
        argsJson: '{}',
      );
      if (stale == 'unauthorized') {
        response.completeError(
          AnyhowException('{"type":"unauthorized","message":"old login"}'),
        );
      } else {
        response.complete(
          _readReply('chapter', 'old', empty: stale == 'empty'),
        );
      }
      final discarded = await old.timeout(const Duration(seconds: 3));
      await Future<void>.delayed(Duration.zero);
      expect(loginEvents, isEmpty);
      expect(discarded.status, PageStatus.failure);
      expect(discarded.errorMessage, const PluginSessionChanged().toString());
      expect(discarded.epInfo, isNull);
      expect(reads, 1);

      final retry = bloc.stream.firstWhere(
        (state) => state.status == PageStatus.success,
      );
      bloc.add(event);
      expect(
        (await retry.timeout(const Duration(seconds: 3))).epInfo?.epName,
        'current',
      );
      expect(reads, 2);
    });
  }

  test(
    'a new reader chapter owns the result while the superseded session reply is pending',
    () async {
      const source = 'reader-session-chapter-fixture';
      await seed(source);
      final entered = Completer<void>(), old = Completer<Uint8List>();
      final hub = ImageRecoveryHub(listenToPlatform: false);
      final bloc = PageBloc(recoveryHub: hub);
      var reads = 0;
      api.invoke = (_, function) async {
        if (function != 'getReadSnapshot')
          return Uint8List.fromList(utf8.encode('{"ok":true}'));
        if (++reads == 1) {
          entered.complete();
          return old.future;
        }
        return _readReply('new', 'new chapter');
      };
      addTearDown(() async {
        if (!old.isCompleted) old.complete(_readReply('old', 'old chapter'));
        await bloc.close();
        await hub.dispose();
        api.invoke = null;
      });
      bloc.add(_readChapter(source, 'old'));
      await entered.future.timeout(const Duration(seconds: 3));
      await executeQjsCall(
        pluginId: source,
        fnPath: 'loginWithPassword',
        argsJson: '{}',
      );
      final result = bloc.stream.firstWhere(
        (state) => state.status == PageStatus.success,
      );
      bloc.add(_readChapter(source, 'new'));
      expect(
        (await result.timeout(const Duration(seconds: 3))).epInfo?.epId,
        'new',
      );
      old.complete(_readReply('old', 'old chapter'));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.epInfo?.epId, 'new');
      expect(reads, 2);
    },
  );

  test(
    'reader accepts a verified request alias and refuses an empty chapter',
    () async {
      addTearDown(() => api.invoke = null);
      var empty = false;
      api.invoke = (_, function) async {
        if (function != 'getReadSnapshot')
          return Uint8List.fromList(utf8.encode('{}'));
        return Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'data': {
                'comic': {'id': 'work'},
                'chapter': {
                  'id': 'provider-alias',
                  'requestId': 'request-2',
                  'order': 2,
                  'pages': empty
                      ? []
                      : [
                          {
                            'path': 'page.jpg',
                            'url': 'https://fixture.invalid/page.jpg',
                          },
                        ],
                },
              },
            }),
          ),
        );
      };
      Future<dynamic> read() => getPluginReadSnapshot(
        'work',
        2,
        _copy,
        null,
        'logical-2',
        'request-2',
        'logical-2',
        'shared-storage',
        const {},
      );
      final loaded = await read();
      expect(loaded.epId, 'logical-2');
      expect(loaded.docs.single.path, 'page.jpg');
      empty = true;
      await expectLater(read(), throwsFormatException);
    },
  );

  test('search scheme cache changes with plugin runtime ownership', () async {
    const source = '5a7db804-9c47-4cf0-b8e3-362866c88273';
    await seed(source);
    final oldResponse = Completer<Uint8List>(), started = Completer<void>();
    var schemeCalls = 0;
    Uint8List scheme(String key) => Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'scheme': {
            'fields': [
              {'key': key, 'kind': 'text'},
            ],
          },
        }),
      ),
    );
    api.invoke = (_, function) async {
      if (function != 'getAdvancedSearchScheme') {
        return Uint8List.fromList(utf8.encode('{}'));
      }
      if (++schemeCalls == 1) {
        started.complete();
        return oldResponse.future;
      }
      return scheme('new');
    };
    addTearDown(() => api.invoke = null);
    final old = sourceAdvancedFields(source);
    await started.future;
    invalidateQjsRuntimeForPluginReplacement(source);
    final current = sourceAdvancedFields(source);
    if (identical(old, current)) oldResponse.complete(scheme('old'));
    expect(identical(old, current), isFalse);
    expect((await current).single['key'], 'new');
    oldResponse.complete(scheme('old'));
    expect(await old, isEmpty);
    expect((await sourceAdvancedFields(source)).single['key'], 'new');
    expect(schemeCalls, 2);
  });

  test(
    'Bika page exclusions never write through the legacy settings parameter',
    () async {
      const source = 'e9f18928-3ba8-4d86-a12e-b53a62f47933';
      await seed(source);
      api.invoke = (runtime, function) async => Uint8List.fromList(
        utf8.encode(
          jsonEncode(
            function == 'searchComic'
                ? {
                    'source': source,
                    'data': {
                      'items': [],
                      'paging': {
                        'page': 1,
                        'pages': 1,
                        'total': 0,
                        'hasReachedMax': true,
                      },
                    },
                    'extern': {
                      'blockedCategories': {'短篇': true},
                    },
                  }
                : {'ok': true},
          ),
        ),
      );
      addTearDown(() => api.invoke = null);
      final result = await getPluginSearchResult(
        const SearchEvent(
          searchStates: SearchStates(
            from: source,
            searchKeyword: 'query',
            pluginExtern: {
              'categories': ['长篇'],
              'blockedCategories': ['全彩'],
              'settingsBlockedCategories': ['短篇'],
            },
          ),
        ),
        BlocState(),
      );
      final transport =
          jsonDecode(
                api.calls
                    .lastWhere((call) => call.function == 'searchComic')
                    .args,
              )['extern']
              as Map;
      expect(transport['categories'], ['长篇']);
      expect(transport.containsKey('blockedCategories'), isFalse);
      expect(transport.containsKey('settingsBlockedCategories'), isFalse);
      expect(result.pluginExtern['blockedCategories'], ['全彩']);
      expect(result.pluginExtern['settingsBlockedCategories'], ['短篇']);
      final cold = await getPluginSearchResult(
        const SearchEvent(
          searchStates: SearchStates(from: source, searchKeyword: 'cold query'),
        ),
        BlocState(),
      );
      expect(
        cold.pluginExtern['blockedCategories'],
        isEmpty,
        reason:
            'A legacy settings echo must never become a page preference on first entry',
      );
    },
  );

  test(
    'cold aggregate metadata uses the actual source network runtime',
    () async {
      const first = '25d92cb2-e7ca-4572-bd87-196738fc52ea';
      const second = '87125ddb-83ee-401b-9fe0-ab40799305c1';
      await seed(first);
      await seed(second);
      expect(PluginRegistryService.I.getCachedPluginInfo(first), isNull);
      expect(PluginRegistryService.I.getCachedPluginInfo(second), isNull);
      final adapter = AggregateVideoSearch();
      expect(
        await Future.wait([
          adapter.prepare(first, 'keyword'),
          adapter.prepare(second, 'keyword'),
        ]),
        [null, null],
      );
      final metadata = api.calls
          .where((call) => call.function == 'getInfo')
          .toList();
      expect(metadata.length, 2);
      expect(
        metadata.any((call) => call.runtime.startsWith('$first@net.')),
        isTrue,
      );
      expect(
        metadata.any((call) => call.runtime.startsWith('$second@net.')),
        isTrue,
      );
    },
  );

  test(
    'normal calls and registry metadata create explicit generations; config keeps source identity',
    () async {
      await executeQjsCall(pluginId: _copy, fnPath: 'catalog', argsJson: '{}');
      final first = api.calls.last.runtime;
      expect(first, startsWith('$_copy@net.'));
      expect(api.runtimes[first]!.networkProxy, 'http://127.0.0.1:18081');
      global = global.copyWith(address: '127.0.0.1:18082');
      await executeQjsCall(
        pluginId: _copy,
        runtimeName: first,
        fnPath: 'detail',
        argsJson: '{}',
      );
      final second = api.calls.last.runtime;
      expect(second, isNot(first));
      expect(api.runtimes[second]!.networkProxy, 'http://127.0.0.1:18082');
      expect(api.runtimes[first]!.networkProxy, 'http://127.0.0.1:18081');

      onSavePluginConfig('($first)', 'authorization', '"fixture-token"');
      final fullConfig =
          jsonDecode(onLoadPluginConfig(second, '', '{}'))['value'] as Map;
      expect(fullConfig.containsKey('__breezeSyncFields'), false);
      onSavePluginConfig(first, 'cleared', 'null');
      expect(
        jsonDecode(
          onLoadPluginConfig(second, 'cleared', '"fallback"'),
        )['value'],
        isNull,
      );
      expect(
        jsonDecode(
          onLoadPluginConfig(second, 'authorization', 'null'),
        )['value'],
        'fixture-token',
      );
      expect(
        objectbox.pluginConfigBox
            .getAll()
            .where((row) => row.name == _copy)
            .length,
        1,
      );
      expect(
        objectbox.pluginConfigBox.getAll().any(
          (row) => row.name.contains('@net.'),
        ),
        false,
      );
      await PluginRegistryService.I.fetchPluginInfo(
        uuid: _copy,
        runtimeName: _copy,
      );
      expect(api.calls.last.runtime, second);
      expect(api.calls.last.once, true);
    },
  );

  test(
    'whole download pins untagged metadata and image requests; another source sees current route',
    () async {
      final before = await SourceNetworkPolicies.resolve(_copy);
      await runWithQjsTaskGroupNetwork(
        pluginId: _copy,
        taskGroupKey: 'chapter-one',
        action: () async {
          global = global.copyWith(address: '127.0.0.1:18083');
          await executeQjsCall(
            pluginId: _copy,
            fnPath: 'detail',
            argsJson: '{}',
          );
          expect(api.calls.last.runtime, before.runtimeName);
          expect(api.calls.last.group, 'chapter-one');
          final image = await executeQjsFetchImageResult(
            pluginId: _copy,
            fnPath: 'fetchImageBytes',
            argsJson: '{}',
            taskGroupKey: 'chapter-one',
          );
          expect(image.bytes, [0, 128, 255]);
          expect(api.calls.last.runtime, before.runtimeName);
          await executeQjsCall(
            pluginId: _omo,
            fnPath: 'catalog',
            argsJson: '{}',
          );
          expect(
            api.runtimes[api.calls.last.runtime]!.networkProxy,
            'http://127.0.0.1:18083',
          );
          expect(api.calls.last.group, '');
        },
      );
      await executeQjsCall(pluginId: _copy, fnPath: 'catalog', argsJson: '{}');
      expect(api.calls.last.runtime, isNot(before.runtimeName));
      expect(api.calls.last.group, '');
      await runWithQjsTaskGroupNetwork(
        pluginId: _copy,
        taskGroupKey: 'chapter-one',
        action: () async {
          await executeQjsCall(
            pluginId: _copy,
            fnPath: 'detail',
            argsJson: '{}',
          );
          expect(
            api.runtimes[api.calls.last.runtime]!.networkProxy,
            'http://127.0.0.1:18083',
          );
        },
      );
    },
  );

  test(
    'debug URL is handed to a preconfigured once runtime without a Dart direct fetch',
    () async {
      await seed(
        _omo,
        debug: true,
        debugUrl: 'https://fixture.invalid/plugin.cjs',
      );
      global = global.copyWith(address: '127.0.0.1:18084');
      await executeQjsCall(pluginId: _omo, fnPath: 'getInfo', argsJson: '{}');
      final call = api.calls.last;
      expect(call.once, true);
      expect(call.url, 'https://fixture.invalid/plugin.cjs');
      expect(
        api.runtimes[call.runtime]!.networkProxy,
        'http://127.0.0.1:18084',
      );
      expect(api.runtimes[call.runtime]!.bundle, isNull);
    },
  );

  test(
    'overlapping references retain cancellation routing until the last request completes',
    () {
      final refs = QjsTaskRuntimeReferences();
      refs.retain('copy::chapter', 'copy@net.0123456789ab');
      refs.retain('copy::chapter', 'copy@net.0123456789ab');
      refs.release('copy::chapter', 'copy@net.0123456789ab');
      expect(refs.take('copy::chapter'), ['copy@net.0123456789ab']);
      expect(refs.take('copy::chapter'), isEmpty);
    },
  );

  test(
    'concurrent group preparation shares a snapshot and an exception releases it',
    () async {
      final pending = Completer<SourceNetworkSnapshot>();
      var resolutions = 0;
      var current = const SourceNetworkSnapshot(
        source: _copy,
        proxy: 'http://127.0.0.1:18081',
      );
      final routes = QjsNetworkRouteStore(
        resolve: (_) {
          resolutions++;
          return resolutions == 1 ? pending.future : Future.value(current);
        },
      );
      final a = routes.resolve(_copy, taskGroupKey: 'same-chapter');
      final b = routes.resolve(_copy, taskGroupKey: 'same-chapter');
      expect(resolutions, 1);
      pending.complete(current);
      expect(identical(await a, await b), true);
      await expectLater(
        routes.runTaskGroup<void>(
          source: _copy,
          taskGroupKey: 'same-chapter',
          action: () async => throw StateError('fixture download failure'),
        ),
        throwsStateError,
      );
      current = const SourceNetworkSnapshot(source: _copy, proxy: '');
      expect(
        (await routes.resolve(_copy, taskGroupKey: 'same-chapter')).proxy,
        '',
      );
      expect(resolutions, 2);
    },
  );
  test(
    'source session clear fences a delayed write from another network runtime',
    () async {
      const source = 'fixture-retired-independent-source';
      await seed(source);
      final entered = Completer<void>(), release = Completer<void>();
      api.invoke = (runtime, function) async {
        if (function == 'oldLogin') {
          onLoadPluginConfig(runtime, 'auth.authorization', '""');
          entered.complete();
          await release.future;
          onSavePluginConfig(runtime, 'auth.authorization', '"late-token"');
        } else if (function == 'clearPluginSession') {
          onSavePluginConfig(runtime, 'auth.authorization', '""');
        }
        return Uint8List.fromList(utf8.encode('{"ok":true}'));
      };
      addTearDown(() => api.invoke = null);
      final oldLogin = executeQjsCall(
        pluginId: source,
        fnPath: 'oldLogin',
        argsJson: '{}',
      );
      // Attach before advancing the clear; a protected superseded call may fail.
      final settledOldLogin = oldLogin.then<void>(
        (_) {},
        onError: (Object _) {},
      );
      await entered.future;
      global = global.copyWith(address: '127.0.0.1:18083');
      await executeQjsCall(
        pluginId: source,
        fnPath: 'clearPluginSession',
        argsJson: '{}',
      );
      expect(
        jsonDecode(
          onLoadPluginConfig(source, 'auth.authorization', 'null'),
        )['value'],
        '',
      );
      release.complete();
      await settledOldLogin;
      expect(
        jsonDecode(
          onLoadPluginConfig(source, 'auth.authorization', 'null'),
        )['value'],
        '',
        reason:
            'The old runtime must not resurrect account credentials after source clear.',
      );
    },
  );

  test(
    'only legacy Copy member-info HTTP 401 becomes a login requirement',
    () async {
      const fn = 'getUserInfoBundle';
      const path =
          'https://fixture.invalid/api/v3/member/info?fixture=private-value';
      const expired =
          'HTTPError: Request failed with status code 401 Unauthorized: GET $path';
      var message = expired;
      api.invoke = (_, function) async {
        if (function == 'init') return Uint8List.fromList(utf8.encode('{}'));
        throw AnyhowException(message);
      };
      addTearDown(() => api.invoke = null);
      final prompts = <NeedLogin>[];
      final subscription = eventBus.on<NeedLogin>().listen(prompts.add);
      addTearDown(subscription.cancel);
      Future<Map<String, dynamic>> read(String source, String function) =>
          callUnifiedComicPlugin(
            from: source,
            fnPath: function,
            core: const {},
            notifyUnauthorized: false,
          );

      for (final (source, function, raw) in [
        (_omo, fn, expired),
        (_copy, 'getComicDetail', expired),
        (_copy, fn, expired.replaceFirst('401 Unauthorized', '403 Forbidden')),
        (_copy, fn, expired.replaceFirst('/member/info', '/other/info')),
        (_copy, fn, 'TLS connect failed for $path'),
        (_copy, fn, 'Request failed due to a network error: GET $path'),
        (
          _copy,
          fn,
          'HTTPError: Request failed with status code 500: GET $path\n$expired',
        ),
      ]) {
        message = raw;
        await expectLater(
          read(source, function),
          throwsA(isA<AnyhowException>()),
        );
      }
      for (final raw in [
        expired.replaceFirst('HTTPError: ', ''),
        expired,
        expired.replaceFirst(' Unauthorized', ''),
        '[bundle:copy fn:getUserInfoBundle source:copy.cjs] $expired',
      ]) {
        message = raw;
        await expectLater(
          read(_copy, fn),
          throwsA(
            isA<PluginLoginRequiredException>()
                .having((error) => error.payload.pluginId, 'source', _copy)
                .having(
                  (error) => error.toString(),
                  'safe text',
                  isNot(contains('private-value')),
                ),
          ),
        );
      }
      await Future<void>.delayed(Duration.zero);
      expect(prompts, isEmpty);
    },
  );

  for (final unauthorized in [false, true]) {
    test(
      'a superseded plugin read discards ${unauthorized ? 'login errors' : 'results'}',
      () async {
        const source = 'fixture-superseded-read-source';
        await seed(source);
        final entered = Completer<void>(), reply = Completer<Uint8List>();
        final events = <NeedLogin>[];
        final subscription = eventBus.on<NeedLogin>().listen(events.add);
        addTearDown(subscription.cancel);
        final ok = Uint8List.fromList(utf8.encode('{"ok":true}'));
        const expired = PluginLoginRequiredException(
          UnauthorizedPayload(pluginId: source, message: 'expired'),
        );
        api.invoke = (_, function) async {
          if (function == 'oldRead') {
            entered.complete();
            return reply.future;
          }
          if (function == 'currentUnauthorized') throw expired;
          return ok;
        };
        addTearDown(() => api.invoke = null);
        Future<Map<String, dynamic>> call(String function) =>
            callUnifiedComicPlugin(
              from: source,
              fnPath: function,
              core: const {},
            );

        final old = call('oldRead');
        final rejected = expectLater(old, throwsA(isA<PluginSessionChanged>()));
        await entered.future;
        expect(await call('loginWithPassword'), {'ok': true});
        if (unauthorized) {
          reply.completeError(expired);
        } else {
          reply.complete(ok);
        }
        await rejected;
        await Future<void>.delayed(Duration.zero);
        expect(events, isEmpty);
        expect(await call('currentRead'), {'ok': true});
        await expectLater(
          call('currentUnauthorized'),
          throwsA(isA<PluginLoginRequiredException>()),
        );
        await Future<void>.delayed(Duration.zero);
        expect(events.map((event) => event.from), [source]);
      },
    );
  }

  test(
    'session clear seals its own init background writer and new custom login remains legal',
    () async {
      const source = 'c319b887-13fd-410d-85e2-123cf2e347fa';
      await seed(source);
      String? clearingRuntime;
      api.invoke = (runtime, function) async {
        if (function == 'clearPluginSession') {
          clearingRuntime = runtime;
          onSavePluginConfig(runtime, 'arbitraryCredentialKey', '""');
        } else if (function == 'customAuthorize') {
          onSavePluginConfig(
            runtime,
            'arbitraryCredentialKey',
            '"fresh-token"',
          );
        } else if (function == 'preferences') {
          onSavePluginConfig(runtime, 'ordinaryNull', 'null');
          onSavePluginConfig(runtime, 'ordinaryEmpty', '""');
        }
        return Uint8List.fromList(utf8.encode('{"ok":true}'));
      };
      addTearDown(() => api.invoke = null);
      await executeQjsCall(
        pluginId: source,
        fnPath: 'clearPluginSession',
        argsJson: '{}',
      );
      expect(
        () => onSavePluginConfig(
          clearingRuntime!,
          'arbitraryCredentialKey',
          '"detached-init-token"',
        ),
        throwsA(isA<PluginSessionChanged>()),
      );
      await executeQjsCall(
        pluginId: source,
        fnPath: 'customAuthorize',
        argsJson: '{}',
        sessionChange: true,
      );
      expect(
        jsonDecode(
          onLoadPluginConfig(source, 'arbitraryCredentialKey', 'null'),
        )['value'],
        'fresh-token',
      );
      final generation = pluginSessionWriteFence.generation(source);
      global = global.copyWith(address: '127.0.0.1:18084');
      await executeQjsCall(
        pluginId: source,
        fnPath: 'preferences',
        argsJson: '{}',
      );
      expect(
        pluginSessionWriteFence.generation(source),
        generation,
        reason:
            'Neither a network change nor ordinary empty/null config fields is logout intent.',
      );
      expect(
        jsonDecode(
          onLoadPluginConfig(source, 'ordinaryNull', '"fallback"'),
        )['value'],
        isNull,
      );
      expect(
        jsonDecode(
          onLoadPluginConfig(source, 'ordinaryEmpty', 'null'),
        )['value'],
        '',
      );
    },
  );

  test(
    'active download completes with its bytes while retired writes fail and its VM retires afterwards',
    () async {
      const source = '91e46615-52c9-4ca2-b2bb-34731c5d5e61';
      await seed(source);
      final entered = Completer<String>(), release = Completer<void>();
      api.invoke = (runtime, function) async {
        if (function == 'downloadFixture') {
          entered.complete(runtime);
          await release.future;
          expect(
            () => onSavePluginConfig(runtime, 'privateSession', '"stale"'),
            throwsA(isA<PluginSessionChanged>()),
          );
          return Uint8List.fromList([1, 2, 3, 4]);
        }
        if (function == 'customLogout')
          onSavePluginConfig(runtime, 'privateSession', 'null');
        return Uint8List.fromList(utf8.encode('{"ok":true}'));
      };
      addTearDown(() => api.invoke = null);
      final download = executeQjsFetchImageBytes(
        pluginId: source,
        fnPath: 'downloadFixture',
        argsJson: '{}',
        taskGroupKey: 'download-protected',
      );
      final runtime = await entered.future;
      await executeQjsCall(
        pluginId: source,
        fnPath: 'customLogout',
        argsJson: '{}',
        sessionChange: true,
      );
      expect(
        api.runtimes.containsKey(runtime),
        isTrue,
        reason:
            'No source-wide cancellation/drop while a download is in flight.',
      );
      release.complete();
      expect(await download, [1, 2, 3, 4]);
      await Future<void>.delayed(Duration.zero);
      expect(api.runtimes.containsKey(runtime), isFalse);
      // A lifecycle rebuild keeps monotonic ownership and permits a fresh login.
      await dropQjsRuntimesForPlugin(source);
      api.invoke = (runtime, function) async {
        if (function == 'loginWithPassword')
          onSavePluginConfig(
            runtime,
            'privateSession',
            '"valid-after-reinstall"',
          );
        return Uint8List.fromList(utf8.encode('{"ok":true}'));
      };
      await executeQjsCall(
        pluginId: source,
        fnPath: 'loginWithPassword',
        argsJson: '{}',
      );
      expect(
        jsonDecode(
          onLoadPluginConfig(source, 'privateSession', 'null'),
        )['value'],
        'valid-after-reinstall',
      );
    },
  );

  test(
    'a delayed standard password change cannot cross a later session clear',
    () async {
      const source = '06ef8717-f803-4629-9bea-279eb4b809e5';
      await seed(source);
      final entered = Completer<void>(), release = Completer<void>();
      api.invoke = (runtime, function) async {
        if (function == 'updatePassword') {
          entered.complete();
          await release.future;
          onSavePluginConfig(runtime, 'auth.password', '"late-password"');
        } else if (function == 'clearPluginSession') {
          onSavePluginConfig(runtime, 'auth.password', '""');
        }
        return Uint8List.fromList(utf8.encode('{"ok":true}'));
      };
      addTearDown(() => api.invoke = null);
      final password = executeQjsCall(
        pluginId: source,
        fnPath: 'updatePassword',
        argsJson: '{}',
      );
      final rejected = expectLater(
        password,
        throwsA(isA<PluginSessionChanged>()),
      );
      await entered.future;
      await executeQjsCall(
        pluginId: source,
        fnPath: 'clearPluginSession',
        argsJson: '{}',
      );
      release.complete();
      await rejected;
      expect(
        jsonDecode(
          onLoadPluginConfig(source, 'auth.password', 'null'),
        )['value'],
        '',
      );
    },
  );

  test(
    'superseded session intent waiting for preparation cannot borrow the new runtime',
    () async {
      const source = '39f32341-3e28-43f8-af78-cb7d1477d6ca';
      await seed(source);
      final entered = Completer<void>(), release = Completer<void>();
      var staleDispatches = 0;
      api.invoke = (runtime, function) async {
        if (function == 'customAuthorizeAfterPreparation') {
          staleDispatches++;
          onSavePluginConfig(runtime, 'authorization', '"late-token"');
        } else if (function == 'clearPluginSession') {
          onSavePluginConfig(runtime, 'authorization', '""');
        }
        return Uint8List.fromList(utf8.encode('{"ok":true}'));
      };
      addTearDown(() => api.invoke = null);
      // Simulate delayed login preparation after the user has already committed
      // session intent. The real task-group network snapshot stays pinned while
      // the newer clear runs outside this operation's Zone.
      final older = runPluginSessionChange(
        source,
        () => runWithQjsTaskGroupNetwork(
          pluginId: source,
          taskGroupKey: 'old-login-preparation',
          action: () async {
            entered.complete();
            await release.future;
            return executeQjsCall(
              pluginId: source,
              fnPath: 'customAuthorizeAfterPreparation',
              argsJson: '{}',
            );
          },
        ),
      );
      final settled = older.then<void>((_) {}, onError: (Object _) {});
      await entered.future;
      global = global.copyWith(address: '127.0.0.1:18085');
      await executeQjsCall(
        pluginId: source,
        fnPath: 'clearPluginSession',
        argsJson: '{}',
      );
      release.complete();
      await settled;
      expect(
        jsonDecode(
          onLoadPluginConfig(source, 'authorization', 'null'),
        )['value'],
        '',
        reason:
            'An old operation must not borrow a newly authorized VM before its outer owner check.',
      );
      expect(staleDispatches, 0);
    },
  );

  test(
    'read-only runtime preparation aborts before rebuilding a retired VM',
    () async {
      const source = 'ab9e9fa4-3793-448d-ae92-7a3b60f098b9';
      await seed(source);
      final entered = Completer<String>(), release = Completer<void>();
      var held = false;
      api.beforeRuntimeReady = (runtime) async {
        if (!held && canonicalQjsSource(runtime) == source) {
          held = true;
          entered.complete(runtime);
          await release.future;
        }
      };
      addTearDown(() => api.beforeRuntimeReady = null);
      final pending = executeQjsCall(
        pluginId: source,
        fnPath: 'readOnlyCatalog',
        argsJson: '{}',
      );
      final rejected = expectLater(
        pending,
        throwsA(isA<PluginSessionChanged>()),
      );
      final retired = await entered.future;
      await executeQjsCall(
        pluginId: source,
        fnPath: 'clearPluginSession',
        argsJson: '{}',
      );
      release.complete();
      await rejected;
      expect(
        api.builds.where((request) => request.runtimeName == retired),
        isEmpty,
        reason:
            'Post-await retirement must be checked before build and init side effects.',
      );
      expect(
        api.calls.where((call) => call.function == 'readOnlyCatalog'),
        isEmpty,
      );
    },
  );

  test(
    'stale direct metadata lease cannot dispatch and cancellation fallback includes actual session VM',
    () async {
      const source = '5e5c4a4c-080b-4598-88fa-aa08ad92dfad';
      await seed(source);
      final prepared = await ensureQjsRuntimeReady(
        pluginId: source,
        initialize: false,
      );
      await executeQjsCall(
        pluginId: source,
        fnPath: 'clearPluginSession',
        argsJson: '{}',
      );
      var dispatched = false;
      await expectLater(
        runWithPluginSessionRuntimeCall(prepared, () async {
          dispatched = true;
          return 'metadata';
        }),
        throwsA(isA<PluginSessionChanged>()),
      );
      expect(dispatched, isFalse);
      await executeQjsCall(pluginId: source, fnPath: 'catalog', argsJson: '{}');
      final actual = api.calls.last.runtime;
      expect(actual, contains('.breeze-session.'));
      api.cancellations.clear();
      await cancelTrackedQjsTasks(
        pluginId: source,
        taskGroupKey: 'not-yet-tracked',
      );
      expect(api.cancellations, contains(actual));
    },
  );
}
