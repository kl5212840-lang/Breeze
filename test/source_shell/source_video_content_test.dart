import '../test_helper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/source_shell/models/source_shell_section.dart';
import 'package:zephyr/page/source_shell/view/source_video_content.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

Map<String, dynamic> videoAction(String module, {String? home}) => {
  'type': 'openVideoLibrary',
  'payload': {
    'source': 'stale-source',
    'title': module,
    'tabTitle': module == 'movie' ? '电影' : '里番',
    'url': home ?? 'https://$module.test/',
    'protocol': 2,
    'catalogFnPath': 'catalog',
    'detailFnPath': 'detail',
    'playbackFnPath': 'play',
    'capabilities': {
      'search': module == 'movie' ? 'full' : 'none',
      'year': false,
      'sourceSort': false,
      'recent': false,
      'detailFromSnapshot': true,
      'itemNamespace': module,
    },
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  testWidgets(
    'browse-only is explicit for independent sources and false overrides legacy fallback',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const network = MethodChannel('breeze.video.network');
      messenger.setMockMethodCallHandler(network, (_) async => false);
      addTearDown(() => messenger.setMockMethodCallHandler(network, null));
      final preference = ValueNotifier('breeze');
      addTearDown(preference.dispose);
      for (final fixture in [
        (
          source: 'fixture-retired-independent-source',
          flag: true,
          expected: true,
        ),
        (source: 'unknown-source', flag: null, expected: false),
        (
          source: 'e9f18928-3ba8-4d86-a12e-b53a62f47933',
          flag: false,
          expected: false,
        ),
      ]) {
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: preference,
            child: MaterialApp(
              home: SourceVideoContent(
                source: fixture.source,
                browseOnly: fixture.flag,
                leading: const Icon(Icons.arrow_back),
                actions: [
                  SourceShellAction(title: '电影', action: videoAction('movie')),
                ],
                pluginCall: (_, _) async => {
                  'data': {
                    'items': [],
                    'categories': [],
                    'page': 1,
                    'pageCount': 1,
                  },
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ApiVideoLibraryPage>(find.byType(ApiVideoLibraryPage))
              .browseOnly,
          fixture.expected,
        );
        expect(
          find.byKey(const ValueKey('api-library.scope')),
          fixture.expected ? findsNothing : findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    },
  );

  test('declared modules add one tab before profile and keep comic duties', () {
    final sections = SourceShellSection.fromPluginInfo({
      'functions': [
        {'id': 'navigation', 'title': '分类'},
        {'id': 'ranking', 'title': '排行榜'},
      ],
      'breezeVideoModules': [
        videoAction('movie'),
        videoAction('animate'),
        videoAction('duplicate', home: 'https://movie.test/'),
        videoAction('invalid', home: 'https://name:password@invalid.test/'),
        videoAction('invalid', home: 'http://invalid.test/'),
        videoAction('invalid', home: 'https://invalid.test/?private=1'),
      ],
      'breezeExperience': {'aggregateMedia': 'comic', 'profileTab': true},
    }, 'current-source');
    expect(sections.map((e) => e.id), [
      'navigation',
      'ranking',
      'video',
      'profile',
    ]);
    final video = sections[2];
    expect(video.icon, Icons.video_library_outlined);
    expect(video.videoGroup, isTrue);
    expect(video.actions.map((e) => e.title), ['电影', '里番']);
    expect(
      video.actions.map((e) => (e.action['payload'] as Map)['source']),
      everyElement('current-source'),
    );
    expect(sections.first.functionId, 'navigation');
  });

  test('invalid declarations do not remove a legacy navigation path', () {
    final sections = SourceShellSection.fromPluginInfo({
      'functions': [
        {'id': 'navigation', 'title': '分类'},
      ],
      'breezeVideoModules': [
        {'type': 'openWeb', 'payload': {}},
        videoAction('invalid')..['payload']['catalogFnPath'] = 'bad();',
      ],
    }, 'source');
    expect(sections.map((e) => e.id), ['navigation']);
    expect(sections.any((e) => e.videoGroup), isFalse);
  });

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'modules retain scope, instance and lazy catalog: $style $brightness',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final channels = <MethodChannel>[];
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
            call,
          ) async {
            if (call.method == 'create') {
              final args = call.arguments as Map;
              final channel = MethodChannel(
                '${args['viewType']}.${args['id']}',
              );
              channels.add(channel);
              messenger.setMockMethodCallHandler(channel, (_) async => null);
            }
            return null;
          });
          addTearDown(() {
            messenger.setMockMethodCallHandler(
              SystemChannels.platform_views,
              null,
            );
            for (final channel in channels) {
              messenger.setMockMethodCallHandler(channel, null);
            }
          });
          final preference = ValueNotifier(style);
          addTearDown(preference.dispose);
          final calls = <String>[];
          var active = true;
          late StateSetter update;
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                theme: ThemeData(
                  brightness: brightness,
                  platform: TargetPlatform.iOS,
                ),
                home: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Scaffold(
                      extendBody: true,
                      body: SourceVideoContent(
                        source: 'source-$style-${brightness.name}',
                        actions: [
                          SourceShellAction(
                            title: '电影',
                            action: videoAction('movie'),
                          ),
                          SourceShellAction(
                            title: '里番',
                            action: videoAction('animate'),
                          ),
                        ],
                        leading: const Icon(Icons.chevron_left),
                        active: active,
                        pluginCall: (fn, args) async {
                          calls.add('$fn:${args['home']}');
                          return {
                            'data': {
                              'items': [],
                              'categories': [],
                              'page': 1,
                              'pageCount': 1,
                            },
                          };
                        },
                      ),
                      bottomNavigationBar: VideoNativeNavigation(
                        items: const [
                          BottomNavigationBarItem(
                            icon: Icon(Icons.grid_view),
                            label: '分类',
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(Icons.video_library),
                            label: '视频',
                          ),
                        ],
                        symbols: const ['square.grid.2x2', 'film'],
                        currentIndex: 1,
                        onTap: (_) {},
                      ),
                    );
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final movieState = tester.state(find.byType(ApiVideoLibraryPage));
          NativeVideoSegmentedControl scope() =>
              tester.widget<NativeVideoSegmentedControl>(
                find.byKey(const ValueKey('api-library.scope')),
              );
          NativeVideoSegmentedControl control() =>
              tester.widget<NativeVideoSegmentedControl>(
                find.byKey(const ValueKey('source-video.modules')),
              );
          expect(calls, ['catalog:https://movie.test/']);
          expect(find.byType(VideoNativeNavigation), findsOneWidget);
          expect(find.byType(AppBar), findsOneWidget);
          scope().onSelected!('1');
          await tester.pumpAndSettle();
          expect(scope().selected, '1');
          control().onSelected!('https://animate.test/');
          await tester.pumpAndSettle();
          expect(scope().selected, '0');
          expect(calls, [
            'catalog:https://movie.test/',
            'catalog:https://animate.test/',
          ]);
          expect(
            find.byType(ApiVideoLibraryPage, skipOffstage: false),
            findsNWidgets(2),
          );
          expect(find.byType(VideoNativeNavigation), findsOneWidget);
          expect(find.byType(AppBar), findsOneWidget);
          control().onSelected!('https://movie.test/');
          await tester.pumpAndSettle();
          expect(
            tester.state(find.byType(ApiVideoLibraryPage)),
            same(movieState),
          );
          expect(scope().selected, '1');
          expect(calls.length, 2);
          update(() => active = false);
          await tester.pumpAndSettle();
          expect(
            tester
                .widgetList<ApiVideoLibraryPage>(
                  find.byType(ApiVideoLibraryPage, skipOffstage: false),
                )
                .every((e) => !e.active),
            isTrue,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
