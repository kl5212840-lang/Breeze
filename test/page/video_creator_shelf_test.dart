import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_creator_shelf.dart';
import 'package:zephyr/page/video/video_thumbnail.dart';
import 'package:zephyr/page/video/video_interaction.dart';

void main() {
  final page = Uri.parse('https://hanime1.me/subscriptions');
  final artist = <String, dynamic>{
    'entityKey': 'artist:11',
    'title': 'Example author',
    'pageUrl': 'https://hanime1.me/user/11',
    'followed': true,
  };
  List<Map<String, dynamic>> videos(int count) => [
    for (var i = 0; i < count; i++) {'id': i, 'title': 'Video $i'},
  ];
  Future<void> mount(
    WidgetTester tester, {
    Map<String, dynamic>? creator,
    int count = 9,
    PageStorageBucket? bucket,
    double width = 390,
    double scale = 1,
    bool opening = false,
    bool reduced = false,
    VoidCallback? onOpenCreator,
    VoidCallback? onOpenWorks,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reduced,
            ),
            child: PageStorage(
              bucket: bucket ?? PageStorageBucket(),
              child: SingleChildScrollView(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: VideoCreatorShelf(
                      key: const ValueKey('source.owner.artist:11'),
                      creator: creator ?? artist,
                      videos: videos(count),
                      page: page,
                      opening: opening,
                      onOpenCreator: onOpenCreator ?? () {},
                      onOpenWorks: onOpenWorks,
                      cardExtent: (_) => 80,
                      cardBuilder: (card) => Text(card['title'] as String),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder row() => find.byKey(const PageStorageKey('creator.videos.artist:11'));
  ScrollPosition position(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(of: row(), matching: find.byType(Scrollable)),
      )
      .position;

  testWidgets(
    'one header exposes profile and all works without a trailing card',
    (tester) async {
      var profiles = 0, works = 0;
      await mount(
        tester,
        onOpenCreator: () => profiles++,
        onOpenWorks: () => works++,
      );
      expect(find.text('Example author'), findsOneWidget);
      expect(find.text(t.videoCommunity.following), findsOneWidget);
      expect(find.text(t.videoCommunity.viewCreatorWorks), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('creator.open')));
      await tester.tap(find.byKey(const ValueKey('creator.works')));
      expect(profiles, 1);
      expect(works, 1);
      final list = tester.widget<ListView>(row());
      expect(list.scrollDirection, Axis.horizontal);
      await tester.drag(row(), const Offset(-4000, 0));
      await tester.pumpAndSettle();
      expect(find.text('Video 8'), findsOneWidget);
      expect(find.text(t.videoCommunity.viewCreatorWorks), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('empty author keeps actions together in the same header', (
    tester,
  ) async {
    var opened = 0;
    await mount(tester, count: 0, onOpenCreator: () => opened++);
    expect(find.byType(VideoCreatorShelf), findsOneWidget);
    expect(find.text(t.videoCommunity.viewCreatorWorks), findsOneWidget);
    expect(find.text(t.videoCommunity.emptyLibrary), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    await tester.tap(find.byKey(const ValueKey('creator.works')));
    expect(
      opened,
      1,
      reason: 'known profile may resolve its actual works link',
    );
  });

  testWidgets(
    'stable identity retains offset through metadata and target updates',
    (tester) async {
      final bucket = PageStorageBucket();
      await mount(tester, bucket: bucket);
      await tester.drag(row(), const Offset(-430, 0));
      await tester.pumpAndSettle();
      final before = position(tester).pixels;
      expect(before, greaterThan(100));
      await mount(
        tester,
        bucket: bucket,
        creator: {
          ...artist,
          'title': 'Updated name',
          'pageUrl': '/new-observed-target',
        },
      );
      expect(position(tester).pixels, closeTo(before, .1));
      await tester.tap(find.byKey(const ValueKey('creator.toggle')));
      await tester.pump();
      expect(row(), findsOneWidget, reason: 'keep the shelf during its exit');
      await tester.pumpAndSettle();
      expect(row(), findsNothing);
      expect(find.text(t.videoCommunity.viewCreatorWorks), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('creator.toggle')));
      await tester.pump();
      expect(position(tester).pixels, closeTo(before, .1));
      await mount(tester, bucket: bucket, count: 1);
      await tester.pump();
      expect(position(tester).pixels, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'bucket restores both collapse and offset after shelf recreation',
    (tester) async {
      final bucket = PageStorageBucket();
      await mount(tester, bucket: bucket);
      await tester.drag(row(), const Offset(-400, 0));
      await tester.pumpAndSettle();
      final before = position(tester).pixels;
      await tester.tap(find.byKey(const ValueKey('creator.toggle')));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await mount(tester, bucket: bucket);
      expect(row(), findsNothing);
      await tester.tap(find.byKey(const ValueKey('creator.toggle')));
      await tester.pump();
      expect(position(tester).pixels, closeTo(before, .1));
    },
  );

  testWidgets(
    'small large-type header wraps actions and preserves 44pt targets',
    (tester) async {
      await mount(
        tester,
        width: 288,
        scale: 2,
        creator: {
          ...artist,
          'title': 'Very long author name with words to wrap',
        },
      );
      expect(tester.takeException(), isNull);
      for (final key in ['creator.open', 'creator.works', 'creator.toggle']) {
        final rect = tester.getRect(find.byKey(ValueKey(key)));
        expect(rect.width, greaterThanOrEqualTo(44), reason: key);
        expect(rect.height, greaterThanOrEqualTo(44), reason: key);
      }
      final works = tester.getRect(find.byKey(const ValueKey('creator.works')));
      final profile = tester.getRect(
        find.byKey(const ValueKey('creator.open')),
      );
      expect(works.top, greaterThanOrEqualTo(profile.bottom));
      expect(works.right, lessThanOrEqualTo(288));
    },
  );

  testWidgets(
    'opening reserves avatar space and prevents repeated navigation',
    (tester) async {
      var opened = 0;
      await mount(tester, count: 0, onOpenCreator: () => opened++);
      final before = tester.getRect(find.byKey(const ValueKey('creator.open')));
      await mount(
        tester,
        count: 0,
        opening: true,
        onOpenCreator: () => opened++,
      );
      expect(
        tester.getRect(find.byKey(const ValueKey('creator.open'))),
        before,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('creator.open')));
      await tester.tap(find.byKey(const ValueKey('creator.works')));
      expect(opened, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('avatarUrl and name are supported without legacy fields', (
    tester,
  ) async {
    await mount(
      tester,
      count: 0,
      creator: {
        'entityKey': 'artist:11',
        'name': 'Name only',
        'avatarUrl': 'preferred-avatar',
        'coverUrl': 'legacy-avatar',
      },
    );
    expect(find.text('Name only'), findsOneWidget);
    expect(
      tester.widget<VideoThumbnail>(find.byType(VideoThumbnail)).url,
      'preferred-avatar',
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'disclosure reverses continuously without losing horizontal position',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await mount(tester);
        await tester.drag(row(), const Offset(-350, 0));
        await tester.pumpAndSettle();
        final before = position(tester).pixels;
        final region = find.byType(VideoDisclosureRegion);
        final full = tester.getSize(region).height;
        final toggle = find.byKey(const ValueKey('creator.toggle'));
        expect(
          tester.getSemantics(toggle),
          isSemantics(hasExpandedState: true, isExpanded: true),
        );
        await tester.tap(toggle);
        await tester.pump();
        expect(
          tester
              .widget<VideoDisclosureIndicator>(
                find.byType(VideoDisclosureIndicator),
              )
              .expanded,
          false,
        );
        expect(
          tester.getSemantics(toggle),
          isSemantics(hasExpandedState: true, isExpanded: false),
        );
        await tester.pump(const Duration(milliseconds: 70));
        final mid = tester.getSize(region).height;
        expect(mid, greaterThan(0));
        expect(mid, lessThan(full));
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tester.getSize(region).height, closeTo(full, .1));
        expect(position(tester).pixels, closeTo(before, .1));
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'reduced motion collapses immediately and restores its scroll offset',
    (tester) async {
      await mount(tester, reduced: true);
      await tester.drag(row(), const Offset(-350, 0));
      await tester.pumpAndSettle();
      final before = position(tester).pixels;
      await tester.tap(find.byKey(const ValueKey('creator.toggle')));
      await tester.pump();
      expect(row(), findsNothing);
      await tester.tap(find.byKey(const ValueKey('creator.toggle')));
      await tester.pump();
      expect(position(tester).pixels, closeTo(before, .1));
      final rotation = tester.widget<AnimatedRotation>(
        find.descendant(
          of: find.byType(VideoDisclosureIndicator),
          matching: find.byType(AnimatedRotation),
        ),
      );
      expect(rotation.turns, .25);
      expect(rotation.duration, Duration.zero);
      expect(tester.takeException(), isNull);
    },
  );
}
