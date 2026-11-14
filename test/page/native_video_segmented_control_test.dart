import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/native_video_controls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <MethodChannel>[];
  final updates = <MethodCall>[];
  setUp(() {
    channels.clear();
    updates.clear();
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final id = (call.arguments as Map)['id'];
        final channel = MethodChannel('breeze.video.control.$id');
        channels.add(channel);
        messenger.setMockMethodCallHandler(channel, (update) async {
          updates.add(update);
          return null;
        });
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
  });

  Widget selector({
    double width = 360,
    double scale = 1,
    bool system = true,
    bool enabled = true,
    Brightness brightness = Brightness.light,
    String selected = 'local',
    Map<String, String> options = const {'local': '本机收藏', 'site': '站点追番'},
    ValueChanged<String>? onSelected,
  }) => MaterialApp(
    theme: ThemeData(brightness: brightness),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: VideoControlAppearance(
      systemControls: system,
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: NativeVideoSegmentedControl(
              options: options,
              selected: selected,
              enabled: enabled,
              onSelected: onSelected,
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> nativeSelect(WidgetTester tester, String value) async {
    await messenger.handlePlatformMessage(
      channels.single.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall('select', value)),
      (_) {},
    );
    await tester.pump();
  }

  testWidgets(
    'iOS uses the native selector with ordered values and 44pt targets',
    (tester) async {
      final choices = <String>[];
      await tester.pumpWidget(selector(onSelected: choices.add));
      await tester.pumpAndSettle();
      final view = tester.widget<UiKitView>(find.byType(UiKitView));
      final args = view.creationParams! as Map;
      expect(args['kind'], 'segmented');
      expect(args['options'], [
        {'value': 'local', 'title': '本机收藏'},
        {'value': 'site', 'title': '站点追番'},
      ]);
      expect(args['selected'], 'local');
      expect(args['enabled'], isTrue);
      expect(args['dark'], isFalse);
      expect(
        tester.getSize(find.byType(UiKitView)).height,
        greaterThanOrEqualTo(44),
      );
      expect(find.byType(SegmentedButton<String>), findsNothing);
      expect(choices, isEmpty);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'updating title, order, selection and theme keeps the same native view',
    (tester) async {
      final choices = <String>[];
      await tester.pumpWidget(selector(onSelected: choices.add));
      await tester.pumpAndSettle();
      updates.clear();
      await tester.pumpWidget(
        selector(
          options: const {'site': '追番', 'local': '收藏'},
          selected: 'site',
          enabled: false,
          brightness: Brightness.dark,
          onSelected: choices.add,
        ),
      );
      await tester.pumpAndSettle();
      expect(channels, hasLength(1));
      final args = updates.last.arguments as Map;
      expect(updates.last.method, 'update');
      expect(args['options'], [
        {'value': 'site', 'title': '追番'},
        {'value': 'local', 'title': '收藏'},
      ]);
      expect(args['selected'], 'site');
      expect(args['enabled'], isFalse);
      expect(args['dark'], isTrue);
      expect(choices, isEmpty);
      await nativeSelect(tester, 'local');
      expect(
        choices,
        isEmpty,
        reason: 'a delayed native event cannot select a disabled control',
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'native user events accept only a different current valid value',
    (tester) async {
      final choices = <String>[];
      await tester.pumpWidget(selector(onSelected: choices.add));
      await tester.pumpAndSettle();
      await nativeSelect(tester, 'missing');
      await nativeSelect(tester, 'local');
      expect(choices, isEmpty);
      await nativeSelect(tester, 'site');
      expect(choices, ['site']);
      await tester.pumpWidget(
        selector(
          options: const {'local': '本机收藏', 'new': '新选项'},
          onSelected: choices.add,
        ),
      );
      await tester.pumpAndSettle();
      await nativeSelect(tester, 'site');
      expect(choices, [
        'site',
      ], reason: 'removed options cannot be delivered by an old event');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final scale in [1.0, 2.2]) {
    testWidgets(
      'narrow labels wrap vertically at text scale $scale without clipping',
      (tester) async {
        final choices = <String>[];
        const options = {'local': '在本机收藏的全部作品', 'site': '来自站点账号的追番作品'};
        await tester.pumpWidget(
          selector(
            width: 180,
            scale: scale,
            options: options,
            onSelected: choices.add,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(UiKitView), findsNothing);
        final fallback = tester.widget<SegmentedButton<String>>(
          find.byType(SegmentedButton<String>),
        );
        expect(fallback.direction, Axis.vertical);
        for (final label in options.values) {
          final text = tester.widget<Text>(find.text(label));
          expect(text.maxLines, isNull);
          expect(text.overflow, isNot(TextOverflow.ellipsis));
        }
        await tester.tap(find.text(options['site']!));
        await tester.pumpAndSettle();
        expect(choices, ['site']);
        expect(
          tester.getSize(find.byType(SegmentedButton<String>)).height,
          greaterThanOrEqualTo(88),
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets(
    'large text increases the native layout height when width permits',
    (tester) async {
      await tester.pumpWidget(
        selector(
          width: 700,
          scale: 3,
          options: const {'a': 'A', 'b': 'B'},
          selected: 'a',
          onSelected: (_) {},
        ),
      );
      await tester.pumpAndSettle();
      final args =
          tester.widget<UiKitView>(find.byType(UiKitView)).creationParams!
              as Map;
      expect(args['fontSize'], 39);
      expect(tester.getSize(find.byType(UiKitView)).height, greaterThan(44));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('explicit multiline labels always use the wrapping fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      selector(
        width: 600,
        options: const {'local': '本机\n收藏', 'site': '站点追番'},
        onSelected: (_) {},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(UiKitView), findsNothing);
    final fallback = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    );
    expect(fallback.direction, Axis.vertical);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('non-system appearance uses the controlled Flutter selector', (
    tester,
  ) async {
    final choices = <String>[];
    await tester.pumpWidget(selector(system: false, onSelected: choices.add));
    await tester.pumpAndSettle();
    expect(find.byType(UiKitView), findsNothing);
    final fallback = tester.widget<SegmentedButton<String>>(
      find.byType(SegmentedButton<String>),
    );
    expect(fallback.direction, Axis.horizontal);
    expect(fallback.selected, {'local'});
    await tester.tap(find.text('站点追番'));
    await tester.pumpAndSettle();
    expect(choices, ['site']);
    expect(
      tester
          .widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>))
          .selected,
      {'local'},
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'missing selections stay unselected and null callbacks disable interaction',
    (tester) async {
      await tester.pumpWidget(selector(system: false, selected: 'missing'));
      await tester.pumpAndSettle();
      final fallback = tester.widget<SegmentedButton<String>>(
        find.byType(SegmentedButton<String>),
      );
      expect(fallback.selected, isEmpty);
      expect(fallback.emptySelectionAllowed, isTrue);
      expect(fallback.onSelectionChanged, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'vertical fallback has intrinsic height inside an unbounded scroll header',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    width: 132,
                    child: NativeVideoSegmentedControl(
                      options: const {'a': '很长的第一个选项', 'b': '很长的第二个选项'},
                      selected: 'a',
                      onSelected: (_) {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(SegmentedButton<String>)).height,
        inInclusiveRange(88, 400),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty dynamic options do not construct an invalid selector', (
    tester,
  ) async {
    await tester.pumpWidget(selector(options: const {}, onSelected: (_) {}));
    await tester.pumpAndSettle();
    expect(find.byType(UiKitView), findsNothing);
    expect(find.byType(SegmentedButton<String>), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('floating glass keeps independent full-size readable plates', (
    tester,
  ) async {
    Widget control(bool readable) => MaterialApp(
      home: Scaffold(
        body: VideoControlAppearance(
          systemControls: true,
          readableSurface: readable,
          child: Center(
            child: NativeVideoTextButton(
              label: '归类',
              tooltip: '归类',
              light: false,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(control(false));
    await tester.pumpAndSettle();
    var args =
        tester.widget<UiKitView>(find.byType(UiKitView)).creationParams as Map;
    expect(args['readableSurface'], isNull);
    expect(args['backgroundInset'], 4.0);
    updates.clear();
    await tester.pumpWidget(control(true));
    await tester.pumpAndSettle();
    args = updates.last.arguments as Map;
    expect(args['readableSurface'], isTrue);
    expect(args['backgroundInset'], 0.0);
    expect(channels, hasLength(1));
    expect(
      tester.getSize(find.byType(UiKitView)).height,
      greaterThanOrEqualTo(44),
    );
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
