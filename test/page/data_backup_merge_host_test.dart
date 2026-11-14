import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/sync/backup_protection_manager.dart';
import 'package:zephyr/page/setting/data_backup/data_backup_page.dart';
import 'package:zephyr/page/setting/data_backup/method.dart';
import 'package:zephyr/page/video/video_hls_assets.dart';
import 'package:zephyr/service/offline_backup_merge.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import '../test_helper.dart';
import '../ui_preview_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
    await BackupProtectionManager.shared.load();
    await loadUiPreviewFonts();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform_views,
          (_) async => null,
        ),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null),
  );
  testWidgets(
    'HLS backup explains the limit and allows another export without files',
    (tester) async {
      final attempts = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: DataBackupPage(
            actions: DataBackupActions(
              exportBackup: (includeFiles) async {
                attempts.add(includeFiles);
                if (includeFiles) throw const HlsPortableBackupUnsupported();
              },
            ),
          ),
        ),
      );
      final includeFiles = find.byKey(
        const ValueKey('backup.include-downloads'),
      );
      final export = find.byKey(const ValueKey('backup.export'));
      await tester.tap(includeFiles);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(includeFiles).value, isTrue);
      await tester.tap(export);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(attempts, [true]);
      expect(find.text(t.dataBackup.hlsNotPortable), findsOneWidget);
      expect(find.text(t.dataBackup.exportFailed), findsNothing);
      expect(tester.widget<SwitchListTile>(includeFiles).value, isTrue);
      await tester.tap(find.widgetWithText(TextButton, t.common.ok));
      await tester.pumpAndSettle();
      await tester.tap(includeFiles);
      await tester.pumpAndSettle();
      await tester.tap(export);
      await tester.pumpAndSettle();
      expect(attempts, [true, false]);
    },
  );

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'file import chooses independent content and mode after one entry $style $brightness',
        (tester) async {
          final preference = ValueNotifier(style);
          final directories = <Directory>[];
          final calls = <BackupImportMode>[];
          final exports = <bool>[];
          final selections = <BackupImportOptions>[];
          Completer<void>? pending;
          final actions = DataBackupActions(
            selectBackup: (_) async {
              // Keep the injected picker free of real I/O futures under FakeAsync.
              final directory = Directory(
                TestObjectBoxHelper.tempPath,
              ).createTempSync('file-ui-');
              directories.add(directory);
              return BackupConfig(
                version: 'fixture',
                includeDownloads: true,
                cacheDir: directory.path,
                extractDir: '${directory.path}/extract',
                zipPath: '${directory.path}/backup.zip',
              );
            },
            inspectBackup: (_) async => OfflineBackupPreview(
              version: 'fixture',
              exportedAt: DateTime.utc(2026, 11, 2),
              includeDownloads: true,
              counts: const {'unifiedComicFavorite': 3, 'downloadTask': 2},
            ),
            importBackupWithOptions: (_, mode, options) {
              calls.add(mode);
              selections.add(options);
              return pending?.future ?? Future.value();
            },
            exportBackup: (include) async {
              exports.add(include);
            },
          );
          addTearDown(() {
            preference.dispose();
            for (final directory in directories) {
              if (directory.existsSync()) directory.deleteSync(recursive: true);
            }
          });
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 844);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          Widget host(double scale) => AppInterfaceStyleScope(
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
                  key: const ValueKey('backup.preview'),
                  child: child!,
                ),
              ),
              home: DataBackupPage(actions: actions),
            ),
          );
          await tester.pumpWidget(host(1));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<SwitchListTile>(
                  find.byKey(const ValueKey('backup.include-downloads')),
                )
                .value,
            isFalse,
          );
          expect(
            find.byKey(const ValueKey('backup.export-encrypted')),
            findsNothing,
          );
          await tester.tap(find.byKey(const ValueKey('backup.export')));
          await tester.pumpAndSettle();
          expect(exports, [false]);
          await writeUiPreview(
            tester,
            const ValueKey('backup.preview'),
            'file-backup-normal-$style-${brightness.name}',
          );

          tester.view.physicalSize = const Size(320, 760);
          await tester.pumpWidget(host(2));
          await tester.pumpAndSettle();
          final merge = find.byKey(const ValueKey('backup.import'));
          expect(find.byKey(const ValueKey('backup.merge')), findsNothing);
          expect(find.byKey(const ValueKey('backup.restore')), findsNothing);
          await tester.scrollUntilVisible(
            merge,
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(merge);
          await tester.pumpAndSettle();
          await tester.tap(merge);
          await tester.pumpAndSettle();
          expect(
            find.widgetWithText(AlertDialog, t.backupFlow.previewTitle),
            findsOneWidget,
          );
          expect(
            tester
                .widget<CheckboxListTile>(
                  find.byKey(const ValueKey('backup.option.settings')),
                )
                .value,
            isTrue,
          );
          expect(
            tester
                .widget<CheckboxListTile>(
                  find.byKey(const ValueKey('backup.option.plugins')),
                )
                .value,
            isTrue,
          );
          expect(find.text(t.backupFlow.records(count: 3)), findsOneWidget);
          expect(
            find.text(t.backupFlow.version(value: 'fixture')),
            findsOneWidget,
          );
          expect(find.text(t.backupFlow.mergeFilesHint), findsOneWidget);
          expect(calls, isEmpty);
          await writeUiPreview(
            tester,
            const ValueKey('backup.preview'),
            'file-backup-import-large-$style-${brightness.name}',
          );
          await tester.tap(find.text(t.common.cancel));
          await tester.pumpAndSettle();
          expect(calls, isEmpty);
          expect(directories.last.existsSync(), isFalse);

          await tester.tap(merge);
          await tester.pumpAndSettle();
          pending = Completer<void>();
          final confirm = find.byKey(const ValueKey('backup.confirm-import'));
          await tester.ensureVisible(confirm);
          await tester.tap(confirm);
          await tester.pump(const Duration(milliseconds: 350));
          expect(calls, [BackupImportMode.merge]);
          expect(selections.single.importSettings, isTrue);
          expect(selections.single.importPlugins, isTrue);
          expect(
            tester
                .widget<ListTile>(find.byKey(const ValueKey('backup.import')))
                .onTap,
            isNull,
          );
          pending.complete();
          await tester.pumpAndSettle();
          expect(find.text(t.backupFlow.mergeDone), findsOneWidget);
          await tester.tap(find.text(t.common.ok));
          await tester.pumpAndSettle();
          pending = null;

          await tester.tap(merge);
          await tester.pumpAndSettle();
          final restore = find.byKey(const ValueKey('backup.mode.restore'));
          await tester.ensureVisible(restore);
          await tester.tap(restore);
          await tester.pumpAndSettle();
          final settings = find.byKey(const ValueKey('backup.option.settings'));
          final plugins = find.byKey(const ValueKey('backup.option.plugins'));
          await tester.ensureVisible(settings);
          await tester.tap(settings);
          await tester.ensureVisible(plugins);
          await tester.tap(plugins);
          await tester.ensureVisible(confirm);
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          expect(find.text(t.backupFlow.restoreTitle), findsOneWidget);
          expect(find.text(t.backupFlow.restoreFilesHint), findsOneWidget);
          expect(find.text(t.backupFlow.replaceSettingsWarning), findsNothing);
          expect(find.text(t.backupFlow.replacePluginsWarning), findsNothing);
          expect(calls, [BackupImportMode.merge]);
          await writeUiPreview(
            tester,
            const ValueKey('backup.preview'),
            'file-backup-replace-large-$style-${brightness.name}',
          );
          final replace = find.byKey(const ValueKey('backup.confirm-replace'));
          await tester.ensureVisible(replace);
          await tester.tap(replace);
          await tester.pumpAndSettle();
          expect(calls, [BackupImportMode.merge, BackupImportMode.restore]);
          expect(selections.last.importSettings, isFalse);
          expect(selections.last.importPlugins, isFalse);
          expect(find.text(t.backupFlow.restoreDone), findsOneWidget);
          await tester.tap(find.text(t.common.ok));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }

  testWidgets(
    'cancel final replacement confirmation writes nothing and releases the selected file',
    (tester) async {
      // Real filesystem futures must run outside the widget test fake clock.
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('backup-cancel-'),
      ))!;
      addTearDown(() {
        if (directory.existsSync()) directory.deleteSync(recursive: true);
      });
      var imports = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: DataBackupPage(
            actions: DataBackupActions(
              selectBackup: (_) async => BackupConfig(
                version: 'fixture',
                includeDownloads: true,
                cacheDir: directory.path,
                extractDir: '${directory.path}/extract',
                zipPath: '${directory.path}/backup.zip',
              ),
              inspectBackup: (_) async => const OfflineBackupPreview(
                version: 'fixture',
                exportedAt: null,
                includeDownloads: true,
                counts: {'unifiedComicFavorite': 1},
              ),
              importBackupWithOptions: (_, _, _) async {
                imports++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final prefs = await SharedPreferences.getInstance();
      final before = {for (final key in prefs.getKeys()) key: prefs.get(key)};
      final entry = find.byKey(const ValueKey('backup.import'));
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      final restore = find.byKey(const ValueKey('backup.mode.restore'));
      await tester.ensureVisible(restore);
      await tester.tap(restore);
      await tester.pump();
      final confirm = find.byKey(const ValueKey('backup.confirm-import'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('backup.replace-confirm')),
        findsOneWidget,
      );
      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();
      expect(imports, 0);
      expect(await tester.runAsync(directory.exists), isFalse);
      expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, before);
    },
  );
}
