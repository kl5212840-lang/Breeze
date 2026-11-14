import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_favorites.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/omofun_favorites_page.dart';
import 'package:zephyr/page/video/omofun_site_client.dart';
import 'package:zephyr/page/video/video_browse_theme.dart';
import 'package:zephyr/page/video/video_library_store.dart';

OmoSiteClient siteClient() => OmoSiteClient(
  home: Uri.parse('https://www.omofuna.com/'),
  request: (operation, _) async => operation == 'account'
      ? {
          'kind': 'account',
          'account': {'id': '1', 'name': '测试'},
        }
      : {
          'kind': 'favorites',
          'rawCount': 1,
          'hasMore': false,
          'items': [
            {
              'recordId': '20',
              'vodId': '1',
              'item': {
                'id': 'aaaaaaaaaaaaaaaa',
                'title': '收藏布局样本',
                'detailUrl':
                    'https://www.omofuna.com/anime/aaaaaaaaaaaaaaaa.html',
              },
            },
          ],
        },
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final brightness in Brightness.values) {
    testWidgets('collection controls are readable in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final client = siteClient();
      addTearDown(client.dispose);
      final theme = videoBrowseTheme(
        ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.purple,
            brightness: brightness,
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: OmoSiteFavoritesPage(
              client: client,
              source: 'omo',
              active: true,
              onImportMode: (_) {},
              onOpen: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final input = tester.widget<TextField>(find.byType(TextField).first);
      expect(input.decoration?.filled, isTrue);
      expect(input.decoration?.border, isA<OutlineInputBorder>());
      final manage = find.byKey(const ValueKey('omo-favorites.manage'));
      expect(tester.widget<NativeVideoTextButton>(manage).light, isFalse);
      expect(tester.getSize(manage).height, greaterThanOrEqualTo(44));
      await tester.tap(manage);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('api-video.edit.aaaaaaaaaaaaaaaa')),
        findsOneWidget,
      );
      expect(find.text(t.common.done), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('small phone large type keeps site actions inside the screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = siteClient();
    addTearDown(client.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.8)),
          child: child!,
        ),
        home: Scaffold(
          body: OmoSiteFavoritesPage(
            client: client,
            source: 'omo',
            active: true,
            onImportMode: (_) {},
            onOpen: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final element in find.byType(NativeVideoTextButton).evaluate()) {
      final bounds = tester.getRect(find.byWidget(element.widget));
      expect(bounds.left, greaterThanOrEqualTo(16));
      expect(bounds.right, lessThanOrEqualTo(304));
      expect(bounds.height, greaterThanOrEqualTo(44));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'local search and management share the collection control style',
    (tester) async {
      final store = VideoLibraryStore(deviceId: 'test', storageKey: 'ui-2269');
      addTearDown(store.dispose);
      await store.setFavorite(
        'test',
        ApiVideoItem(
          id: '1',
          title: '本机收藏样本',
          detailUrl: Uri.parse('https://example.test/anime/1.html'),
        ),
        true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ApiVideoFavorites(
              source: 'test',
              mode: ApiVideoView.grid,
              store: store,
              onOpen: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final input = tester.widget<TextField>(find.byType(TextField).first);
      expect(input.decoration?.filled, isTrue);
      expect(input.decoration?.border, isA<OutlineInputBorder>());
      final manage = find.byKey(const ValueKey('local-favorites.manage'));
      expect(tester.widget<NativeVideoTextButton>(manage).light, isFalse);
      expect(tester.getSize(manage).height, greaterThanOrEqualTo(44));
      expect(tester.takeException(), isNull);
    },
  );
}
