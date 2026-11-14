import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import '../ui_preview_helper.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/comic_list/models/comic_list_scene.dart';
import 'package:zephyr/page/comic_list/view/comic_list_page.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/source_choice_menu.dart';

import '../test_helper.dart';

const _source = 'e9f18928-3ba8-4d86-a12e-b53a62f47933';

class _RankingApi extends RustLibApi {
  final requests = <Map<String, dynamic>>[];
  String source = _source;
  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;
  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('ranking-fixture');
  @override
  Future<Uint8List> crateApiQjsQjsTaskCall({
    required String runtimeName,
    required String taskGroupKey,
    required bool isOnce,
    String? bundleJs,
    String? bundleUrl,
    required String fnPath,
    required String argsJson,
  }) async {
    final args = jsonDecode(argsJson) as Map<String, dynamic>;
    final Map<String, dynamic> reply;
    if (fnPath == 'init') {
      reply = {
        'data': {'ok': true},
      };
    } else if (fnPath == 'getRankingFilterBundle') {
      reply = {
        'source': source,
        'scheme': {
          'fields': [
            {
              'key': 'ranking',
              'kind': 'choice',
              'label': '榜单',
              'options': [
                for (final period in {
                  'day': 'H24',
                  'week': 'D7',
                  'month': 'D30',
                }.entries)
                  {
                    'label': period.key,
                    'value': period.key,
                    'result': {
                      'core': {'days': period.value, 'type': 'comic'},
                    },
                  },
              ],
            },
            {
              'key': 'rankingType',
              'kind': 'choice',
              'label': '类别',
              'options': [
                for (final type in ['comic', 'creator'])
                  {
                    'label': type,
                    'value': type,
                    'result': {
                      'core': {'type': type},
                    },
                  },
              ],
            },
          ],
        },
        'data': {
          'values': {'ranking': 'day', 'rankingType': 'comic'},
        },
      };
    } else if (fnPath == 'getRankingData') {
      requests.add(args);
      reply = {
        'source': source,
        'data': {'items': [], 'hasReachedMax': true},
      };
    } else {
      throw StateError('Unexpected ranking fixture call: $fnPath');
    }
    return Uint8List.fromList(utf8.encode(jsonEncode(reply)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = _RankingApi();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const connectivityStatus = MethodChannel(
    'dev.fluttercommunity.plus/connectivity_status',
  );
  setUpAll(() async {
    messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
    messenger.setMockMethodCallHandler(connectivityStatus, (_) async => null);
    await loadUiPreviewFonts();
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: api);
  });
  tearDownAll(() async {
    await TestObjectBoxHelper.tearDownTestObjectBox();
    messenger.setMockMethodCallHandler(connectivity, null);
    messenger.setMockMethodCallHandler(connectivityStatus, null);
  });
  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      for (final narrow in [false, true]) {
        for (final currentSource in [
          _source,
          'fixture-retired-independent-source',
        ]) {
          testWidgets(
            'ranking periods stay visible and submit ordered core $style $brightness narrow=$narrow source=$currentSource',
            (tester) async {
              SharedPreferences.setMockInitialValues({});
              api.requests.clear();
              api.source = currentSource;
              final embedded = currentSource == _source;
              tester.view.devicePixelRatio = 1;
              tester.view.physicalSize = Size(narrow ? 320 : 430, 1100);
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              final messenger = TestDefaultBinaryMessengerBinding
                  .instance
                  .defaultBinaryMessenger;
              final channels = <MethodChannel>[];
              MethodChannel? segmentedChannel;
              messenger.setMockMethodCallHandler(
                SystemChannels.platform_views,
                (call) async {
                  if (call.method == 'create') {
                    final args = call.arguments as Map;
                    final channel = MethodChannel(
                      '${args['viewType']}.${args['id']}',
                    );
                    channels.add(channel);
                    messenger.setMockMethodCallHandler(channel, (update) async {
                      if (update.method == 'update' &&
                          update.arguments is Map &&
                          (update.arguments as Map)['kind'] == 'segmented') {
                        segmentedChannel = channel;
                      }
                      return null;
                    });
                  }
                  return null;
                },
              );
              addTearDown(() {
                messenger.setMockMethodCallHandler(
                  SystemChannels.platform_views,
                  null,
                );
                for (final channel in channels)
                  messenger.setMockMethodCallHandler(channel, null);
              });
              final settings = GlobalSettingCubit();
              final preference = ValueNotifier(style);
              addTearDown(settings.close);
              addTearDown(preference.dispose);
              final scene = ComicListScene(
                from: currentSource,
                title: '排行榜',
                filter: ComicListRequestConfig(
                  fnPath: 'getRankingFilterBundle',
                ),
                body: ComicListBodyConfig(
                  params: currentSource == _source
                      ? const {}
                      : const {'layout': 'bikaRanking'},
                  request: ComicListRequestConfig(
                    fnPath: 'getRankingData',
                    core: {'days': 'H24', 'type': 'comic'},
                    extern: {'source': 'ranking'},
                  ),
                ),
              );
              await tester.pumpWidget(
                BlocProvider.value(
                  value: settings,
                  child: AppInterfaceStyleScope(
                    style: preference,
                    child: MaterialApp(
                      theme: ThemeData(
                        brightness: brightness,
                        platform: TargetPlatform.iOS,
                        fontFamily: uiPreviewDirectory == null
                            ? null
                            : 'AccountPreview',
                      ),
                      builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(narrow ? 2 : 1),
                        ),
                        child: RepaintBoundary(
                          key: const ValueKey('ranking-preview'),
                          child: child!,
                        ),
                      ),
                      home: embedded
                          ? Scaffold(
                              body: ComicListPage(scene: scene, embedded: true),
                            )
                          : ComicListPage(scene: scene),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              if (currentSource == _source) {
                await writeUiPreview(
                  tester,
                  const ValueKey('ranking-preview'),
                  'ranking-title-$style-${brightness.name}-${narrow ? 'large' : 'regular'}',
                );
              }
              Finder period() =>
                  find.byKey(const ValueKey('bika-ranking.period'));
              NativeVideoSegmentedControl control() =>
                  tester.widget<NativeVideoSegmentedControl>(period());
              if (!narrow) {
                expect(
                  tester.getSize(period()).height,
                  lessThanOrEqualTo(80),
                  reason: 'three frequent periods remain a compact visible row',
                );
              }
              expect(
                tester
                    .getRect(find.byKey(const ValueKey('bika-ranking.type')))
                    .center
                    .dy,
                closeTo(tester.getRect(find.text('排行榜')).center.dy, 2),
                reason:
                    'the type choice shares the title row instead of occupying its own row',
              );
              expect(
                tester
                    .getRect(
                      embedded
                          ? find.byKey(const ValueKey('bika-ranking.type'))
                          : find.byType(SourceMoreButton),
                    )
                    .right,
                closeTo(tester.getRect(period()).right, 0.5),
                reason:
                    'ranking header and its period bar share the visible trailing edge',
              );
              final labels = [
                t.bikaRanking.day,
                t.bikaRanking.week,
                t.bikaRanking.month,
              ];
              expect(control().options.values.toList(), labels);
              expect(control().selected, 'day');
              Future<void> select(String value) async {
                final native = find.descendant(
                  of: period(),
                  matching: find.byType(UiKitView),
                );
                if (native.evaluate().isNotEmpty) {
                  final view = tester.widget<UiKitView>(native);
                  final args = view.creationParams as Map;
                  final options = args['options'] as List;
                  expect(
                    options.map((value) => (value as Map)['title']),
                    labels,
                  );
                  expect(segmentedChannel, isNotNull);
                  await messenger.handlePlatformMessage(
                    segmentedChannel!.name,
                    const StandardMethodCodec().encodeMethodCall(
                      MethodCall('select', value),
                    ),
                    (_) {},
                  );
                } else {
                  for (final label in labels)
                    expect(find.text(label).hitTestable(), findsOneWidget);
                  await tester.tap(find.text(control().options[value]!));
                }
                // Native selection or the actual Flutter tap enters the real
                // ComicListCubit and plugin boundary, without seeded state.
                await tester.pumpAndSettle();
                expect(control().selected, value);
                expect(
                  find.textContaining('榜单 ·'),
                  findsNothing,
                  reason:
                      'the visible period must not create a duplicate summary row',
                );
              }

              await select('week');
              await select('month');
              expect(api.requests.map((request) => request['days']), [
                'H24',
                'D7',
                'D30',
              ]);
              expect(
                api.requests.every((request) => request['type'] == 'comic'),
                isTrue,
              );
              expect(
                api.requests.every(
                  (request) =>
                      (request['extern'] as Map)['source'] == 'ranking',
                ),
                isTrue,
              );
              tester
                  .widget<SourceChoiceMenu<String>>(
                    find.byKey(const ValueKey('bika-ranking.type')),
                  )
                  .onChanged!('creator');
              await tester.pumpAndSettle();
              expect(period(), findsNothing);
              expect(api.requests.last['type'], 'creator');
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox.shrink());
            },
            variant: TargetPlatformVariant.only(TargetPlatform.iOS),
          );
        }
      }
    }
  }
}
