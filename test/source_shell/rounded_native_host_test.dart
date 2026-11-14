import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/page/comic_read/cubit/reader_cubit.dart';
import 'package:zephyr/page/comic_read/method/jump_chapter.dart';
import 'package:zephyr/page/comic_read/widgets/chrome/app_bar.dart';
import 'package:zephyr/page/comic_read/widgets/chrome/bottom.dart';
import 'package:zephyr/type/enum.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import '../test_helper.dart';

void _checkNativeClips(WidgetTester tester) {
  expect(find.byType(UiKitView), findsWidgets);
  for (final element in find.byType(UiKitView).evaluate()) {
    RenderObject? node = element.findRenderObject();
    while (node != null) {
      expect(
        switch (node) {
          RenderClipRRect(:final clipBehavior) => clipBehavior != Clip.none,
          RenderPhysicalShape(:final clipBehavior) => clipBehavior != Clip.none,
          _ => false,
        },
        isFalse,
        reason: 'Native view inherits $node',
      );
      node = node.parent;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async => null,
    );
  });
  tearDown(
    () =>
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null),
  );
  for (final style in ['system', 'breeze']) {
    for (final reducedMotion in [false, true]) {
      testWidgets(
        'reader $style keeps toolbar controls stable with reduced motion=$reducedMotion',
        (tester) async {
          final preference = ValueNotifier(style);
          final reader = ReaderCubit()..updateMenuVisible(visible: true);
          const bottomMarker = ValueKey('reader-bottom-marker');
          await tester.pumpWidget(
            MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => GlobalSettingCubit()),
                BlocProvider.value(value: reader),
              ],
              child: AppInterfaceStyleScope(
                style: preference,
                child: MaterialApp(
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(disableAnimations: reducedMotion),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Stack(
                      children: [
                        ComicReadAppBar(
                          title: 'Reader',
                          changePageIndex: (_) {},
                          onToggleFullscreen: () {},
                        ),
                        BottomWidget(
                          type: ComicEntryType.normal,
                          comicInfo: const {},
                          sliderWidget: const SizedBox(
                            key: bottomMarker,
                            width: 100,
                            height: 20,
                          ),
                          order: 0,
                          epsNumber: 0,
                          comicId: 'fixture',
                          from: '',
                          jumpChapter: JumpChapter.create(
                            ComicEntryType.normal,
                            true,
                            const {},
                            0,
                            '',
                            '',
                            '',
                            '',
                            const {},
                            0,
                            'fixture',
                            '',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final header = find.byType(AppBar);
          final footer = find.byKey(bottomMarker);
          final headerSlide = find.descendant(
            of: find.byType(ComicReadAppBar),
            matching: find.byType(AnimatedSlide),
          );
          final footerSlide = find.descendant(
            of: find.byType(BottomWidget),
            matching: find.byType(AnimatedSlide),
          );
          final headerBackdrop = find.descendant(
            of: find.byType(ComicReadAppBar),
            matching: find.byType(BackdropFilter),
          );
          final visibleHeader = tester.getRect(header);
          expect(tester.getRect(headerBackdrop), visibleHeader);
          final visibleFooter = tester.getRect(footer);
          final headerHeight = tester.getSize(headerSlide).height;
          final footerHeight = tester.getSize(footerSlide).height;
          bool ignoring(Finder slide) => tester
              .element(slide)
              .findAncestorWidgetOfExactType<IgnorePointer>()!
              .ignoring;
          final originals = tester.stateList(find.byType(UiKitView)).toList();
          if (style == 'system') {
            _checkNativeClips(tester);
          } else {
            expect(find.byType(UiKitView), findsNothing);
          }
          reader.updateMenuVisible(visible: false);
          await tester.idle();
          await tester.pump();
          expect(ignoring(headerSlide), isTrue);
          expect(ignoring(footerSlide), isTrue);
          final hiddenHeader = visibleHeader.shift(Offset(0, -headerHeight));
          final hiddenFooter = visibleFooter.shift(Offset(0, footerHeight));
          if (reducedMotion) {
            expect(
              [tester.getRect(header), tester.getRect(footer)],
              [hiddenHeader, hiddenFooter],
            );
          } else {
            await tester.pump(const Duration(milliseconds: 120));
            expect(
              tester.getRect(header).top,
              inExclusiveRange(hiddenHeader.top, visibleHeader.top),
            );
            expect(
              tester.getRect(footer).top,
              inExclusiveRange(visibleFooter.top, hiddenFooter.top),
            );
          }
          if (style == 'system') {
            _checkNativeClips(tester);
          }
          reader.updateMenuVisible(visible: true);
          await tester.idle();
          if (reducedMotion) {
            await tester.pump();
          } else {
            await tester.pumpAndSettle();
          }
          expect(tester.getRect(header), visibleHeader);
          expect(tester.getRect(footer), visibleFooter);
          expect(ignoring(headerSlide), isFalse);
          expect(ignoring(footerSlide), isFalse);
          expect(
            tester.stateList(find.byType(UiKitView)),
            orderedEquals(originals),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await reader.close();
          preference.dispose();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }
}
