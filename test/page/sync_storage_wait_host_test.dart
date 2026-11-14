import 'package:zephyr/network/sync/backup_protection_manager.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart' show objectbox;
import 'package:zephyr/network/sync/sync_archive_context.dart';
import 'package:zephyr/network/sync/sync_operation_queue.dart';
import 'package:zephyr/network/sync/sync_task_progress.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/global/sync_setting_page.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
    await BackupProtectionManager.shared.load().timeout(const Duration(seconds: 5));
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  for (final style in ['system', 'breeze']) {
    for (final configured in [false, true]) {
      testWidgets('$style configured=$configured explains other storage work and restores controls without starting sync', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        final channels = <MethodChannel>[];
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
          if (call.method == 'create') {
            final args = call.arguments as Map;
            final channel = MethodChannel('${args['viewType']}.${args['id']}');
            channels.add(channel);
            messenger.setMockMethodCallHandler(channel, (_) async => null);
          }
          return null;
        });
        addTearDown(() {
          messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
          for (final channel in channels) { messenger.setMockMethodCallHandler(channel, null); }
        });
        final service = configured ? SyncServiceType.webdav : SyncServiceType.none;
        final setting = objectbox.userSettingBox.get(1)!;
        setting.globalSetting = GlobalSettingState(syncSetting: SyncSettingState(
          syncServiceType: service, autoSync: true,
          webdavSetting: const WebDavSettingState(host: 'https://fixture.invalid',
            username: 'synthetic', password: 'synthetic')));
        objectbox.userSettingBox.put(setting);
        final cubit = GlobalSettingCubit(); await cubit.initBox();
        final follows = ComicFollowCubit(), preference = ValueNotifier(style);
        addTearDown(cubit.close); addTearDown(follows.close); addTearDown(preference.dispose);
        var requests = 0;
        final actions = SyncArchiveActions(synchronize: ({required state, required direction,
          globalSettingCubit, comicFollowCubit, resolveGalleryConflict}) async {
          requests++; return const SyncRunResult();
        });
        final entered = Completer<void>(), release = Completer<void>();
        final busy = syncStorageOperations.run(() async { entered.complete(); await release.future; });
        await entered.future;
        try {
          await tester.pumpWidget(MultiBlocProvider(providers: [
            BlocProvider.value(value: cubit), BlocProvider.value(value: follows),
          ], child: AppInterfaceStyleScope(style: preference,
            child: MaterialApp(home: SyncSettingPage(archiveActions: actions)))));
          await tester.pump();
          expect(find.byKey(const ValueKey('sync.storage-waiting')), findsOneWidget);
          expect(find.text(t.settings.syncStorageWaiting), findsOneWidget);
          expect(find.byKey(const ValueKey('sync.task-progress')), findsNothing);
          expect(syncTaskProgress.running, isFalse,
            reason: 'an unrelated storage lock is not a cloud synchronization');
          final serviceChoice = find.byType(SettingChoiceTile<SyncServiceType>);
          expect(tester.widget<SettingChoiceTile<SyncServiceType>>(serviceChoice).enabled, isFalse);
          expect(tester.widget<SettingChoiceTile<SyncServiceType>>(serviceChoice).value, service);
          if (configured) {
            final upload = find.byKey(const ValueKey('sync.upload'));
            await tester.scrollUntilVisible(upload, 200, scrollable: find.byType(Scrollable).first);
            expect(tester.widget<FilledButton>(upload).onPressed, isNull);
          } else {
            expect(find.byKey(const ValueKey('sync.upload')), findsNothing);
          }
          expect(requests, 0);
          release.complete(); await busy;
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('sync.storage-waiting')), findsNothing);
          await tester.scrollUntilVisible(serviceChoice, -250, scrollable: find.byType(Scrollable).first);
          await tester.pumpAndSettle();
          expect(tester.widget<SettingChoiceTile<SyncServiceType>>(serviceChoice).enabled, isTrue);
          expect(cubit.state.syncSetting.syncServiceType, service);
          expect(cubit.state.syncSetting.webdavSetting.host, 'https://fixture.invalid');
          if (configured) {
            final upload = find.byKey(const ValueKey('sync.upload'));
            await tester.scrollUntilVisible(upload, 200, scrollable: find.byType(Scrollable).first);
            expect(tester.widget<FilledButton>(upload).onPressed, isNotNull);
          }
          expect(requests, 0); expect(tester.takeException(), isNull);
        } finally {
          if (!release.isCompleted) release.complete();
          await busy;
          await tester.pumpWidget(const SizedBox.shrink()); await tester.pump();
        }
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
    }
  }
}
