import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';

void main() {
  final home = Uri.parse('https://example.org/');
  final modu = Uri.parse('https://www.mdzyapi.com/');
  Map<String, dynamic> wire(Uri origin) => {
    'id': '42',
    'title': 'Fixture',
    'detailUrl': origin.resolve('video/42').toString(),
  };

  test('known zero clicks survive the wire and snapshots', () {
    final sourceCounters = {'day': 0, 'week': 0, 'month': 0};
    final legacy = ApiVideoItem.fromJson({
      ...wire(modu),
      'sourceViews': 12,
      'sourceCounters': sourceCounters,
    }, home: modu);
    expect(legacy.sourceViewsAreClicks, isTrue);
    expect(legacy.sourceViews, 12);
    expect(legacy.sourceCounters, isEmpty);

    final observed = ApiVideoItem.fromJson({
      ...wire(modu),
      'sourceViews': 0,
      'sourceViewsKind': 'clicks',
      'sourceCounters': sourceCounters,
      'sourceRating': 1.1,
      'sourceRatingCount': 611,
      'sourceRatingCountConsistent': false,
    }, home: modu);
    final retained = ApiVideoItem.fromJson(
      Map<String, dynamic>.of(observed.toLibraryJson()),
      home: modu,
    );
    expect(retained.sourceViews, 0);
    expect(retained.sourceCounters, sourceCounters);
    expect(retained.sourceRating, 1.1);
    expect(retained.sourceRatingCount, 611);
    expect(retained.sourceRatingDisplayCount, isNull);
  });

  test('generic source views distinguish zero from absent', () {
    final missing = ApiVideoItem.fromJson(wire(home), home: home);
    final zero = ApiVideoItem.fromJson({
      ...wire(home),
      'sourceViews': '0',
    }, home: home);
    expect(missing.sourceViews, isNull);
    expect(zero.sourceViews, 0);
    expect(zero.sourceViewsAreClicks, isFalse);
  });

  testWidgets('remote search labels an unknown total as loaded works', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = ApiVideoRepository(
      source: 'numeric-catalog-fixture',
      home: home,
      catalogFn: 'catalog',
      detailFn: 'detail',
      playbackFn: 'play',
      pluginCall: (_, args) async => {
        'data': {
          'page': 1,
          'pageCount': 2,
          'total': 1,
          'totalKnown': false,
          'items': [wire(home)],
          'categories': [],
        },
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ApiVideoLibraryPage(
          repository: repository,
          title: 'Fixture',
          initialQuery: 'fixture',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(t.videoLibrary.loadedResults(count: 1)), findsOneWidget);
    expect(find.text(t.videoLibrary.results(count: 1)), findsNothing);
  });
}
