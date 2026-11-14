import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/widgets/native_view_occlusion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final routeName in [
    'breeze.download.comic-chapters',
    'breeze.download.video-work',
    'breeze.download.settings',
  ]) {
    testWidgets(
      '$routeName is identified for diagnostics without admitting paint culling',
      (tester) async {
        final samples = <Map<String, Object?>>[];
        final observer = NativeCompositionObserver(diagnostics: samples.add);
        final navigator = GlobalKey<NavigatorState>();
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          (_) async => null,
        );
        addTearDown(
          () => messenger.setMockMethodCallHandler(
            SystemChannels.platform_views,
            null,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            navigatorObservers: [observer],
            home: Scaffold(
              body: SourceChromeIconButton(
                icon: Icons.search,
                symbol: 'magnifyingglass',
                tooltip: 'source',
                onPressed: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            settings: RouteSettings(name: routeName),
            builder: (_) => const Scaffold(body: Text('work')),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        expect(
          samples.any(
            (sample) =>
                sample['event'] == 'route-added' &&
                sample['route'] == routeName,
          ),
          isTrue,
        );
        expect(observer.candidateRoutes, isEmpty);
        expect(observer.candidateOpaqueDestinations, isEmpty);
        expect(
          samples
              .where((sample) => sample['event'] == 'control-paint')
              .any(
                (sample) => const {
                  'covered',
                  'covered-offscreen',
                  'partly-visible',
                }.contains(sample['decision']),
              ),
          isFalse,
        );
        await tester.pumpAndSettle();
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(
          samples.any(
            (sample) =>
                sample['event'] == 'route-removed' &&
                sample['route'] == routeName,
          ),
          isTrue,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets(
    'composition observations are bounded, redact content and preserve UIKit identity',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var creates = 0;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') creates++;
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        ),
      );
      final samples = <Map<String, Object?>>[];
      final observer = NativeCompositionObserver(
        candidateRoutes: const {
          '/': {'PRIVATE_ROUTE_VALUE'},
        },
        diagnostics: samples.add,
        diagnosticBudget: 8,
      );
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [observer],
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: Scaffold(
            body: Center(
              child: ClipRRect(
                key: const ValueKey('PRIVATE_CLIP_KEY_VALUE'),
                clipBehavior: Clip.hardEdge,
                borderRadius: BorderRadius.circular(14),
                child: SourceChromeIconButton(
                  icon: Icons.settings,
                  symbol: 'gearshape',
                  tooltip: 'PRIVATE_LABEL_VALUE',
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final original = tester.state(find.byType(UiKitView));
      expect(creates, 1);
      for (var iteration = 0; iteration < 4; iteration++) {
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'PRIVATE_ROUTE_VALUE'),
            builder: (_) => const Scaffold(body: Text('PRIVATE_PAGE_VALUE')),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        await tester.pumpAndSettle();
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(UiKitView)), same(original));
      }
      expect(samples, isNotEmpty);
      expect(samples.length, lessThanOrEqualTo(8));
      expect(
        samples.any((sample) => sample['event'] == 'control-paint'),
        isTrue,
      );
      final ancestry = samples
          .where((sample) => sample['event'] == 'control-paint')
          .expand((sample) => sample['platformViewAncestry'] as List)
          .cast<Map>();
      expect(
        ancestry.any(
          (view) => (view['nonRectClips'] as List).cast<Map>().any(
            (clip) =>
                clip['renderType'] == 'RenderClipRRect' &&
                clip['widgetType'] == 'ClipRRect' &&
                clip['clipBehavior'] == 'hardEdge' &&
                (clip['rect'] as List).length == 4,
          ),
        ),
        isTrue,
      );
      expect(jsonEncode(samples), isNot(contains('PRIVATE_')));
      expect(creates, 1);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
