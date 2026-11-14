import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_detail_page.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/omofun_favorites_page.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_favorites.dart';
import 'package:zephyr/page/video/source_profile_video_preview.dart';
import 'package:zephyr/page/video/omofun_account_page.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/service/collection_view_preferences.dart';
import 'package:zephyr/network/sync/portable_preferences.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/search/widget/search_field_surface.dart';

import '../test_helper.dart';

class _RejectViewStore extends InMemorySharedPreferencesStore {
  _RejectViewStore() : super.empty();
  bool rejectNextView = false;
  @override
  Future<bool> setValue(String type, String key, Object value) {
    if (rejectNextView && key.contains(CollectionViewPreferences.prefix)) {
      rejectNextView = false;
      return Future.value(false);
    }
    return super.setValue(type, key, value);
  }
}

Finder _bottomDestination(String label) => find.descendant(
  of: find.byType(VideoNativeNavigation),
  matching: find.text(label),
);

Future<void> _selectBottom(WidgetTester tester, String label) async {
  await tester.tap(_bottomDestination(label));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(CollectionViewPreferences.flush);
  testWidgets(
    'Omo navigation loads the account and following preview only on demand',
    (tester) async {
      tester.view.physicalSize = const Size(320, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final home = Uri.parse('https://www.omofuna.com/');
      const source = 'omo-navigation-fixture';
      final store = VideoLibraryStore.shared;
      ApiVideoItem favorite(int index, Uri origin) => ApiVideoItem(
        id: '1234567890abcde$index',
        title: 'Local favorite $index',
        detailUrl: origin.resolve('/anime/1234567890abcde$index.html'),
      );
      for (var index = 0; index < 5; index++) {
        await store.setFavorite(source, favorite(index, home), true);
      }
      await store.setFavorite('other-source', favorite(5, home), true);
      await store.setFavorite(
        source,
        favorite(6, Uri.parse('https://other.example/')),
        true,
      );
      final catalog = <String>[], operations = <String>[];
      final client = OmoSiteClient(
        home: home,
        request: (operation, args) async {
          operations.add(operation);
          if (operation == 'favorites') {
            return {
              'kind': 'favorites',
              'items': [],
              'rawCount': 0,
              'hasMore': false,
            };
          }
          return {
            'kind': 'account',
            'account': {'id': '1', 'name': '显示昵称', 'group': '游客'},
          };
        },
      );
      addTearDown(client.dispose);
      final repository = ApiVideoRepository(
        source: source,
        home: home,
        catalogFn: 'catalog',
        detailFn: 'detail',
        playbackFn: 'play',
        capabilities: const ApiVideoCapabilities(
          presentation: 'anime',
          siteAccount: true,
          recent: false,
        ),
        pluginCall: (operation, args) async {
          if (operation == 'detail') {
            return {'data': favorite(4, home).toLibraryJson()};
          }
          catalog.add('${args['typeId']}');
          return {
            'data': {
              'items': [],
              'categories': [
                {'id': 'type:1', 'parentId': '0', 'name': '日漫'},
                {'id': 'week:0', 'parentId': 'week', 'name': '周一'},
              ],
              'total': 0,
              'page': 1,
              'pageCount': 1,
            },
          };
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: ApiVideoLibraryPage(
            repository: repository,
            title: 'OmoFun',
            siteClient: client,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<VideoNativeNavigation>(find.byType(VideoNativeNavigation))
            .items
            .map((item) => item.label),
        [
          t.videoSource.discover,
          t.videoSource.weeklyTab,
          t.videoSource.rankingTab,
          t.videoSource.topicsTab,
          t.videoSource.me,
        ],
      );
      expect(catalog, ['']);
      expect(operations, isEmpty);
      await _selectBottom(tester, t.videoSource.me);
      expect(find.text('显示昵称'), findsOneWidget);
      expect(find.text(t.videoSource.login), findsNothing);
      expect(operations, ['account', 'favorites']);
      expect(find.byKey(const ValueKey('api-library.view-mode')), findsNothing);
      expect(find.text(t.videoSource.siteFavorites), findsOneWidget);
      expect(find.byType(OmoSiteFavoritesPage), findsNothing);

      Finder rail(String title) => find.byWidgetPredicate(
        (widget) =>
            widget is SourceProfileVideoPreview && widget.title == title,
      );
      final local = rail(t.videoSource.localFavorites);
      SourceProfileVideoPreview localPreview() => tester.widget(local);
      expect(local, findsOneWidget);
      expect(
        tester.getTopLeft(local).dy,
        lessThan(tester.getTopLeft(rail(t.omoAccount.localHistory)).dy),
      );
      expect(localPreview().countLabel, '5');
      expect(localPreview().items.map((item) => item.title), [
        'Local favorite 4',
        'Local favorite 3',
        'Local favorite 2',
        'Local favorite 1',
      ]);

      final recent = find.text(favorite(4, home).title);
      await tester.ensureVisible(recent);
      await tester.tap(recent);
      await tester.pumpAndSettle();
      final detail = find.byType(ApiVideoDetailPage);
      expect(detail, findsOneWidget);
      expect(
        tester.widget<ApiVideoDetailPage>(detail).initialItem.detailUrl,
        favorite(4, home).detailUrl,
      );
      expect(find.byType(ApiVideoFavorites), findsNothing);
      Navigator.of(tester.element(detail)).pop();
      await tester.pumpAndSettle();

      await store.setFavorite(source, favorite(4, home), false);
      await tester.pumpAndSettle();
      expect(localPreview().countLabel, '4');
      expect(localPreview().items.map((item) => item.title), [
        'Local favorite 3',
        'Local favorite 2',
        'Local favorite 1',
        'Local favorite 0',
      ]);

      final localViewAll = find.byKey(
        ValueKey<(String, Key)>((
          'profile-view-all',
          ValueKey(localPreview().identity),
        )),
      );
      await Scrollable.ensureVisible(
        tester.element(localViewAll),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      expect(localViewAll.hitTestable(), findsOneWidget);
      await tester.tap(localViewAll.hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(ApiVideoFavorites), findsOneWidget);
      expect(find.text(favorite(3, home).title), findsOneWidget);
      expect(find.text(favorite(5, home).title), findsNothing);
      expect(find.text(favorite(6, home).title), findsNothing);
      expect(find.byType(VideoNativeNavigation), findsNothing);
      await tester.tap(find.byTooltip(t.common.back));
      await tester.pumpAndSettle();
      expect(find.byType(ApiVideoFavorites), findsNothing);
      expect(
        tester
            .widget<VideoNativeNavigation>(find.byType(VideoNativeNavigation))
            .currentIndex,
        4,
      );

      await tester.scrollUntilVisible(
        find.text(t.videoSource.siteFavorites),
        120,
        scrollable: find.descendant(
          of: find.byType(OmoAccountPage),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        ),
      );
      final preview = tester.widget<SourceProfileVideoPreview>(
        find.byWidgetPredicate(
          (widget) =>
              widget is SourceProfileVideoPreview &&
              widget.title == t.videoSource.siteFavorites,
        ),
      );
      final follows = find.byKey(
        ValueKey<(String, Key)>(('profile-open', ValueKey(preview.identity))),
      );
      await Scrollable.ensureVisible(tester.element(follows), alignment: .5);
      await tester.pumpAndSettle();
      expect(follows.hitTestable(), findsOneWidget);
      await tester.tap(follows);
      await tester.pumpAndSettle();
      expect(find.byType(OmoSiteFavoritesPage), findsOneWidget);
      expect(find.byKey(const ValueKey('omo-favorites.view')), findsOneWidget);
      await tester.tap(find.byTooltip(t.common.back));
      await tester.pumpAndSettle();

      await _selectBottom(tester, t.videoSource.weeklyTab);
      expect(catalog.last, 'week:0');
      final feed = tester.widget<NativeVideoSegmentedControl>(
        find.byKey(const ValueKey('api-recommendation.week-feed')),
      );
      feed.onSelected!('feed');
      await tester.pumpAndSettle();
      expect(catalog, ['', 'week:0', 'recent:feed']);
      await _selectBottom(tester, t.videoSource.discover);
      expect(catalog, ['', 'week:0', 'recent:feed']);
      expect(tester.takeException(), isNull);
    },
  );

  Future<({List<String> calls, ApiVideoRepository repository})>
  mountRecommendations(
    WidgetTester tester,
    String source, {
    String module = '',
  }) async {
    final home = Uri.parse('https://www.omofuna.com/');
    final calls = <String>[];
    final client = OmoSiteClient(
      home: home,
      request: (_, _) async => {'kind': 'signedOut'},
    );
    addTearDown(client.dispose);
    final repository = ApiVideoRepository(
      source: source,
      home: home,
      catalogFn: 'catalog',
      detailFn: 'detail',
      playbackFn: 'play',
      capabilities: ApiVideoCapabilities(
        presentation: 'anime',
        siteAccount: true,
        recent: false,
        itemNamespace: module,
      ),
      pluginCall: (fn, args) async {
        if (fn != 'catalog') {
          return {
            'data': {
              'id': 'fixture',
              'title': 'Fixture',
              'detailUrl': '${home}anime/1234567890abcdef.html',
              'lines': [],
            },
          };
        }
        calls.add('${args['typeId']}');
        return {
          'data': {
            'items': [],
            'total': 0,
            'page': 1,
            'pageCount': 1,
            'categories': [
              {'id': 'type:1', 'parentId': '0', 'name': '日漫'},
              {
                'id': 'week',
                'parentId': '0',
                'name': '排期组',
                'selectable': false,
              },
              {
                'id': 'rank',
                'parentId': '0',
                'name': '榜单组',
                'selectable': false,
              },
              {
                'id': 'topics',
                'parentId': '0',
                'name': '专题组',
                'selectable': false,
              },
              for (var day = 0; day < 7; day++)
                {'id': 'week:$day', 'parentId': 'week', 'name': '排期$day'},
              {'id': 'rank:dayhot', 'parentId': 'rank', 'name': '日榜'},
              {'id': 'rank:weekhot', 'parentId': 'rank', 'name': '周榜'},
              {
                'id': 'topic:1',
                'parentId': 'topics',
                'name': '季度专题甲',
                'description': '源站专题说明甲',
              },
              {
                'id': 'topic:2',
                'parentId': 'topics',
                'name': '季度专题乙',
                'description': '源站专题说明乙',
              },
            ],
          },
        };
      },
    );
    final style = ValueNotifier('breeze');
    addTearDown(style.dispose);
    await tester.pumpWidget(
      AppInterfaceStyleScope(
        style: style,
        child: MaterialApp(
          home: ApiVideoLibraryPage(
            key: ValueKey('$source|$module'),
            repository: repository,
            title: 'OmoFun',
            siteClient: client,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (calls: calls, repository: repository);
  }

  testWidgets('phone Discover leaves room for search and keeps view in More', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mountRecommendations(tester, 'recommendation-phone-toolbar');
    expect(find.byKey(const ValueKey('api-library.view-mode')), findsNothing);
    final field = tester.getRect(find.byType(SearchFieldSurface));
    final more = find.byType(SourceMoreButton);
    final target = tester.getRect(more);
    expect(field.width, greaterThanOrEqualTo(180));
    expect(field.center.dy, closeTo(target.center.dy, .01));
    expect(target.size, const Size(44, 44));
    expect(
      tester.widget<SourceMoreButton>(more).actions.map((e) => e.id),
      contains('display'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'recommendation tabs keep their categories and Discover filters separate',
    (tester) async {
      final fixture = await mountRecommendations(
        tester,
        'recommendation-routes',
      );
      await tester.tap(find.text(t.videoLibrary.moreCategories));
      await tester.pumpAndSettle();
      expect(find.text('排期组'), findsNothing);
      expect(find.text('榜单组'), findsNothing);
      expect(find.text('专题组'), findsNothing);
      await tester.tap(find.text('${t.videoLibrary.all} 日漫'));
      await tester.pumpAndSettle();
      expect(fixture.calls.last, 'type:1');

      for (final (label, prefix) in [
        (t.videoSource.weeklyTab, 'week:'),
        (t.videoSource.rankingTab, 'rank:'),
        (t.videoSource.topicsTab, 'topic:'),
      ]) {
        await _selectBottom(tester, label);
        final selection = find.byKey(
          const ValueKey('api-recommendation.selection'),
        );
        expect(selection, findsOneWidget);
        expect(find.byType(VideoNativeNavigation), findsOneWidget);
        expect(fixture.calls.last, startsWith(prefix));
        expect(find.text(t.videoLibrary.clearFilters), findsNothing);
        await tester.tap(selection);
        await tester.pumpAndSettle();
        if (prefix == 'topic:') {
          expect(find.text('源站专题说明乙'), findsOneWidget);
          await tester.tap(find.text('季度专题乙'));
          await tester.pumpAndSettle();
          expect(fixture.calls.last, 'topic:2');
        } else {
          Navigator.of(tester.element(selection)).pop();
          await tester.pumpAndSettle();
        }
      }
      final before = fixture.calls.length;
      await _selectBottom(tester, t.videoSource.discover);
      expect(fixture.calls.length, before);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '日漫'))
            .selected,
        isTrue,
      );
      await _selectBottom(tester, t.videoSource.topicsTab);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('api-recommendation.selection')),
          matching: find.text('季度专题乙'),
        ),
        findsOneWidget,
      );
      expect(fixture.calls.length, before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recommendation views share scoped library preference, keep favorites independent and react to restore',
    (tester) async {
      const source = 'recommendation-view';
      final legacy = 'breeze.video.library.view.$source';
      SharedPreferences.setMockInitialValues({legacy: 'list'});
      final fixture = await mountRecommendations(tester, source);
      final scope = 'plugin|$source|${fixture.repository.home}|library';
      expect(
        tester
            .widget<ApiVideoCollection>(find.byType(ApiVideoCollection).first)
            .mode,
        ApiVideoView.list,
      );
      await _selectBottom(tester, t.videoSource.rankingTab);
      await tester.tap(find.byKey(const ValueKey('api-library.view-mode')));
      await tester.pumpAndSettle();
      expect(await CollectionViewPreferences.read(scope), 'grid');
      expect((await SharedPreferences.getInstance()).getString(legacy), 'list');
      await _selectBottom(tester, t.videoSource.discover);
      expect(
        tester
            .widget<ApiVideoCollection>(find.byType(ApiVideoCollection).first)
            .mode,
        ApiVideoView.grid,
      );
      final favoriteScope =
          'plugin|$source|${fixture.repository.home}|favorite';
      expect(
        await CollectionViewPreferences.read(favoriteScope, legacyKey: legacy),
        'list',
      );
      await _selectBottom(tester, t.videoSource.topicsTab);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CollectionViewPreferences.keyFor(scope), 'list');
      PortablePreferences
          .changes
          .value++; // Same notification used after an actual portable restore.
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ApiVideoCollection>(find.byType(ApiVideoCollection).first)
            .mode,
        ApiVideoView.list,
      );
      expect(fixture.calls.last, startsWith('topic:'));
    },
  );

  testWidgets(
    'failed scoped view save re-reads storage and leaves the legacy default untouched',
    (tester) async {
      final store = _RejectViewStore();
      SharedPreferencesStorePlatform.instance = store;
      final fixture = await mountRecommendations(
        tester,
        'recommendation-save-failure',
      );
      final scope =
          'plugin|recommendation-save-failure|${fixture.repository.home}|library';
      await _selectBottom(tester, t.videoSource.weeklyTab);
      store.rejectNextView = true;
      await tester.tap(find.byKey(const ValueKey('api-library.view-mode')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ApiVideoCollection>(find.byType(ApiVideoCollection).first)
            .mode,
        ApiVideoView.grid,
      );
      expect(await CollectionViewPreferences.read(scope), isNull);
      expect(find.text(t.videoLibrary.saveFailed), findsOneWidget);
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          'breeze.video.library.view.recommendation-save-failure',
        ),
        isFalse,
      );
    },
  );

  testWidgets('module namespaces do not share the same plugin library view', (
    tester,
  ) async {
    const source = 'module-view-fixture';
    await CollectionViewPreferences.write(
      'plugin|$source|movie|library',
      'list',
    );
    await CollectionViewPreferences.write(
      'plugin|$source|anime|library',
      'grid',
    );
    await mountRecommendations(tester, source, module: 'movie');
    expect(
      tester
          .widget<ApiVideoCollection>(find.byType(ApiVideoCollection).first)
          .mode,
      ApiVideoView.list,
    );
    await mountRecommendations(tester, source, module: 'anime');
    expect(
      tester
          .widget<ApiVideoCollection>(find.byType(ApiVideoCollection).first)
          .mode,
      ApiVideoView.grid,
    );
  });
}
