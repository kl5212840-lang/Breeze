import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/plugin_settings/cubit/plugin_settings_cubit.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_settings_content.dart';

import '../test_helper.dart';

Future<void> _mount(
  WidgetTester tester,
  ValueNotifier<PluginSettingsState> state,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder(
          valueListenable: state,
          builder: (context, value, _) => PluginSettingsContent(
            from: 'fixture',
            pluginRuntimeName: 'fixture',
            state: value,
            debugEnabled: false,
            debugUrl: '',
            deleted: false,
            pluginVersion: 'fixture',
            colorScheme: Theme.of(context).colorScheme,
            onUpdateDebugConfig: ({required enabled, required url}) async {},
            onConfirmDeletePlugin: () async {},
            onUpdatePlugin: () async {},
            onOpenLoginPage: () async {},
            onOpenDetailPage: () async {},
            onCommitField: (_, _) async {},
            onRunAction: (_) async {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <MethodChannel>[];
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    channels.clear();
  });
  testWidgets(
    'refresh retains settings values, native menus and management geometry',
    (tester) async {
      const loaded = PluginSettingsState(
        loading: false,
        isVideoSource: true,
        sections: [
          {
            'title': 'Playback',
            'fields': [
              {
                'key': 'quality',
                'kind': 'select',
                'label': 'Quality',
                'options': [
                  {'value': 'auto', 'label': 'Auto'},
                  {'value': 'high', 'label': 'High'},
                ],
              },
            ],
          },
        ],
        values: {'quality': 'auto'},
      );
      final state = ValueNotifier(loaded);
      addTearDown(state.dispose);
      await _mount(tester, state);
      await tester.pumpAndSettle();
      final menus = tester.stateList(find.byType(UiKitView)).toList();
      expect(menus, hasLength(1));
      final version = tester.getRect(find.textContaining('fixture'));
      state.value = loaded.copyWith(loading: true);
      await tester.pump();
      expect(tester.stateList(find.byType(UiKitView)), orderedEquals(menus));
      expect(find.text('Quality'), findsOneWidget);
      expect(tester.getRect(find.textContaining('fixture')), version);
      state.value = loaded;
      await tester.pumpAndSettle();
      expect(tester.stateList(find.byType(UiKitView)), orderedEquals(menus));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  testWidgets('first load and first failure keep their distinct feedback', (
    tester,
  ) async {
    final state = ValueNotifier(const PluginSettingsState());
    addTearDown(state.dispose);
    await _mount(tester, state);
    await tester.pump();
    expect(state.value.hasContent, isFalse);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    state.value = state.value.copyWith(
      loading: false,
      error: 'initial failure',
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('initial failure'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'successful empty schema remains content during refresh and failure',
    (tester) async {
      const loaded = PluginSettingsState(
        loading: false,
        hasLoadedSettings: true,
      );
      final state = ValueNotifier(loaded);
      addTearDown(state.dispose);
      await _mount(tester, state);
      await tester.pumpAndSettle();
      expect(loaded.sections, isEmpty);
      expect(loaded.hasContent, isTrue);
      final version = tester.getRect(find.textContaining('fixture'));
      final menus = tester.stateList(find.byType(UiKitView)).toList();
      expect(
        menus,
        isEmpty,
        reason:
            'Global return mode is now in app behavior; an empty plugin schema has no choice menu',
      );
      state.value = loaded.copyWith(loading: true);
      await tester.pump();
      expect(state.value.hasLoadedSettings, isTrue);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(tester.getRect(find.textContaining('fixture')), version);
      expect(tester.stateList(find.byType(UiKitView)), orderedEquals(menus));
      state.value = state.value.copyWith(
        loading: false,
        error: 'refresh failure',
      );
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.getRect(find.textContaining('fixture')), version);
      expect(tester.stateList(find.byType(UiKitView)), orderedEquals(menus));
      final error = find.text('refresh failure');
      await tester.scrollUntilVisible(
        error,
        250,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('plugin-settings-sections')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(error, findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
