import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_cover_overlay.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';

void main() {
  test(
    'known duration never derives a total from a watch position or invents zero',
    () {
      expect(formatKnownVideoDuration(Duration.zero), isEmpty);
      expect(
        formatKnownVideoDuration(
          const Duration(hours: 1, minutes: 23, seconds: 45),
        ),
        '1:23:45',
      );
      expect(knownVideoDurationText('0:00'), isEmpty);
      expect(knownVideoDurationText('--:--'), isEmpty);
      expect(knownVideoDurationText('45 min'), '45 min');
      expect(knownVideoDurationText('02:42:25'), '2:42:25');
      expect(knownVideoDurationText('00:23:55'), '23:55');
      expect(videoCoverDurationText('', clockFallback: '1:30'), '1:30');
      expect(videoCoverDurationText('--:--', clockFallback: '02:42:25'), '2:42:25');
      expect(videoCoverDurationText('45 min', clockFallback: '1:30'), '45 min');
      for (final unknown in ['已看到 1:30', '1:99', '16:9', '更新至30集', '0:00', '未知']) {
        expect(videoCoverDurationText('', clockFallback: unknown), isEmpty);
      }
      expect(knownVideoDurationText('1:99'), isEmpty);
    },
  );

  testWidgets('compact known-duration poster keeps its full triangle and clock', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Center(child: SizedBox(
      key: const ValueKey('compact-poster'), width: 42, height: 63,
      child: const VideoCoverOverlay(durationText: '1:30', child: ColoredBox(color: Colors.grey)),
    ))));
    final frame = tester.getRect(find.byKey(const ValueKey('compact-poster')));
    final duration = tester.getRect(find.text('1:30'));
    expect(frame.contains(duration.topLeft), isTrue);
    expect(frame.contains(duration.bottomRight - const Offset(.1, .1)), isTrue);
    expect(find.byKey(const ValueKey('video-cover-marker')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final style in CollectionCoverStyle.values) {
    testWidgets(
      'real poster keeps its media marker above $style protection and preserves card gestures',
      (tester) async {
        final privacy = CollectionCoverPrivacyController.instance;
        final before = privacy.state.value;
        privacy.state.value = CollectionCoverPrivacySettings(
          enabled: true,
          ready: true,
          style: style,
        );
        addTearDown(() => privacy.state.value = before);
        var taps = 0, holds = 0;
        Future<void> mount(String duration, {String remarks = ''}) => tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  key: const ValueKey('poster-bounds'),
                  width: 80,
                  height: 120,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => taps++,
                    onLongPress: () => holds++,
                    child: CollectionCoverPrivacyScope(
                      child: ApiVideoPoster(
                        item: ApiVideoItem(
                          id: 'fixture',
                          title: 'Video',
                          detailUrl: Uri.parse(
                            'https://fixture.test/voddetail/1.html',
                          ),
                          sourceDuration: duration,
                          remarks: remarks,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await mount('1:23:45');
        await tester.pumpAndSettle();
        final marker = find.byKey(const ValueKey('video-cover-marker'));
        expect(marker, findsOneWidget);
        expect(tester.widget<Icon>(marker).icon, Icons.play_arrow_rounded);
        expect(
          find.ancestor(
            of: marker,
            matching: find.byType(CollectionCoverPrivacy),
          ),
          findsNothing,
        );
        final bounds = tester.getRect(
          find.byKey(const ValueKey('poster-bounds')),
        );
        final duration = tester.getRect(find.text('1:23:45'));
        expect(bounds.contains(duration.topLeft), isTrue);
        expect(
          bounds.contains(duration.bottomRight - const Offset(.1, .1)),
          isTrue,
        );
        await tester.tap(marker);
        await tester.longPress(marker);
        expect(taps, 1);
        expect(holds, 1);
        await mount('', remarks: '1:30');
        await tester.pumpAndSettle();
        expect(find.text('1:30'), findsOneWidget,
          reason: 'a legacy bare source clock stays above the protected image');
        await mount('', remarks: '已看到 1:30');
        await tester.pumpAndSettle();
        expect(find.text('1:30'), findsNothing);
        expect(marker, findsOneWidget);
        expect(find.text('0:00'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
