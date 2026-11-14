import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/app_locale_binding.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/src/rust/frb_generated.dart';

import '../test_helper.dart';

class _LocaleApi extends RustLibApi {
  String? language;

  @override
  void crateApiQjsSetQjsErrorMessageLanguage({required String lang}) {
    language = lang;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final api = _LocaleApi();
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    await LocaleSettings.instance.loadLocale(AppLocale.enUs);
    RustLib.initMock(api: api);
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  late GlobalSettingCubit settings;
  setUp(() {
    settings = GlobalSettingCubit();
    final previous = LocaleSettings.currentLocale;
    LocaleSettings.setLocaleSync(AppLocale.zhCn);
    addTearDown(() => LocaleSettings.setLocaleSync(previous));
  });
  tearDown(() => settings.close());

  test('applying the OS language leaves the saved preference untouched', () async {
    final saved = const GlobalSettingState().copyWith(
      syncSetting: const SyncSettingState(settingsSyncTime: 123),
    );
    settings.applySyncedState(saved);

    await settings.refreshDisplayLocale(systemLocale: const Locale('en', 'GB'));

    expect(LocaleSettings.currentLocale, AppLocale.enUs);
    expect(api.language, 'en-US');
    expect(settings.state, saved);
    final reopened = GlobalSettingCubit();
    addTearDown(reopened.close);
    await reopened.initBox();
    expect(reopened.state, saved);
  });

  testWidgets('switches existing routes without discarding input', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      BlocProvider.value(
        value: settings,
        child: TranslationProvider(child: _App(navigator)),
      ),
    );

    await tester.enterText(find.byType(TextField), 'retained draft');
    navigator.currentState!.push<void>(
      MaterialPageRoute(builder: (_) => const _SettingsRoute()),
    );
    await tester.pumpAndSettle();
    expect(find.text('语言'), findsOneWidget);

    await settings.setLocale(const Locale('en', 'US'));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('语言'), findsNothing);
    expect(api.language, 'en-US');

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('retained draft'), findsOneWidget);
  });

  testWidgets('follows preferred supported OS language until a manual choice', (
    tester,
  ) async {
    final dispatcher = tester.binding.platformDispatcher;
    addTearDown(dispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      BlocProvider.value(
        value: settings,
        child: TranslationProvider(child: _App(GlobalKey<NavigatorState>())),
      ),
    );
    final original = settings.state;
    dispatcher.localesTestValue = const [Locale('fr'), Locale('en', 'GB')];
    await tester.pumpAndSettle();
    expect(find.text('Search'), findsOneWidget);
    expect(api.language, 'en-US');
    expect(settings.state, original);

    await settings.setLocale(const Locale('zh', 'CN'));
    await tester.pumpAndSettle();
    dispatcher.localesTestValue = const [Locale('en', 'US')];
    await tester.pumpAndSettle();
    expect(find.text('搜索'), findsOneWidget);
    expect(api.language, 'zh-CN');
  });
}

class _App extends StatelessWidget {
  const _App(this.navigator);

  final GlobalKey<NavigatorState> navigator;

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigator,
    locale: TranslationProvider.of(context).flutterLocale,
    supportedLocales: AppLocaleUtils.supportedLocales,
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => AppLocaleBinding(child: child!),
    home: const _HomeRoute(),
  );
}

class _HomeRoute extends StatelessWidget {
  const _HomeRoute();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [Text(t.common.search), const TextField()]),
  );
}

class _SettingsRoute extends StatelessWidget {
  const _SettingsRoute();

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Text(t.settings.language));
}
