import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/search/widget/search_field_surface.dart';
import 'package:zephyr/widgets/android_glass_plate.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform_views,
          (_) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  testWidgets(
    'Android system search keeps one capsule, editor and close slot',
    (tester) async {
      const close = ValueKey('android-system-search-close');
      final contrast = ValueNotifier(false);
      addTearDown(contrast.dispose);
      var closes = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          builder: (context, child) => ValueListenableBuilder<bool>(
            valueListenable: contrast,
            builder: (context, highContrast, _) => MediaQuery(
              data: MediaQuery.of(context).copyWith(highContrast: highContrast),
              child: child!,
            ),
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                child: SearchQueryField(
                  query: '',
                  inline: true,
                  closeKey: close,
                  onClose: () => closes++,
                ),
              ),
            ),
          ),
        ),
      );
      final input = tester.widget<TextField>(find.byType(TextField));
      final focusBorder =
          input.decoration!.focusedBorder! as OutlineInputBorder;
      final plate = tester.widget<AndroidGlassPlate>(
        find.byType(AndroidGlassPlate),
      );
      expect(plate.role, AndroidGlassRole.search);
      expect(focusBorder.borderRadius, plate.corners);
      expect(input.decoration!.enabledBorder!.borderSide, BorderSide.none);
      expect(
        focusBorder.borderSide.color,
        ThemeData.dark().colorScheme.primary.withValues(alpha: .74),
      );
      final idlePlateRect = tester.getRect(find.byType(AndroidGlassPlate));
      await tester.enterText(find.byType(TextField), '关键词');
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(AndroidGlassPlate)), idlePlateRect);
      expect(find.byType(BackdropFilter), findsNothing);
      final rect = tester.getRect(find.byType(EditableText));
      final editor = tester.state(find.byType(EditableText));
      contrast.value = true;
      await tester.pumpAndSettle();
      expect(find.byType(AndroidGlassPlate), findsNothing);
      expect(tester.getRect(find.byType(EditableText)), rect);
      expect(tester.state(find.byType(EditableText)), same(editor));
      expect(input.controller!.text, '关键词');
      final highContrastBorder = tester
          .widget<TextField>(find.byType(TextField))
          .decoration!
          .focusedBorder!;
      expect(highContrastBorder.borderSide, isNot(BorderSide.none));
      await tester.tap(find.byKey(close));
      expect(closes, 1);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'Android in-place search reveals one stable editor and skips reduced motion',
    (tester) async {
      final open = ValueNotifier(false);
      final reduced = ValueNotifier(false);
      final focus = FocusNode();
      addTearDown(open.dispose);
      addTearDown(reduced.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: reduced,
              builder: (context, reduceMotion, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reduceMotion),
                child: child!,
              ),
              child: ValueListenableBuilder(
                valueListenable: open,
                builder: (context, isOpen, _) => Center(
                  child: SizedBox(
                    width: 240,
                    child: isOpen
                        ? SearchQueryField(
                            query: '',
                            inline: true,
                            focusNode: focus,
                            animateExpansion: true,
                          )
                        : IconButton(
                            onPressed: () => open.value = true,
                            icon: const Icon(Icons.search),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final editor = find.byType(EditableText);
      final revealing = find.byWidgetPredicate(
        (widget) => widget is ClipRRect && widget.clipper != null,
      );
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      expect(editor, findsOneWidget);
      expect(revealing, findsOneWidget);
      final rect = tester.getRect(editor);
      final state = tester.state(editor);
      final firstClip = tester.widget<ClipRRect>(revealing);
      final firstWidth = firstClip.clipper!.getClip(const Size(240, 48)).width;
      expect(firstWidth, 48);
      focus.requestFocus();
      await tester.pump(const Duration(milliseconds: 70));
      final clip = tester.widget<ClipRRect>(revealing);
      final width = clip.clipper!.getClip(const Size(240, 48)).width;
      expect(width, greaterThan(firstWidth));
      expect(width, lessThan(240));
      await tester.pumpAndSettle();
      expect(revealing, findsNothing);
      expect(tester.getRect(editor), rect);
      expect(tester.state(editor), same(state));
      expect(focus.hasFocus, isTrue);
      open.value = false;
      reduced.value = true;
      await tester.pump();
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();
      expect(editor, findsOneWidget);
      expect(revealing, findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final styleName in ['breeze', 'system']) {
    testWidgets(
      'compact search hint stays on one visible line at large text $styleName',
      (tester) async {
        const hint = '搜索视频或作者';
        final semantics = tester.ensureSemantics();
        try {
          final style = ValueNotifier(styleName);
          addTearDown(style.dispose);
          var opened = false;
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: style,
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 180,
                      child: SearchQueryField(
                        query: '',
                        hintText: hint,
                        onTap: () => opened = true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(hint),
          );
          final boxes = paragraph.getBoxesForSelection(
            const TextSelection(baseOffset: 0, extentOffset: hint.length),
          );
          expect(
            boxes.map((box) => box.top).toSet(),
            hasLength(1),
            reason:
                'The prompt must stay in the compact search row instead of wrapping into its clipped area.',
          );
          expect(find.bySemanticsLabel(RegExp(hint)), findsWidgets);
          await tester.tap(find.byType(SearchQueryField));
          expect(opened, isTrue);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
      variant: TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );
  }

  testWidgets('a plain source route inside a router renders its search entry', (
    tester,
  ) async {
    final router = RootStackRouter.build(routes: []);
    addTearDown(router.dispose);
    final observer = AutoRouteObserver();
    var opened = false;
    await tester.pumpWidget(
      RouterScope(
        controller: router,
        navigatorObservers: [observer],
        inheritableObserversBuilder: () => [observer],
        stateHash: 0,
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: SearchQueryField(
                query: '',
                hintText: '搜索',
                onTap: () => opened = true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(SearchQueryField));
    expect(opened, isTrue);
    expect(find.text('搜索'), findsOneWidget);
  });

  testWidgets(
    'style and theme changes retain editing state and search geometry',
    (tester) async {
      final style = ValueNotifier('system');
      final theme = ValueNotifier(ThemeMode.light);
      final focus = FocusNode();
      addTearDown(style.dispose);
      addTearDown(theme.dispose);
      addTearDown(focus.dispose);
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: ValueListenableBuilder(
            valueListenable: theme,
            builder: (_, mode, _) => MaterialApp(
              theme: ThemeData.light(),
              darkTheme: ThemeData.dark(),
              themeMode: mode,
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SearchQueryField(
                    query: '',
                    inline: true,
                    focusNode: focus,
                    hintText: '搜索',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(UiKitView), findsOneWidget);
      focus.requestFocus();
      await tester.pump();
      await tester.enterText(find.byType(TextField), '关键词');
      final controller = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      controller.value = const TextEditingValue(
        text: '关键词',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      );
      final geometry = tester.getRect(find.byType(EditableText));
      final editing = controller.value;
      theme.value = ThemeMode.dark;
      await tester.pumpAndSettle();
      style.value = 'breeze';
      await tester.pumpAndSettle();
      expect(find.byType(UiKitView), findsNothing);
      expect(tester.getRect(find.byType(EditableText)), geometry);
      expect(controller.value, editing);
      expect(focus.hasFocus, isTrue);
      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration!.filled,
        isFalse,
      );
      final surface = find.descendant(
        of: find.byType(SearchFieldSurface),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).gradient != null,
        ),
      );
      expect(surface, findsOneWidget);
      style.value = 'system';
      await tester.pumpAndSettle();
      expect(find.byType(UiKitView), findsOneWidget);
      expect(controller.value, editing);
      expect(focus.hasFocus, isTrue);
      expect(tester.getRect(find.byType(EditableText)), geometry);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'moving search route retains native painting and its single editor',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const Scaffold()),
      );
      navigator.currentState!.push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, _, _) => const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: SearchQueryField(query: '', inline: true),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(UiKitView), findsOneWidget);
      final editor = tester.state(find.byType(EditableText));
      final material = tester.state(
        find.byType(UiKitView, skipOffstage: false),
      );
      await tester.pumpAndSettle();
      expect(find.byType(UiKitView), findsOneWidget);
      expect(tester.state(find.byType(EditableText)), same(editor));
      expect(tester.state(find.byType(UiKitView)), same(material));
      navigator.currentState!.pop();
      await tester.pump();
      expect(find.byType(UiKitView), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
