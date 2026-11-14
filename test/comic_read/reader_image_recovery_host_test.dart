import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/http/picture/picture.dart';
import 'package:zephyr/cubit/comic_read_preference_cubit.dart';
import 'package:zephyr/page/comic_read/cubit/reader_cubit.dart';
import 'package:zephyr/page/comic_read/widgets/image/read_image_widget.dart';
import 'package:zephyr/util/error_filter.dart';
import 'package:zephyr/widgets/picture_bloc/bloc/picture_bloc.dart';
import 'package:zephyr/widgets/picture_bloc/models/picture_info.dart';

void main() {
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
      await tester.pump();
      expect(requests.single.chapterId, 'logical-1');
      expect(requests.single.storageChapterId, 'shared-storage');
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
    expect(decoded, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reader uses the HTTP status, not digits in the image path', (
    tester,
  ) async {
    final reader = ReaderCubit()..updateCurrentSlot(0);
    final settings = GlobalSettingCubit();
    final preference = ComicReadPreferenceCubit();
    addTearDown(reader.close);
    addTearDown(settings.close);
    addTearDown(preference.close);
    const url = 'https://images.example.invalid/00404.webp';
    final failures = <Object>[
      const DownloadPictureHttpException(url, 'Unavailable', statusCode: 503),
      TimeoutException('Timed out fetching $url'),
      const DownloadPictureHttpException(url, 'Missing', statusCode: 404),
    ];
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
                autoRecover: false,
                initiallyActive: false,
                loader: (_) async => throw failures[attempts++],
              ),
            ),
          ),
        ),
      ),
    );
    final placeholder = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              'asset/image/error_image/404.png',
    );
    for (final index in [0, 1]) {
      await tester.pumpAndSettle();
      expect(attempts, index + 1);
      expect(bloc.pictureNotFound, isFalse);
      expect(placeholder, findsNothing);
      final retry = find.text(
        t.reader.imageLoadFailedRetry(
          error: userFacingErrorMessage(
            normalizeSearchErrorMessage(failures[index]),
          ),
        ),
      );
      expect(retry, findsOneWidget);
      await tester.tap(retry);
    }
    await tester.pumpAndSettle();
    expect(attempts, 3);
    expect(bloc.pictureNotFound, isTrue);
    expect(placeholder, findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
