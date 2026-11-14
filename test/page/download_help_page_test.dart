import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/donwload_task/view/download_help.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

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
        final arguments = call.arguments as Map;
        final channel = MethodChannel(
          '${arguments['viewType']}.${arguments['id']}',
        );
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
  for (final style in ['system', 'breeze']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'download context help remains readable $style/$scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final preference = ValueNotifier(style);
          addTearDown(preference.dispose);
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => openDownloadHelp(context),
                      child: const Text('open-help'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open-help'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsOneWidget);
          final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
          expect(dialog.scrollable, isTrue);
          for (final text in [
            t.download.helpExport,
            t.download.helpHls,
            t.download.helpDelete,
            t.download.helpContinue,
          ]) {
            expect(find.textContaining(text), findsOneWidget);
          }
          expect(
            ModalRoute.of(tester.element(find.byType(AlertDialog))),
            isA<PopupRoute<void>>(),
          );
          final viewport = tester.getRect(find.byType(AlertDialog));
          expect(viewport.left, greaterThanOrEqualTo(0));
          expect(viewport.right, lessThanOrEqualTo(320));
          await tester.drag(
            find
                .descendant(
                  of: find.byType(AlertDialog),
                  matching: find.byType(Scrollable),
                )
                .first,
            const Offset(0, -500),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(t.common.gotIt));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
          expect(find.text('open-help'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant({
          TargetPlatform.iOS,
          TargetPlatform.android,
        }),
      );
    }
  }
}
