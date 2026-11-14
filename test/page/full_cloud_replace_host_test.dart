import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/global/full_cloud_replace_page.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';
import '../network/sync/full_cloud_replace_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> reveal(WidgetTester tester, String key) async {
    await tester.scrollUntilVisible(find.byKey(ValueKey(key)), 180,
      scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
  }

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets('readonly preview, separate cancel and real confirmation on narrow large-text host $style $brightness', (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final preference = ValueNotifier(style);
        addTearDown(preference.dispose);
        final cloud = FullReplaceMemoryServer()
          ..comic({'version': 'v1', 'favorites': []}, legacy: true);
        final service = cloud.service(emptyFullReplaceSnapshot);
        await tester.pumpWidget(AppInterfaceStyleScope(style: preference,
          child: MaterialApp(theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.8)), child: child!),
            home: FullCloudReplacePage(createService: () => service))));
        await tester.pumpAndSettle();
        expect(cloud.writes, isEmpty);
        await reveal(tester, 'cloud-replace.preview');
        await tester.tap(find.byKey(const ValueKey('cloud-replace.preview')));
        await tester.pumpAndSettle();
        expect(cloud.writes, isEmpty);
        expect(cloud.ensureCalls, 0);
        await reveal(tester, 'cloud-replace.confirm');
        expect(tester.getSize(find.byKey(const ValueKey('cloud-replace.confirm'))).height, greaterThanOrEqualTo(44));
        await tester.tap(find.byKey(const ValueKey('cloud-replace.confirm')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(cloud.writes, isEmpty);
        await tester.tap(find.text(t.common.cancel));
        await tester.pumpAndSettle();
        expect(cloud.writes, isEmpty);
        expect(find.byKey(const ValueKey('cloud-replace.confirm')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('cloud-replace.confirm')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('cloud-replace.final-confirm')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('cloud-replace.success')), findsOneWidget);
        expect(cloud.writes, isNotEmpty);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('partial failure remains visible, never reports success, and retry rereads actual remote', (tester) async {
    final cloud = FullReplaceMemoryServer()..truncateFailedPut = true;
    cloud.failPut = (p) => p.contains('/comic_');
    await tester.pumpWidget(MaterialApp(home: FullCloudReplacePage(
      createService: () => cloud.service(emptyFullReplaceSnapshot))));
    await tester.pumpAndSettle();
    await reveal(tester, 'cloud-replace.preview');
    await tester.tap(find.byKey(const ValueKey('cloud-replace.preview')));
    await tester.pumpAndSettle();
    await reveal(tester, 'cloud-replace.confirm');
    await tester.tap(find.byKey(const ValueKey('cloud-replace.confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cloud-replace.final-confirm')));
    await tester.pumpAndSettle();
    expect(find.text(t.settings.cloudReplacePartial), findsOneWidget);
    expect(find.byKey(const ValueKey('cloud-replace.success')), findsNothing);
    cloud.failPut = null;
    await reveal(tester, 'cloud-replace.preview');
    await tester.tap(find.byKey(const ValueKey('cloud-replace.preview')));
    await tester.pumpAndSettle();
    await reveal(tester, 'cloud-replace.confirm');
    await tester.tap(find.byKey(const ValueKey('cloud-replace.confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('cloud-replace.final-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cloud-replace.success')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
