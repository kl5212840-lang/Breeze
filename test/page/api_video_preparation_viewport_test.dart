import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/video/api_video_detail_page.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final textScale in [1.0, 2.0]) {
    testWidgets('preparation viewport reserves visible details in landscape and preserves portrait geometry at ${textScale}x text', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(956, 440);
      final style = ValueNotifier('breeze');
      final pending = Completer<Map<String, dynamic>>();
      final home = Uri.parse('https://viewport-fixture.test/');
      final raw = <String, dynamic>{
        'id': '42', 'title': 'Viewport fixture', 'description': 'A public description remains available while resolution is pending.',
        'detailUrl': '${home}voddetail/42.html',
        'lines': [{'id': 'main', 'label': 'Line', 'episodes': [
          {'id': 'one', 'title': 'Episode 1', 'resolveOnPlayback': true, 'watchUrl': '${home}voddetail/42.html?line=main&episode=one'},
        ]}],
      };
      final item = ApiVideoItem.fromJson(raw, home: home);
      expect(item.lines.single.episodes.single.watchUrl, home.resolve('voddetail/42.html?line=main&episode=one'));
      final calls = <String>[];
      final repository = ApiVideoRepository(source: 'viewport-fixture', home: home, catalogFn: 'list', detailFn: 'detail', playbackFn: 'play',
        pluginCall: (path, _) async {
          calls.add(path);
          return path == 'play' ? pending.future : {'data': raw};
        });
      try {
        await tester.pumpWidget(AppInterfaceStyleScope(style: style, child: MaterialApp(
          builder: (context, child) {
            final media = MediaQuery.of(context);
            final landscape = media.size.width > media.size.height;
            return MediaQuery(data: media.copyWith(
              padding: landscape ? const EdgeInsets.fromLTRB(44, 24, 44, 21) : const EdgeInsets.only(top: 60, bottom: 34),
              textScaler: TextScaler.linear(textScale),
            ), child: child!);
          },
          home: ApiVideoDetailPage(repository: repository, initialItem: item),
        )));
        for (var i = 0; i < 50 && !calls.contains('play'); i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(calls, containsAllInOrder(['detail', 'play']), reason: 'Real validated episodes reach the pending resolver before checking the preparation shell');
        final surface = find.byKey(const ValueKey('api-initial.gesture-surface'));
        final back = find.byKey(const ValueKey('api-initial.back'));
        final episodes = find.byKey(const ValueKey('api-initial.episodes'));
        final videoRect = tester.getRect(surface);
        expect(videoRect, const Rect.fromLTWH(44, 24, 868, 237));
        await tester.ensureVisible(episodes); await tester.pump();
        expect(tester.getRect(episodes).top, greaterThanOrEqualTo(videoRect.bottom));
        expect(tester.getRect(episodes).bottom, lessThanOrEqualTo(419));
        expect(episodes.hitTestable(), findsOneWidget);
        expect(tester.getRect(back), const Rect.fromLTWH(52, 32, 44, 44));
        expect(back.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Natural 16:9 landscape height and accessibility minimum cannot overflow the short viewport');
        tester.view.physicalSize = const Size(440, 956);
        await tester.pump(); await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getRect(surface), const Rect.fromLTWH(0, 60, 440, 247.5));
        expect(tester.getRect(back), const Rect.fromLTWH(8, 68, 44, 44));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        if (!pending.isCompleted) pending.complete({'data': raw});
        await tester.pump(const Duration(milliseconds: 500));
        style.dispose(); tester.view.resetPhysicalSize(); tester.view.resetDevicePixelRatio();
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }
}
