import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_favorites.dart';
import 'package:zephyr/page/video/api_video_history.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/page/video/video_search_page.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

final _home = Uri.parse('https://embedded.test/');
ApiVideoItem _item(String id) => ApiVideoItem(
  id: id,
  title: '作品$id',
  detailUrl: _home.resolve('/voddetail/$id.html'),
);

ApiVideoRepository _repository(String source, List<String> details) =>
    ApiVideoRepository(
      source: source,
      home: _home,
      catalogFn: 'list',
      detailFn: 'detail',
      playbackFn: 'play',
      capabilities: const ApiVideoCapabilities(year: false, recent: false),
      pluginCall: (path, args) async {
        if (path == 'detail') {
          final id = args['id'] as String;
          details.add(id);
          return {'data': _item(id).toLibraryJson()};
        }
        return {
          'data': {
            'items': [_item('1').toLibraryJson()],
            'categories': [],
            'page': 1,
            'pageCount': 1,
            'total': 1,
          },
        };
      },
    );

void main() {
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final channels = <MethodChannel>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final channel = MethodChannel('${args['viewType']}.${args['id']}');
        channels.add(channel);
        messenger.setMockMethodCallHandler(channel, (_) async => null);
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
      for (final channel in channels) {
        messenger.setMockMethodCallHandler(channel, null);
      }
    });
  });
  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'embedded library has one host navigation, three scopes and active detail gates: $style $brightness at 320pt 2x',
        (tester) async {
          tester.view.physicalSize = const Size(320, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final source = 'embedded-$style-${brightness.name}';
          SharedPreferences.setMockInitialValues({
            'breeze.video.library.view.$source': 'list',
          });
          await VideoLibraryStore.shared.setFavorite(source, _item('2'), true);
          await VideoWatchHistory.record(
            source,
            VideoWatchRecord(
              watchUrl: _home.resolve('/voddetail/3.html?line=1&episode=1'),
              title: '作品3',
              position: const Duration(seconds: 30),
              duration: const Duration(minutes: 10),
              updatedAt: DateTime.utc(2026),
              completed: false,
            ),
          );
          final details = <String>[];
          final repository = _repository(source, details);
          final preference = ValueNotifier(style);
          addTearDown(preference.dispose);
          var active = false;
          late StateSetter update;
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                theme: ThemeData(brightness: brightness),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(2)),
                  child: child!,
                ),
                home: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Scaffold(
                      body: ApiVideoLibraryPage(
                        repository: repository,
                        title: '视频',
                        embedded: true,
                        active: active,
                        leading: IconButton(
                          key: const ValueKey('outer.back'),
                          onPressed: () {},
                          icon: const Icon(Icons.arrow_back),
                        ),
                        moduleControl: NativeVideoSegmentedControl(
                          key: const ValueKey('module.control'),
                          options: const {'movie': '电影', 'animate': '里番'},
                          selected: 'movie',
                          onSelected: (_) {},
                        ),
                      ),
                      bottomNavigationBar: VideoNativeNavigation(
                        key: const ValueKey('outer.navigation'),
                        currentIndex: 0,
                        onTap: (_) {},
                        symbols: const ['film', 'person'],
                        items: const [
                          BottomNavigationBarItem(
                            icon: Icon(Icons.video_library),
                            label: '视频',
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(Icons.person),
                            label: '我的',
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          NativeVideoSegmentedControl scope() =>
              tester.widget<NativeVideoSegmentedControl>(
                find.byKey(const ValueKey('api-library.scope')),
              );
          void expectActivation(int tab, bool active) {
            expect(
              tester
                  .widget<ApiVideoFavorites>(
                    find.byType(ApiVideoFavorites, skipOffstage: false),
                  )
                  .active,
              active && tab == 1,
            );
            expect(
              tester
                  .widget<ApiVideoHistory>(
                    find.byType(ApiVideoHistory, skipOffstage: false),
                  )
                  .active,
              active && tab == 2,
            );
            if (tab == 0) {
              expect(
                tester
                    .widget<ApiVideoCollection>(find.byType(ApiVideoCollection))
                    .detailsActive,
                active,
              );
            }
          }

          expect(find.byType(VideoNativeNavigation), findsOneWidget);
          expect(find.byType(AppBar), findsOneWidget);
          expect(find.byKey(const ValueKey('outer.back')), findsOneWidget);
          expect(find.byType(VideoSearchEntry), findsOneWidget);
          expect(find.byType(SourceMoreButton), findsOneWidget);
          expect(scope().options.keys, ['0', '1', '2']);
          expect(details, isEmpty);
          expectActivation(0, false);
          expect(
            tester.getRect(find.byKey(const ValueKey('module.control'))).bottom,
            lessThanOrEqualTo(
              tester
                  .getRect(find.byKey(const ValueKey('api-library.scope')))
                  .top,
            ),
          );
          update(() => active = true);
          await tester.pumpAndSettle();
          expectActivation(0, true);
          expect(details, ['1']);
          scope().onSelected!('1');
          await tester.pumpAndSettle();
          expectActivation(1, true);
          expect(scope().selected, '1');
          expect(find.byKey(const ValueKey('outer.back')), findsOneWidget);
          expect(find.byType(AppBar), findsNothing);
          expect(
            tester
                .widget<ApiVideoFavorites>(find.byType(ApiVideoFavorites))
                .compactHeader,
            isTrue,
          );
          expect(
            find.byKey(const ValueKey('local-favorites.view')).hitTestable(),
            findsOneWidget,
          );
          expect(
            tester
                .widget<NativeVideoMenu>(
                  find.byKey(const ValueKey('local-favorites.manage')),
                )
                .options,
            isNot(contains('view')),
          );
          expect(find.byType(VideoNativeNavigation), findsOneWidget);
          update(() => active = false);
          await tester.pumpAndSettle();
          expectActivation(1, false);
          final before = details.length;
          scope().onSelected!('2');
          await tester.pumpAndSettle();
          expectActivation(2, false);
          expect(details.length, before);
          update(() => active = true);
          await tester.pumpAndSettle();
          expectActivation(2, true);
          expect(details, contains('3'));
          expect(scope().selected, '2');
          expect(
            tester
                .widget<ApiVideoHistory>(find.byType(ApiVideoHistory))
                .compactHeader,
            isTrue,
          );
          expect(find.byKey(const ValueKey('outer.back')), findsOneWidget);
          expect(find.byType(VideoNativeNavigation), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }

  testWidgets(
    'standalone keeps its navigation and embedded works without module control',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = _repository('standalone-default', []);
      await tester.pumpWidget(
        MaterialApp(
          home: ApiVideoLibraryPage(repository: repo, title: 'Standalone'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VideoNativeNavigation), findsOneWidget);
      expect(find.byKey(const ValueKey('api-library.scope')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          home: ApiVideoLibraryPage(
            repository: repo,
            title: 'Embedded',
            embedded: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(VideoNativeNavigation), findsNothing);
      expect(find.byKey(const ValueKey('api-library.scope')), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
