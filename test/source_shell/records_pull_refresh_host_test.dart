import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/source_shell/models/source_profile_records.dart';
import 'package:zephyr/page/source_shell/view/source_profile_records_view.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/pull_refresh_feedback.dart';

import '../test_helper.dart';

// Refresh waits for both the platform's bounce and the indicator's snap.
// Advance actual frames without settling the intentionally pending spinner.
Future<void> _advanceRefreshFrames(
  WidgetTester tester,
  bool Function() started,
) async {
  for (var frame = 0; frame < 80 && !started(); frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <MethodChannel>[];
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestObjectBoxHelper.cleanComicFolderBoxes();
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final channel = MethodChannel(
          'breeze.video.control.${(call.arguments as Map)['id']}',
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
    for (final brightness in Brightness.values) {
      testWidgets(
        'records empty and short hosts really pull, await, retain and retry $style $brightness',
        (tester) async {
          tester.view.physicalSize = const Size(390, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final preference = ValueNotifier(style);
          addTearDown(preference.dispose);
          for (final short in [false, true]) {
            if (short) {
              objectbox.unifiedFavoriteBox.put(createTestFavorite('short'));
            }
            final entries = loadSourceProfileRecords(['test']).favorites;
            var gate = Completer<void>();
            var reads = 0;
            await tester.pumpWidget(
              AppInterfaceStyleScope(
                style: preference,
                child: MaterialApp(
                  theme: ThemeData(brightness: brightness),
                  home: Scaffold(
                    body: SourceProfileRecordsView(
                      key: ValueKey(short),
                      mode: ShelfPageMode.favorite,
                      entries: entries,
                      onBack: () {},
                      onRefreshWithResult: () async {
                        reads++;
                        await gate.future;
                        return PullRefreshResult.unchanged;
                      },
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text(t.common.refresh), findsNothing);
            final scroll = find
                .descendant(
                  of: find.byType(RefreshIndicator),
                  matching: find.byType(Scrollable),
                )
                .first;
            final position = tester.state<ScrollableState>(scroll).position;
            expect(position.viewportDimension, greaterThan(0));
            expect(position.pixels, position.minScrollExtent);
            expect(position.physics.shouldAcceptUserOffset(position), isTrue);
            await tester.drag(scroll, const Offset(0, 350));
            await _advanceRefreshFrames(tester, () => reads != 0);
            expect(
              reads,
              1,
              reason:
                  'The actual drag must refresh; viewport=${position.viewportDimension}, offset=${position.pixels}',
            );
            expect(find.byType(RefreshProgressIndicator), findsOneWidget);
            expect(find.byType(LinearProgressIndicator), findsNothing);
            if (short) expect(find.text('Test Comic short'), findsOneWidget);
            gate.completeError(StateError('offline refresh fixture'));
            await tester.pumpAndSettle();
            expect(find.byType(RefreshProgressIndicator), findsNothing);
            expect(find.text(t.common.refreshRetained), findsNothing);
            expect(
              find.widgetWithText(TextButton, t.common.retry),
              findsOneWidget,
            );
            if (short) expect(find.text('Test Comic short'), findsOneWidget);
            gate = Completer<void>();
            await tester.tap(find.widgetWithText(TextButton, t.common.retry));
            await _advanceRefreshFrames(tester, () => reads >= 2);
            expect(reads, 2);
            expect(find.byType(RefreshProgressIndicator), findsOneWidget);
            gate.complete();
            await tester.pumpAndSettle();
            expect(
              find.widgetWithText(TextButton, t.common.retry),
              findsNothing,
            );
            expect(find.text(t.common.refreshUnchanged), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          }
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }
}
