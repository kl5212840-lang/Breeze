import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:zephyr/service/image_recovery.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/widgets/picture_bloc/bloc/picture_bloc.dart';
import 'package:zephyr/widgets/picture_bloc/models/picture_info.dart';
import 'package:zephyr/widgets/picture_bloc/picture_recovery_region.dart';
import 'package:zephyr/widgets/pull_refresh_feedback.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('a committed list refresh retries only its failed covers', (
    tester,
  ) async {
    final visibility = VisibilityDetectorController.instance;
    final previousInterval = visibility.updateInterval;
    visibility.updateInterval = Duration.zero;
    addTearDown(() => visibility.updateInterval = previousInterval);
    final calls = <String, int>{};
    PictureBloc cover(String id, {bool fails = false}) {
      final bloc = PictureBloc(
        autoRecover: false,
        initiallyActive: false,
        loader: (_) async {
          final count = calls.update(
            id,
            (value) => value + 1,
            ifAbsent: () => 1,
          );
          if (fails && count == 1) throw const SocketException('CDN timed out');
          return '/fixtures/$id.jpg';
        },
      )..add(GetPicture(PictureInfo(from: 'source', path: id)));
      return bloc;
    }

    final failed = cover('failed', fails: true);
    final healthy = cover('healthy');
    final other = cover('other', fails: true);
    final indicator = GlobalKey<RefreshIndicatorState>();
    var result = PullRefreshResult.failed;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: PullRefreshFeedback.indicator(
                    indicatorKey: indicator,
                    onRefresh: () async => result,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        for (final bloc in [failed, healthy])
                          PictureRecoveryRegion(
                            bloc: bloc,
                            child: const SizedBox(height: 100, width: 80),
                          ),
                      ],
                    ),
                  ),
                ),
                PictureRecoveryRegion(
                  bloc: other,
                  child: const SizedBox(height: 100, width: 80),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, {'failed': 1, 'healthy': 1, 'other': 1});
      expect(failed.state.status, PictureLoadStatus.failure);
      unawaited(indicator.currentState!.show());
      await tester.pumpAndSettle();
      expect(calls, {'failed': 1, 'healthy': 1, 'other': 1});

      result = PullRefreshResult.unchanged;
      unawaited(indicator.currentState!.show());
      await tester.pumpAndSettle();
      expect(calls, {'failed': 2, 'healthy': 1, 'other': 1});
      expect(failed.state.status, PictureLoadStatus.success);
      expect(other.state.status, PictureLoadStatus.failure);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      for (final bloc in [failed, healthy, other]) {
        unawaited(bloc.close());
      }
      await tester.pump();
    }
  });
  test(
    'a transient first image recovers; success is never fetched by retryFailed',
    () async {
      final hub = ImageRecoveryHub(listenToPlatform: false);
      var calls = 0;
      final bloc = PictureBloc(
        recoveryHub: hub,
        loader: (_) async {
          calls++;
          if (calls == 1) throw const SocketException('temporary');
          return '/fixture/good.jpg';
        },
      );
      bloc.add(
        const GetPicture(
          PictureInfo(from: 'source', url: 'https://host/image', path: 'cover'),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(bloc.recovering, true);
      expect(bloc.state.status, PictureLoadStatus.initial);
      await Future<void>.delayed(const Duration(milliseconds: 850));
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
      expect(bloc.state.status, PictureLoadStatus.success);
      await bloc.retryFailed();
      expect(calls, 2);
      await bloc.close();
      await hub.dispose();
    },
  );
  test(
    'superseded offscreen request restarts once visible without retaining an old owner result',
    () async {
      final hub = ImageRecoveryHub(listenToPlatform: false);
      final pending = Completer<String>();
      var calls = 0;
      final bloc = PictureBloc(
        initiallyActive: false,
        recoveryHub: hub,
        loader: (_) {
          calls++;
          return calls == 1
              ? pending.future
              : Future.value('/fixture/current.jpg');
        },
      );
      bloc.add(const GetPicture(PictureInfo(from: 'source', path: 'cover')));
      await Future<void>.delayed(Duration.zero);
      expect(calls, 0);
      bloc.setRecoveryActive(true);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      bloc.setRecoveryActive(false);
      pending.completeError(const ImageRecoverySuperseded());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, PictureLoadStatus.initial);
      bloc.setRecoveryActive(true);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
      expect(bloc.state.imagePath, '/fixture/current.jpg');
      await bloc.close();
      await hub.dispose();
    },
  );

  test(
    'a changing session waits for its completion instead of retrying immediately',
    () async {
      const source = 'picture-recovery-session-fixture';
      final hub = ImageRecoveryHub(listenToPlatform: false);
      final owner = pluginSessionWriteFence.beginSessionChange(source);
      var calls = 0;
      final bloc = PictureBloc(
        recoveryHub: hub,
        loader: (_) async {
          calls++;
          if (calls == 1) throw const ImageRecoverySuperseded();
          return '/fixture/current.jpg';
        },
      );
      bloc.add(const GetPicture(PictureInfo(from: source, path: 'cover')));
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      expect(bloc.state.status, PictureLoadStatus.initial);
      pluginSessionWriteFence.seal(source, owner);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 2);
      expect(bloc.state.status, PictureLoadStatus.success);
      await bloc.close();
      await hub.dispose();
    },
  );
}
