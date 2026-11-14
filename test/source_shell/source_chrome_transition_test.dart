import 'package:flutter/material.dart' as legacy;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';

void main() {
  testWidgets(
    'source chrome retains native instances, configuration and geometry through route motion',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final controlChannels = <MethodChannel>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final args = call.arguments as Map;
          final channel = MethodChannel('${args['viewType']}.${args['id']}');
          controlChannels.add(channel);
          messenger.setMockMethodCallHandler(channel, (_) async => null);
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in controlChannels) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });

      final navigator = GlobalKey<NavigatorState>();
      Widget page(String id) => Scaffold(
        body: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SourceChromeIconButton(
              key: ValueKey('$id.back'),
              icon: Icons.arrow_back,
              symbol: 'chevron.left',
              tooltip: 'Back',
              onPressed: () {},
            ),
            SourceMoreButton(key: ValueKey('$id.more')),
            SourceChromeIconButton(
              key: ValueKey('$id.filters'),
              icon: Icons.filter_list_rounded,
              symbol: 'line.3.horizontal.decrease',
              tooltip: 'Filters',
              onPressed: () {},
            ),
          ],
        ),
      );
      Finder button(String id) => find.byKey(ValueKey(id), skipOffstage: false);
      Finder native(String id) => find.descendant(
        of: button(id),
        matching: find.byType(UiKitView, skipOffstage: false),
      );
      void expectNative(String id, bool visible) {
        for (final kind in ['back', 'more', 'filters']) {
          expect(native('$id.$kind'), visible ? findsOneWidget : findsNothing);
        }
      }

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) =>
              // Match the application's bridge for auto_route's Flutter routes.
              // ignore: deprecated_member_use
              MaterialUiCompatibilityBridge(child: child!),
          onGenerateRoute: (_) =>
              legacy.MaterialPageRoute<void>(builder: (_) => page('root')),
        ),
      );
      await tester.pumpAndSettle();
      expectNative('root', true);
      final originals = {
        for (final kind in ['back', 'more', 'filters'])
          kind: tester.state(native('root.$kind')),
      };
      final size = tester.getSize(button('root.back'));
      expect(size, const Size(44, 44));

      navigator.currentState!.push<void>(
        legacy.MaterialPageRoute<void>(builder: (_) => page('detail')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expectNative('root', true);
      for (final kind in originals.keys) {
        expect(tester.state(native('root.$kind')), same(originals[kind]));
      }
      expectNative('detail', true);
      expect(find.byIcon(Icons.filter_list_rounded), findsNothing);
      expect(find.byIcon(Icons.filter_alt_outlined), findsNothing);
      expect(tester.getSize(button('detail.filters')), const Size(44, 44));
      expect(tester.getSize(button('detail.back')), size);
      expect(tester.getSize(button('detail.more')), size);

      await tester.pumpAndSettle();
      expectNative('detail', true);
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expectNative('root', true);
      for (final kind in originals.keys) {
        expect(tester.state(native('root.$kind')), same(originals[kind]));
      }
      expectNative('detail', true);
      await tester.pumpAndSettle();
      expectNative('root', true);
      expect(button('detail.back'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
