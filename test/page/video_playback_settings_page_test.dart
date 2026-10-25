import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';
import 'package:zephyr/page/video/video_playback_settings_page.dart';

Future<void> pump(WidgetTester tester, [int count = 5]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('control styles switch and persist with large phone text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const VideoPlaybackSettingsPage(),
      ),
    );
    await pump(tester);
    for (final style in ['breeze', 'system']) {
      await tester.scrollUntilVisible(
        find.text(t.videoPlayback.controlsStyle).hitTestable(),
        150,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.videoPlayback.controlsStyle).hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .widgetWithText(
              ListTile,
              style == 'breeze'
                  ? t.videoPlayback.breezeControls
                  : t.videoPlayback.systemControls,
            )
            .last,
      );
      await pump(tester);
      expect((await VideoPlaybackPreferences.read()).controlsStyle, style);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('history disables resume and a rejected save stays unchanged', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: VideoPlaybackSettingsPage()),
    );
    await pump(tester);
    await tester.scrollUntilVisible(
      find.text(t.videoPlayback.recordHistory).hitTestable(),
      250,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    final historyRow = find.widgetWithText(
      SwitchListTile,
      t.videoPlayback.recordHistory,
    );
    // A visible title does not guarantee that a multiline row's tap center is
    // inside the viewport after content-driven density or text-size changes.
    await tester.ensureVisible(historyRow);
    await tester.pumpAndSettle();
    await tester.tap(historyRow);
    await pump(tester);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, t.videoPlayback.resumeProgress),
          )
          .onChanged,
      isNull,
    );
    expect((await VideoPlaybackPreferences.read()).recordHistory, isFalse);
    await tester.pumpWidget(
      MaterialApp(
        home: VideoPlaybackSettingsPage(
          key: const ValueKey('failure'),
          savePreference: (_, _) async =>
              throw StateError('storage unavailable'),
        ),
      ),
    );
    await pump(tester);
    await tester.tap(
      find.widgetWithText(SwitchListTile, t.videoPlayback.autoplay),
    );
    await pump(tester);
    expect(find.text(t.videoPlayback.settingsSaveFailed), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, t.videoPlayback.autoplay),
          )
          .value,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('stalled settings load ends in a retryable error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VideoPlaybackSettingsPage(
          readPreferences: () => Completer<VideoPlaybackPreferences>().future,
        ),
      ),
    );
    await pump(tester, 40);
    expect(find.text(t.videoPlayback.settingsLoadFailed), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(t.common.retry), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a save is serialized and a failed reread offers retry', (
    tester,
  ) async {
    final save = Completer<void>();
    var reads = 0;
    var writes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: VideoPlaybackSettingsPage(
          readPreferences: () async {
            if (++reads == 2) throw StateError('storage unavailable');
            return const VideoPlaybackPreferences();
          },
          savePreference: (_, _) {
            writes++;
            return save.future;
          },
        ),
      ),
    );
    await pump(tester);
    await tester.tap(
      find.widgetWithText(SwitchListTile, t.videoPlayback.autoplay),
    );
    await pump(tester);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(tester.widget<PopScope>(find.byType(PopScope).last).canPop, isFalse);
    // A repeated physical tap cannot issue another write while saving.
    await tester.tapAt(tester.getCenter(find.text(t.videoPlayback.autoplay)));
    expect(writes, 1);
    save.complete();
    await pump(tester);
    expect(find.text(t.videoPlayback.settingsLoadFailed), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNothing);
    await tester.tap(find.text(t.common.retry));
    await pump(tester);
    expect(find.text(t.videoPlayback.settingsLoadFailed), findsNothing);
    expect(find.byType(SwitchListTile), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('speed choices scroll with large phone text and persist', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const VideoPlaybackSettingsPage(),
      ),
    );
    await pump(tester);
    await tester.scrollUntilVisible(
      find.text(t.videoPlayback.defaultSpeed),
      150,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.tap(find.text(t.videoPlayback.defaultSpeed));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('2.0×'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('2.0×').hitTestable(), findsOneWidget);
    await tester.tap(find.text('2.0×'));
    await pump(tester);
    expect((await VideoPlaybackPreferences.read()).defaultSpeed, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'settings search filters real source fields and keeps host preferences isolated',
    (tester) async {
      var quality = 'auto';
      final sourceWrites = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: VideoPlaybackSettingsPage(
            source: 'fixture-video',
            sourceName: 'Fixture',
            readSourceBundle: () async => {
              'scheme': {
                'sections': [
                  {
                    'fields': [
                      {
                        'key': 'video.preferredSource',
                        'kind': 'select',
                        'label': 'Source quality',
                        'options': [
                          {'value': 'auto', 'label': 'Auto'},
                          {'value': 'highest', 'label': 'Highest'},
                        ],
                      },
                    ],
                  },
                ],
              },
              'data': {
                'values': {'video.preferredSource': quality},
              },
            },
            saveSourcePreference: (key, value) async {
              sourceWrites.add(key);
              quality = value as String;
            },
          ),
        ),
      );
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'quality');
      await tester.pump();
      expect(find.text(t.videoPlayback.autoplay), findsNothing);
      await tester.tap(find.text('Source quality'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Highest'));
      await pump(tester);
      expect(sourceWrites, ['video.preferredSource']);
      expect(quality, 'highest');
      expect((await VideoPlaybackPreferences.read()).defaultSpeed, 1);
      await tester.enterText(find.byType(TextField), 'animation');
      await tester.pump();
      expect(find.text(t.videoPlayback.settingsMotionNote), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'unknown-absent');
      await tester.pump();
      expect(find.text(t.videoPlayback.settingsSearchEmpty), findsOneWidget);
      expect(tester.takeException(), null);
    },
  );
}
