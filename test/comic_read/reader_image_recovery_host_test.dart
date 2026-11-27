import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/http/picture/picture.dart';
import 'package:zephyr/cubit/comic_read_preference_cubit.dart';
import 'package:zephyr/page/comic_read/cubit/reader_cubit.dart';
import 'package:zephyr/page/comic_read/widgets/image/read_image_widget.dart';
import 'package:zephyr/service/image_recovery.dart';
import 'package:zephyr/widgets/picture_bloc/bloc/picture_bloc.dart';
import 'package:zephyr/widgets/picture_bloc/bloc/picture_state.dart';
import 'package:zephyr/widgets/picture_bloc/models/picture_info.dart';

void main() {
  test('reader resumes decode repair on return to an inactive slot', () async {
    const info = PictureInfo(
      from: 'source',
      path: 'page.webp',
      url: 'https://images.example.invalid/page.webp',
    );
    final invalidation = Completer<bool>();
    var loads = 0;
    var invalidations = 0;
    final bloc = PictureBloc(
      autoRecover: false,
      loader: (_) async => ++loads == 1 ? 'broken.webp' : 'repaired.webp',
      cacheInvalidator: (request, path) {
        expect(request, info);
        expect(path, 'broken.webp');
        invalidations++;
        return invalidation.future;
      },
    );
    addTearDown(bloc.close);
    final initialImage = bloc.stream.firstWhere(
      (state) => state.imagePath == 'broken.webp',
    );
    bloc.add(const GetPicture(info));
    await initialImage;

    final repair = bloc.reportDecodeFailure(
      const FormatException('Invalid image'),
      imagePath: 'broken.webp',
    );
    await bloc.reportDecodeFailure(
      const FormatException('Duplicate decoder callback'),
      imagePath: 'broken.webp',
    );
    bloc.setRecoveryActive(false);
    invalidation.complete(true);
    await repair;
    expect(loads, 1);
    expect(bloc.state.status, PictureLoadStatus.initial);
    expect(bloc.state.imagePath, isNull);

    final repairedImage = bloc.stream.firstWhere(
      (state) => state.imagePath == 'repaired.webp',
    );
    bloc.setRecoveryActive(true);
    await repairedImage;
    expect(invalidations, 1);
    expect(loads, 2);
    expect(bloc.state.status, PictureLoadStatus.success);
    expect(bloc.state.imagePath, 'repaired.webp');
  });

  testWidgets(
    '正文recovery follows current slot and closes old identity ownership',
    (tester) async {
      final reader = ReaderCubit()..updateCurrentSlot(0);
      final settings = GlobalSettingCubit();
      final preference = ComicReadPreferenceCubit();
      final requests = <PictureInfo>[];
      final blocs = <PictureBloc>[];
      var info = const PictureInfo(
        from: 'source',
        cartoonId: 'work',
        chapterId: 'logical-1',
        storageChapterId: 'shared-storage',
        path: 'one.jpg',
        url: 'https://example.invalid/one',
      );
      late StateSetter rebuild;
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: reader),
            BlocProvider.value(value: settings),
            BlocProvider.value(value: preference),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, update) {
                  rebuild = update;
                  return ReadImageWidget(
                    index: 5,
                    isColumn: true,
                    pictureInfo: info,
                    pictureBlocFactory: () {
                      final bloc = PictureBloc(
                        autoRecover: false,
                        initiallyActive: false,
                        loader: (event) async {
                          requests.add(event.pictureInfo);
                          throw const FormatException('HTTP 404');
                        },
                      );
                      blocs.add(bloc);
                      return bloc;
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(requests, isEmpty);
      reader.updateCurrentSlot(5);
      await tester.pumpAndSettle();
      expect(requests.single.chapterId, 'logical-1');
      expect(requests.single.storageChapterId, 'shared-storage');
      final terminal = find.text(t.error.loadFailed);
      expect(terminal, findsOneWidget);
      await tester.tap(terminal);
      await tester.pump();
      expect(requests, hasLength(1));
      rebuild(
        () => info = info.copyWith(
          from: 'other-source',
          cartoonId: 'other-work',
          chapterId: 'logical-2',
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(blocs.first.isClosed, isTrue);
      expect(requests.map((value) => value.chapterId), [
        'logical-1',
        'logical-2',
      ]);
      expect(requests.last.from, 'other-source');
      expect(requests.last.cartoonId, 'other-work');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(blocs.every((bloc) => bloc.isClosed), isTrue);
      await reader.close();
      await settings.close();
      await preference.close();
    },
  );

  testWidgets('missing downloaded image explains how to recover', (
    tester,
  ) async {
    final reader = ReaderCubit();
    final settings = GlobalSettingCubit();
    final preference = ComicReadPreferenceCubit();
    final decoded = <int>[];
    addTearDown(reader.close);
    addTearDown(settings.close);
    addTearDown(preference.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: reader),
          BlocProvider.value(value: settings),
          BlocProvider.value(value: preference),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ReaderDecodedImageScope(
              onDecoded: (_, page) => decoded.add(page),
              offline: true,
              child: ReadImageWidget(
                index: 0,
                chapterPage: 1,
                isColumn: true,
                pictureInfo: const PictureInfo(
                  from: 'source',
                  path: 'missing.jpg',
                ),
                pictureBlocFactory: () => PictureBloc(
                  autoRecover: false,
                  initiallyActive: false,
                  loader: (_) async =>
                      throw const DownloadPictureNotFoundException(''),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(t.download.fileUnavailable), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ReadImageWidget),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
    expect(decoded, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'reader retries transient failures after reconnect without a tap',
    (tester) async {
      final reader = ReaderCubit()..updateCurrentSlot(0);
      final settings = GlobalSettingCubit();
      final preference = ComicReadPreferenceCubit();
      addTearDown(reader.close);
      addTearDown(settings.close);
      addTearDown(preference.close);
      final hub = ImageRecoveryHub(listenToPlatform: false)
        ..updateConnectivity([ConnectivityResult.none]);
      addTearDown(hub.dispose);
      const url = 'https://images.example.invalid/00404.webp';
      final failures = <Object>[
        const DownloadPictureHttpException(url, 'Unavailable', statusCode: 503),
        TimeoutException('Timed out fetching $url'),
        const DownloadPictureHttpException(url, 'Missing', statusCode: 404),
      ];
      final navigator = GlobalKey<NavigatorState>();
      var attempts = 0;
      late PictureBloc bloc;
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: reader),
            BlocProvider.value(value: settings),
            BlocProvider.value(value: preference),
          ],
          child: MaterialApp(
            navigatorKey: navigator,
            home: Scaffold(
              body: ReadImageWidget(
                index: 0,
                isColumn: true,
                pictureInfo: const PictureInfo(
                  from: 'source',
                  path: '00404.webp',
                  url: url,
                ),
                pictureBlocFactory: () => bloc = PictureBloc(
                  initiallyActive: false,
                  recoveryHub: hub,
                  loader: (_) async => throw failures[attempts++],
                ),
              ),
            ),
          ),
        ),
      );
      final page = find.byType(ReadImageWidget);
      final retryControl = find.descendant(
        of: page,
        matching: find.byType(InkWell),
      );
      await tester.pump();
      final frame = tester.getRect(page);
      expect(attempts, 1);
      expect(bloc.pictureNotFound, isFalse);
      expect(find.text('1'), findsOneWidget);
      expect(retryControl, findsNothing);
      await tester.pump(const Duration(seconds: 10));
      expect(attempts, 1);

      unawaited(
        navigator.currentState!.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Covered')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      hub.updateConnectivity([ConnectivityResult.wifi]);
      await tester.pump(const Duration(seconds: 10));
      expect(attempts, 1);

      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));
      expect(attempts, 2);
      expect(bloc.pictureNotFound, isFalse);
      expect(find.text('1'), findsOneWidget);
      expect(retryControl, findsNothing);

      await tester.pump(const Duration(milliseconds: 2400));
      expect(attempts, 3);
      expect(bloc.pictureNotFound, isTrue);
      expect(find.text(t.error.notFound), findsOneWidget);
      expect(retryControl, findsNothing);
      expect(tester.getRect(page), frame);
      await tester.tap(find.text(t.error.notFound));
      await tester.pump(const Duration(seconds: 10));
      expect(attempts, 3);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
