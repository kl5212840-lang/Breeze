import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/source_shell/source_experience_scope.dart';
import 'package:zephyr/page/video/api_video_detail_page.dart';
import 'package:zephyr/page/video/api_video_library_page.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/api_video_repository.dart';
import 'package:zephyr/page/video/video_page_route.dart';
import 'package:zephyr/plugin/bridge/plugin_config_bridge.dart';
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';

const other = '83d82c45-7da1-45ec-9663-f93887b71947';
Future<void> install(String source) => PluginRegistryService.I.upsert(
  PluginInfo(
    uuid: source,
    version: '0.1.4',
    originScript: '',
    insertedAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    isEnabled: true,
    isDeleted: false,
    lastLoadSuccess: true,
    debug: false,
    getInfoJson: jsonEncode({
      'breezeExperience': {
        'bikaExperience': {
          'version': 1,
          'appearanceKey': bikaExperienceAppearanceKey,
          'loadingArtwork': bikaExperienceArtwork,
        },
      },
    }),
  ),
);
Future<void> until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 70; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (ready()) return;
  }
  expect(ready(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const connectivityChanges = MethodChannel(
    'dev.fluttercommunity.plus/connectivity_status',
  );
  setUpAll(() async {
    messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
    messenger.setMockMethodCallHandler(connectivityChanges, (_) async => null);
    await TestObjectBoxHelper.setUpTestObjectBox();
    await PluginRegistryService.I.init();
  });
  tearDownAll(() async {
    await TestObjectBoxHelper.tearDownTestObjectBox();
    messenger.setMockMethodCallHandler(connectivity, null);
    messenger.setMockMethodCallHandler(connectivityChanges, null);
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalPluginInstallationState.instance.reload();
    objectbox.pluginInfoBox.removeAll();
    objectbox.pluginConfigBox.removeAll();
    await PluginRegistryService.I.refreshFromDb();
    await install(bikaPlusSourceId);
    await install(other);
    // These routes exercise an explicitly selected source appearance.
    savePluginConfigValueSync(
      bikaPlusSourceId,
      bikaExperienceAppearanceKey,
      'original',
    );
  });

  for (final brightness in Brightness.values) {
    test(
      'original $brightness uses recovered neutrals and clears inherited global component colors',
      () {
        final base = ThemeData(brightness: brightness).copyWith(
          cardColor: Colors.green,
          chipTheme: const ChipThemeData(backgroundColor: Colors.orange),
          dialogTheme: const DialogThemeData(backgroundColor: Colors.purple),
        );
        final source = sourceOriginalPinkTheme(base),
            dark = brightness == Brightness.dark;
        expect(
          source.scaffoldBackgroundColor,
          dark ? const Color(0xFF121212) : const Color(0xFFF8F8FA),
        );
        expect(
          source.colorScheme.surface,
          dark ? const Color(0xFF1E1E1E) : Colors.white,
        );
        expect(
          source.colorScheme.outline,
          dark ? const Color(0xFF555555) : const Color(0xFFCCCCCC),
        );
        expect(
          source.colorScheme.outlineVariant,
          dark ? const Color(0xFF444444) : const Color(0xFFE0E0E0),
        );
        expect(
          source.appBarTheme.backgroundColor,
          dark ? const Color(0xFF35232B) : bikaOriginalBrandColor,
        );
        expect(
          source.appBarTheme.foregroundColor,
          dark ? const Color(0xFFFFE3ED) : const Color(0xFF3B1727),
        );
        expect(source.cardColor, dark ? const Color(0xFF252525) : Colors.white);
        expect(source.dialogTheme.backgroundColor, source.cardColor);
        expect(source.chipTheme.backgroundColor, source.colorScheme.surface);
        expect(
          source.navigationBarTheme.indicatorColor,
          dark ? const Color(0xFF35232B) : const Color(0xFFF8DCE7),
        );
        expect(
          source.navigationBarTheme.iconTheme!.resolve({
            WidgetState.selected,
          })!.color,
          dark ? const Color(0xFFFFB0CD) : const Color(0xFFAD416C),
        );
        expect(base.cardColor, Colors.green);
        expect(base.dialogTheme.backgroundColor, Colors.purple);
        expect(base.chipTheme.backgroundColor, Colors.orange);
      },
    );
  }

  for (final targetSource in [bikaPlusSourceId, other]) {
    testWidgets(
      'pushed real video catalog keeps its own $targetSource appearance and retains state through account/style changes',
      (tester) async {
        final globalStyle = ValueNotifier('system');
        addTearDown(globalStyle.dispose);
        final calls = <String>[];
        final repo = ApiVideoRepository(
          source: targetSource,
          home: Uri.parse('https://theme-fixture.invalid/'),
          catalogFn: 'list',
          detailFn: 'item',
          playbackFn: 'play',
          capabilities: const ApiVideoCapabilities(
            search: 'none',
            year: false,
            recent: false,
          ),
          pluginCall: (fn, _) async {
            calls.add(fn);
            return {
              'data': {
                'page': 1,
                'pageCount': 1,
                'items': [],
                'categories': [],
              },
            };
          },
        );
        late ThemeData applicationTheme;
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: globalStyle,
            child: MaterialApp(
              theme:
                  ThemeData(
                    colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
                  ).copyWith(
                    appBarTheme: const AppBarThemeData(
                      backgroundColor: Color(0xFF123456),
                    ),
                    dialogTheme: const DialogThemeData(
                      backgroundColor: Colors.purple,
                    ),
                  ),
              home: Builder(
                builder: (context) {
                  applicationTheme = Theme.of(context);
                  return SourceExperienceBoundary(
                    source: bikaPlusSourceId,
                    builder: (context) => Scaffold(
                      body: TextButton(
                        key: const ValueKey('open-catalog'),
                        onPressed: () =>
                            Navigator.of(
                              context,
                              rootNavigator: true,
                            ).push<void>(
                              videoPageRoute<void>(
                                builder: (_) => ApiVideoLibraryPage(
                                  key: const ValueKey('theme-catalog'),
                                  repository: repo,
                                  title: 'Theme fixture',
                                ),
                              ),
                            ),
                        child: const Text('open'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.tap(find.byKey(const ValueKey('open-catalog')));
        await tester.pumpAndSettle();
        await until(tester, () => calls.contains('list'));
        await tester.pumpAndSettle();
        final owner = find.byKey(const ValueKey('theme-catalog'));
        final retained = tester.state(owner);
        final appBar = find.descendant(
          of: owner,
          matching: find.byType(AppBar),
        );
        BuildContext context() => tester.element(appBar);
        SourceExperienceState scoped() =>
            SourceExperienceScope.maybeOf(context())!;
        final original = targetSource == bikaPlusSourceId;
        expect(scoped().isOriginal, original);
        expect(scoped().applicationTheme, applicationTheme);
        expect(
          Theme.of(context()).appBarTheme.backgroundColor,
          original ? bikaOriginalBrandColor : const Color(0xFF123456),
        );
        expect(
          SourceExperienceScope.controlsStyleOf(context()),
          original ? 'breeze' : 'system',
        );
        final transportCalls = calls.toList();
        savePluginConfigValueSync(
          bikaPlusSourceId,
          'auth.account',
          'synthetic-account-switch',
        );
        savePluginConfigValueSync(
          bikaPlusSourceId,
          'auth.authorization',
          'synthetic-session-switch',
        );
        await until(tester, () => tester.state(owner) == retained);
        expect(scoped().isOriginal, original);
        expect(calls, transportCalls);
        savePluginConfigValueSync(
          bikaPlusSourceId,
          bikaExperienceAppearanceKey,
          'follow',
        );
        await until(tester, () => !scoped().isOriginal);
        expect(
          Theme.of(context()).appBarTheme.backgroundColor,
          const Color(0xFF123456),
        );
        expect(scoped().applicationTheme, applicationTheme);
        expect(SourceExperienceScope.controlsStyleOf(context()), 'system');
        expect(tester.state(owner), same(retained));
        expect(calls, transportCalls);
        Navigator.of(context()).pop();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('open-catalog')), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'an explicit white page app bar and its dark foreground take precedence over the brand default',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SourceExperienceBoundary(
            source: bikaPlusSourceId,
            builder: (_) => Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                title: const Text('white page'),
                leading: const Icon(
                  Icons.arrow_back,
                  key: ValueKey('white-page-icon'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        IconTheme.of(
          tester.element(find.byKey(const ValueKey('white-page-icon'))),
        ).color,
        Colors.black,
      );
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(AppBar),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, Colors.white);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'pushed real video detail has a source boundary independent of its caller route',
    (tester) async {
      final globalStyle = ValueNotifier('breeze');
      addTearDown(globalStyle.dispose);
      final home = Uri.parse('https://theme-detail.invalid/');
      final item = {
        'id': 'fixture',
        'title': 'Theme detail',
        'detailUrl': home.resolve('item').toString(),
        'description': 'Native detail fixture',
        'lines': [],
      };
      final repository = ApiVideoRepository(
        source: bikaPlusSourceId,
        home: home,
        catalogFn: 'list',
        detailFn: 'item',
        playbackFn: 'play',
        pluginCall: (_, _) async => {'data': item},
      );
      await tester.pumpWidget(
        AppInterfaceStyleScope(
          style: globalStyle,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    videoPageRoute<void>(
                      builder: (_) => ApiVideoDetailPage(
                        key: const ValueKey('theme-detail'),
                        repository: repository,
                        initialItem: ApiVideoItem.fromJson(item, home: home),
                      ),
                    ),
                  ),
                  child: const Text('detail'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('detail'));
      await tester.pump();
      final owner = find.byKey(const ValueKey('theme-detail'));
      await until(tester, () => owner.evaluate().isNotEmpty);
      final retained = tester.state(owner);
      final boundary = find
          .descendant(of: owner, matching: find.byType(SourceExperienceScope))
          .first;
      expect(
        tester.widget<SourceExperienceScope>(boundary).data.isOriginal,
        isTrue,
      );
      expect(
        Theme.of(tester.element(boundary)).scaffoldBackgroundColor,
        const Color(0xFFF8F8FA),
      );
      savePluginConfigValueSync(
        bikaPlusSourceId,
        bikaExperienceAppearanceKey,
        'follow',
      );
      await until(
        tester,
        () => !tester.widget<SourceExperienceScope>(boundary).data.isOriginal,
      );
      expect(tester.state(owner), same(retained));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
