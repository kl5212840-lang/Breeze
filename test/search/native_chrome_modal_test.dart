import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search/widget/search_input_dialog.dart';
import 'package:zephyr/page/search/widget/source_select_dialog.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <MethodChannel>[];
  setUp(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final channel = MethodChannel('${args['viewType']}.${args['id']}');
        channels.add(channel);
        messenger.setMockMethodCallHandler(channel, (_) async => null);
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    channels.clear();
  });

  testWidgets(
    'source dialog retains native header and editor through its complete transition',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                SourceBackButton(onPressed: () {}),
                const Expanded(
                  child: SearchQueryField(query: '词条', inline: true),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final views = tester
          .stateList(find.byType(UiKitView, skipOffstage: false))
          .toList();
      expect(views, hasLength(2));
      final editor = tester.state(find.byType(EditableText));
      final geometry = tester.getRect(find.byType(EditableText));
      Map<String, bool>? result;
      showSourceSelectDialog(
        tester.element(find.byType(SearchQueryField)),
        initial: const {'one': true},
        sourceOptions: const [(pluginId: 'one', title: 'Example')],
      ).then((value) => result = value);
      await tester.pumpAndSettle();
      expect(
        find.byType(UiKitView),
        findsNWidgets(2),
        reason:
            'A Flutter modal must composite over the unchanged native chrome',
      );
      expect(
        tester.stateList(find.byType(UiKitView, skipOffstage: false)),
        orderedEquals(views),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.state(find.byType(EditableText)), same(editor));
      expect(tester.getRect(find.byType(EditableText)), geometry);
      await tester.tap(find.text(t.common.apply));
      await tester.pump();
      expect(result, {
        'one': true,
      }, reason: 'Apply is not delayed until the exit animation');
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.byType(UiKitView), findsNWidgets(2));
      await tester.pumpAndSettle();
      expect(tester.stateList(find.byType(UiKitView)), orderedEquals(views));
      expect(tester.state(find.byType(EditableText)), same(editor));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'source picker aligns adaptive switches and scrolls at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 570);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: const Scaffold(body: Text('Search host')),
        ),
      );
      final host = tester.element(find.text('Search host'));
      final initial = {'id-0': true, 'id-1': false};
      final sources = [
        for (var index = 0; index < 16; index++)
          (
            pluginId: 'id-$index',
            title: index == 1
                ? 'Long source name wraps across lines'
                : 'Source $index',
          ),
      ];
      Finder row(int index) => find.byKey(ValueKey('search-source.id-$index'));
      Finder toggle(int index) =>
          find.descendant(of: row(index), matching: find.byType(Switch));
      Future<Map<String, bool>?> open() => showSourceSelectDialog(
        host,
        initial: initial,
        sourceOptions: sources,
      );

      final draft = open();
      await tester.pumpAndSettle();
      expect(tester.getRect(toggle(0)).right, tester.getRect(toggle(1)).right);
      expect(tester.getSize(row(0)).height, greaterThanOrEqualTo(44));
      expect(tester.widget<Switch>(toggle(0)).value, isTrue);
      expect(tester.widget<Switch>(toggle(1)).value, isFalse);
      await tester.tap(toggle(0));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();
      expect(await draft, isNull);
      expect(initial, {'id-0': true, 'id-1': false});

      final applied = open();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        row(15),
        100,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('search-source-options')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(toggle(15));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.apply));
      await tester.pumpAndSettle();
      expect(await applied, {'id-0': true, 'id-1': false, 'id-15': false});
      expect(tester.takeException(), isNull);
    },
  );
}
