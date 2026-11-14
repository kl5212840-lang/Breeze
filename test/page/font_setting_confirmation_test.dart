import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/page/font_setting/view/font_setting_page.dart';
import 'package:zephyr/util/font/font_profile.dart';

class _FontPaths extends PathProviderPlatform {
  _FontPaths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

class _FontPreferenceStore extends InMemorySharedPreferencesStore {
  _FontPreferenceStore(Map<String, Object> data) : super.withData(data);
  bool rejectFontSave = false;
  @override
  Future<bool> setValue(String valueType, String key, Object value) =>
      rejectFontSave && key.contains('font_profile_')
      ? Future.value(false)
      : super.setValue(valueType, key, value);
}

// Engine codecs, file I/O and isolate replies need the real event loop. Fake
// pumpAndSettle advances virtual frames and can starve these completions while
// an intentional loading indicator is animating.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() ready,
  String reason,
) async {
  final elapsed = Stopwatch()..start();
  while (!ready() && elapsed.elapsed < const Duration(seconds: 5)) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await tester.pump();
  expect(ready(), isTrue, reason: reason);
  await tester.pumpAndSettle();
}

// Start the real operation in this test's zone, then keep pumping its captured
// continuations while allowing native I/O to progress. Awaiting FontLoader or
// a path-provider future inside runAsync can deadlock outside test timeouts.
Future<void> _fontOperation(
  WidgetTester tester,
  Future<void> Function() start,
  String stage,
) async {
  debugPrint('font fixture stage started: $stage');
  var completed = false;
  Object? failure;
  StackTrace? trace;
  unawaited(
    Future<void>.sync(start).then<void>(
      (_) {
        completed = true;
      },
      onError: (Object error, StackTrace stack) {
        failure = error;
        trace = stack;
        completed = true;
      },
    ),
  );
  await _pumpUntil(tester, () => completed, 'font stage completes: $stage');
  if (failure != null) Error.throwWithStackTrace(failure!, trace!);
  debugPrint('font fixture stage completed: $stage');
}

void main() {
  testWidgets(
    'single and all-font removal require confirmation and preserve source files',
    (tester) async {
      final previousPaths = PathProviderPlatform.instance;
      final temporary = Directory.systemTemp.createTempSync(
        'breeze_font_confirmation_',
      );
      PathProviderPlatform.instance = _FontPaths(temporary.path);
      final original = File('asset/fonts/JetBrainsMonoNL-Regular.ttf').absolute;
      final managedDirectory = Directory('${temporary.path}/files/fonts')
        ..createSync(recursive: true);
      final managed = original.copySync(
        '${managedDirectory.path}/w400-fixture.ttf',
      );
      SharedPreferences.setMockInitialValues({
        'font_profile_w400': managed.path,
      });
      final preferences = _FontPreferenceStore({
        'flutter.font_profile_w400': managed.path,
      });
      SharedPreferencesStorePlatform.instance = preferences;
      final controller = FontProfileController.instance;
      final events = <ToastEvent>[];
      final subscription = eventBus.on<ToastEvent>().listen(events.add);
      try {
        await _fontOperation(
          tester,
          controller.init,
          'load imported regular font',
        );
        expect(controller.pathForWeight(400), managed.path);
        await tester.pumpWidget(MaterialApp(home: const FontSettingPage()));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byTooltip(t.fontSetting.clearFile));
        await tester.tap(find.byTooltip(t.fontSetting.clearFile));
        await tester.pumpAndSettle();
        expect(find.text(t.fontSetting.clearFileConfirmTitle), findsOneWidget);
        expect(managed.existsSync(), isTrue);
        await tester.tap(find.text(t.common.cancel));
        await tester.pumpAndSettle();
        expect(managed.existsSync(), isTrue);
        expect(controller.pathForWeight(400), managed.path);
        await tester.tap(find.byTooltip(t.fontSetting.clearFile));
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.common.remove));
        await _pumpUntil(
          tester,
          () =>
              controller.pathForWeight(400) == null &&
              events.any(
                (event) =>
                    event.type == ToastType.success &&
                    event.message == t.fontSetting.cleared,
              ),
          'font deletion completes before its success event',
        );
        expect(controller.pathForWeight(400), isNull);
        expect(managed.existsSync(), isFalse);
        expect(original.existsSync(), isTrue);

        bool? importedBold;
        await _fontOperation(tester, () async {
          importedBold = await controller.setPath(700, original.path);
        }, 'import bold fixture font');
        expect(importedBold, isTrue);
        await tester.pumpAndSettle();
        final boldPath = controller.pathForWeight(700)!;
        final beforeFailure = managedDirectory
            .listSync()
            .map((file) => file.path)
            .toSet();
        preferences.rejectFontSave = true;
        Object? saveFailure;
        await _fontOperation(tester, () async {
          try {
            await controller.setPath(700, original.path);
          } catch (error) {
            saveFailure = error;
          }
        }, 'reject replacement preference write');
        expect(saveFailure, isA<StateError>());
        expect(controller.pathForWeight(700), boldPath);
        expect(File(boldPath).existsSync(), isTrue);
        expect(
          managedDirectory.listSync().map((file) => file.path).toSet(),
          beforeFailure,
        );
        expect(
          (await SharedPreferences.getInstance()).getString(
            'font_profile_w700',
          ),
          boldPath,
        );
        preferences.rejectFontSave = false;
        List<bool>? importedWeights;
        await _fontOperation(tester, () async {
          importedWeights = await Future.wait([
            controller.setPath(400, original.path),
            controller.setPath(500, original.path),
          ]);
        }, 'concurrent weights retain both selections');
        expect(importedWeights, [true, true]);
        expect(controller.paths.keys, containsAll([400, 500, 700]));
        await tester.ensureVisible(find.byTooltip(t.fontSetting.clear));
        await tester.tap(find.byTooltip(t.fontSetting.clear));
        await tester.pumpAndSettle();
        expect(find.text(t.fontSetting.clearAllConfirmTitle), findsOneWidget);
        await tester.tap(find.text(t.common.cancel));
        await tester.pumpAndSettle();
        expect(File(boldPath).existsSync(), isTrue);
        await tester.tap(find.byTooltip(t.fontSetting.clear));
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.common.remove));
        await _pumpUntil(
          tester,
          () =>
              controller.paths.isEmpty &&
              events.any(
                (event) =>
                    event.type == ToastType.success &&
                    event.message == t.fontSetting.allCleared,
              ),
          'all-font deletion completes before its success event',
        );
        expect(controller.paths, isEmpty);
        expect(File(boldPath).existsSync(), isFalse);
        expect(original.existsSync(), isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        try {
          await _fontOperation(
            tester,
            subscription.cancel,
            'release fixture subscription',
          );
        } finally {
          PathProviderPlatform.instance = previousPaths;
          temporary.deleteSync(recursive: true);
        }
      }
    },
  );
}
