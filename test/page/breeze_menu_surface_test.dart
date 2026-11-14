import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

void main() {
  testWidgets('metadata copies the full address without changing selection', (
    tester,
  ) async {
    final preference = ValueNotifier('breeze');
    addTearDown(preference.dispose);
    final messenger = tester.binding.defaultBinaryMessenger;
    String? clipboard, selection;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard = (call.arguments as Map)['text'] as String;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    const address = 'https://example.invalid/full/server/path';
    await tester.pumpWidget(
      AppInterfaceStyleScope(
        style: preference,
        child: MaterialApp(
          home: Scaffold(
            body: NativeVideoMenu(
              label: 'Server',
              tooltip: 'Server',
              selected: 'auto',
              options: const {
                'auto': 'Auto',
                'server': 'Manual',
                'other': 'Other',
              },
              optionDetails: const {'server': '42 ms', 'other': '1342 ms'},
              optionBadges: const {'server': 'Active'},
              optionCopyText: const {'server': address},
              onSelected: (value) => selection = value,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Server'));
    await tester.pumpAndSettle();
    final menu = find.byKey(const ValueKey('video-host-menu'));
    final manual = find.text('Manual');
    expect(
      tester.getTopLeft(manual).dx,
      tester.getTopLeft(find.text('Other')).dx,
    );
    expect(
      tester.getTopRight(find.text('42 ms')).dx,
      tester.getTopRight(find.text('1342 ms')).dx,
    );
    expect(
      tester.getTopRight(find.text('Active')).dx + 8,
      closeTo(tester.getTopRight(find.byIcon(Icons.check_rounded)).dx, 2),
    );
    final active = find.text('Active');
    expect(active, findsOneWidget);
    final colors = Theme.of(tester.element(active)).colorScheme;
    expect(tester.widget<Text>(active).style?.color, colors.onPrimaryContainer);
    expect(
      find.ancestor(
        of: active,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color ==
                  colors.primaryContainer,
        ),
      ),
      findsOneWidget,
    );
    expect(find.text(address), findsNothing);
    expect(
      find.descendant(of: menu, matching: find.byIcon(Icons.check_rounded)),
      findsOneWidget,
    );
    await tester.longPress(manual);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('已复制域名'), findsOneWidget);
    expect(clipboard, address);
    expect(selection, isNull);
    expect(menu, findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    await tester.tap(manual);
    await tester.pumpAndSettle();
    expect(selection, 'server');
    expect(menu, findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final direction in TextDirection.values) {
    testWidgets(
      'route details stack on a narrow menu with large text: $direction',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final preference = ValueNotifier('breeze');
        addTearDown(preference.dispose);
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: preference,
            child: MaterialApp(
              builder: (context, child) => Directionality(
                textDirection: direction,
                child: MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(2)),
                  child: child!,
                ),
              ),
              home: Scaffold(
                body: NativeVideoMenu(
                  label: 'Route',
                  tooltip: 'Route',
                  selected: 'auto',
                  options: const {
                    'auto': 'Automatic',
                    'edge': 'edge.example.invalid',
                  },
                  optionDetails: const {'edge': '2431 ms'},
                  optionBadges: const {'edge': 'In use'},
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Route'));
        await tester.pumpAndSettle();
        final title = tester.getRect(find.text('edge.example.invalid'));
        final detail = tester.getRect(find.text('2431 ms'));
        final badge = tester.getRect(find.text('In use'));
        expect(detail.top, greaterThanOrEqualTo(title.bottom));
        if (direction == TextDirection.ltr) {
          expect(detail.left, title.left);
          expect(badge.left, greaterThan(title.right));
        } else {
          expect(detail.right, title.right);
          expect(badge.right, lessThan(title.left));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('native compact option metadata is independent from selection', (
    tester,
  ) async {
    final preference = ValueNotifier('system');
    addTearDown(preference.dispose);
    final messenger = tester.binding.defaultBinaryMessenger;
    Map<Object?, Object?>? arguments;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final bytes = (call.arguments as Map)['params'] as Uint8List;
        arguments =
            const StandardMessageCodec().decodeMessage(
                  ByteData.sublistView(bytes),
                )
                as Map<Object?, Object?>;
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        null,
      ),
    );
    await tester.pumpWidget(
      AppInterfaceStyleScope(
        style: preference,
        child: MaterialApp(
          home: Scaffold(
            body: NativeVideoMenu(
              label: 'Server',
              tooltip: 'Server',
              selected: 'auto',
              options: const {'auto': 'Auto', 'server': 'Manual'},
              optionDetails: const {'server': '42 ms'},
              optionBadges: const {'server': 'Active'},
              optionCopyText: const {'server': 'https://example.invalid/full'},
              onSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(arguments?['compactPopup'], isTrue);
    expect(arguments?['selected'], 'auto');
    expect(arguments?['copyConfirmation'], '已复制域名');
    expect(arguments?['options'], [
      {'value': 'auto', 'title': 'Auto'},
      {
        'value': 'server',
        'title': 'Manual',
        'detail': '42 ms',
        'badge': 'Active',
        'copyText': 'https://example.invalid/full',
      },
    ]);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  for (final brightness in Brightness.values) {
    testWidgets(
      'Breeze compact menu separates its surface without dimming $brightness',
      (tester) async {
        final preference = ValueNotifier('breeze');
        addTearDown(preference.dispose);
        var underlying = 0;
        String? selection;
        final theme = ThemeData(brightness: brightness);
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: preference,
            child: MaterialApp(
              theme: theme,
              home: Scaffold(
                body: Column(
                  children: [
                    NativeVideoMenu(
                      label: 'Choose server',
                      tooltip: 'Server',
                      selected: 'a',
                      hostPresentation: true,
                      options: const {
                        'a': 'First server',
                        'b': 'Second server',
                      },
                      onSelected: (value) => selection = value,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => underlying++,
                      child: const Text('Page action'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Choose server'));
        await tester.pumpAndSettle();
        final barrier = tester.widget<ModalBarrier>(
          find.byType(ModalBarrier).last,
        );
        expect(barrier.color, anyOf(isNull, Colors.transparent));
        final surface = tester
            .widgetList<Material>(find.byType(Material))
            .where(
              (material) =>
                  material.color == theme.colorScheme.surfaceContainerLowest &&
                  material.elevation > 0,
            );
        expect(surface, isNotEmpty);
        await tester.tap(find.text('Page action'));
        await tester.pumpAndSettle();
        expect(
          underlying,
          0,
          reason: 'Dismissal must not click the page underneath',
        );
        expect(selection, isNull);
        await tester.tap(find.text('Choose server'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Second server'));
        await tester.pumpAndSettle();
        expect(selection, 'b');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
