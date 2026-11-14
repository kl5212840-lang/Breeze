import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/main.dart' show eventBus;
import 'package:zephyr/network/http/plugin/unauthorized_payload.dart';
import 'package:zephyr/page/comic_read/bloc/page_bloc.dart';
import 'package:zephyr/page/comic_read/model/normal_comic_ep_info.dart';
import 'package:zephyr/service/image_recovery.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/util/event/event.dart';

PageEvent open({ComicEntryType type = ComicEntryType.normal}) => PageEvent(
  'work',
  1,
  'logical',
  'request',
  'storage',
  'logical',
  {},
  'source',
  type,
);

void main() {
  testWidgets(
    'transient chapter failure recovers without exposing a retry button and stops after a bounded budget',
    (tester) async {
      final hub = ImageRecoveryHub(listenToPlatform: false);
      var reads = 0, available = false;
      final bloc = PageBloc(
        recoveryHub: hub,
        loadPage: (_) async {
          reads++;
          if (!available) throw const SocketException('network unavailable');
          return NormalComicEpInfo(epId: 'logical');
        },
      );
      bloc.add(open());
      await tester.pump();
      expect(bloc.state.status, PageStatus.initial);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 2400));
      expect(reads, 3);
      expect(bloc.state.status, PageStatus.failure);
      await tester.pump(const Duration(minutes: 1));
      expect(reads, 3);
      available = true;
      hub.updateConnectivity([ConnectivityResult.none]);
      hub.updateConnectivity([ConnectivityResult.wifi]);
      await tester.pump(const Duration(milliseconds: 800));
      expect(bloc.state.status, PageStatus.success);
      expect(bloc.state.epInfo!.epId, 'logical');
      // Stream shutdown must finish outside the widget clock; await the actual
      // close Future rather than replacing it with a timeout or elapsed pump.
      await tester.runAsync(bloc.close);
      await hub.dispose();
    },
  );

  testWidgets('an expired chapter session prompts once and waits for login', (
    tester,
  ) async {
    final hub = ImageRecoveryHub(listenToPlatform: false);
    var reads = 0;
    final prompts = <NeedLogin>[];
    final subscription = eventBus.on<NeedLogin>().listen(prompts.add);
    final bloc = PageBloc(
      recoveryHub: hub,
      loadPage: (_) async {
        reads++;
        throw const PluginLoginRequiredException(
          UnauthorizedPayload(pluginId: 'source', message: '请重新登录'),
        );
      },
    );
    addTearDown(() async {
      await bloc.close();
      await subscription.cancel();
      await hub.dispose();
    });
    bloc.add(open());
    await tester.pump();
    expect(bloc.state.status, PageStatus.failure);
    hub.updateConnectivity([ConnectivityResult.none]);
    hub.updateConnectivity([ConnectivityResult.wifi]);
    await tester.pump(const Duration(seconds: 10));
    expect(reads, 1);
    expect(prompts.map((prompt) => prompt.from), ['source']);
  });

  for (final type in [
    ComicEntryType.download,
    ComicEntryType.historyAndDownload,
  ]) {
    testWidgets(
      'offline $type never retries a missing local page as network work',
      (tester) async {
        final hub = ImageRecoveryHub(listenToPlatform: false);
        var reads = 0;
        final bloc = PageBloc(
          recoveryHub: hub,
          loadPage: (_) async {
            reads++;
            throw const SocketException('network unavailable');
          },
        );
        bloc.add(open(type: type));
        await tester.pump();
        expect(bloc.state.status, PageStatus.failure);
        hub.didChangeAppLifecycleState(AppLifecycleState.paused);
        hub.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await tester.pump(const Duration(seconds: 10));
        expect(reads, 1);
        await tester.runAsync(bloc.close);
        await hub.dispose();
      },
    );
  }

  testWidgets('backgrounding and closing revoke pending chapter retries', (
    tester,
  ) async {
    final hub = ImageRecoveryHub(listenToPlatform: false);
    var reads = 0;
    final bloc = PageBloc(
      recoveryHub: hub,
      loadPage: (_) async {
        reads++;
        throw const SocketException('network unavailable');
      },
    );
    bloc.add(open());
    await tester.pump();
    bloc.setRecoveryActive(false);
    await tester.pump(const Duration(seconds: 10));
    expect(reads, 1);
    await tester.runAsync(bloc.close);
    hub.didChangeAppLifecycleState(AppLifecycleState.paused);
    hub.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 10));
    expect(reads, 1);
    await hub.dispose();
  });
  testWidgets(
    'terminal chapter failure stays manual and is not revived by online signals',
    (tester) async {
      final hub = ImageRecoveryHub(listenToPlatform: false);
      var reads = 0;
      final bloc = PageBloc(
        recoveryHub: hub,
        loadPage: (_) async {
          reads++;
          throw const FormatException('HTTP 404');
        },
      );
      bloc.add(open());
      await tester.pump();
      expect(bloc.state.status, PageStatus.failure);
      hub.updateConnectivity([ConnectivityResult.none]);
      hub.updateConnectivity([ConnectivityResult.wifi]);
      await tester.pump(const Duration(seconds: 10));
      expect(reads, 1);
      await tester.runAsync(bloc.close);
      await hub.dispose();
    },
  );
}
