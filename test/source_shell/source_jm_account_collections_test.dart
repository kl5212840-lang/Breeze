import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/widgets/breeze_switch.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search_result/view/search_result_page.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/view/source_jm_account_collections.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/service/plugin_account_identity.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/widgets/task_dialog.dart';

import '../test_helper.dart';

const _source = 'jm-account-collections-fixture';

class _CollectionsApi extends RustLibApi {
  String source = _source;
  int tagReads = 0;
  bool rejectRead = false;
  int? rejectFollowPage;
  Completer<void>? gate;
  Completer<void>? writeGate;
  bool rejectWrite = false;
  List<String> tags = ['私有标签'];
  final writes = <Map<String, dynamic>>[];
  final searches = <Map<String, dynamic>>[];
  final followReads = <int>[];
  final followIds = <int>[];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected native API: ${invocation.memberName}');

  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;

  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('offline-jm-account-collections');

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
    final args = Map<String, dynamic>.from(jsonDecode(argsJson) as Map);
    final data = <String, dynamic>{'accountId': 'a'};
    if (fnPath == 'setJmAccountCollection') {
      writes.add(args);
      await writeGate?.future;
      if (rejectWrite) throw StateError('fixture write failed');
      if (args['collection'] == 'tags') {
        final name = (args['tags'] as List).single as String;
        if (args['enabled'] == true) {
          tags.add(name);
        } else {
          tags.remove(name);
        }
        data['tags'] = List.of(tags);
      } else {
        data['enabled'] = args['enabled'];
        if (args['enabled'] == false) {
          followIds.remove(int.tryParse('${args['comicId']}'));
        }
      }
    } else if (fnPath == 'searchComic') {
      searches.add(args);
      return Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'source': _source,
            'scheme': {
              'version': '1.0.0',
              'type': 'searchResult',
              'source': _source,
              'list': 'comicGrid',
            },
            'data': {
              'paging': {
                'page': 1,
                'pages': 1,
                'total': 0,
                'hasReachedMax': true,
              },
              'items': [],
            },
          }),
        ),
      );
    } else if (args['collection'] == 'comic') {
      data.addAll({
        'enabled': false,
        'tags': ['标签甲'],
      });
    } else if (args['collection'] == 'tags') {
      tagReads++;
      if (rejectRead) throw StateError('fixture transport unavailable');
      data['tags'] = List.of(tags);
      await gate?.future;
    } else if (args['collection'] == 'follows') {
      final page = args['page'] as int;
      followReads.add(page);
      if (page == rejectFollowPage) {
        throw StateError('fixture follow page unavailable');
      }
      data.addAll({
        'page': page,
        'total': followIds.length,
        'hasMore': page * 20 < followIds.length,
        'items': [
          for (final id in followIds.skip((page - 1) * 20).take(20))
            {'id': '$id', 'title': '追踪 $id'},
        ],
      });
    }
    return Uint8List.fromList(
      utf8.encode(jsonEncode({'source': source, 'data': data})),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = _CollectionsApi();
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: api);
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api.source = _source;
    api.tagReads = 0;
    api.rejectRead = false;
    api.rejectFollowPage = null;
    api.gate = null;
    api.writeGate = null;
    api.rejectWrite = false;
    api.tags = ['私有标签'];
    api.writes.clear();
    api.searches.clear();
    api.followReads.clear();
    api.followIds.clear();
  });

  Future<void> mount(
    WidgetTester tester,
    JmAccountCollection collection,
  ) async {
    final setting = GlobalSettingCubit();
    addTearDown(setting.close);
    await tester.pumpWidget(
      BlocProvider.value(
        value: setting,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => openJmAccountCollection(
                  context,
                  source: api.source,
                  collection: collection,
                  accountId: collection == JmAccountCollection.tags
                      ? 'a'
                      : null,
                  comicId: '123',
                  comicTags: const ['标签甲', '标签乙'],
                ),
                child: const Text('Open fixture'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open fixture'));
  }

  testWidgets(
    'removing a follow rebuilds offsets before loading the next page',
    (tester) async {
      api.followIds.addAll(List.generate(41, (index) => index + 1));
      await mount(tester, JmAccountCollection.follows);
      await tester.pumpAndSettle();
      final first = find.byKey(const ValueKey('1'));
      await tester.tap(
        find.descendant(of: first, matching: find.byType(IconButton)),
      );
      await tester.pumpAndSettle();
      expect(api.followReads, [1, 1]);
      expect(find.byKey(const ValueKey('1')), findsNothing);
      final next = find.text('加载更多');
      await tester.scrollUntilVisible(next, 360);
      expect(find.text('追踪 21'), findsOneWidget);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(api.followReads, [1, 1, 2]);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 2));
    },
  );

  testWidgets(
    'refresh reads the loaded follow tail even if the head is unchanged',
    (tester) async {
      api.followIds.addAll(List.generate(40, (index) => index + 1));
      await mount(tester, JmAccountCollection.follows);
      await tester.pumpAndSettle();
      final next = find.text('加载更多');
      await tester.scrollUntilVisible(next, 360);
      await tester.tap(next);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('追踪 40'), 360);

      api.followIds[39] = 41;
      final refresh = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );

      api.rejectFollowPage = 2;
      await refresh.onRefresh();
      await tester.pumpAndSettle();
      expect(api.followReads, [1, 2, 1, 2]);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      await tester.scrollUntilVisible(find.text('追踪 40'), 200);
      expect(find.text('追踪 40'), findsOneWidget);
      expect(find.text('追踪 41'), findsNothing);

      api.rejectFollowPage = null;
      await refresh.onRefresh();
      await tester.pumpAndSettle();

      expect(api.followReads, [1, 2, 1, 2, 1, 2]);
      expect(find.text('追踪 40'), findsNothing);
      expect(find.text('追踪 41'), findsOneWidget);
    },
  );

  testWidgets('confirmed account warm tags survive a failed refresh', (
    tester,
  ) async {
    final source = PluginAccountAuthenticationService.jm;
    api.source = source;
    final generation = pluginSessionWriteFence.generation(source);
    expect(
      PluginAccountIdentities.confirm(
        source,
        const PluginAccountAuthentication(serverIdentity: 'a'),
        generation: generation,
      ),
      isTrue,
    );
    addTearDown(() => pluginSessionWriteFence.advance(source));
    const tag = '私有标签';
    await mount(tester, JmAccountCollection.tags);
    await tester.pumpAndSettle();
    expect(api.tagReads, 1);
    expect(find.text(tag), findsOneWidget);
    await tester.tap(find.byType(SourceBackButton).hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open fixture'));
    await tester.pumpAndSettle();
    expect(api.tagReads, 1);
    expect(find.text(tag), findsOneWidget);

    api.rejectRead = true;
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(api.tagReads, 2);
    expect(find.text(tag), findsOneWidget);
    expect(find.text(t.common.retry), findsOneWidget);

    pluginSessionWriteFence.advance(source);
    await tester.pumpAndSettle();
    expect(find.text(tag), findsNothing);
  });

  testWidgets(
    'comic account action sends desired follow state with account identity',
    (tester) async {
      await mount(tester, JmAccountCollection.comic);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const ValueKey('标签甲')))
            .value,
        isTrue,
      );
      expect(find.byType(SettingPageShell), findsOneWidget);
      expect(find.byType(SettingSection), findsNWidgets(2));
      expect(find.byType(BreezeSwitchListTile), findsOneWidget);
      final follow = find.byType(SwitchListTile);
      expect(tester.widget<SwitchListTile>(follow).value, isFalse);
      await tester.tap(follow);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(follow).value, isTrue);
      expect(api.writes, hasLength(1));
      expect(api.writes.single, containsPair('accountId', 'a'));
      expect(api.writes.single, containsPair('enabled', true));
      expect(api.writes.single, containsPair('comicId', '123'));
    },
  );

  testWidgets(
    'tag browsing uses the original plugin and tag search scope with ordinary back',
    (tester) async {
      await mount(tester, JmAccountCollection.tags);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(find.byTooltip(t.sourceProfile.jmRemoveTag), findsNothing);
      await tester.tap(find.text('私有标签'));
      await tester.pumpAndSettle();
      expect(find.byType(SearchResultPage), findsOneWidget);
      expect(api.searches.single, containsPair('keyword', '私有标签'));
      expect(api.searches.single['extern'], containsPair('main_tag', 3));
      await tester.tap(find.byType(SourceBackButton).hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('私有标签'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'tag removal confirms first and keeps the row pending until the server replies',
    (tester) async {
      api.writeGate = Completer<void>();
      await mount(tester, JmAccountCollection.tags);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.bookshelf.manage));
      await tester.pumpAndSettle();
      final remove = find.byTooltip(t.sourceProfile.jmRemoveTag);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(
        find.text(t.sourceProfile.jmRemoveTagConfirm(name: '私有标签')),
        findsOneWidget,
      );
      expect(api.writes, isEmpty);
      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();
      expect(api.writes, isEmpty);
      expect(find.text('私有标签'), findsOneWidget);

      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.remove));
      await tester.pump(const Duration(milliseconds: 300));
      expect(api.writes.single, containsPair('tagWasPresent', true));
      expect(api.writes.single, containsPair('accountId', 'a'));
      expect(api.writes.single, containsPair('enabled', false));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(remove, findsNothing);
      expect(find.text('私有标签'), findsOneWidget);

      api.writeGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('私有标签'), findsNothing);
      expect(find.text(t.sourceProfile.jmTagRemoved), findsOneWidget);
      expect(api.writes, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'adding a tag keeps the input on failure and submits one validated tag',
    (tester) async {
      api.rejectWrite = true;
      await mount(tester, JmAccountCollection.tags);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.bookshelf.manage));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.sourceProfile.jmAddTag));
      await tester.pumpAndSettle();
      final field = find.byType(TextField);
      final add = find.widgetWithText(TextButton, t.common.add);
      await tester.enterText(field, '无效,名称');
      await tester.pump();
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.text(t.sourceProfile.jmTagInvalid), findsOneWidget);
      expect(api.writes, isEmpty);
      await tester.enterText(field, '  新标签  ');
      await tester.pump();
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.byType(TaskDialog), findsOneWidget);
      expect(tester.widget<TextField>(field).controller?.text, '  新标签  ');
      api.rejectWrite = false;
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.byType(TaskDialog), findsNothing);
      expect(find.text('新标签'), findsOneWidget);
      expect(api.writes, hasLength(2));
      expect(api.writes.last, containsPair('enabled', true));
      expect(api.writes.last['tags'], ['新标签']);
      expect(api.tags, contains('新标签'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'account transition clears the list and ignores late private data',
    (tester) async {
      api.gate = Completer<void>();
      await mount(tester, JmAccountCollection.tags);
      await tester.pump(const Duration(milliseconds: 400));
      final generation = pluginSessionWriteFence.beginSessionChange(_source);
      pluginSessionWriteFence.seal(_source, generation);
      api.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('私有标签'), findsNothing);
      expect(find.text('禁漫账号已变化，请返回个人页后重开'), findsOneWidget);
      expect(api.writes, isEmpty);
    },
  );
}
