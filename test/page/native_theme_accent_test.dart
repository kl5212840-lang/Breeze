import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_scope_controls.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/breeze_control_colors.dart';

Widget _app(
  ColorScheme colors,
  ValueNotifier<String> style, {
  List<String> selectedSources = const [],
}) => MaterialApp(
  home: AppInterfaceStyleScope(
    style: style,
    child: Theme(
      data: ThemeData(colorScheme: colors),
      child: Scaffold(
        appBar: AppBar(leading: const SourceBackButton(onPressed: _noop)),
        body: Column(
          children: [
            const NativeVideoTextButton(
              label: 'Source',
              tooltip: 'Source',
              light: false,
              onPressed: _noop,
            ),
            BookshelfSourceNavigation(
              sources: const {'source-a': 'Source A'},
              selected: selectedSources,
              showManage: false,
              classicChips: true,
              onChanged: (_) {},
            ),
            const NativeVideoIconButton(
              tooltip: 'Play',
              icon: Icons.play_arrow,
              symbol: 'play.fill',
              onPressed: _noop,
            ),
            NativeVideoSegmentedControl(
              options: const {'library': 'Library', 'history': 'History'},
              selected: 'history',
              onSelected: (_) {},
            ),
          ],
        ),
        bottomNavigationBar: VideoNativeNavigation(
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Me'),
          ],
          symbols: const ['house', 'person'],
          currentIndex: 1,
          onTap: (_) {},
        ),
      ),
    ),
  ),
);

void _noop() {}

void main() {
  testWidgets(
    'UIKit creation and in-place updates use the current resolved theme roles',
    (tester) async {
      final style = ValueNotifier('system');
      addTearDown(style.dispose);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final channels = <MethodChannel>[];
      final creation = <int, Map<dynamic, dynamic>>{};
      final updates = <int, Map<dynamic, dynamic>>{};
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method != 'create') return null;
        final args = call.arguments as Map;
        final id = args['id'] as int;
        final params = args['params'] as Uint8List;
        creation[id] =
            const StandardMessageCodec().decodeMessage(
                  ByteData.sublistView(params),
                )
                as Map;
        final channel = MethodChannel('${args['viewType']}.$id');
        channels.add(channel);
        messenger.setMockMethodCallHandler(channel, (event) async {
          if (event.method == 'update') updates[id] = event.arguments as Map;
          return null;
        });
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in channels) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });

      void expectTheme(
        Iterable<Map<dynamic, dynamic>> args,
        ColorScheme colors, {
        bool sourceSelected = false,
      }) {
        expect(args, hasLength(7));
        for (final (label, selected) in [
          (t.common.all, !sourceSelected),
          ('Source A', sourceSelected),
        ]) {
          final source = args.singleWhere((value) => value['label'] == label);
          expect(
            source['accent'],
            (selected ? colors.primary : colors.onSurfaceVariant).toARGB32(),
          );
        }
        expect(
          args.singleWhere((value) => value['label'] == 'Source')['accent'],
          colors.primary.toARGB32(),
        );
        expect(
          args.singleWhere((value) => value['symbol'] == 'play.fill')['light'],
          isTrue,
        );
        expect(
          args.singleWhere(
            (value) => value['symbol'] == 'chevron.left',
          )['light'],
          isFalse,
        );
        final nav = args.singleWhere((value) => value['items'] != null);
        expect(nav['selected'], 1);
        expect(nav['accent'], colors.primary.toARGB32());
        final segment = args.singleWhere(
          (value) => value['kind'] == 'segmented',
        );
        expect(segment['selected'], 'history');
        final selection = BreezeControlColors.systemSegmentSelection(colors);
        expect(segment.containsKey('accent'), isFalse);
        expect(segment['selectedBackground'], selection.fill.toARGB32());
        expect(segment['selectedForeground'], selection.foreground.toARGB32());
        expect(segment['selectedBackground'], isNot(Colors.white.toARGB32()));
        expect(segment['dark'], colors.brightness == Brightness.dark);
      }

      const brown = Color(0xff9a482d);
      final light = ColorScheme.fromSeed(seedColor: brown);
      final dark = ColorScheme.fromSeed(
        seedColor: brown,
        brightness: Brightness.dark,
      );
      final source = ColorScheme.fromSeed(seedColor: const Color(0xff37724b));
      final resolved = light.copyWith(primary: const Color(0xff6540af));

      await tester.pumpWidget(_app(light, style));
      await tester.pumpAndSettle();
      expectTheme(creation.values, light);
      final originalIds = creation.keys.toSet();
      final effective = Map.of(creation);
      final segmentId = creation.entries
          .singleWhere((entry) => entry.value['kind'] == 'segmented')
          .key;

      var previous = light;
      for (final scheme in [dark, resolved, source, resolved]) {
        updates.clear();
        await tester.pumpWidget(_app(scheme, style));
        await tester.pumpAndSettle();
        expect(creation.keys.toSet(), originalIds);
        expect(
          updates.containsKey(segmentId),
          previous.brightness != scheme.brightness ||
              BreezeControlColors.systemSegmentSelection(previous) !=
                  BreezeControlColors.systemSegmentSelection(scheme),
        );
        effective.addAll(updates);
        expectTheme(effective.values, scheme);
        previous = scheme;
      }
      updates.clear();
      await tester.pumpWidget(
        _app(resolved, style, selectedSources: const ['source-a']),
      );
      await tester.pumpAndSettle();
      expect(creation.keys.toSet(), originalIds);
      expect(
        updates.values.map((value) => value['label']),
        unorderedEquals([t.common.all, 'Source A']),
      );
      effective.addAll(updates);
      expectTheme(effective.values, resolved, sourceSelected: true);

      style.value = 'breeze';
      await tester.pumpAndSettle();
      expect(find.byType(UiKitView), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
