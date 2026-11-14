import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/native_playback_session.dart';
import 'package:zephyr/page/video/video_episode_download_picker.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

void main() {
  final episodes = [
    for (final id in ['one', 'two', 'three'])
      NativeVideoCard(
        title: '真实剧集 $id',
        watchUrl: Uri.parse(
          'https://fixture.test/voddetail/42.html?line=a&episode=$id',
        ),
        coverUrl: null,
      ),
    NativeVideoCard(
      title: '另一线路的真实标题',
      watchUrl: Uri.parse(
        'https://fixture.test/voddetail/42.html?line=b&episode=other',
      ),
      coverUrl: null,
    ),
    NativeVideoCard(
      title: '失效条目',
      watchUrl: Uri.parse('https://fixture.test/media.m3u8?line=a'),
      coverUrl: null,
    ),
  ];
  for (final style in ['system', 'breeze']) {
    testWidgets(
      '$style narrow large-text sheet selects actual episodes and cancels without submission',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final preference = ValueNotifier(style);
        addTearDown(preference.dispose);
        List<NativeVideoCard>? result;
        var completions = 0;
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: preference,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.8)),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async {
                      result = await showVideoEpisodeDownloadPicker(
                        context,
                        episodes: episodes,
                        currentWatch: episodes.first.watchUrl,
                        lineLabels: const {'a': '原站线路甲', 'b': '原站线路乙'},
                      );
                      completions++;
                    },
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        Future<void> open() async {
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
        }

        Future<void> click(Key key) async {
          final target = find.byKey(key);
          if (key is ValueKey<String> &&
              key.value.startsWith('download-episodes.item.')) {
            final list = find.byKey(const ValueKey('download-episodes.list'));
            await tester.ensureVisible(list);
            await tester.pumpAndSettle();
            final scrollable = find
                .descendant(of: list, matching: find.byType(Scrollable))
                .first;
            // Each action may return to an earlier, lazily unbuilt episode.
            tester.state<ScrollableState>(scrollable).position.jumpTo(0);
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              target,
              160,
              scrollable: scrollable,
            );
            await tester
                .state<ScrollableState>(scrollable)
                .position
                .ensureVisible(tester.renderObject(target));
            await tester.pumpAndSettle();
            final visible = tester
                .getRect(target)
                .intersect(tester.getRect(list));
            expect(visible.height, greaterThanOrEqualTo(44));
            await tester.tapAt(visible.center);
            await tester.pumpAndSettle();
            return;
          } else {
            if (target.evaluate().isEmpty &&
                key is ValueKey<String> &&
                (key.value == 'download-episodes.line' ||
                    key.value == 'download-episodes.select-all')) {
              final list = find.byKey(const ValueKey('download-episodes.list'));
              tester
                  .state<ScrollableState>(
                    find
                        .descendant(of: list, matching: find.byType(Scrollable))
                        .first,
                  )
                  .position
                  .jumpTo(0);
              await tester.pumpAndSettle();
            }
            await tester.ensureVisible(target);
          }
          await tester.pumpAndSettle();
          await tester.tap(target);
          await tester.pumpAndSettle();
        }

        await open();
        final initialList = find.byKey(
          const ValueKey('download-episodes.list'),
        );
        await tester.scrollUntilVisible(
          find.byKey(
            ValueKey('download-episodes.item.${episodes.first.watchUrl}'),
          ),
          160,
          scrollable: find
              .descendant(of: initialList, matching: find.byType(Scrollable))
              .first,
        );
        expect(find.text(t.videoPlayback.currentPlayback), findsOneWidget);
        final invalid = find.byKey(
          ValueKey('download-episodes.item.${episodes.last.watchUrl}'),
        );
        final list = find.byKey(const ValueKey('download-episodes.list'));
        await tester.ensureVisible(list);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          invalid,
          200,
          scrollable: find
              .descendant(of: list, matching: find.byType(Scrollable))
              .first,
        );
        expect(tester.widget<CheckboxListTile>(invalid).onChanged, isNull);
        tester
            .state<ScrollableState>(
              find
                  .descendant(of: list, matching: find.byType(Scrollable))
                  .first,
            )
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        await click(const ValueKey('download-episodes.select-all'));
        expect(
          find.text(t.videoPlayback.downloadEpisodeCount(count: 3)),
          findsOneWidget,
        );
        await click(const ValueKey('download-episodes.select-all'));
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('download-episodes.submit')),
              )
              .onPressed,
          isNull,
        );
        await click(ValueKey('download-episodes.item.${episodes[1].watchUrl}'));
        await click(const ValueKey('download-episodes.cancel'));
        expect(result, isNull);
        expect(completions, 1);
        await open();
        await click(ValueKey('download-episodes.item.${episodes[1].watchUrl}'));
        await click(const ValueKey('download-episodes.line'));
        await tester.tap(find.text('原站线路乙').last);
        await tester.pumpAndSettle();
        await click(ValueKey('download-episodes.item.${episodes[3].watchUrl}'));
        await click(const ValueKey('download-episodes.submit'));
        expect(result, [episodes[1], episodes[3]]);
        expect(completions, 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}
