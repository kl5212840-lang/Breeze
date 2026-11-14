import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/plugin_store/view/plugin_store_page.dart';
import 'package:zephyr/page/search/widget/search_field_surface.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/global/interface_style_setting.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const preferences = MethodChannel('plugins.flutter.io/shared_preferences');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Completer<bool> write;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.resetStatic();
    VideoPlaybackPreferences.interfaceStyle.value = 'system';
    write = Completer<bool>();
    messenger.setMockMethodCallHandler(preferences, (call) async {
      if (call.method == 'getAll') return <String, Object>{};
      return write.future;
    });
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (_) async => null,
    );
  });
  tearDown(() {
    if (!write.isCompleted) write.complete(true);
    messenger.setMockMethodCallHandler(preferences, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
    'plugin store has one editor and one unclipped native search background',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PluginStorePage()));
      await tester.pump();
      expect(find.byType(SearchFieldSurface), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      final surfaces = find.byWidgetPredicate(
        (w) => w is UiKitView && w.viewType == 'breeze.search.surface',
      );
      expect(surfaces, findsOneWidget);
      var roundedAncestors = 0;
      tester.element(surfaces).visitAncestorElements((element) {
        if (element.widget is ClipRRect) roundedAncestors++;
        return true;
      });
      expect(roundedAncestors, 0);
      final editor = tester
          .widget<TextField>(find.byType(TextField))
          .controller;
      await tester.enterText(find.byType(TextField), '插件');
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller,
        same(editor),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'appearance choice retains its element and geometry while saving',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: InterfaceStyleSetting())),
      );
      await tester.pump();
      final finder = find.byType(SettingChoice<String>);
      final element = tester.element(finder);
      final rect = tester.getRect(finder);
      tester.widget<SettingChoice<String>>(finder).onChanged('breeze');
      await tester.pump();
      expect(finder, findsOneWidget);
      expect(tester.element(finder), same(element));
      expect(tester.getRect(finder), rect);
      expect(
        tester
            .widget<IgnorePointer>(
              find
                  .ancestor(of: finder, matching: find.byType(IgnorePointer))
                  .first,
            )
            .ignoring,
        isTrue,
      );
      write.complete(true);
      await tester.pumpAndSettle();
      expect(tester.element(finder), same(element));
      expect(tester.getRect(finder), rect);
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
