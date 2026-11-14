import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_floating_selection_actions.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_selection_toolbar.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    required ScrollController controller,
    required ValueNotifier<int> count,
    bool accessible = false,
    bool reduceMotion = false,
    bool busy = false,
    double scale = 1,
    VoidCallback? action,
    VoidCallback? rowTap,
  }) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            accessibleNavigation: accessible,
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: ValueListenableBuilder<int>(
            valueListenable: count,
            builder: (context, selectedCount, _) => Column(
              children: [
                BookshelfSelectionToolbar(
                  selectedCount: selectedCount,
                  allSelected: false,
                  onCancel: () {},
                  onToggleAll: () {},
                ),
                Expanded(
                  child: BookshelfFloatingSelectionActions(
                    selecting: true,
                    selectedCount: selectedCount,
                    busy: busy,
                    actions: [
                      BookshelfBatchAction(
                        id: 'move',
                        label: '移动',
                        icon: Icons.folder,
                        symbol: 'folder',
                        onPressed: action ?? () {},
                      ),
                      BookshelfBatchAction(
                        id: 'remove',
                        label: '删除',
                        icon: Icons.delete,
                        symbol: 'trash',
                        onPressed: action ?? () {},
                      ),
                    ],
                    child: ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.only(
                        bottom: BookshelfFloatingSelectionActions
                            .contentBottomPadding,
                      ),
                      itemExtent: 60,
                      itemCount: 40,
                      itemBuilder: (_, index) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: rowTap,
                        child: Text('作品 $index'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Finder button(String id) => find.byKey(ValueKey('shelf-selection.$id'));
  bool hidden(WidgetTester tester) => tester
      .widget<IgnorePointer>(
        find
            .ancestor(
              of: button('remove'),
              matching: find.byType(IgnorePointer),
            )
            .first,
      )
      .ignoring;

  testWidgets(
    '320pt large text keeps context and floating targets separate and above viewport bottom',
    (tester) async {
      final controller = ScrollController(), count = ValueNotifier(1);
      addTearDown(controller.dispose);
      addTearDown(count.dispose);
      await mount(tester, controller: controller, count: count, scale: 2);
      for (final id in ['cancel', 'select-all', 'move', 'remove']) {
        expect(tester.getSize(button(id)).height, greaterThanOrEqualTo(44));
        expect(button(id).hitTestable(), findsOneWidget);
      }
      expect(
        find.descendant(
          of: find.byType(BookshelfSelectionToolbar),
          matching: button('remove'),
        ),
        findsNothing,
      );
      expect(
        tester.getBottomRight(button('remove')).dy,
        lessThanOrEqualTo(628),
      );
      expect(
        tester.getTopLeft(button('remove')).dy,
        greaterThan(tester.getBottomLeft(button('cancel')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('batch actions share one surface and retain separate targets', (
    tester,
  ) async {
    final controller = ScrollController(), count = ValueNotifier(1);
    addTearDown(controller.dispose);
    addTearDown(count.dispose);
    await mount(tester, controller: controller, count: count);
    final surface = find.descendant(
      of: find.byKey(const ValueKey('shelf-selection.floating-actions')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Material &&
            widget.shape is StadiumBorder &&
            widget.elevation > 0,
      ),
    );
    expect(surface, findsOneWidget);
    for (final id in ['move', 'remove']) {
      expect(
        find.descendant(of: surface, matching: button(id)),
        findsOneWidget,
      );
      expect(button(id).hitTestable(), findsOneWidget);
    }
    expect(
      tester.getTopLeft(button('remove')).dx,
      closeTo(tester.getTopRight(button('move')).dx, .01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'only user downward drag hides; upward drag reveals and cancel stays available',
    (tester) async {
      final controller = ScrollController(), count = ValueNotifier(1);
      addTearDown(controller.dispose);
      addTearDown(count.dispose);
      await mount(tester, controller: controller, count: count);
      controller.jumpTo(120);
      await tester.pumpAndSettle();
      expect(hidden(tester), isFalse);
      await tester.drag(find.byType(ListView), const Offset(0, -160));
      await tester.pumpAndSettle();
      expect(hidden(tester), isTrue);
      expect(button('cancel').hitTestable(), findsOneWidget);
      expect(button('remove').hitTestable(), findsNothing);
      final exclusion = tester.widget<ExcludeSemantics>(
        find
            .ancestor(
              of: button('remove'),
              matching: find.byType(ExcludeSemantics),
            )
            .first,
      );
      expect(exclusion.excluding, isTrue);
      await tester.drag(find.byType(ListView), const Offset(0, 100));
      await tester.pumpAndSettle();
      expect(hidden(tester), isFalse);
    },
  );

  testWidgets(
    'selection count changes reveal without automatic scrolling hiding again',
    (tester) async {
      final controller = ScrollController(), count = ValueNotifier(1);
      addTearDown(controller.dispose);
      addTearDown(count.dispose);
      await mount(tester, controller: controller, count: count);
      await tester.drag(find.byType(ListView), const Offset(0, -160));
      await tester.pumpAndSettle();
      expect(hidden(tester), isTrue);
      count.value = 2;
      await tester.pumpAndSettle();
      expect(hidden(tester), isFalse);
      final scrolling = controller.animateTo(
        600,
        duration: const Duration(milliseconds: 160),
        curve: Curves.linear,
      );
      await tester.pumpAndSettle();
      await scrolling;
      expect(hidden(tester), isFalse);
    },
  );

  testWidgets(
    'screen reader keeps actions visible and reduced motion has no transition duration',
    (tester) async {
      final controller = ScrollController(), count = ValueNotifier(1);
      addTearDown(controller.dispose);
      addTearDown(count.dispose);
      await mount(
        tester,
        controller: controller,
        count: count,
        accessible: true,
        reduceMotion: true,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(hidden(tester), isFalse);
      final opacity = tester.widget<AnimatedOpacity>(
        find
            .ancestor(
              of: button('remove'),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
      );
      final slide = tester.widget<AnimatedSlide>(
        find
            .ancestor(
              of: button('remove'),
              matching: find.byType(AnimatedSlide),
            )
            .first,
      );
      expect(opacity.duration, Duration.zero);
      expect(slide.duration, Duration.zero);
    },
  );

  testWidgets('busy actions and list taps cannot mutate or click through', (
    tester,
  ) async {
    final controller = ScrollController(), count = ValueNotifier(1);
    addTearDown(controller.dispose);
    addTearDown(count.dispose);
    var writes = 0, rowTaps = 0;
    await mount(
      tester,
      controller: controller,
      count: count,
      busy: true,
      action: () => writes++,
      rowTap: () => rowTaps++,
    );
    await tester.tap(button('remove'));
    await tester.tapAt(
      tester.getTopLeft(find.byType(ListView)) + const Offset(20, 20),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(rowTaps, 0);
    expect(hidden(tester), isFalse);
  });
}
