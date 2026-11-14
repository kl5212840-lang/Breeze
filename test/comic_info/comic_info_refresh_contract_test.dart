import 'dart:async';
import 'dart:convert';

import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/page/comic_info/bloc/get_comic_info_bloc.dart';
import 'package:zephyr/page/comic_info/json/normal/normal_comic_all_info.dart'
    as normal;
import 'package:zephyr/page/comic_info/method/get_plugin_detail.dart';
import 'package:zephyr/type/enum.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:zephyr/service/image_recovery.dart';

import '../test_helper.dart';

PluginComicDetail _detail(String id, String title, {bool isFavourite = false}) {
  final info = normal.NormalComicAllInfo(
    comicInfo: normal.ComicInfo(
      id: id,
      title: title,
      titleMeta: const [],
      description: '',
      cover: const normal.ComicImage(id: '', url: '', name: ''),
      metadata: const [],
    ),
    eps: const [],
    recommend: const [],
    isFavourite: isFavourite,
  );
  return PluginComicDetail(
    normalInfo: info,
    source: PluginComicDetailSource(
      from: 'fixture',
      normalInfo: info,
      raw: const {},
    ),
  );
}

GetComicInfoEvent _event(
  String id, [
  ComicEntryType type = ComicEntryType.normal,
]) => GetComicInfoEvent(
  comicId: id,
  from: 'fixture',
  type: type,
  extern: const {'kept': true},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  test(
    'detail errors distinguish transport, malformed data and confirmed sign-in',
    () async {
      const loginHint = '请先登录站点账号后查看会员章节';
      const readableHint = '此作品因授权暂时无法阅读';
      const routeHint = '此访问线路暂时无法读取作品';
      final prettyEnvelope = const JsonEncoder.withIndent('  ').convert({
        'type': 'comic_detail_error',
        'reason': 'sourceUnavailable',
        'source': 'fixture',
        'retryable': true,
        'message': routeHint,
      });
      final cases = [
        (
          AnyhowException("unexpected token: 'error'"),
          t.comicFollow.checkInvalidResponse,
          false,
        ),
        (
          const FormatException('Unexpected character', '<html>private body'),
          t.comicFollow.checkInvalidResponse,
          false,
        ),
        (
          AnyhowException(
            'HTTPError: Request failed with status code 401: GET https://example.test/private',
          ),
          t.comicFollow.checkSourceUnavailable,
          false,
        ),
        (
          AnyhowException(
            '[bundle:fixture fn:getComicDetail source:fixture.cjs] Error: {"type":"comic_detail_error","reason":"network"}\n[stack-hook]',
          ),
          t.comicFollow.checkNetworkUnavailable,
          false,
        ),
        (
          AnyhowException(
            '[bundle:fixture fn:getComicDetail source:fixture.cjs] Error: $prettyEnvelope\n[stack-hook]',
          ),
          routeHint,
          true,
        ),
        (
          AnyhowException(
            '{"type":"comic_detail_error","reason":"sourceUnavailable","message":"token=private"}',
          ),
          t.comicFollow.checkSourceUnavailable,
          false,
        ),
        (
          const PluginLoginRequiredException(
            UnauthorizedPayload(pluginId: 'fixture', message: loginHint),
          ),
          loginHint,
          false,
        ),
        (
          AnyhowException(
            '[bundle:fixture fn:getComicDetail source:fixture.cjs] Error: $readableHint\n[stack-hook] at raw-source.js:12',
          ),
          readableHint,
          true,
        ),
      ];
      for (final (error, message, recovering) in cases) {
        final hub = ImageRecoveryHub(listenToPlatform: false);
        final bloc = GetComicInfoBloc(
          recoveryHub: hub,
          readDetail: (_) async => throw error,
        );
        try {
          expect(await bloc.refresh(_event('a')), isFalse);
          expect(bloc.state.status, GetComicInfoStatus.failure);
          expect(bloc.state.result, message);
          expect(bloc.state.recovering, recovering);
        } finally {
          await bloc.close();
          await hub.dispose();
        }
      }
    },
  );

  testWidgets(
    'temporary detail failure recovers without a manual refresh and leaves success cached',
    (tester) async {
      final hub = ImageRecoveryHub(listenToPlatform: false);
      var reads = 0;
      final bloc = GetComicInfoBloc(
        recoveryHub: hub,
        readDetail: (_) async {
          if (++reads == 1) throw TimeoutException('temporary connection');
          return _detail('a', 'recovered');
        },
      );
      final first = bloc.refresh(_event('a'));
      await tester.pump();
      expect(await first, isFalse);
      expect(bloc.state.recovering, isTrue);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(bloc.state.status, GetComicInfoStatus.success);
      expect(bloc.state.allInfo!.comicInfo.title, 'recovered');
      await tester.pump(const Duration(seconds: 10));
      expect(reads, 2);
      await tester.runAsync(bloc.close);
      await hub.dispose();
    },
  );

  testWidgets(
    'detail exhausts a finite budget, then network recovery retries only the current failed book',
    (tester) async {
      final hub = ImageRecoveryHub(listenToPlatform: false);
      var reads = 0;
      final bloc = GetComicInfoBloc(
        recoveryHub: hub,
        readDetail: (_) async {
          if (++reads <= 3) throw TimeoutException('temporary connection');
          return _detail('a', 'online again');
        },
      );
      final first = bloc.refresh(_event('a'));
      await tester.pump();
      expect(await first, isFalse);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2400));
      await tester.pump();
      expect(reads, 3);
      expect(bloc.state.recovering, isFalse);
      await tester.pump(const Duration(minutes: 1));
      expect(reads, 3);
      hub.updateConnectivity([ConnectivityResult.none]);
      hub.updateConnectivity([ConnectivityResult.wifi]);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump();
      expect(reads, 4);
      expect(bloc.state.status, GetComicInfoStatus.success);
      await tester.runAsync(bloc.close);
      await hub.dispose();
    },
  );

  testWidgets('new detail identity cancels a failed book recovery window', (
    tester,
  ) async {
    final hub = ImageRecoveryHub(listenToPlatform: false);
    final reads = <String>[];
    final bloc = GetComicInfoBloc(
      recoveryHub: hub,
      readDetail: (event) async {
        reads.add(event.comicId);
        if (event.comicId == 'old')
          throw TimeoutException('temporary connection');
        return _detail('new', 'current');
      },
    );
    final first = bloc.refresh(_event('old'));
    await tester.pump();
    expect(await first, isFalse);
    final second = bloc.refresh(_event('new'));
    await tester.pump();
    expect(await second, isTrue);
    await tester.pump(const Duration(seconds: 5));
    expect(reads, ['old', 'new']);
    expect(bloc.state.comicId, 'new');
    await tester.runAsync(bloc.close);
    await hub.dispose();
  });

  test(
    'same-book read joins, explicit refresh bypasses throttle, failure keeps detail',
    () async {
      final pending = <Completer<PluginComicDetail>>[];
      final calls = <GetComicInfoEvent>[];
      final bloc = GetComicInfoBloc(
        readDetail: (event) {
          calls.add(event);
          final gate = Completer<PluginComicDetail>();
          pending.add(gate);
          return gate.future;
        },
      );
      addTearDown(bloc.close);
      bloc.add(_event('a'));
      await Future<void>.delayed(Duration.zero);
      var done = false;
      final joined = bloc.refresh(_event('a')).then((value) {
        done = true;
        return value;
      });
      expect(calls, hasLength(1));
      expect(done, isFalse);
      pending[0].complete(_detail('a', 'retained'));
      expect(await joined, isTrue);
      // No fake delay to wait out the ordinary 100ms event throttle.
      final refresh = bloc.refresh(_event('a'));
      await Future<void>.delayed(Duration.zero);
      expect(calls, hasLength(2));
      expect(calls.last.extern, {'kept': true});
      expect(bloc.state.status, GetComicInfoStatus.success);
      expect(bloc.state.allInfo!.comicInfo.title, 'retained');
      final duplicate = bloc.refresh(_event('a'));
      pending[1].completeError(StateError('read fixture unavailable'));
      expect(await refresh, isFalse);
      expect(await duplicate, isFalse);
      expect(bloc.state.allInfo!.comicInfo.title, 'retained');
      expect(bloc.refreshError, isNotEmpty);
    },
  );

  test(
    'new book releases the old waiter and rejects its late detail',
    () async {
      final gates = <String, Completer<PluginComicDetail>>{};
      final bloc = GetComicInfoBloc(
        readDetail: (event) {
          final gate = Completer<PluginComicDetail>();
          gates[event.comicId] = gate;
          return gate.future;
        },
      );
      addTearDown(bloc.close);
      final old = bloc.refresh(_event('old'));
      await Future<void>.delayed(Duration.zero);
      final current = bloc.refresh(_event('new'));
      expect(await old, isFalse);
      gates['old']!.complete(_detail('old', 'stale'));
      await Future<void>.delayed(Duration.zero);
      gates['new']!.complete(_detail('new', 'current'));
      expect(await current, isTrue);
      expect(bloc.state.comicId, 'new');
      expect(bloc.state.allInfo!.comicInfo.title, 'current');
    },
  );

  for (final staleFailure in [false, true]) {
    test(
      'account change replaces a pending detail read, staleFailure=$staleFailure',
      () async {
        final event = _event('account-comic');
        final pending = <Completer<PluginComicDetail>>[];
        final bloc = GetComicInfoBloc(
          readDetail: (_) {
            final read = Completer<PluginComicDetail>();
            pending.add(read);
            return read.future;
          },
        );
        addTearDown(bloc.close);
        final original = bloc.refresh(event);
        await Future<void>.delayed(Duration.zero);
        pending[0].complete(
          _detail(event.comicId, 'Previous account', isFavourite: true),
        );
        expect(await original, isTrue);
        expect(bloc.state.allInfo!.isFavourite, isTrue);

        final old = bloc.refresh(event);
        await Future<void>.delayed(Duration.zero);
        expect(pending, hasLength(2));
        final owner = pluginSessionWriteFence.beginSessionChange(event.from);
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.allInfo, isNull);
        expect(pending, hasLength(2));
        expect(await old, isFalse);

        if (staleFailure) bloc.setRecoveryActive(false);
        pluginSessionWriteFence.seal(event.from, owner);
        if (staleFailure) {
          await Future<void>.delayed(Duration.zero);
          expect(pending, hasLength(2));
          bloc.setRecoveryActive(true);
        }
        await Future<void>.delayed(Duration.zero);
        expect(pending, hasLength(3));
        final current = bloc.refresh(event);
        pending[2].complete(_detail(event.comicId, 'Current account'));
        expect(await current, isTrue);
        if (staleFailure) {
          pending[1].completeError(TimeoutException('previous account'));
        } else {
          pending[1].complete(
            _detail(event.comicId, 'Stale account', isFavourite: true),
          );
        }
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.allInfo!.comicInfo.title, 'Current account');
        expect(bloc.state.allInfo!.isFavourite, isFalse);
        expect(bloc.state.recovering, isFalse);
        expect(bloc.refreshError, isNull);
      },
    );
  }

  test('account changes preserve a locally downloaded detail', () async {
    final event = _event('local-account-comic', ComicEntryType.download);
    final local =
        createTestDownload('${event.from}:${event.comicId}', storageRoot: '')
          ..source = event.from
          ..comicId = event.comicId
          ..detailJson = jsonEncode(
            _detail(event.comicId, 'Downloaded').normalInfo,
          );
    objectbox.unifiedDownloadBox.put(local);
    addTearDown(() => objectbox.unifiedDownloadBox.remove(local.id));
    var remoteReads = 0;
    final bloc = GetComicInfoBloc(
      readDetail: (_) async {
        remoteReads++;
        return _detail(event.comicId, 'Remote');
      },
    );
    addTearDown(bloc.close);
    expect(await bloc.refresh(event), isTrue);
    final before = bloc.state;
    expect(before.allInfo!.comicInfo.title, 'Downloaded');
    final owner = pluginSessionWriteFence.beginSessionChange(event.from);
    pluginSessionWriteFence.seal(event.from, owner);
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state, same(before));
    expect(remoteReads, 0);
  });

  test(
    'opening or refreshing a missing downloaded detail stays offline',
    () async {
      var remoteReads = 0;
      final bloc = GetComicInfoBloc(
        readDetail: (_) async {
          remoteReads++;
          return _detail('missing', 'must not read');
        },
      );
      addTearDown(bloc.close);
      final event = _event('missing', ComicEntryType.download);
      final loaded = bloc.stream.firstWhere(
        (state) => state.status != GetComicInfoStatus.initial,
      );
      bloc.add(event);
      expect(
        (await loaded.timeout(const Duration(seconds: 2))).status,
        GetComicInfoStatus.failure,
      );
      expect(await bloc.refresh(event.copyWith()), isFalse);
      expect(remoteReads, 0);
      expect(bloc.state.status, GetComicInfoStatus.failure);
    },
  );
}
