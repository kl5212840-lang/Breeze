import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/sync_archive_context.dart';
import 'package:zephyr/network/sync/sync_service.dart' show SyncDirection;
import 'package:zephyr/network/sync/sync_task_progress.dart';
import 'package:zephyr/network/sync/sync_payload_compatibility.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/page/setting/global/sync_setting_page.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import '../test_helper.dart';
import '../ui_preview_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    await loadUiPreviewFonts();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform_views,
          (call) async => null,
        );
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null),
  );
  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'two directed sync actions respect scope, wait and offer safe retry $style $brightness',
        (tester) async {
          tester.view.physicalSize = const Size(320, 760);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final setting = objectbox.userSettingBox.get(1)!;
          setting.globalSetting = GlobalSettingState(
            syncSetting: SyncSettingState(
              syncServiceType: SyncServiceType.webdav,
              webdavSetting: const WebDavSettingState(
                host: 'https://fixture.invalid',
                username: 'synthetic',
                password: 'synthetic',
              ),
              syncSettings: true,
              syncPlugins: false,
            ),
          );
          objectbox.userSettingBox.put(setting);
          final cubit = GlobalSettingCubit();
          await cubit.initBox();
          final follows = ComicFollowCubit();
          final preference = ValueNotifier(style);
          addTearDown(cubit.close);
          addTearDown(follows.close);
          addTearDown(preference.dispose);
          var calls = 0;
          var pending = Completer<SyncRunResult>();
          final actions = SyncArchiveActions(
            synchronize:
                ({
                  required state,
                  required direction,
                  globalSettingCubit,
                  comicFollowCubit,
                  resolveGalleryConflict,
                }) {
                  expect(direction, SyncDirection.upload);
                  calls++;
                  expect(state.syncSetting.syncPlugins, isFalse);
                  return pending.future;
                },
          );
          Widget host(double scale) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider.value(value: follows),
            ],
            child: AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                theme: ThemeData(
                  brightness: brightness,
                  fontFamily: uiPreviewDirectory == null
                      ? null
                      : 'AccountPreview',
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: RepaintBoundary(
                    key: const ValueKey('sync.preview'),
                    child: child!,
                  ),
                ),
                home: SyncSettingPage(archiveActions: actions),
              ),
            ),
          );
          await tester.pumpWidget(host(1.8));
          await tester.pumpAndSettle();
          expect(calls, 0);
          expect(find.byKey(const ValueKey('sync.protection')), findsNothing);
          expect(find.text(t.backupSecurity.standard), findsNothing);
          final scopeNote = find.text(t.settings.syncScopeNote);
          await tester.scrollUntilVisible(
            scopeNote,
            180,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          final footerTextLeft = tester.getTopLeft(scopeNote).dx;
          final action = find.byKey(const ValueKey('sync.upload'));
          await tester.scrollUntilVisible(
            action,
            300,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          // A completed task deliberately remains readable after reopening;
          // later variants must not assume the process-wide snapshot is empty.
          final hasPreviousTask = syncTaskProgress.value != null;
          final direction = find.byKey(
            ValueKey(
              hasPreviousTask ? 'sync.task-phase' : 'sync.direction-note',
            ),
          );
          await tester.scrollUntilVisible(
            direction,
            -160,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(direction.hitTestable(), findsOneWidget);
          final note = tester.widget<SettingNote>(direction);
          expect(
            note.text,
            hasPreviousTask
                ? t.settings.syncTaskFinished
                : t.settings.syncMergeNote,
          );
          expect(
            tester.getTopLeft(find.text(note.text)).dx,
            closeTo(footerTextLeft, .5),
            reason: 'direction and scope notes share the section footer gutter',
          );
          expect(find.text(t.settings.syncUploadHint), findsNothing);
          expect(find.text(t.settings.syncRestoreHint), findsNothing);
          expect(find.text(t.settings.syncUploadLocal), findsOneWidget);
          expect(find.text(t.settings.syncRestoreCloud), findsOneWidget);
          expect(find.text(t.settings.legacyCompatibility), findsNothing);
          expect(find.text(t.settings.importLegacy), findsNothing);
          expect(find.text(t.settings.uploadToCloud), findsNothing);
          await tester.scrollUntilVisible(
            action,
            160,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(action);
          await tester.pump();
          expect(calls, 1);
          await tester.scrollUntilVisible(
            action,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump(const Duration(milliseconds: 350));
          expect(tester.widget<FilledButton>(action).onPressed, isNull);
          pending.completeError(const SyncCompatibilityException());
          await tester.pumpAndSettle();
          expect(find.text(t.settings.syncUpdateRequired), findsOneWidget);
          expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
          pending = Completer<SyncRunResult>();
          await tester.tap(action);
          await tester.pump();
          expect(calls, 2);
          pending.complete(
            const SyncRunResult(
              newArchiveSynced: true,
              legacyArchiveImported: true,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('sync.error')), findsNothing);
          expect(cubit.state.syncSetting.syncPlugins, isFalse);
          final automatic = find.text(t.settings.autoSync);
          await tester.scrollUntilVisible(
            automatic,
            180,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: find.byType(SwitchListTile),
              matching: find.text(t.settings.autoSyncSubtitle),
            ),
            findsOneWidget,
          );
          expect(find.byType(SettingDetailsNotes), findsNothing);
          await writeUiPreview(
            tester,
            const ValueKey('sync.preview'),
            'unified-sync-large-$style-${brightness.name}',
          );
          tester.view.physicalSize = const Size(390, 844);
          await tester.pumpWidget(host(1));
          await tester.pumpAndSettle();
          await writeUiPreview(
            tester,
            const ValueKey('sync.preview'),
            'unified-sync-normal-$style-${brightness.name}',
          );
          if (brightness == Brightness.light) {
            final callsBeforeLayout = calls;
            for (final width in [320.0, 390.0, 440.0]) {
              for (final scale in [1.0, 1.4, 2.0]) {
                tester.view.physicalSize = Size(width, 1000);
                await tester.pumpWidget(host(scale));
                await tester.pumpAndSettle();
                tester
                    .state<ScrollableState>(find.byType(Scrollable).first)
                    .position
                    .jumpTo(0);
                await tester.pump();
                for (final actionKey in ['sync.upload', 'sync.restore']) {
                  final action = find.byKey(ValueKey(actionKey));
                  await tester.scrollUntilVisible(
                    action,
                    160,
                    scrollable: find.byType(Scrollable).first,
                  );
                  await tester.pumpAndSettle();
                  expect(
                    tester.getSize(action).height,
                    greaterThanOrEqualTo(44),
                  );
                  expect(
                    tester.getSize(action).width,
                    lessThanOrEqualTo(width),
                  );
                }
                expect(find.byType(SettingDetailsNotes), findsNothing);
                expect(find.text(t.backupSecurity.scopeHint), findsNothing);
                expect(
                  calls,
                  callsBeforeLayout,
                  reason: 'layout changes never start uploads or restores',
                );
                expect(
                  tester.takeException(),
                  isNull,
                  reason: '$style width=$width scale=$scale',
                );
              }
            }
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }
}
