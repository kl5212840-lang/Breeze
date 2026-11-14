import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/routing/plugin_routing_rules.dart';
import 'package:zephyr/network/routing/routing_observed_media.dart';
import 'package:zephyr/network/routing/routing_plugin_discovery.dart';
import 'package:zephyr/network/routing/routing_probe_session.dart';
import 'package:zephyr/page/setting/network/routing_rules_page.dart';
import 'package:zephyr/page/video/native_video_page.dart';
import 'package:zephyr/page/video/api_video_detail_page.dart';

const id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
class _Discovery extends RoutingPluginDiscovery {
  @override Stream<void> get changes => const Stream.empty();
  @override List<RoutingSource> installedSources() => const [RoutingSource(id, 'Public comic fixture', [])];
  @override bool isInstalled(String source) => source == id;
  @override Future<RoutingSource> scanInstalled(RoutingSource source) async =>
    RoutingSource(source.id, source.name, ['static.fixture.tv']);
}

Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(done(), isTrue);
}
Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target); await tester.pump();
  await tester.tap(target); await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocaleSettings.setLocale(AppLocale.zhCn);
  });
  for (final cancel in [false, true]) {
    testWidgets('real routing source update stays on page, review/cancel boundaries, cancel=$cancel', (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pending = Completer<void>();
      final entered = Completer<void>();
      late RoutingProbeSession probe;
      await tester.pumpWidget(MaterialApp(home: RoutingRulesPage(
        discovery: _Discovery(),
        probeFactory: (source) => probe = RoutingProbeSession(source: source,
          isCurrent: () => true,
          info: () async => {'function': [{'action': {'type': 'openComicList', 'payload': {'scene': {'body': {
            'type': 'pluginPagedComicList', 'request': {'fnPath': 'readPublicList'},
          }}}}}]},
          call: (_, _, _) async {
            if (!entered.isCompleted) entered.complete();
            await pending.future;
            await RoutingObservedMediaDomains.observeHosts(source, ['runtime.fixture.tv']);
            return {'data': {'items': []}};
          }),
      )));
      await tester.pumpAndSettle();
      await _tap(tester, 'routing-select:$id');
      await _tap(tester, 'routing-next');
      await tester.pumpAndSettle();
      await _tap(tester, 'routing-domains:$id');
      await tester.pumpAndSettle();
      await _tap(tester, 'routing-refresh:$id');
      await _until(tester, () => entered.isCompleted);
      expect(find.byType(NativeVideoPage), findsNothing);
      expect(find.byType(ApiVideoDetailPage), findsNothing);
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('routing-generate'))).onPressed, isNull);
      expect(find.byKey(ValueKey('routing-probe-cancel:$id')), findsOneWidget);
      if (cancel) await _tap(tester, 'routing-probe-cancel:$id');
      pending.complete();
      await _until(tester, () => probe.result != null);
      await tester.pumpAndSettle();
      final candidate = find.byKey(ValueKey('routing-confirm:$id:runtime.fixture.tv'));
      if (cancel) {
        expect(probe.result!.cancelled, isTrue);
        expect(candidate, findsNothing);
        expect((await RoutingObservedMediaDomains.read())[id], isNull);
      } else {
        expect(probe.result!.complete, isTrue);
        await _until(tester, () => candidate.evaluate().isNotEmpty);
        expect(tester.widget<CheckboxListTile>(candidate).value, isFalse);
        await _tap(tester, 'routing-generate');
        await tester.pumpAndSettle();
        expect(find.text(t.routingRules.runtimeChanged), findsOneWidget);
        expect(find.byKey(const ValueKey('copy-routing-block')), findsNothing);
        await _tap(tester, 'routing-confirm:$id:runtime.fixture.tv');
        await _tap(tester, 'routing-generate');
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('copy-routing-block')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
