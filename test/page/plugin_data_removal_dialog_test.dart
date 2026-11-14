import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/cubit/plugin_registry_cubit.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/plugin_settings/view/plugin_settings_page.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_settings_content.dart';
import 'package:zephyr/page/video/video_local_resources.dart';
import 'package:zephyr/service/local_plugin_installation_state.dart';
import 'package:zephyr/service/local_import_recovery.dart'
    show recoverPendingBackupImport;
import 'package:zephyr/plugin/plugin_registry_service.dart';
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';
import '../test_helper.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_data_removal_dialog.dart';

const _productionSource = '6833b0c6-04d7-43e5-a07f-47b68725681b';

class _PreviewApi extends RustLibApi {
  @override
  Future<bool> crateApiQjsIsQjsRuntimeInitialized({
    required String name,
  }) async => true;
  @override
  Future<bool> crateApiQjsQjsDropRuntime({required String runtimeName}) async =>
      true;
  @override
  Future<String> crateApiQjsQjsCurrentBundle({
    required String runtimeName,
  }) async => jsonEncode('preview-fixture');
  @override
  Future<Uint8List> crateApiQjsQjsTaskCall({
    required String runtimeName,
    required String taskGroupKey,
    required bool isOnce,
    String? bundleJs,
    String? bundleUrl,
    required String fnPath,
    required String argsJson,
  }) async => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'source': _productionSource,
        'scheme': {'sections': [], 'actions': []},
        'data': {'values': {}, 'canLogin': false, 'canShowUserInfo': false},
      }),
    ),
  );
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected native call: ${invocation.memberName}');
}

TextButton _purgeButton(WidgetTester tester) => tester.widget<TextButton>(
  find.widgetWithText(TextButton, t.pluginLifecycle.purge),
);

Future<void> _waitForDialog(WidgetTester tester) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    await tester.pump(const Duration(milliseconds: 10));
    if (find.byType(AlertDialog).evaluate().isNotEmpty) {
      await tester.pump();
      return;
    }
  }
  expect(
    find.byType(AlertDialog),
    findsOneWidget,
    reason: 'The production removal route must be inserted',
  );
}

Future<void> _openProductionSettings(WidgetTester tester) async {
  final registry = PluginRegistryCubit();
  addTearDown(registry.close);
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: registry),
        BlocProvider(create: (_) => GlobalSettingCubit()),
      ],
      child: const MaterialApp(
        home: PluginSettingsPage(
          from: _productionSource,
          pluginUuid: _productionSource,
          pluginRuntimeName: _productionSource,
          pluginDisplayName: 'Production preview fixture',
          scope: PluginSettingsScope.management,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _beginProductionRemoval(WidgetTester tester) async {
  await tester.tap(find.text(t.pluginLifecycle.deleteEntry));
  await _waitForDialog(tester);
}

void main() {
  const counts = PluginDataRemovalCounts(
    favorites: 4,
    history: 8,
    follows: 2,
    settings: 3,
    downloads: 5,
    images: 1,
  );

  testWidgets('confirmation defaults to this device and keeps download files', (
    tester,
  ) async {
    PluginDataRemovalChoice? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showPluginDataRemovalDialog(
                  context,
                  pluginName: 'Dynamic source',
                  counts: counts,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isFalse,
    );
    expect(
      tester.widget<RadioGroup<bool>>(find.byType(RadioGroup<bool>)).groupValue,
      isFalse,
    );
    await tester.ensureVisible(find.text(t.pluginLifecycle.purge).last);
    await tester.tap(find.text(t.pluginLifecycle.purge).last);
    await tester.pumpAndSettle();
    expect(result?.cloudDelete, isFalse);
    expect(result?.includeDownloads, isFalse);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets(
    'narrow large text allows cloud choice, independent files and cancel',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      PluginDataRemovalChoice? result;
      var returned = false;
      for (final brightness in [Brightness.light, Brightness.dark]) {
        returned = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.8)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showPluginDataRemovalDialog(
                      context,
                      pluginName:
                          'A long plugin name with a stable dynamic identity',
                      counts: counts,
                    );
                    returned = true;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(t.pluginLifecycle.cloudAlso));
        await tester.tap(find.text(t.pluginLifecycle.cloudAlso));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<RadioGroup<bool>>(find.byType(RadioGroup<bool>))
              .groupValue,
          isTrue,
        );
        expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          isTrue,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text(t.common.cancel));
        await tester.tap(find.text(t.common.cancel));
        await tester.pumpAndSettle();
        expect(returned, isTrue);
        expect(result, isNull);
        expect(find.text('open'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets('changed fresh scope requires review and a second confirmation', (
    tester,
  ) async {
    var calls = 0, returned = false;
    PluginDataRemovalChoice? result;
    const newer = PluginDataRemovalCounts(
      favorites: 9,
      history: 8,
      follows: 2,
      settings: 3,
      downloads: 5,
      images: 1,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showPluginDataRemovalDialog(
                  context,
                  pluginName: 'Dynamic source',
                  counts: counts,
                  inspect: (_) async {
                    calls++;
                    return newer;
                  },
                );
                returned = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.pluginLifecycle.purge).last);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(returned, isFalse);
    expect(find.text(t.pluginLifecycle.changed), findsOneWidget);
    expect(find.text(t.pluginLifecycle.favorites(count: 9)), findsOneWidget);
    await tester.tap(find.text(t.pluginLifecycle.purge).last);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(returned, isTrue);
    expect(result?.cloudDelete, isFalse);
  });

  testWidgets(
    'failed inspection cannot confirm and one nearby retry refreshes it',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showPluginDataRemovalDialog(
                  context,
                  pluginName: 'Dynamic source',
                  inspect: (_) async {
                    if (++calls == 1)
                      throw const PluginDataRemovalInspectionFailure(
                        'Fixture read unavailable',
                      );
                    return counts;
                  },
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Fixture read unavailable'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, t.pluginLifecycle.purge),
            )
            .onPressed,
        isNull,
      );
      expect(find.text(t.common.retry), findsOneWidget);
      await tester.ensureVisible(find.text(t.common.retry));
      await tester.tap(find.text(t.common.retry));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, t.pluginLifecycle.purge),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    },
  );

  testWidgets(
    'cancelling a pending read never closes a later parent route or confirms',
    (tester) async {
      final pending = Completer<PluginDataRemovalCounts?>();
      var returned = false;
      PluginDataRemovalChoice? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showPluginDataRemovalDialog(
                    context,
                    pluginName: 'Dynamic source',
                    inspect: (_) => pending.future,
                  );
                  returned = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.tap(find.text(t.common.cancel));
      await tester.pump(const Duration(milliseconds: 400));
      expect(returned, isTrue);
      expect(result, isNull);
      pending.complete(counts);
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending initial inspection locks both scope and files until settled',
    (tester) async {
      final pending = Completer<PluginDataRemovalCounts?>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showPluginDataRemovalDialog(
                  context,
                  pluginName: 'Waiting fixture',
                  inspect: (_) {
                    calls++;
                    return pending.future;
                  },
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(_purgeButton(tester).onPressed, isNull);
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile))
            .onChanged,
        isNull,
      );
      for (final tile in tester.widgetList<RadioListTile<bool>>(
        find.byType(RadioListTile<bool>),
      )) {
        expect(tile.enabled, isFalse);
      }
      await tester.tap(find.text(t.pluginLifecycle.cloudAlso));
      expect(calls, 1);
      pending.complete(counts);
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(_purgeButton(tester).onPressed, isNotNull);
      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'one confirmation recheck runs even for retained duplicate callbacks',
    (tester) async {
      final pending = Completer<PluginDataRemovalCounts?>();
      var calls = 0, returns = 0;
      PluginDataRemovalChoice? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showPluginDataRemovalDialog(
                    context,
                    pluginName: 'Single flight',
                    counts: counts,
                    inspect: (_) {
                      calls++;
                      return pending.future;
                    },
                  );
                  returns++;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final confirm = _purgeButton(tester).onPressed!;
      confirm();
      confirm();
      await tester.pump();
      expect(calls, 1);
      expect(returns, 0);
      pending.complete(counts);
      await tester.pumpAndSettle();
      expect(returns, 1);
      expect(result?.includeDownloads, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late null during cancel transition cannot pop its parent', (
    tester,
  ) async {
    final pending = Completer<PluginDataRemovalCounts?>();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (parent) => Scaffold(
                    body: Column(
                      children: [
                        const Text('parent remains'),
                        TextButton(
                          onPressed: () => showPluginDataRemovalDialog(
                            parent,
                            pluginName: 'Closing fixture',
                            inspect: (_) => pending.future,
                          ),
                          child: const Text('inspect'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              child: const Text('open parent'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open parent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('inspect'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.text(t.common.cancel));
    // Complete while State is still mounted during the dialog reverse route.
    pending.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('parent remains'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'passive hover is suppressed on scope, files and destructive actions',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showPluginDataRemovalDialog(
                    context,
                    pluginName: 'Hover fixture',
                    counts: counts,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byType(TouchHoverIntent), findsNWidgets(5));
        expect(
          tester
              .widget<CheckboxListTile>(find.byType(CheckboxListTile))
              .hoverColor,
          Colors.transparent,
        );
        for (final row in tester.widgetList<RadioListTile<bool>>(
          find.byType(RadioListTile<bool>),
        )) {
          expect(row.hoverColor, Colors.transparent);
        }
        expect(
          _purgeButton(
            tester,
          ).style!.overlayColor!.resolve({WidgetState.hovered}),
          Colors.transparent,
        );
        await tester.tap(find.text(t.common.cancel));
        await tester.pumpAndSettle();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  group('production settings removal boundary', () {
    setUpAll(() async {
      await TestObjectBoxHelper.setUpTestObjectBox();
      RustLib.initMock(api: _PreviewApi());
      await recoverPendingBackupImport();
      await PluginRegistryService.I.init();
    });
    tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

    Future<void> resetFixture(WidgetTester tester) async {
      // Dispose each host before replacing its mock preferences/database rows.
      // Keep production singleton tails in one testWidgets event loop.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      SharedPreferences.setMockInitialValues({});
      await LocalPluginInstallationState.instance.reload();
      objectbox.pluginConfigBox.removeAll();
      TestObjectBoxHelper.cleanComicFolderBoxes();
      objectbox.unifiedFavoriteBox.put(
        createTestFavorite('$_productionSource:comic')
          ..source = _productionSource,
      );
      objectbox.pluginConfigBox.put(
        PluginConfig(
          name: _productionSource,
          config: '{"fixturePreference":true}',
        ),
      );
      VideoLocalResources.invalidate();
    }

    testWidgets('production removal entry cancels before writing', (
      tester,
    ) async {
      await resetFixture(tester);
      await _openProductionSettings(tester);
      await _beginProductionRemoval(tester);
      expect(find.byKey(const ValueKey('plugin-remove-local')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('plugin-remove-local')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('plugin-remove-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();

      expect(objectbox.unifiedFavoriteBox.count(), 1);
      expect(objectbox.pluginConfigBox.count(), 1);
      expect(
        LocalPluginInstallationState.instance.isRemoved(_productionSource),
        isFalse,
      );
      expect(
        LocalPluginInstallationState.instance.isDataExcluded(
          _productionSource,
          PluginDataScope.records,
        ),
        isFalse,
      );
    });
  });
}
