import 'package:zephyr/network/sync/backup_protection_manager.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show eventBus, objectbox;
import 'package:zephyr/network/sync/sync_archive_context.dart';
import 'package:zephyr/network/sync/sync_task_progress.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/page/setting/global/sync_setting_page.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/toast.dart';

import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
    // Protection tiles read an actual local file. Initialize that singleton
    // outside testWidgets' FakeAsync zone before any route builds its tile.
    await BackupProtectionManager.shared.load().timeout(
      const Duration(seconds: 5),
    );
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  for (final style in ['system', 'breeze']) {
    testWidgets(
      '$style task survives leaving and reopening settings without another upload',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
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
          for (final channel in channels) {
            messenger.setMockMethodCallHandler(channel, null);
          }
        });
        final setting = objectbox.userSettingBox.get(1)!;
        setting.globalSetting = const GlobalSettingState(
          syncSetting: SyncSettingState(
            syncServiceType: SyncServiceType.webdav,
            webdavSetting: WebDavSettingState(
              host: 'https://fixture.invalid',
              username: 'synthetic',
              password: 'synthetic',
            ),
          ),
        );
        objectbox.userSettingBox.put(setting);
        final cubit = GlobalSettingCubit();
        await tester.runAsync(cubit.initBox);
        late ComicFollowCubit follows;
        await tester.runAsync(() async {
          follows = ComicFollowCubit();
          await follows.loadFromDatabase();
        });
        final preference = ValueNotifier(style);
        addTearDown(cubit.close);
        addTearDown(follows.close);
        addTearDown(preference.dispose);
        final complete = Completer<SyncRunResult>(), events = <ToastEvent>[];
        addTearDown(() async {
          if (!complete.isCompleted) complete.complete(const SyncRunResult());
        });
        final subscription = eventBus.on<ToastEvent>().listen(events.add);
        addTearDown(subscription.cancel);
        var calls = 0;
        final actions = SyncArchiveActions(
          synchronize:
              ({
                required state,
                required direction,
                globalSettingCubit,
                comicFollowCubit,
                resolveGalleryConflict,
              }) async {
                calls++;
                syncTaskProgress.phase(
                  SyncTaskPhase.artwork,
                  completed: 1,
                  total: 2,
                );
                return complete.future;
              },
        );
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider.value(value: follows),
            ],
            child: AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              SyncSettingPage(archiveActions: actions),
                        ),
                      ),
                      child: const Text('Open synchronization'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open synchronization'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        final upload = find.byKey(const ValueKey('sync.upload'));
        await tester.ensureVisible(upload);
        await tester.pump();
        final uploadBefore = tester.getRect(upload);
        final configurationBefore = tester.getRect(
          find.byType(SyncSettingPage),
        );
        await tester.tap(upload);
        await tester.pump();
        expect(
          tester.getRect(upload),
          uploadBefore,
          reason:
              'starting sync replaces nearby status without shifting the action',
        );
        expect(
          tester.getRect(find.byType(SyncSettingPage)),
          configurationBefore,
        );
        expect(find.byKey(const ValueKey('sync.task-status')), findsOneWidget);
        final progressBeforeLeave = tester.getRect(
          find.byKey(const ValueKey('sync.task-progress')),
        );
        expect(progressBeforeLeave.bottom, lessThanOrEqualTo(uploadBefore.top));
        expect(
          uploadBefore.top - progressBeforeLeave.bottom,
          lessThan(24),
          reason:
              'progress stays next to its action, not inserted at the page top',
        );
        final id = syncTaskProgress.value!.id;
        expect(syncTaskProgress.running, isTrue);
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(syncTaskProgress.running, isTrue);
        await tester.tap(find.text('Open synchronization'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(calls, 1);
        expect(syncTaskProgress.value!.id, id);
        final progress = find.byKey(const ValueKey('sync.task-progress'));
        await tester.ensureVisible(progress);
        await tester.pump();
        expect(tester.widget<LinearProgressIndicator>(progress).value, .5);
        await tester.ensureVisible(upload);
        await tester.pump();
        expect(tester.widget<FilledButton>(upload).onPressed, isNull);
        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.runAsync(() async {
          complete.complete(const SyncRunResult(newArchiveSynced: true));
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(syncTaskProgress.value!.status, SyncTaskStatus.completed);
        expect(
          events.where(
            (event) => event.message == t.settings.manualUploadSuccess,
          ),
          hasLength(1),
        );
        await tester.tap(find.text('Open synchronization'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(calls, 1);
        expect(find.byKey(const ValueKey('sync.task-phase')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
