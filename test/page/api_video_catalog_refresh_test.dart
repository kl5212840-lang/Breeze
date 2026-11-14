import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'successful refresh replaces the read range and stale details while failure retains it',
    (tester) async {
      var revision = 0;
      var fail = false;
      var invalid = false;
      final requests = <Map<String, dynamic>>[];
      final pendingOld = Completer<Map<String, dynamic>>();
      var deferDetail = false;
      Map<String, dynamic> row(
        String id, {
        String tag = '',
        String year = '',
      }) => {
        'id': id,
        'title': '作品$id',
        'detailUrl': 'https://refresh.test/videos/$id',
        'coverUrl': 'https://images.example/$id.jpg',
        'genres': tag,
        'year': year,
      };
      final repo = ApiVideoRepository(
        source: 'catalog-refresh-fixture',
        home: Uri.parse('https://refresh.test/'),
        catalogFn: 'list',
        detailFn: 'detail',
        playbackFn: 'play',
        capabilities: const ApiVideoCapabilities(
          search: 'none',
          year: false,
          recent: false,
        ),
        pluginCall: (fn, args) async {
          requests.add({'fn': fn, ...args});
          if (fn == 'detail') {
            if (deferDetail) return pendingOld.future;
            return {
              'data': row(
                args['id'] as String,
                tag: revision == 0 ? 'stale-tag' : 'fresh-tag',
                year: revision == 0 ? '2025' : '2026',
              ),
            };
          }
          if (fail) throw StateError('fixture refresh unavailable');
          if (invalid) {
            return {
              'data': {'page': 1, 'pageCount': 1},
            };
          }
          final page = args['page'] as int;
          return {
            'data': {
              'page': page,
              'pageCount': 3,
              'total': revision == 0 ? 60 : 41,
              'items': [
                for (var i = 0; i < 20; i++)
                  row(
                    revision == 0
                        ? '$page-$i'
                        : i == 1
                        ? 'new-$page'
                        : '$page-$i',
                    tag: revision == 0 ? '' : 'fresh-tag',
                    year: revision == 0 ? '' : '2026',
                  ),
              ],
              'categories': [],
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
            home: ApiVideoLibraryPage(repository: repo, title: 'Fixture'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip(t.common.refresh), findsNothing);
      ApiVideoCollection collection() => tester.widget<ApiVideoCollection>(
        find.byType(ApiVideoCollection).first,
      );
      Finder editor() => find.descendant(
        of: find.byKey(const ValueKey('api-catalog.local-query')),
        matching: find.byType(TextField),
      );
      Future<void> refresh() async {
        await tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator).first)
            .onRefresh();
        await tester.pumpAndSettle();
      }

      Future<void> pressVisible(Finder control) async {
        if (control.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            control,
            400,
            maxScrolls: 30,
            scrollable: find
                .descendant(
                  of: find.byType(ApiVideoCollection).first,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
        }
        await tester.ensureVisible(control);
        await tester.pumpAndSettle();
        expect(
          control.hitTestable(),
          findsOneWidget,
          reason:
              'scroll the actual footer above the navigation before tapping',
        );
        await tester.tap(control);
        await tester.pumpAndSettle();
      }

      // Real row-enrichment contract: insert a detail already read for this item.
      final summary = collection().items.first;
      final oldDetail = await collection().loadDetail!(summary);
      collection().onDetailLoaded?.call(oldDetail);
      await tester.pumpAndSettle();
      tester
          .widget<KeywordScopeMenu>(find.byType(KeywordScopeMenu))
          .onChanged(KeywordSearchScope.all);
      await tester.pumpAndSettle();
      await tester.enterText(editor(), 'stale-tag');
      await tester.pumpAndSettle();
      expect(collection().items.single.id, summary.id);
      await pressVisible(
        find.byKey(const ValueKey('api-catalog.local-load-next')),
      );
      expect(requests.where((r) => r['fn'] == 'list').map((r) => r['page']), [
        1,
        2,
      ]);
      await tester.enterText(editor(), '');
      await tester.pumpAndSettle();
      final lateCallback = collection().onDetailLoaded;
      deferDetail = true;
      final lateRead = collection()
          .loadDetail!(
            collection().items.firstWhere((item) => item.id == '1-2'),
          )
          .catchError((_) => oldDetail);
      await tester.pump();
      await tester.enterText(editor(), 'stale-tag');
      await tester.pumpAndSettle();
      revision = 1;
      await refresh();
      expect(requests.lastWhere((r) => r['fn'] == 'list')['refresh'], isTrue);
      expect(requests.lastWhere((r) => r['fn'] == 'list')['page'], 1);
      expect(
        collection().items,
        isEmpty,
        reason:
            'old visited metadata must not override the refreshed tags/year',
      );
      expect(
        find.text(
          t.videoLibrary.localCatalogScope(loaded: 20, total: 41, shown: 0),
        ),
        findsOneWidget,
      );
      lateCallback?.call(oldDetail);
      deferDetail = false;
      pendingOld.complete({
        'data': row(summary.id, tag: 'stale-tag', year: '2025'),
      });
      await lateRead;
      await tester.pumpAndSettle();
      expect(
        collection().items,
        isEmpty,
        reason: 'late metadata from the previous snapshot is refused',
      );
      await tester.enterText(editor(), 'fresh-tag');
      await tester.pumpAndSettle();
      expect(collection().items, hasLength(20));
      expect(collection().items.any((item) => item.id == 'new-1'), isTrue);
      expect(collection().items.any((item) => item.id == '1-1'), isFalse);
      final refreshed = collection().items.first;
      final detail = await collection().loadDetail!(refreshed);
      collection().onDetailLoaded?.call(detail);
      await tester.pumpAndSettle();
      expect(requests.lastWhere((r) => r['fn'] == 'detail')['refresh'], isTrue);
      fail = true;
      await refresh();
      expect(collection().items, hasLength(20));
      expect(
        find.text(
          t.videoLibrary.localCatalogScope(loaded: 20, total: 41, shown: 20),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('api-catalog.refresh-retry')),
        findsOneWidget,
      );
      expect(find.text(t.common.refreshRetained), findsNothing);
      fail = false;
      invalid = true;
      await refresh();
      expect(collection().items, hasLength(20));
      expect(
        find.byKey(const ValueKey('api-catalog.refresh-retry')),
        findsOneWidget,
      );
      invalid = false;
      await pressVisible(
        find.byKey(const ValueKey('api-catalog.refresh-retry')),
      );
      expect(collection().items, hasLength(20));
      expect(requests.lastWhere((r) => r['fn'] == 'list')['refresh'], isTrue);
      await pressVisible(
        find.byKey(const ValueKey('api-catalog.local-load-next')),
      );
      expect(collection().items, hasLength(40));
      expect(
        requests.where((r) => r['fn'] == 'list' && r['page'] == 3),
        isEmpty,
      );
      final reads = requests.where((r) => r['fn'] == 'list').length;
      final generation = collection().detailGeneration;
      await refresh();
      expect(collection().items, hasLength(40));
      expect(collection().detailGeneration, generation);
      expect(find.text(t.common.refreshChecked), findsOneWidget);
      expect(requests.where((r) => r['fn'] == 'list'), hasLength(reads + 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('catalog pull waits and reports the scope that was read', (
    tester,
  ) async {
    final style = ValueNotifier('breeze');
    addTearDown(style.dispose);
    Completer<Map<String, dynamic>>? pending;
    var pulls = 0;
    var complete = true;
    Map<String, dynamic> payload() => {
      'data': {
        'page': 1,
        'pageCount': complete ? 1 : 2,
        'total': 0,
        'totalKnown': complete,
        'items': [],
        'categories': [],
      },
    };
    final repo = ApiVideoRepository(
      source: 'scoped-feedback-fixture',
      home: Uri.parse('https://refresh.test/'),
      catalogFn: 'list',
      detailFn: 'detail',
      playbackFn: 'play',
      capabilities: const ApiVideoCapabilities(
        search: 'none',
        year: false,
        recent: false,
      ),
      pluginCall: (_, args) async {
        if (args['refresh'] == true) {
          pulls++;
          final gate = pending;
          if (gate != null) return gate.future;
        }
        return payload();
      },
    );
    Future<void> mount() async {
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            home: ApiVideoLibraryPage(repository: repo, title: 'Fixture'),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await mount();
    final gate = pending = Completer<Map<String, dynamic>>();
    final scrollable = find
        .descendant(
          of: find.byType(RefreshIndicator),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(scrollable, const Offset(0, 350));
    for (var frame = 0; frame < 80 && pulls == 0; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(pulls, 1);
    expect(find.byType(RefreshProgressIndicator), findsOneWidget);
    expect(find.text(t.common.refreshUnchanged), findsNothing);
    gate.complete(payload());
    pending = null;
    await tester.pumpAndSettle();
    expect(find.text(t.common.refreshUnchanged), findsOneWidget);
    expect(find.text(t.common.refreshChecked), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    complete = false;
    await mount();
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(pulls, 2);
    expect(find.text(t.common.refreshUnchanged), findsNothing);
    expect(find.text(t.common.refreshChecked), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'catalog and tab changes never focus inline search automatically',
    (tester) async {
      final style = ValueNotifier('breeze');
      addTearDown(style.dispose);
      final repo = ApiVideoRepository(
        source: 'focus-catalog-fixture',
        home: Uri.parse('https://focus.test/'),
        catalogFn: 'list',
        detailFn: 'detail',
        playbackFn: 'play',
        capabilities: const ApiVideoCapabilities(
          search: 'none',
          year: false,
          recent: false,
        ),
        pluginCall: (_, _) async => {
          'data': {
            'page': 1,
            'pageCount': 1,
            'total': 0,
            'items': [],
            'categories': [],
          },
        },
      );
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            home: ApiVideoLibraryPage(
              repository: repo,
              title: 'Fixture',
              embedded: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      void noFocus() => expect(
        tester
            .widgetList<EditableText>(find.byType(EditableText))
            .any((w) => w.focusNode.hasFocus),
        isFalse,
      );
      noFocus();
      final scope = find.byKey(const ValueKey('api-library.scope'));
      tester.widget<NativeVideoSegmentedControl>(scope).onSelected!('2');
      await tester.pumpAndSettle();
      noFocus();
      tester.widget<NativeVideoSegmentedControl>(scope).onSelected!('0');
      await tester.pumpAndSettle();
      noFocus();
      final field = find.descendant(
        of: find.byKey(const ValueKey('api-catalog.local-query')),
        matching: find.byType(TextField),
      );
      await tester.tap(field);
      await tester.enterText(field, 'manual');
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<EditableText>(find.byType(EditableText))
            .any((w) => w.focusNode.hasFocus),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
