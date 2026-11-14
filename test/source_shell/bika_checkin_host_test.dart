import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/main.dart' show eventBus;
import 'package:zephyr/page/source_shell/models/source_checkin_status.dart';
import 'package:zephyr/page/source_shell/view/source_profile_content.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/toast.dart';

import '../test_helper.dart';
import '../ui_preview_helper.dart';

const _bika = 'e9f18928-3ba8-4d86-a12e-b53a62f47933';
const _action = ValueKey('profile-checkin-action');
const _verify = ValueKey('profile-checkin-verify');

/// Synthetic plugin/native boundary; all data is generated here. Never invokes
/// the real Bika plugin, credentials, network, sign-in, or a device.
class _BikaProfileApi extends RustLibApi {
  Object? slogan = '品牌资料保留';
  bool? punched = false;
  bool profileFails = false;
  bool statusFails = false;
  Completer<void>? checkinGate;
  String? receiptAccount;
  String? receiptDate;
  bool receiptSigned = true;
  bool conflictingVerification = false;
  String verificationSource = 'serverProfile';
  bool updateProfileAfterCheckin = true;
  final calls = <String>[];

  void reset() {
    slogan = '品牌资料保留';
    punched = false;
    profileFails = false;
    statusFails = false;
    checkinGate = null;
    receiptAccount = null;
    receiptDate = null;
    receiptSigned = true;
    conflictingVerification = false;
    verificationSource = 'serverProfile';
    updateProfileAfterCheckin = true;
    calls.clear();
  }

  Map<String, dynamic> status(bool? value) {
    final today = sourceCheckinDate(DateTime.now());
    return {
      'accountId': 'bika-fixture-user',
      'checkedIn': value,
      'isPunched': value,
      'checkedInDate': value == true ? today : null,
      'checkinDateBasis': 'observedUtc8',
      'profileDataSource': 'serverProfile',
      'verification': {
        'source': verificationSource,
        'dateBasis': 'observedUtc8',
        'serverDate': null,
        'date': today,
        'checkedAt': DateTime.now().toUtc().toIso8601String(),
        'signed': value,
        'status': value == true
            ? 'confirmed'
            : value == false
            ? 'notSigned'
            : 'unknown',
      },
      'checkinProof': value == true
          ? {
              'source': 'serverProfile',
              'date': today,
              'dateBasis': 'observedUtc8',
              'serverDate': null,
              'verifiedThisRequest': true,
            }
          : null,
    };
  }

  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;

  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('offline-bika-checkin-host');

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
    calls.add(fnPath);
    Map<String, dynamic> data;
    switch (fnPath) {
      case 'init':
        data = {'ok': true};
      case 'getUserInfoBundle':
        if (profileFails) throw StateError('Synthetic profile unavailable');
        data = {
          'lines': ['Bika fixture'],
          'avatar': {'id': 'bika-fixture-user'},
          'extern': {
            ...status(punched),
            'name': 'Bika fixture',
            'level': null,
            'exp': null,
            'experience': '',
            'slogan': slogan,
          },
        };
      case 'getFavoriteData' || 'getCloudFavoriteData':
        data = {'items': <Object>[]};
      case 'getCheckinStatus':
        if (statusFails) {
          throw StateError('Synthetic profile verification unavailable');
        }
        data = status(punched);
      case 'checkInToday':
        final gate = checkinGate;
        checkinGate = null;
        if (gate != null) await gate.future;
        data = {
          ...status(receiptSigned),
          'ok': true,
          'message': '今日签到已完成',
          'accountId': receiptAccount ?? 'bika-fixture-user',
          'checkedInDate':
              receiptDate ??
              (receiptSigned ? sourceCheckinDate(DateTime.now()) : null),
          if (conflictingVerification)
            'verification': status(false)['verification'],
        };
        if (updateProfileAfterCheckin) punched = receiptSigned;
      default:
        throw StateError('Unexpected synthetic Bika operation $fnPath');
    }
    return Uint8List.fromList(
      utf8.encode(jsonEncode({'source': runtimeName, 'data': data})),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected native API ${invocation.memberName}');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = _BikaProfileApi();
  setUpAll(() async {
    await loadUiPreviewFonts();
    await TestObjectBoxHelper.setUpTestObjectBox();
    RustLib.initMock(api: api);
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api.reset();
  });
  tearDown(TestObjectBoxHelper.cleanComicFolderBoxes);

  Future<void> mount(
    WidgetTester tester, {
    bool capability = true,
    bool thirdParty = false,
    String style = 'breeze',
    Brightness brightness = Brightness.light,
    double width = 420,
    double scale = 1,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.binding.setSurfaceSize(Size(width, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cubit = GlobalSettingCubit();
    final preference = ValueNotifier(style);
    addTearDown(cubit.close);
    addTearDown(preference.dispose);
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: AppInterfaceStyleScope(
          style: preference,
          child: MaterialApp(
            theme: ThemeData(
              brightness: brightness,
              fontFamily: uiPreviewDirectory == null ? null : 'AccountPreview',
            ),
            builder: (context, child) => RepaintBoundary(
              key: const ValueKey('checkin-preview'),
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
            ),
            home: Scaffold(
              body: SourceProfileContent(
                source: thirdParty ? 'unknown-third-party' : _bika,
                sourceName: thirdParty ? 'Third party' : '哔咔',
                profileKind: thirdParty ? 'generic' : 'bika',
                checkinFunction: capability ? 'checkInToday' : '',
                checkinStatusFunction: capability ? 'getCheckinStatus' : '',
                checkinStatusSource: 'serverProfile',
                onLogin: () async {},
                onSettings: () async {},
                onCloudFavorite: () async {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> refresh(WidgetTester tester) async {
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator).first)
        .onRefresh();
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Key key) async {
    final finder = find.byKey(key);
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester) =>
      tester.widget<ButtonStyleButton>(find.byKey(_action)).onPressed != null;
  bool confirmed(WidgetTester tester) => find
      .descendant(
        of: find.byKey(_action),
        matching: find.text(t.sourceProfile.checkedIn),
      )
      .evaluate()
      .isNotEmpty;

  testWidgets(
    'Bika brand exposes check-in only with declared capability and a loaded account',
    (tester) async {
      await mount(tester);
      expect(find.text('品牌资料保留'), findsOneWidget);
      expect(find.byKey(_action), findsOneWidget);
      expect(find.byKey(_verify), findsNothing);
      expect(
        find.byKey(const ValueKey('profile-checkin-evidence')),
        findsNothing,
      );
      expect(api.calls.where((call) => call == 'checkInToday'), isEmpty);
      await mount(tester, capability: false, thirdParty: true);
      expect(find.byKey(_action), findsNothing);
      expect(find.byKey(_verify), findsNothing);
      api.profileFails = true;
      await mount(tester);
      expect(find.byKey(_action), findsNothing);
      expect(api.calls.where((call) => call == 'checkInToday'), isEmpty);
    },
  );

  testWidgets(
    'profile slogan shows trimmed text and omits absent or malformed data',
    (tester) async {
      api.slogan = '  真实简介\n第二行  ';
      await mount(tester);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('profile-slogan'))).data,
        '真实简介\n第二行',
      );
      for (final value in [
        null,
        ' \n ',
        {'text': 'malformed'},
      ]) {
        api.slogan = value;
        await refresh(tester);
        expect(find.byKey(const ValueKey('profile-slogan')), findsNothing);
      }
      expect(api.calls.where((call) => call == 'checkInToday'), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fresh serverProfile false clears an earlier true for the same observed day',
    (tester) async {
      api.punched = true;
      await mount(tester);
      expect(confirmed(tester), isTrue);
      expect(enabled(tester), isFalse);
      api.punched = false;
      await refresh(tester);
      expect(confirmed(tester), isFalse);
      expect(enabled(tester), isTrue);
      api.punched = true;
      await refresh(tester);
      expect(confirmed(tester), isTrue);
      api.punched = null;
      await refresh(tester);
      expect(confirmed(tester), isFalse);
      expect(enabled(tester), isTrue);
      expect(api.calls.where((call) => call == 'checkInToday'), isEmpty);
    },
  );

  testWidgets(
    'unknown profile never invents success or zero level and has no manual verification',
    (tester) async {
      api.punched = null;
      await mount(tester);
      expect(confirmed(tester), isFalse);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              RegExp(r'^Lv\.\s*0(?:\D|$)').hasMatch(widget.data ?? ''),
        ),
        findsNothing,
      );
      expect(find.byKey(_verify), findsNothing);
      expect(confirmed(tester), isFalse);
      expect(api.calls.where((call) => call == 'getCheckinStatus'), isEmpty);
      expect(api.calls.where((call) => call == 'checkInToday'), isEmpty);
      api.profileFails = true;
      await refresh(tester);
      expect(confirmed(tester), isFalse);
    },
  );

  testWidgets(
    'one explicit user punch remains disabled in flight and uses a matching confirmed record',
    (tester) async {
      await mount(tester);
      final gate = Completer<void>();
      api.checkinGate = gate;
      final action = find.byKey(_action);
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pump();
      expect(enabled(tester), isFalse);
      expect(api.calls.where((call) => call == 'checkInToday'), hasLength(1));
      gate.complete();
      await tester.pumpAndSettle();
      expect(confirmed(tester), isTrue);
      expect(enabled(tester), isFalse);
      expect(api.calls.where((call) => call == 'checkInToday'), hasLength(1));
    },
  );

  testWidgets(
    'wrong-account, old-day and unsigned success envelopes never become successful UI actions',
    (tester) async {
      final successEvents = <ToastEvent>[];
      final subscription = eventBus.on<ToastEvent>().listen((event) {
        if (event.type == ToastType.success) successEvents.add(event);
      });
      addTearDown(subscription.cancel);
      for (final invalid in ['account', 'day', 'unsigned', 'verification']) {
        api.reset();
        api.updateProfileAfterCheckin = false;
        if (invalid == 'account') api.receiptAccount = 'other-fixture-user';
        if (invalid == 'day') api.receiptDate = '2000-01-01';
        if (invalid == 'unsigned') api.receiptSigned = false;
        if (invalid == 'verification') api.conflictingVerification = true;
        await mount(tester);
        await tap(tester, _action);
        expect(confirmed(tester), isFalse, reason: invalid);
        expect(enabled(tester), isTrue, reason: invalid);
        expect(successEvents, isEmpty, reason: invalid);
      }
    },
  );

  testWidgets(
    'normal profile refresh reads status without a manual verification or punch',
    (tester) async {
      await mount(tester);
      api.punched = true;
      await refresh(tester);
      expect(confirmed(tester), isTrue);
      expect(enabled(tester), isFalse);
      expect(api.calls.where((call) => call == 'getCheckinStatus'), isEmpty);
      expect(api.calls.where((call) => call == 'checkInToday'), isEmpty);
      expect(find.byKey(_verify), findsNothing);
      expect(
        find.byKey(const ValueKey('profile-checkin-evidence')),
        findsNothing,
      );
      api.verificationSource = 'unknown';
      await refresh(tester);
      expect(confirmed(tester), isFalse);
      expect(
        find.byKey(const ValueKey('profile-checkin-evidence')),
        findsNothing,
      );
    },
  );

  for (final (style, brightness) in [
    ('system', Brightness.light),
    ('system', Brightness.dark),
    ('breeze', Brightness.light),
    ('breeze', Brightness.dark),
  ]) {
    testWidgets(
      'Bika branded host keeps avatar and 44pt check-in actions at 320 large text $style',
      (tester) async {
        await mount(
          tester,
          style: style,
          brightness: brightness,
          width: 320,
          scale: 1.8,
        );
        final avatar = find.byIcon(Icons.person_outline).first;
        final before = tester.getRect(avatar);
        expect(before.width, greaterThanOrEqualTo(44));
        final action = find.byKey(_action);
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        final actionRect = tester.getRect(action);
        expect(actionRect.height, greaterThanOrEqualTo(44));
        expect(actionRect.left, greaterThanOrEqualTo(0));
        expect(actionRect.right, lessThanOrEqualTo(320));
        expect(find.byKey(_verify), findsNothing);
        await writeUiPreview(
          tester,
          const ValueKey('checkin-preview'),
          'bika-$style-${brightness.name}-available',
        );
        api.punched = true;
        await refresh(tester);
        // The brand avatar remains in the same profile structure when status changes.
        expect(tester.getSize(avatar), before.size);
        expect(confirmed(tester), isTrue);
        await writeUiPreview(
          tester,
          const ValueKey('checkin-preview'),
          'bika-$style-${brightness.name}-confirmed',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
