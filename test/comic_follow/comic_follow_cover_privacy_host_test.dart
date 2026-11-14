import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/page/comic_follow/view/comic_follow_page.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/service/comic_follow/comic_follow_service.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/comic_simplify_entry/cover.dart';
import 'package:zephyr/widgets/picture_bloc/bloc/picture_bloc.dart';

import '../ui_preview_helper.dart';

class _Repository implements ComicFollowRepository {
  bool hasHistory = true;
  ComicFollowDetection detection = const ComicFollowDetection(
    chapterCount: 11,
    latestChapterTitle: '最后检查到的真实章节',
  );
  final row = ComicFollow(
    id: 1,
    uniqueKey: 'privacy:1',
    source: 'privacy',
    comicId: '1',
    title: '保持清晰的追更长标题与章节状态信息',
    description: '',
    cover: '',
    creator: '',
    titleMeta: '',
    metadata: '',
    lastChapterCount: 10,
    detectedChapterCount: 11,
    detectedChapterTitle: '最后检查到的真实章节',
    hasUpdate: true,
    updateTime: DateTime.now().toUtc(),
    deleted: false,
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
    schemaVersion: 1,
  );
  @override
  List<ComicFollow> listActiveFollows() => [row];
  @override
  Map<String, UnifiedComicHistory> listActiveHistories() => {
    if (hasHistory)
      row.uniqueKey: UnifiedComicHistory(
        uniqueKey: row.uniqueKey,
        source: row.source,
        comicId: row.comicId,
        title: row.title,
        description: '',
        cover: '',
        creator: '',
        titleMeta: '',
        metadata: '',
        chapterId: '3',
        chapterTitle: '第三章 ${List.filled(12, row.title).join(' · ')}',
        chapterOrder: 3,
        pageIndex: 1,
        createdAt: DateTime.utc(2026, 10, 26),
        lastReadAt: DateTime.utc(2026, 10, 26, 5, 50),
        updatedAt: DateTime.utc(2026, 10, 26, 5, 50),
        deleted: false,
        schemaVersion: 1,
      ),
  };
  @override
  ComicFollow? getFollowByUniqueKey(String key) =>
      key == row.uniqueKey ? row.copyWith() : null;
  @override
  void putFollow(ComicFollow value) {}
  @override
  UnifiedComicHistory? getActiveHistoryByUniqueKey(String key) =>
      listActiveHistories()[key];
  @override
  Future<ComicFollowDetection?> detectChapter(
    ComicFollow value, {
    bool Function()? canContinue,
  }) async => detection;
  @override
  Future<void> notifyUpdate(
    int count, {
    Map<String, int> updates = const {},
    bool Function(String key, int count)? canDeliver,
  }) async {}
}

Future<void> _until(
  WidgetTester tester,
  bool Function() ready,
  String stage,
) async {
  final elapsed = Stopwatch()..start();
  while (!ready() && elapsed.elapsed < const Duration(seconds: 5)) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(ready(), isTrue, reason: stage);
  await tester.pump();
}

Future<void> _close(WidgetTester tester, Future<void> Function() close) async {
  var done = false;
  Object? failure;
  unawaited(
    close().then<void>(
      (_) => done = true,
      onError: (Object error) {
        failure = error;
        done = true;
      },
    ),
  );
  await _until(
    tester,
    () => done,
    'subscription closes while fake continuations are pumped',
  );
  if (failure != null) throw failure!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadUiPreviewFonts);
  testWidgets(
    'real follow image layer uses shared protection in both styles and themes',
    (tester) async {
      final controller = CollectionCoverPrivacyController.instance;
      final previous = controller.state.value;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const connectivity = MethodChannel(
        'dev.fluttercommunity.plus/connectivity',
      );
      const connectivityChanges = MethodChannel(
        'dev.fluttercommunity.plus/connectivity_status',
      );
      messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
      messenger.setMockMethodCallHandler(
        connectivityChanges,
        (_) async => null,
      );
      final channels = <MethodChannel>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final arguments = call.arguments as Map;
          final channel = MethodChannel(
            '${arguments['viewType']}.${arguments['id']}',
          );
          channels.add(channel);
          messenger.setMockMethodCallHandler(channel, (_) async => null);
        }
        return null;
      });
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        for (final style in ['system', 'breeze']) {
          for (final brightness in Brightness.values) {
            final notifier = ValueNotifier(style);
            final textScale = ValueNotifier(1.7);
            final repository = _Repository();
            var now = repository.row.updateTime;
            final cubit = ComicFollowCubit(
              repository: repository,
              now: () => now,
            );
            final registry = PluginRegistryCubit();
            try {
              controller.state.value = const CollectionCoverPrivacySettings(
                enabled: true,
                ready: true,
              );
              await tester.pumpWidget(
                MultiBlocProvider(
                  providers: [
                    BlocProvider.value(value: cubit),
                    BlocProvider.value(value: registry),
                  ],
                  child: AppInterfaceStyleScope(
                    style: notifier,
                    child: MaterialApp(
                      theme: ThemeData(
                        brightness: brightness,
                        platform: TargetPlatform.iOS,
                        fontFamily: uiPreviewDirectory == null
                            ? null
                            : "AccountPreview",
                      ),
                      builder: (context, child) =>
                          ValueListenableBuilder<double>(
                            valueListenable: textScale,
                            builder: (context, scale, _) => MediaQuery(
                              data: MediaQuery.of(
                                context,
                              ).copyWith(textScaler: TextScaler.linear(scale)),
                              child: child!,
                            ),
                          ),
                      home: const RepaintBoundary(
                        key: ValueKey('follow-privacy-preview'),
                        child: ComicFollowPage(),
                      ),
                    ),
                  ),
                ),
              );
              await _until(
                tester,
                () => find.byType(CoverWidget).evaluate().isNotEmpty,
                'real follow row mounts',
              );
              final filter = find.byKey(const ValueKey('follow-filter'));
              expect(filter, findsOneWidget);
              expect(
                tester.widget<NativeVideoSegmentedControl>(filter).options.keys,
                unorderedEquals([
                  ComicFollowFilter.all.name,
                  ComicFollowFilter.unread.name,
                ]),
              );
              final sort = find.byKey(const ValueKey('follow-sort'));
              expect(sort, findsOneWidget);
              final menu = tester.widget<NativeVideoMenu>(sort);
              expect(
                menu.options,
                containsPair(
                  ComicFollowSort.update.name,
                  t.comicFollow.lastUpdate,
                ),
              );
              expect(
                find.byType(PopupMenuButton<ComicFollowSort>),
                findsNothing,
              );
              expect(
                find.text(t.comicFollow.noUnread),
                findsNothing,
                reason: 'the all list does not duplicate an unread summary',
              );
              final reading = find.byKey(
                const ValueKey('follow-reading-privacy:1'),
              );
              final readingText = find.descendant(
                of: reading,
                matching: find.byType(Text),
              );
              final readParagraph = tester.widget<Text>(readingText);
              expect(readParagraph.maxLines, 1);
              expect(readParagraph.overflow, TextOverflow.ellipsis);
              expect(
                tester.getSize(readingText).height,
                lessThan(40),
                reason: 'a long chapter name stays one line at large text',
              );
              final check = find.byKey(
                const ValueKey('follow-check-privacy:1'),
              );
              final times = find.byKey(
                const ValueKey('follow-times-privacy:1'),
              );
              expect(
                find.descendant(
                  of: reading,
                  matching: find.textContaining('第三章'),
                ),
                findsOneWidget,
              );
              final readTime = find.descendant(
                of: times,
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is Text &&
                      w.data?.startsWith(t.comicFollow.lastReadAt(time: '')) ==
                          true,
                ),
              );
              expect(readTime, findsOneWidget);
              expect(
                find.descendant(of: reading, matching: readTime),
                findsNothing,
                reason:
                    'secondary times span the full card instead of stretching only its right column',
              );
              final checkTime = find.descendant(
                of: check,
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is Text &&
                      w.data?.startsWith(t.comicFollow.checkTime(time: '')) ==
                          true,
                ),
              );
              expect(checkTime, findsOneWidget);
              expect(
                tester.widget<Text>(checkTime).style!.fontSize,
                lessThan(
                  tester
                      .widget<Text>(find.text('保持清晰的追更长标题与章节状态信息'))
                      .style!
                      .fontSize!,
                ),
              );
              final cover = find.byType(CoverWidget);
              final originalImage = find.descendant(
                of: cover,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is DecoratedBox &&
                      widget.decoration is BoxDecoration &&
                      (widget.decoration as BoxDecoration).image != null,
                ),
              );
              final pictureBuilder = find.descendant(
                of: cover,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is BlocBuilder<PictureBloc, PictureLoadState>,
                ),
              );
              final bloc = tester.element(pictureBuilder).read<PictureBloc>();
              // The source transport is deliberately unavailable offline. Feed
              // controlled outcomes to the actual host-owned picture Bloc, then
              // retain real FileImage/ResizeImage and engine rendering.
              await _until(
                tester,
                () => bloc.state.status == PictureLoadStatus.failure,
                'offline image request terminates before controlled outcomes',
              );
              if (style == 'breeze') {
                await tester.tap(sort);
                await tester.pumpAndSettle();
                expect(
                  find.byKey(const ValueKey('video-host-menu')),
                  findsOneWidget,
                );
                await tester.tap(find.text(t.comicFollow.lastUpdate));
                await tester.pumpAndSettle();
                expect(cubit.state.sort, ComicFollowSort.update);
                await tester.tap(
                  find.descendant(
                    of: filter,
                    matching: find.text(t.comicFollow.unread),
                  ),
                );
                await tester.pumpAndSettle();
                expect(cubit.state.filter, ComicFollowFilter.unread);
                expect(find.text('保持清晰的追更长标题与章节状态信息'), findsOneWidget);
              }

              bloc.emit(const PictureLoadState());
              await tester.pump();
              final switchFinder = find.descendant(
                of: find.byType(CollectionCoverPrivacyButton),
                matching: find.byType(SourceChromeIconButton),
              );
              tester.widget<SourceChromeIconButton>(switchFinder).onPressed!();
              await _until(
                tester,
                () => !controller.state.value.enabled,
                'shared switch persists off',
              );
              expect(
                tester.element(pictureBuilder).read<PictureBloc>(),
                same(bloc),
              );
              expect(bloc.state.status, PictureLoadStatus.initial);
              bloc.emit(
                PictureLoadState(
                  status: PictureLoadStatus.success,
                  imagePath: File(
                    'asset/image/assets/default_cover.png',
                  ).absolute.path,
                ),
              );
              await _until(
                tester,
                () => originalImage.evaluate().isNotEmpty,
                'original image mounts in the shared protection layer',
              );
              final filters = find.descendant(
                of: cover,
                matching: find.byType(ImageFiltered),
              );
              expect(originalImage, findsWidgets);
              expect(tester.widget<ImageFiltered>(filters).enabled, isFalse);
              tester.widget<SourceChromeIconButton>(switchFinder).onPressed!();
              await _until(
                tester,
                () => controller.state.value.enabled,
                'shared switch persists on',
              );
              expect(tester.widget<ImageFiltered>(filters).enabled, isTrue);
              expect(
                tester.element(pictureBuilder).read<PictureBloc>(),
                same(bloc),
              );
              expect(tester.getSize(cover), const Size(80, 120));
              final title = find.text('保持清晰的追更长标题与章节状态信息');
              expect(title, findsOneWidget);
              expect(
                find.ancestor(of: title, matching: find.byType(ImageFiltered)),
                findsNothing,
              );
              await _until(
                tester,
                () =>
                    PaintingBinding.instance.imageCache.pendingImageCount == 0,
                'real image decoder settles',
              );
              await writeUiPreview(
                tester,
                const ValueKey('follow-privacy-preview'),
                'follow-cover-$style-${brightness.name}',
              );
              tester.view.physicalSize = const Size(430, 932);
              textScale.value = 1;
              await tester.pumpAndSettle();
              expect(find.text('保持清晰的追更长标题与章节状态信息'), findsOneWidget);
              expect(
                tester.getRect(times).top,
                greaterThanOrEqualTo(tester.getRect(cover).bottom),
              );
              expect(
                tester.getRect(readTime).left,
                closeTo(tester.getRect(cover).left, 1),
              );
              expect(
                tester.getRect(readTime).top,
                closeTo(tester.getRect(checkTime).top, 1),
                reason:
                    'normal-size timestamps share one full-width metadata row',
              );
              expect(tester.getSize(cover), const Size(94.5, 141.75));
              await writeUiPreview(
                tester,
                const ValueKey('follow-privacy-preview'),
                'follow-compact-$style-${brightness.name}-standard',
              );
              for (final width in [320.0, 390.0, 440.0]) {
                for (final scale in [1.0, 1.4, 2.0]) {
                  tester.view.physicalSize = Size(width, 1400);
                  textScale.value = scale;
                  await tester.pumpAndSettle();
                  final image = tester.getRect(cover);
                  final card = tester.getRect(
                    find.byKey(const ValueKey('dismiss-privacy:1')),
                  );
                  final identity = tester.getRect(
                    find.byKey(const ValueKey('follow-identity-privacy:1')),
                  );
                  final chapters = tester.getRect(
                    find.byKey(const ValueKey('follow-chapters-privacy:1')),
                  );
                  final footer = tester.getRect(times);
                  final expectedWidth = ((card.width - 20) / 4).clamp(
                    80.0,
                    96.0,
                  );
                  expect(image.width, closeTo(expectedWidth, .01));
                  expect(image.width / image.height, closeTo(2 / 3, .0001));
                  expect(image.width, inInclusiveRange(80.0, 96.0));
                  expect(identity.left, closeTo(image.right + 12, .1));
                  if (chapters.left < identity.left - 1) {
                    expect(
                      chapters.top,
                      greaterThanOrEqualTo(image.bottom + 7.9),
                    );
                    expect(
                      chapters.top,
                      greaterThanOrEqualTo(identity.bottom + 7.9),
                    );
                  } else {
                    expect(
                      chapters.top,
                      greaterThanOrEqualTo(identity.bottom + 7.9),
                    );
                  }
                  expect(
                    footer.top,
                    greaterThanOrEqualTo(chapters.bottom + 7.9),
                  );
                  expect(card.right, greaterThanOrEqualTo(identity.right));
                  expect(
                    tester.element(pictureBuilder).read<PictureBloc>(),
                    same(bloc),
                    reason:
                        'responsive geometry preserves the current image loader',
                  );
                  expect(
                    tester.takeException(),
                    isNull,
                    reason: 'width=$width scale=$scale',
                  );
                }
              }
              tester.view.physicalSize = const Size(320, 900);
              textScale.value = 1.7;
              await tester.pumpAndSettle();
              final checkRight = tester.getRect(checkTime).right;
              repository.hasHistory = false;
              await cubit.refreshHistories();
              await tester.pumpAndSettle();
              expect(readTime, findsNothing);
              expect(
                tester.getRect(checkTime).right,
                closeTo(checkRight, .01),
                reason: 'missing read time preserves the right-hand check slot',
              );
              repository.hasHistory = true;
              await cubit.refreshHistories();
              await tester.pumpAndSettle();
              repository.detection = const ComicFollowDetection.failed(
                ComicFollowCheckFailure.network,
              );
              now = now.add(const Duration(minutes: 3));
              await cubit.checkUpdateForItem(repository.row);
              final failedCheck = find.text(
                t.comicFollow.checkNetworkUnavailable,
              );
              final retryCheck = find.byKey(
                const ValueKey('follow-retry-privacy:1'),
              );
              final attemptedTime = find.descendant(
                of: times,
                matching: find.textContaining(
                  t.comicFollow.lastCheckAttempt(time: ''),
                ),
              );
              for (final (width, scale) in [(430.0, 1.0), (320.0, 2.0)]) {
                tester.view.physicalSize = Size(width, 932);
                textScale.value = scale;
                await tester.pumpAndSettle();
                expect(failedCheck, findsOneWidget);
                expect(
                  tester.getRect(failedCheck).left,
                  closeTo(tester.getRect(cover).left, 1),
                );
                if (width == 320) {
                  expect(
                    tester.getRect(attemptedTime).top,
                    greaterThanOrEqualTo(tester.getRect(readTime).bottom),
                  );
                  expect(
                    tester.getRect(attemptedTime).left,
                    closeTo(tester.getRect(readTime).left, 1),
                  );
                } else {
                  expect(
                    tester.getRect(attemptedTime).top,
                    closeTo(tester.getRect(readTime).top, 1),
                  );
                }
                expect(
                  tester.getSize(retryCheck).height,
                  greaterThanOrEqualTo(44),
                );
                expect(
                  tester.getSize(retryCheck).width,
                  greaterThanOrEqualTo(44),
                );
                expect(
                  tester.element(pictureBuilder).read<PictureBloc>(),
                  same(bloc),
                );
                expect(tester.takeException(), isNull);
                await writeUiPreview(
                  tester,
                  const ValueKey('follow-privacy-preview'),
                  'follow-check-failure-$style-${brightness.name}-$width',
                );
              }
              bloc.emit(
                const PictureLoadState(
                  status: PictureLoadStatus.failure,
                  result: 'fixture unavailable',
                ),
              );
              final retry = find.descendant(
                of: cover,
                matching: find.byIcon(Icons.refresh),
              );
              final notFound = find.descendant(
                of: cover,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Image &&
                      widget.image is AssetImage &&
                      (widget.image as AssetImage).assetName ==
                          'asset/image/error_image/404.png',
                ),
              );
              await _until(
                tester,
                () =>
                    bloc.state.status == PictureLoadStatus.failure &&
                    (bloc.pictureNotFound ? notFound : retry)
                        .evaluate()
                        .isNotEmpty,
                'failure swaps the original image for the matching cover fallback',
              );
              expect(originalImage, findsNothing);
              expect(tester.widget<ImageFiltered>(filters).enabled, isTrue);
              expect(bloc.pictureNotFound ? notFound : retry, findsOneWidget);
              expect(bloc.pictureNotFound ? retry : notFound, findsNothing);
              expect(
                tester.element(pictureBuilder).read<PictureBloc>(),
                same(bloc),
              );
              expect(tester.takeException(), isNull);
            } finally {
              await tester.pumpWidget(const SizedBox.shrink());
              await _close(tester, cubit.close);
              await _close(tester, registry.close);
              notifier.dispose();
              textScale.dispose();
            }
          }
        }
      } finally {
        controller.state.value = previous;
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        messenger.setMockMethodCallHandler(connectivity, null);
        messenger.setMockMethodCallHandler(connectivityChanges, null);
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in channels) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      }
    },
  );
}
