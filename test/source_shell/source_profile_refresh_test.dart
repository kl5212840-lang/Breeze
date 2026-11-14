import 'package:zephyr/widgets/read_recovery_scope.dart';
import 'package:zephyr/page/comic_list/cubit/jm_collection_snapshots.dart';
import 'package:zephyr/page/comic_list/view/plugin_paged_comic_list_view.dart';
import 'package:zephyr/plugin/bridge/plugin_session_write_fence.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/service/plugin_account_identity.dart';
import 'package:zephyr/service/plugin_account_authentication.dart';
import 'package:zephyr/page/source_shell/models/source_shell_section.dart';
import 'package:zephyr/page/source_shell/view/source_shell_page.dart';
import 'package:zephyr/page/video/video_native_navigation.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/page/account/plugin_saved_accounts_page.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/config/router/router.gr.dart'
    show LoginRoute, LoginRouteArgs;
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show eventBus, objectbox;
import 'package:zephyr/page/bookshelf/models/shelf_page_mode.dart';
import 'package:zephyr/page/login_page.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/source_shell/view/jm_collection_toolbar.dart';
import 'package:zephyr/page/source_shell/models/source_checkin_status.dart';
import 'package:zephyr/page/source_shell/view/source_profile_content.dart';
import 'package:zephyr/page/source_shell/view/source_profile_records_view.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/util/event/event.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/toast.dart';

import '../test_helper.dart';

const _source = 'profile-refresh-fixture';
const _cloudKey = ValueKey('profile-preview-cloud');

Map<String, dynamic> _cloudItem(String id) => {
  'source': _source,
  'id': id,
  'title': 'Cloud fixture $id',
  'subtitle': '',
  'finished': false,
  'likesCount': 0,
  'viewsCount': 0,
  'updatedAt': '',
  'cover': {'id': id, 'url': '', 'path': '', 'extern': <String, dynamic>{}},
  'metadata': [],
  'raw': <String, dynamic>{},
  'extern': <String, dynamic>{},
};

class _ProfileApi extends RustLibApi {
  String accountName = 'Profile fixture';
  String? cloudFailure;
  Completer<void>? cloudGate;
  List<String> cloudIds = ['first'];
  int cloudReads = 0;
  Object? cloudTotal = 47;
  bool malformedCloud = false;
  String? profileAuthFailure;
  String? requiredCopyEndpoint;
  int profileReads = 0;
  final cloudArguments = <Map<String, dynamic>>[];
  String slogan = '真实简介';
  bool updateBioSucceeds = true;
  bool updateBioVisible = true;
  bool failProfileAfterBio = false;
  int bioWrites = 0;
  String avatarUrl = '';
  bool avatarVisible = true;
  String? avatarRestriction;
  final avatarWrites = <img.Image?>[];
  bool? checkedIn;
  bool profileFailure = false;
  bool failProfileAfterCheckin = false;
  bool checkinSucceeds = true;
  int checkinCalls = 0;

  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;

  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('offline-profile-refresh');

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
    Object response;
    switch (fnPath) {
      case 'init':
        response = {
          'data': {'ok': true},
        };
      case 'getLoginBundle':
        response = {
          'scheme': {
            'fields': [
              {'key': 'username', 'kind': 'text', 'label': 'Account'},
              {'key': 'password', 'kind': 'password', 'label': 'Password'},
            ],
            'submitFnPath': 'loginWithPassword',
          },
          'data': {
            'values': {
              'username': 'saved-account',
              'password': 'fixture-secret',
            },
          },
        };
      case 'getUserInfoBundle':
        profileReads++;
        final requiredEndpoint = requiredCopyEndpoint;
        if (requiredEndpoint != null &&
            loadPluginConfigValue<String>(
                  runtimeName,
                  'api.domain',
                  fallback: '',
                ) !=
                requiredEndpoint) {
          throw AnyhowException(
            jsonEncode({'type': 'unauthorized', 'message': '登录过期，请重新登录'}),
          );
        }
        if (profileAuthFailure != null)
          throw AnyhowException(profileAuthFailure!);
        if (profileFailure) throw StateError('fixture profile unavailable');
        response = {
          'source': _source,
          'data': {
            'lines': [accountName],
            if (avatarUrl.isNotEmpty) 'avatar': {'url': avatarUrl},
            'extern': {
              'name': accountName,
              'accountId': accountName,
              'userId': accountName,
              'username': accountName,
              'slogan': slogan,
              'checkedIn': checkedIn,
              'checkedInDate': checkedIn == true
                  ? sourceCheckinDate(DateTime.now())
                  : null,
            },
          },
        };
      case 'updateBio':
        bioWrites++;
        final args = jsonDecode(argsJson) as Map;
        if (updateBioSucceeds && updateBioVisible)
          slogan = args['value'] as String;
        profileFailure = failProfileAfterBio;
        response = {'ok': updateBioSucceeds};
      case 'updateAvatar':
        final args = jsonDecode(argsJson) as Map;
        final jpeg = base64Decode(args['jpegBase64'] as String);
        if (runtimeName == PluginAccountAuthenticationService.copy) {
          expect(jpeg.length, lessThanOrEqualTo(500000));
        }
        avatarWrites.add(img.decodeJpg(jpeg));
        if (avatarVisible) avatarUrl = 'https://avatar.example/updated.jpg';
        response = avatarRestriction == null
            ? {'ok': true}
            : {'ok': false, 'avatarRestriction': avatarRestriction};
      case 'checkInToday':
        checkinCalls++;
        profileFailure = failProfileAfterCheckin;
        response = {
          'source': _source,
          'data': {
            'ok': checkinSucceeds,
            'message': checkinSucceeds ? '签到成功' : '签到失败',
            'accountId': accountName,
            'checkedIn': true,
            'checkedInDate': sourceCheckinDate(DateTime.now()),
          },
        };
      case 'getCloudFavoriteData' || 'getFavoriteData':
        cloudReads++;
        cloudArguments.add(
          Map<String, dynamic>.from(jsonDecode(argsJson) as Map),
        );
        final gate = cloudGate;
        cloudGate = null;
        if (gate != null) await gate.future;
        if (cloudFailure != null) throw AnyhowException(cloudFailure!);
        response = {
          'source': _source,
          'data': {
            'paging': {'page': 1, 'pages': 3, 'total': cloudTotal},
            'items': malformedCloud ? null : cloudIds.map(_cloudItem).toList(),
          },
        };
      default:
        throw StateError('Unexpected fixture operation: $fnPath');
    }
    return Uint8List.fromList(utf8.encode(jsonEncode(response)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected native API: ${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = _ProfileApi();
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: api);
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const connectivity = MethodChannel(
      'dev.fluttercommunity.plus/connectivity',
    );
    const changes = MethodChannel(
      'dev.fluttercommunity.plus/connectivity_status',
    );
    messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
    messenger.setMockMethodCallHandler(changes, (_) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(connectivity, null);
      messenger.setMockMethodCallHandler(changes, null);
    });
    JmCollectionSnapshots.instance.clear();
    api.accountName = 'Profile fixture';
    api.cloudFailure = null;
    api.cloudGate = null;
    api.cloudIds = ['first'];
    api.cloudReads = 0;
    api.cloudTotal = 47;
    api.malformedCloud = false;
    api.profileAuthFailure = null;
    api.requiredCopyEndpoint = null;
    api.profileReads = 0;
    api.cloudArguments.clear();
    api.slogan = '真实简介';
    api.updateBioSucceeds = true;
    api.updateBioVisible = true;
    api.failProfileAfterBio = false;
    api.bioWrites = 0;
    api.avatarUrl = '';
    api.avatarVisible = true;
    api.avatarRestriction = null;
    api.avatarWrites.clear();
    api.checkedIn = null;
    api.profileFailure = false;
    api.failProfileAfterCheckin = false;
    api.checkinSucceeds = true;
    api.checkinCalls = 0;
  });
  tearDown(() async {
    await JmCollectionSnapshots.instance.flush();
    TestObjectBoxHelper.cleanComicFolderBoxes();
  });

  Future<void> mount(
    WidgetTester tester,
    String kind,
    String style,
    Brightness brightness, {
    Future<void> Function()? onLogin,
    Future<void> Function()? onCloudFavorite,
    bool editBio = false,
    bool editAvatar = false,
    String source = _source,
    double textScale = 1,
    SourceProfileBackController? backController,
    ValueNotifier<bool>? readActivity,
    GlobalKey<NavigatorState>? navigator,
    bool expectCover = true,
  }) async {
    final cubit = GlobalSettingCubit();
    final preference = ValueNotifier(style);
    final activity = readActivity ?? ValueNotifier(true);
    if (readActivity == null) addTearDown(activity.dispose);
    addTearDown(cubit.close);
    addTearDown(preference.dispose);
    // Match SourceShellPage's deferred navigation listener: a profile child
    // registers/clears its BackController while its provider is mounting.
    final chromeRevision = ValueNotifier<int>(0);
    var chromeDisposed = false;
    void chromeChanged() => scheduleMicrotask(() {
      if (!chromeDisposed) chromeRevision.value++;
    });
    backController?.addListener(chromeChanged);
    addTearDown(() {
      chromeDisposed = true;
      backController?.removeListener(chromeChanged);
      chromeRevision.dispose();
    });
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: AppInterfaceStyleScope(
          style: preference,
          child: MaterialApp(
            navigatorKey: navigator,
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: AnimatedBuilder(
              animation: chromeRevision,
              builder: (context, _) => Scaffold(
                appBar: kind == 'jm' && backController != null
                    ? AppBar(
                        title: Text(backController.title ?? '我的'),
                        actions: [
                          if (backController.title != null &&
                              backController.jmHeader.actions != null)
                            backController.jmHeader.actions!,
                        ],
                      )
                    : null,
                body: ValueListenableBuilder<bool>(
                  valueListenable: activity,
                  builder: (_, active, __) => ReadRecoveryScope(
                    active: active,
                    child: SourceProfileContent(
                      source: source,
                      sourceName: 'Fixture',
                      profileKind: kind,
                      backController: backController,
                      bioUpdateFunction: editBio ? 'updateBio' : '',
                      avatarUploadFunction: editAvatar ? 'updateAvatar' : '',
                      checkinFunction: kind == 'jm' ? 'checkInToday' : '',
                      cloudFavoriteFunction: kind == 'generic'
                          ? 'getCloudFavoriteData'
                          : '',
                      onLogin: onLogin ?? () async {},
                      onSettings: () async {},
                      onCloudFavorite: onCloudFavorite ?? () async {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(_cloudKey),
      250,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.pumpAndSettle();
    if (expectCover) {
      expect(
        find.byKey(const ValueKey('profile-cover-$_source:first')),
        findsOneWidget,
      );
    }
    if (kind == 'jm') {
      final scrollable = find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first;
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
    }
  }

  SourceProfileComicPreviewCard cloudCard(WidgetTester tester) =>
      tester.widget<SourceProfileComicPreviewCard>(
        find.byWidgetPredicate(
          (widget) =>
              widget is SourceProfileComicPreviewCard &&
              widget.previewKey == _cloudKey,
        ),
      );

  testWidgets(
    'a retained Copy profile rechecks account once after its endpoint changes',
    (tester) async {
      const source = PluginAccountAuthenticationService.copy;
      const key = 'api.domain';
      final activity = ValueNotifier(true);
      addTearDown(activity.dispose);
      api.requiredCopyEndpoint = 'working fixture line';
      await savePluginConfigValue(source, key, 'failed fixture line');
      await mount(
        tester,
        'generic',
        'breeze',
        Brightness.light,
        source: source,
        readActivity: activity,
        expectCover: false,
      );
      expect(api.profileReads, 1);
      expect(PluginAccountIdentities.current(source), isNull);
      final generation = pluginSessionWriteFence.generation(source);

      activity.value = false;
      await tester.pumpAndSettle();
      await savePluginConfigValue(source, key, api.requiredCopyEndpoint);
      await tester.pumpAndSettle();
      expect(api.profileReads, 1);

      activity.value = true;
      await tester.pumpAndSettle();
      expect(api.profileReads, 2);
      expect(PluginAccountIdentities.current(source)?.label, api.accountName);
      expect(pluginSessionWriteFence.generation(source), generation);
      await savePluginConfigValue(source, key, api.requiredCopyEndpoint);
      await tester.pumpAndSettle();
      expect(api.profileReads, 2);
    },
  );

  testWidgets(
    'cloud preview displays the full count and refreshes after view all',
    (tester) async {
      var views = 0;
      await mount(
        tester,
        'bika',
        'breeze',
        Brightness.light,
        onCloudFavorite: () async {
          views++;
          api.cloudIds = ['second'];
          api.cloudTotal = 62;
        },
      );
      expect(cloudCard(tester).countLabel, '47');
      expect(api.cloudArguments.single['page'], 1);
      expect((api.cloudArguments.single['extern'] as Map)['sort'], 'dd');
      final action = find.descendant(
        of: find.byKey(_cloudKey),
        matching: find.text('查看全部'),
      );
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(views, 1);
      expect(api.cloudReads, 2);
      expect(cloudCard(tester).countLabel, '62');
      expect(
        find.byKey(const ValueKey('profile-cover-$_source:second')),
        findsOneWidget,
      );
      api.cloudTotal = null;
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(cloudCard(tester).countLabel, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final listSucceeds in [true, false]) {
    testWidgets(
      'an earlier profile read survives a later default-list read only on failure ($listSucceeds)',
      (tester) async {
        final cache = JmCollectionSnapshots.instance;
        PluginAccountIdentities.confirm(
          _source,
          const PluginAccountAuthentication(
            serverIdentity: 'head-order-fixture',
          ),
          generation: pluginSessionWriteFence.generation(_source),
        );
        final navigator = GlobalKey<NavigatorState>();
        var listReads = 0;
        await mount(
          tester,
          'bika',
          'breeze',
          Brightness.light,
          navigator: navigator,
          onCloudFavorite: () async {
            await navigator.currentState!.push<void>(
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  body: PluginPagedComicListView(
                    pluginId: _source,
                    fnPath: 'getFavoriteData',
                    coreBuilder: (page) => {'page': page},
                    externBuilder: (_) => {
                      'source': 'cloudFavorite',
                      'sort': 'dd',
                    },
                    cloudFavorite: true,
                    requestPage: (_, __, ___, ____) async {
                      listReads++;
                      if (!listSucceeds) throw const FormatException('fixture');
                      return {
                        'source': _source,
                        'data': {
                          'total': 62,
                          'items': [_cloudItem('newer-head')],
                        },
                      };
                    },
                  ),
                ),
              ),
            );
          },
        );
        expect(cloudCard(tester).countLabel, '47');
        final gate = Completer<void>();
        api.cloudGate = gate;
        final earlier = tester
            .widget<RefreshIndicator>(find.byType(RefreshIndicator))
            .onRefresh();
        await tester.pump();
        expect(api.cloudReads, 2);
        final openList = find.descendant(
          of: find.byKey(_cloudKey),
          matching: find.text('查看全部'),
        );
        await tester.ensureVisible(openList);
        await tester.tap(openList);
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(PluginPagedComicListView), findsOneWidget);
        expect(listReads, 1);
        final query = cache.key(
          _source,
          'getFavoriteData',
          {'page': 1},
          {'source': 'cloudFavorite', 'sort': 'dd'},
        );
        expect(cache.read(query, _source)!.knownTotal, listSucceeds ? 62 : 47);
        final revision = cache.revision(_source);
        api.cloudIds = ['earlier-head'];
        api.cloudTotal = 16;
        gate.complete();
        await earlier;
        await tester.pump();

        final profile = tester.widget<SourceProfileComicPreviewCard>(
          find.byWidgetPredicate(
            (widget) =>
                widget is SourceProfileComicPreviewCard &&
                widget.previewKey == _cloudKey,
            skipOffstage: false,
          ),
        );
        expect(profile.countLabel, listSucceeds ? '47' : '16');
        expect(
          profile.entries.single.id,
          listSucceeds ? 'first' : 'earlier-head',
        );
        expect(cache.revision(_source), revision + (listSucceeds ? 0 : 1));
        if (listSucceeds) expect(listReads, 1);

        api.cloudIds = ['newer-head'];
        api.cloudTotal = 62;
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(cloudCard(tester).countLabel, '62');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'a confirmed removal updates the mounted profile without manual refresh',
    (tester) async {
      final cache = JmCollectionSnapshots.instance;
      final generation = pluginSessionWriteFence.generation(_source);
      PluginAccountIdentities.confirm(
        _source,
        const PluginAccountAuthentication(
          serverIdentity: 'profile-commit-fixture',
        ),
        generation: generation,
      );
      await mount(tester, 'bika', 'breeze', Brightness.light);
      expect(cloudCard(tester).countLabel, '47');
      await cache.mutate(
        source: _source,
        account: cache.accountScope(_source)!,
        generation: generation,
        id: 'first',
        favorited: false,
        previouslyFavorited: true,
      );
      await tester.pumpAndSettle();
      expect(cloudCard(tester).countLabel, '46');
      expect(
        find.byKey(const ValueKey('profile-cover-$_source:first')),
        findsNothing,
      );
      // This fixture deliberately keeps returning the old site state. A read
      // during the site's consistency window must not resurrect the cover.
      expect(api.cloudReads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('hidden profile commits wait for visibility before a read', (
    tester,
  ) async {
    final activity = ValueNotifier(true);
    addTearDown(activity.dispose);
    final cache = JmCollectionSnapshots.instance;
    final generation = pluginSessionWriteFence.generation(_source);
    PluginAccountIdentities.confirm(
      _source,
      const PluginAccountAuthentication(
        serverIdentity: 'profile-hidden-fixture',
      ),
      generation: generation,
    );
    await mount(
      tester,
      'bika',
      'breeze',
      Brightness.light,
      readActivity: activity,
    );
    activity.value = false;
    await tester.pump();
    await cache.mutate(
      source: _source,
      account: cache.accountScope(_source)!,
      generation: generation,
      id: 'first',
      favorited: false,
      previouslyFavorited: true,
    );
    await tester.pump(const Duration(seconds: 3));
    expect(api.cloudReads, 1);
    api.cloudIds = ['second'];
    api.cloudTotal = 46;
    activity.value = true;
    // Visibility is delivered during the first frame. Its zero-delay recovery
    // timer runs in the next event-loop turn, before the second frame settles.
    await tester.pump();
    await tester.pumpAndSettle();
    expect(api.cloudReads, 2);
    expect(cloudCard(tester).countLabel, '46');
    expect(
      find.byKey(const ValueKey('profile-cover-$_source:second')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed initial identity stops preview loading and retries identity first',
    (tester) async {
      api.profileFailure = true;
      await mount(
        tester,
        'generic',
        'breeze',
        Brightness.light,
        expectCover: false,
      );
      expect(api.cloudReads, 0);
      expect(cloudCard(tester).loading, isFalse);
      expect(cloudCard(tester).error, isNotNull);
      api.profileFailure = false;
      final retry = find.descendant(
        of: find.byKey(_cloudKey),
        matching: find.widgetWithText(TextButton, '重试'),
      );
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(api.cloudReads, 1);
      expect(cloudCard(tester).loading, isFalse);
      expect(cloudCard(tester).countLabel, '47');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'malformed cloud refresh retains covers and known count with retry',
    (tester) async {
      await mount(tester, 'bika', 'breeze', Brightness.dark);
      api.malformedCloud = true;
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('profile-cover-$_source:first')),
        findsOneWidget,
      );
      expect(cloudCard(tester).countLabel, '47');
      expect(cloudCard(tester).error, isNotNull);
      expect(find.text('站点账号中还没有收藏的漫画'), findsNothing);
    },
  );

  testWidgets(
    'an observed account change clears old cloud data before a failed read',
    (tester) async {
      await mount(tester, 'bika', 'breeze', Brightness.light);
      api.accountName = 'Second fixture account';
      api.cloudFailure = 'fixture network temporarily unavailable';
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('profile-cover-$_source:first')),
        findsNothing,
      );
      expect(cloudCard(tester).countLabel, isNull);
      expect(cloudCard(tester).error, isNotNull);
    },
  );

  testWidgets(
    'profile sign-out clears cloud data even if the cloud endpoint would succeed',
    (tester) async {
      await mount(tester, 'bika', 'breeze', Brightness.light);
      api.profileAuthFailure = jsonEncode({
        'type': 'unauthorized',
        'source': _source,
        'message': '登录已过期',
      });
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('profile-cover-$_source:first')),
        findsNothing,
      );
      expect(cloudCard(tester).countLabel, isNull);
      expect(find.text('登录后查看站点收藏'), findsOneWidget);
      expect(api.cloudReads, 1);
    },
  );

  testWidgets('legacy Copy member 401 shows sign-in in the mounted profile', (
    tester,
  ) async {
    const source = PluginAccountAuthenticationService.copy;
    api.profileAuthFailure =
        'HTTPError: Request failed with status code 401 Unauthorized: GET https://fixture.invalid/api/v3/member/info?fixture=private-value';
    await mount(
      tester,
      'generic',
      'breeze',
      Brightness.light,
      source: source,
      expectCover: false,
    );
    expect(cloudCard(tester).error, t.sourceProfile.signInForFavorites);
    expect(find.text(t.sourceProfile.signInForFavorites), findsWidgets);
    expect(find.textContaining('private-value'), findsNothing);
    expect(api.profileReads, 1);
    expect(api.cloudReads, 0);
  });

  for (final result in ['confirmed', 'stale', 'cancelled', 'cooldown']) {
    testWidgets(
      'avatar from account sheet uploads only on confirmation: $result',
      (tester) async {
        final copyCooldown = result == 'cooldown';
        final directory = Directory.systemTemp.createTempSync(
          'breeze-avatar-test-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final sourceImage = copyCooldown
            ? img.Image(width: 800, height: 600)
            : img.Image(width: 40, height: 60);
        if (copyCooldown) {
          final random = Random(812);
          for (final pixel in sourceImage) {
            pixel.setRgb(
              random.nextInt(256),
              random.nextInt(256),
              random.nextInt(256),
            );
          }
        }
        final original = img.encodePng(sourceImage);
        if (copyCooldown) expect(original.length, greaterThan(500000));
        final file = File('${directory.path}/fixture.png')
          ..writeAsBytesSync(original);
        const fileSelector = MethodChannel('plugins.flutter.io/file_selector');
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(fileSelector, (call) async {
          expect(call.method, 'openFile');
          return [file.path];
        });
        addTearDown(
          () => messenger.setMockMethodCallHandler(fileSelector, null),
        );
        final events = <ToastEvent>[];
        final subscription = eventBus.on<ToastEvent>().listen(events.add);
        addTearDown(subscription.cancel);
        api.avatarVisible = result == 'confirmed';
        api.avatarRestriction = copyCooldown ? 'cooldown' : null;
        await mount(
          tester,
          copyCooldown ? 'generic' : 'bika',
          'breeze',
          Brightness.light,
          editAvatar: true,
          source: copyCooldown
              ? PluginAccountAuthenticationService.copy
              : _source,
          expectCover: !copyCooldown,
        );
        final scrollable = find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first;
        tester.state<ScrollableState>(scrollable).position.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('profile-own-avatar')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('profile-account-avatar-action')),
        );

        Future<void> until(bool Function() ready) async {
          final elapsed = Stopwatch()..start();
          while (!ready() && elapsed.elapsed < const Duration(seconds: 5)) {
            await tester.pump(const Duration(milliseconds: 24));
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
          }
          expect(ready(), isTrue);
          await tester.pumpAndSettle();
        }

        final confirm = find.byKey(const ValueKey('image-editor-confirm'));
        await until(
          () =>
              confirm.evaluate().isNotEmpty &&
              tester.widget<NativeVideoIconButton>(confirm).onPressed != null,
        );
        expect(api.avatarWrites, isEmpty);
        expect(find.byKey(const ValueKey('video-task.body')), findsNothing);
        if (copyCooldown) {
          expect(find.text(t.sourceProfile.copyAvatarRules), findsOneWidget);
        }
        if (result == 'cancelled') {
          await tester.tap(find.byKey(const ValueKey('image-editor-cancel')));
          await tester.pumpAndSettle();
          expect(confirm, findsNothing);
          expect(api.avatarWrites, isEmpty);
        } else {
          await tester.tap(confirm);
          await until(() => events.isNotEmpty);
          expect(api.avatarWrites, hasLength(1));
          expect(api.avatarWrites.single?.width, 200);
          expect(api.avatarWrites.single?.height, 200);
          expect(
            events.single.type,
            result == 'confirmed' ? ToastType.success : ToastType.error,
          );
          if (copyCooldown) {
            expect(events.single.message, t.sourceProfile.copyAvatarInterval);
            expect(find.byType(AlertDialog), findsNothing);
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final result in ['confirmed', 'stale', 'unavailable', 'rejected']) {
    testWidgets('bio success requires a same-account profile read: $result', (
      tester,
    ) async {
      final events = <ToastEvent>[];
      final subscription = eventBus.on<ToastEvent>().listen(events.add);
      addTearDown(subscription.cancel);
      await mount(tester, 'bika', 'breeze', Brightness.light, editBio: true);
      final scrollable = find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first;
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-own-avatar')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('profile-account-bio-action')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '更新后的真实简介');
      api.updateBioVisible = result == 'confirmed';
      api.failProfileAfterBio = result == 'unavailable';
      api.updateBioSucceeds = result != 'rejected';
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(api.bioWrites, 1);
      expect(
        events.where((event) => event.type == ToastType.success).length,
        result == 'confirmed' ? 1 : 0,
      );
      if (result == 'rejected') {
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
      } else {
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('profile-slogan')))
              .data,
          result == 'confirmed' ? '更新后的真实简介' : '真实简介',
        );
      }
      expect(
        api.bioWrites,
        1,
        reason: 'A failed read must not repeat the write',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'confirmed check-in updates immediately and survives a failed profile refresh',
    (tester) async {
      api.failProfileAfterCheckin = true;
      await mount(
        tester,
        'jm',
        'breeze',
        Brightness.light,
        onLogin: () async {
          api.accountName = 'Another account';
          api.profileFailure = false;
        },
      );
      final action = find.byKey(const ValueKey('profile-checkin-action'));
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(api.checkinCalls, 1);
      expect(
        find.descendant(of: action, matching: find.text('今日已签到')),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(action).onPressed, isNull);
      api.profileFailure = false;
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: action, matching: find.text('今日已签到')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('profile-account-action')));
      await tester.pumpAndSettle();
      expect(find.byType(PluginSavedAccountsPage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('saved-account-add')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: action, matching: find.text('今日签到')),
        findsOneWidget,
      );
      expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile receipt disables a repeated check-in without posting', (
    tester,
  ) async {
    api.checkedIn = true;
    await mount(tester, 'jm', 'breeze', Brightness.dark);
    final action = find.byKey(const ValueKey('profile-checkin-action'));
    expect(
      find.descendant(of: action, matching: find.text('今日已签到')),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(action).onPressed, isNull);
    expect(api.checkinCalls, 0);
  });

  testWidgets('a failed check-in response never becomes a successful button', (
    tester,
  ) async {
    api.checkinSucceeds = false;
    await mount(tester, 'jm', 'breeze', Brightness.light);
    final action = find.byKey(const ValueKey('profile-checkin-action'));
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(api.checkinCalls, 1);
    expect(
      find.descendant(of: action, matching: find.text('今日签到')),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
  });

  for (final kind in ['bika', 'jm', 'generic']) {
    for (final style in ['system', 'breeze']) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'cloud refresh retains covers and retries $kind $style ${brightness.name}',
          (tester) async {
            await mount(tester, kind, style, brightness);
            final cover = find.byKey(
              const ValueKey('profile-cover-$_source:first'),
            );
            final element = tester.element(cover);
            final rect = tester.getRect(cover);
            final gate = Completer<void>();
            api.cloudGate = gate;
            final pending = tester
                .widget<RefreshIndicator>(find.byType(RefreshIndicator))
                .onRefresh();
            await tester.pump();
            expect(tester.element(cover), same(element));
            expect(tester.getRect(cover), rect);
            expect(
              find.descendant(
                of: find.byKey(_cloudKey),
                matching: find.byType(LinearProgressIndicator),
              ),
              findsOneWidget,
            );
            api.cloudFailure = 'fixture network temporarily unavailable';
            gate.complete();
            await pending;
            await tester.pumpAndSettle();
            expect(
              cover,
              findsOneWidget,
              reason: 'A refresh error must retain the loaded preview',
            );
            expect(tester.element(cover), same(element));
            expect(tester.getRect(cover), rect);
            final retry = find.descendant(
              of: find.byKey(_cloudKey),
              matching: find.widgetWithText(TextButton, '重试'),
            );
            expect(retry, findsOneWidget);
            api.cloudFailure = null;
            api.cloudIds = ['second'];
            await tester.ensureVisible(retry);
            await tester.tap(retry);
            await tester.pumpAndSettle();
            expect(cover, findsNothing);
            expect(
              find.byKey(const ValueKey('profile-cover-$_source:second')),
              findsOneWidget,
            );
            expect(retry, findsNothing);
            expect(api.cloudReads, 3);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
    testWidgets('confirmed sign-out clears cached cloud preview $kind', (
      tester,
    ) async {
      await mount(tester, kind, 'breeze', Brightness.light);
      api.cloudFailure = jsonEncode({
        'type': 'unauthorized',
        'source': _source,
        'message': '登录已过期',
      });
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('profile-cover-$_source:first')),
        findsNothing,
      );
      expect(find.text('登录后查看站点收藏'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('successful empty cloud response replaces prior preview $kind', (
      tester,
    ) async {
      await mount(tester, kind, 'breeze', Brightness.light);
      api.cloudIds = [];
      api.cloudTotal = 0;
      await tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('profile-cover-$_source:first')),
        findsNothing,
      );
      final preview = cloudCard(tester);
      expect(preview.entries, isEmpty);
      expect(
        preview.countLabel,
        '0',
        reason:
            'A successful empty response publishes the known total, not a failed or stale snapshot',
      );
      expect(preview.error, isNull);
      expect(preview.loading, isFalse);
      expect(find.text('站点收藏 · 0'), findsOneWidget);
      expect(
        find.text('站点账号中还没有收藏的漫画'),
        findsNothing,
        reason:
            'All comic profile previews now use the compact known-zero header',
      );
      final viewAll = find.descendant(
        of: find.byKey(_cloudKey),
        matching: find.widgetWithText(TextButton, '查看全部'),
      );
      expect(viewAll, findsOneWidget);
      expect(tester.widget<TextButton>(viewAll).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'account shortcut opens one saved page and add submits once while pending',
    (tester) async {
      final gate = Completer<void>();
      var opens = 0;
      await mount(
        tester,
        'generic',
        'breeze',
        Brightness.light,
        onLogin: () async {
          opens++;
          await gate.future;
        },
      );
      final switchAccount = find.byKey(
        const ValueKey('profile-account-action'),
      );
      // mount() leaves the main lazy list at its cloud preview; the account
      // action above it may no longer have an Element for ensureVisible().
      await tester.scrollUntilVisible(
        switchAccount,
        -250,
        scrollable: find
            .descendant(
              of: find.byType(SourceProfileContent),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Scrollable &&
                    widget.axisDirection == AxisDirection.down,
              ),
            )
            .first,
      );
      await tester.pumpAndSettle();
      final action = tester.widget<TextButton>(switchAccount);
      action.onPressed!();
      action.onPressed!();
      await tester.pumpAndSettle();
      expect(find.byType(PluginSavedAccountsPage), findsOneWidget);
      expect(opens, 0);
      final add = find.byKey(const ValueKey('saved-account-add'));
      final onTap = tester.widget<ListTile>(add).onTap!;
      onTap();
      onTap();
      await tester.pump();
      expect(opens, 1);
      expect(tester.widget<ListTile>(add).onTap, isNull);
      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<ListTile>(add).onTap, isNotNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(switchAccount).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'source My adds a blank account through the existing LoginRoute',
    (tester) async {
      final preference = ValueNotifier('breeze');
      final settings = GlobalSettingCubit();
      final router = RootStackRouter.build(
        routes: [
          NamedRouteDef(
            name: 'SourceProfileFixture',
            path: '/',
            initial: true,
            builder: (_, _) => SourceShellPage(
              source: _source,
              sourceName: 'Fixture',
              sections: [SourceShellSection.profile(profileKind: 'generic')],
            ),
          ),
          NamedRouteDef(
            name: LoginRoute.name,
            path: '/login',
            builder: (_, data) {
              final args = data.argsAs<LoginRouteArgs>();
              return LoginPage(key: args.key, from: args.from);
            },
          ),
        ],
      );
      addTearDown(preference.dispose);
      addTearDown(settings.close);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        BlocProvider.value(
          value: settings,
          child: AppInterfaceStyleScope(
            style: preference,
            child: MaterialApp.router(routerConfig: router.config()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final account = find.byKey(const ValueKey('profile-account-action'));
      await tester.ensureVisible(account);
      await tester.tap(account);
      await tester.pumpAndSettle();
      expect(find.byType(PluginSavedAccountsPage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('saved-account-add')));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields, hasLength(2));
      expect(fields.map((field) => field.controller?.text), ['', '']);
      await router.maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(PluginSavedAccountsPage), findsOneWidget);
      Navigator.of(tester.element(find.byType(PluginSavedAccountsPage))).pop();
      await tester.pumpAndSettle();
      expect(account, findsOneWidget);
      unawaited(router.push(LoginRoute(from: _source)));
      await tester.pumpAndSettle();
      final ordinary = tester.widgetList<TextField>(find.byType(TextField));
      expect(ordinary.map((field) => field.controller?.text), [
        'saved-account',
        'fixture-secret',
      ]);
      expect(ordinary.last.obscureText, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'account switch never retains the previous private preview on failure',
    (tester) async {
      await mount(
        tester,
        'generic',
        'breeze',
        Brightness.light,
        onLogin: () async {
          api.accountName = 'Second fixture account';
          api.cloudFailure = 'fixture network temporarily unavailable';
        },
      );
      await tester.scrollUntilVisible(
        find.text('切换账号'),
        -250,
        scrollable: find
            .byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.tap(find.text('切换账号'));
      await tester.pumpAndSettle();
      expect(find.byType(PluginSavedAccountsPage), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('saved-account-add')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Second fixture account'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('profile-cover-$_source:first')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('overlapping pulls join the same account cloud read', (
    tester,
  ) async {
    await mount(tester, 'generic', 'breeze', Brightness.light);
    final gate = Completer<void>();
    api.cloudGate = gate;
    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh;
    final first = refresh();
    await tester.pump();
    final second = refresh();
    await tester.pump();
    expect(
      api.cloudReads,
      2,
      reason: 'The initial read plus one shared pending refresh',
    );
    api.cloudIds = ['second'];
    gate.complete();
    await Future.wait([first, second]);
    await tester.pumpAndSettle();
    expect(api.cloudReads, 2);
    expect(
      find.byKey(const ValueKey('profile-cover-$_source:second')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('commits during a pending preview read coalesce one follow-up', (
    tester,
  ) async {
    final cache = JmCollectionSnapshots.instance;
    final generation = pluginSessionWriteFence.generation(_source);
    PluginAccountIdentities.confirm(
      _source,
      const PluginAccountAuthentication(
        serverIdentity: 'profile-follow-up-fixture',
      ),
      generation: generation,
    );
    await mount(tester, 'generic', 'breeze', Brightness.light);
    final gate = Completer<void>();
    api.cloudGate = gate;
    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh;
    final pending = refresh();
    await tester.pump();
    final account = cache.accountScope(_source)!;
    await cache.mutate(
      source: _source,
      account: account,
      generation: generation,
      id: 'first',
      favorited: false,
      previouslyFavorited: true,
    );
    await tester.pump();
    await cache.mutate(
      source: _source,
      account: account,
      generation: generation,
      id: 'unloaded',
      favorited: false,
      previouslyFavorited: true,
    );
    await tester.pump();
    expect(
      api.cloudReads,
      2,
      reason: 'Committed revisions wait for the one physical read',
    );
    expect(cloudCard(tester).countLabel, '45');
    api.cloudIds = ['second'];
    api.cloudTotal = 45;
    gate.complete();
    await pending;
    await tester.pump();
    await tester.pumpAndSettle();
    expect(
      api.cloudReads,
      3,
      reason: 'Both commits coalesce one follow-up for the latest revision',
    );
    expect(cloudCard(tester).countLabel, '45');
    expect(
      find.byKey(const ValueKey('profile-cover-$_source:second')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('profile-cover-$_source:first')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an older-session cloud refresh cannot replace a newer result', (
    tester,
  ) async {
    await mount(tester, 'generic', 'breeze', Brightness.light);
    final older = Completer<void>();
    api.cloudGate = older;
    final refresh = tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh;
    final first = refresh();
    await tester.pump();
    api.cloudIds = ['second'];
    pluginSessionWriteFence.advance(_source);
    await refresh();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('profile-cover-$_source:second')),
      findsOneWidget,
    );
    api.cloudIds = ['older'];
    older.complete();
    await first;
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('profile-cover-$_source:second')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('profile-cover-$_source:older')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'late cloud sign-out cannot invalidate a newer account or another tab',
    (tester) async {
      final events = <NeedLogin>[];
      final subscription = eventBus.on<NeedLogin>().listen(events.add);
      addTearDown(subscription.cancel);
      await mount(tester, 'generic', 'breeze', Brightness.light);
      final older = Completer<void>();
      api.cloudGate = older;
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh;
      final first = refresh();
      await tester.pump();
      api.accountName = 'Second fixture account';
      api.cloudIds = ['second'];
      await refresh();
      await tester.pumpAndSettle();
      api.cloudFailure = jsonEncode({
        'type': 'unauthorized',
        'source': _source,
        'message': '登录已过期',
      });
      older.complete();
      await first;
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('profile-cover-$_source:second')),
        findsOneWidget,
      );
      expect(cloudCard(tester).error, isNull);
      expect(events, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final style in ['system', 'breeze']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'JM shared overview uses compact protected rails and its own local download records $style ${scale}x',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final back = SourceProfileBackController();
          addTearDown(back.dispose);
          api.accountName = '真实且较长的禁漫账号名称用于检查换行';
          objectbox.unifiedFavoriteBox.put(
            createTestFavorite('own-favorite')..source = _source,
          );
          objectbox.unifiedHistoryBox.put(
            createTestHistory('own-history')..source = _source,
          );
          objectbox.unifiedDownloadBox.put(
            createTestDownload('own-download')..source = _source,
          );
          objectbox.unifiedDownloadBox.put(
            createTestDownload('foreign-download')..source = 'other',
          );
          try {
            await mount(
              tester,
              'jm',
              style,
              Brightness.light,
              textScale: scale,
              backController: back,
            );
            final account = find.byKey(const ValueKey('profile-account-card'));
            expect(account, findsOneWidget);
            expect(
              tester.getSize(
                find.byKey(const ValueKey('profile-account-avatar')),
              ),
              const Size(64, 64),
            );
            expect(
              find.byKey(const ValueKey('profile-checkin-verify')),
              findsNothing,
            );
            expect(
              find.byKey(const ValueKey('profile-checkin-evidence')),
              findsNothing,
            );
            final checkinRect = tester.getRect(
              find.byKey(const ValueKey('profile-checkin-action')),
            );
            final accountRect = tester.getRect(
              find.byKey(const ValueKey('profile-account-action')),
            );
            expect(checkinRect.width, closeTo(accountRect.width, .01));
            expect(checkinRect.top, accountRect.top);
            if (scale == 1)
              expect(
                tester.getSize(account).height,
                lessThan(180),
                reason:
                    'Ordinary JM account data no longer reserves the old large hero spacing',
              );
            expect(find.textContaining('Lv.0'), findsNothing);
            expect(
              tester
                  .getSize(find.byKey(const ValueKey('profile-checkin-action')))
                  .height,
              greaterThanOrEqualTo(44),
            );
            expect(
              tester
                  .getSize(find.byKey(const ValueKey('profile-account-action')))
                  .height,
              greaterThanOrEqualTo(44),
            );
            final cloudCover = find
                .descendant(
                  of: find.byKey(_cloudKey),
                  matching: find.byType(AspectRatio),
                )
                .first;
            final coverSize = tester.getSize(cloudCover);
            expect(coverSize.width, closeTo((320 - 24 - 24) / 3, .001));
            expect(coverSize.height, closeTo(coverSize.width * 1.5, .001));
            expect(cloudCard(tester).jmCollection, isTrue);
            expect(
              find.byType(SourceProfilePreviewHeader),
              findsNothing,
              reason:
                  'JM candidate has one view-all action and no disclosure arrow',
            );
            final viewAll = find.descendant(
              of: find.byWidgetPredicate(
                (widget) =>
                    widget is SourceProfileComicPreviewCard &&
                    widget.previewKey ==
                        const ValueKey('profile-preview-download'),
              ),
              matching: find.widgetWithText(TextButton, '查看全部'),
            );
            final overview = find
                .descendant(
                  of: find.byType(SourceProfileContent),
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget is Scrollable &&
                        widget.axisDirection == AxisDirection.down,
                  ),
                )
                .first;
            await tester.scrollUntilVisible(viewAll, 180, scrollable: overview);
            await tester.pumpAndSettle();
            expect(tester.getSize(viewAll).height, greaterThanOrEqualTo(44));
            await tester.tap(viewAll);
            await tester.pumpAndSettle();
            final records = tester.widget<SourceProfileRecordsView>(
              find.byType(SourceProfileRecordsView),
            );
            expect(records.mode, ShelfPageMode.download);
            expect(records.source, _source);
            expect(records.entries.map((entry) => entry.id), ['own-download']);
            expect(records.jmCollection, isTrue);
            expect(back.title, isNull);
            expect(
              ModalRoute.of(
                tester.element(find.byType(SourceProfileRecordsView)),
              )?.settings.name,
              'breeze.source.comic.records',
            );
            expect(
              find.byKey(const ValueKey('jm-record-tools')),
              findsOneWidget,
            );
            expect(find.byType(TextField), findsNothing);
            final search = find.byKey(const ValueKey('jm-record.search'));
            final recordTools = find.byKey(const ValueKey('jm-record-tools'));
            final toolsTop = tester.getTopLeft(recordTools).dy;
            expect(tester.getSize(search), const Size(44, 44));
            await tester.tap(search);
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('source-loaded.search')),
              findsOneWidget,
            );
            expect(tester.getTopLeft(recordTools).dy, closeTo(toolsTop, .01));
            expect(tester.testTextInput.isVisible, isTrue);
            expect(
              tester.widget<SourceChromeIconButton>(search).symbol,
              'xmark',
            );
            expect(back.canGoBack, isFalse);
            tester
                .widget<SourceChromeIconButton>(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget is SourceChromeIconButton &&
                        widget.tooltip == t.common.back,
                  ),
                )
                .onPressed!();
            await tester.pumpAndSettle();
            expect(find.byType(SourceProfileRecordsView), findsNothing);
            expect(find.byType(SourceProfileContent), findsOneWidget);
            expect(back.title, isNull);
            expect(
              api.checkinCalls,
              0,
              reason: 'Reading and navigating never performs check-in',
            );
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          }
        },
      );
    }
  }
  for (final kind in ['jm', 'copy']) {
    testWidgets(
      'real $kind shell opens root records without outer chrome and returns to My',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(bottom: 34);
        tester.view.viewPadding = const FakeViewPadding(bottom: 34);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
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
          messenger.setMockMethodCallHandler(
            SystemChannels.platform_views,
            null,
          );
          for (final channel in channels)
            messenger.setMockMethodCallHandler(channel, null);
        });
        final settings = GlobalSettingCubit(),
            preference = ValueNotifier('system');
        addTearDown(settings.close);
        addTearDown(preference.dispose);
        for (var index = 0; index < 8; index++)
          objectbox.unifiedFavoriteBox.put(
            createTestFavorite('own-$index')
              ..source = _source
              ..createdAt = DateTime.utc(2026, 11, index + 1),
          );
        try {
          await tester.pumpWidget(
            BlocProvider.value(
              value: settings,
              child: AppInterfaceStyleScope(
                style: preference,
                child: MaterialApp(
                  home: SourceShellPage(
                    source: _source,
                    sourceName: 'JM fixture',
                    sections: [
                      SourceShellSection.profile(
                        profileKind: kind,
                        profileCloudFavoriteFunction: 'getCloudFavoriteData',
                      ),
                      SourceShellSection.more(title: '更多', actions: []),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final action = find.descendant(
            of: find.byWidgetPredicate(
              (widget) =>
                  widget is SourceProfileComicPreviewCard &&
                  widget.previewKey ==
                      const ValueKey('profile-preview-favorite'),
            ),
            matching: find.widgetWithText(TextButton, '查看全部'),
          );
          await tester.scrollUntilVisible(
            action,
            180,
            scrollable: find
                .descendant(
                  of: find.byType(SourceProfileContent),
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget is Scrollable &&
                        widget.axisDirection == AxisDirection.down,
                  ),
                )
                .first,
          );
          await tester.tap(action);
          await tester.pumpAndSettle();
          final records = find.byType(SourceProfileRecordsView);
          expect(
            tester.widget<SourceProfileRecordsView>(records).mode,
            ShelfPageMode.favorite,
          );
          expect(find.byType(AppBar), findsNothing);
          expect(find.byType(VideoNativeNavigation), findsNothing);
          expect(
            find.descendant(
              of: records,
              matching: find.byType(JmCollectionNavigationActions),
            ),
            findsOneWidget,
            reason:
                'The root records destination owns its only navigation actions',
          );
          final more = tester.widget<NativeVideoMenu>(
            find.byKey(const ValueKey('jm-record.more')),
          );
          expect(more.symbol, 'ellipsis');
          expect(more.label, isEmpty);
          expect(more.selectionIndicator, isFalse);
          final filter = tester.getRect(
            find.byKey(const ValueKey('source-loaded.filters')),
          );
          expect(filter.width, 44);
          expect(filter.right, 378);
          final list = find.byKey(const ValueKey('profile-detailed-list'));
          final last = find.byKey(
            const ValueKey('profile-record.$_source:own-0'),
          );
          await tester.scrollUntilVisible(
            last,
            200,
            scrollable: find
                .descendant(of: list, matching: find.byType(Scrollable))
                .first,
          );
          await tester.drag(list, const Offset(0, -700));
          await tester.pumpAndSettle();
          expect(tester.getRect(last).bottom, lessThanOrEqualTo(844 - 34 + 1));
          expect(
            ModalRoute.of(tester.element(records))?.settings.name,
            'breeze.source.comic.records',
          );
          tester
              .widget<SourceChromeIconButton>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is SourceChromeIconButton &&
                      widget.tooltip == t.common.back,
                ),
              )
              .onPressed!();
          await tester.pumpAndSettle();
          expect(find.byType(SourceProfileRecordsView), findsNothing);
          expect(find.byType(JmCollectionNavigationActions), findsNothing);
          expect(
            find.descendant(of: find.byType(AppBar), matching: find.text('我的')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
