import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/sync/backup_protection_manager.dart';
import 'package:zephyr/network/sync/comic_sync_core.dart';
import 'package:zephyr/network/sync/sync_archive_context.dart';
import 'package:zephyr/page/setting/common/backup_protection_ui.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/service/backup_security/backup_security.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

class _Profiles implements BackupProtectionProfileStore {
  BackupProtectionProfile? value;
  Future<BackupProtectionProfile?> Function()? readOverride;
  int writes = 0;
  @override
  Future<BackupProtectionProfile?> read() =>
      readOverride?.call() ?? Future.value(value);
  @override
  Future<void> write(BackupProtectionProfile? profile) async {
    writes++;
    value = profile;
  }
}

class _DeviceKeys
    implements BackupDeviceKeyStore, BackupDeviceKeyStoreAvailability {
  _DeviceKeys({this.supported = true});
  final bool supported;
  final Map<String, Uint8List> values = {};
  int writes = 0;
  @override
  Future<bool> isSupported() async => supported;
  @override
  Future<Uint8List?> readKey(String archiveId) async => values[archiveId];
  @override
  Future<void> writeKey(String archiveId, Uint8List key) async {
    writes++;
    values[archiveId] = Uint8List.fromList(key);
  }

  @override
  Future<void> deleteKey(String archiveId) async {
    values.remove(archiveId);
  }
}

/// Only records real core work. Root-zone work is bridged back to the caller's
/// error zone, so deliberate wrong-factor failures reach the production page.
/// The separate successful completion signal lets runAsync await isolate work.
class _Service extends BackupProtectionService {
  _Service(_DeviceKeys keys) : super(deviceKeys: keys);
  Future<dynamic>? lastWork;
  int creates = 0;
  Future<T> _record<T>(Future<T> Function() action) {
    final result = Completer<T>();
    lastWork = Zone.root.run(() async {
      try {
        result.complete(await action());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  @override
  Future<PendingBackupProtection> create(String password) {
    creates++;
    return _record(() => super.create(password));
  }

  @override
  Future<BackupProtectionSession> confirmRecovery(
    PendingBackupProtection pending,
    String recoveryCode, {
    bool trustDevice = true,
  }) => _record(
    () =>
        super.confirmRecovery(pending, recoveryCode, trustDevice: trustDevice),
  );
  @override
  Future<BackupProtectionSession> unlockProfile(
    BackupProtectionProfile profile, {
    String? password,
    String? recoveryCode,
    String? recoveryFile,
    bool useTrustedDevice = false,
    bool trustDevice = false,
  }) => _record(
    () => super.unlockProfile(
      profile,
      password: password,
      recoveryCode: recoveryCode,
      recoveryFile: recoveryFile,
      useTrustedDevice: useTrustedDevice,
      trustDevice: trustDevice,
    ),
  );
}

class _Cloud extends ComicSyncRemoteAdapter {
  final Map<String, List<int>> files = {};
  int deletes = 0;
  @override
  Future<void> testConnection() async {}
  @override
  Future<void> ensureRemoteReady() async {}
  @override
  Future<List<String>> listRemoteDataFiles() async => files.keys.toList();
  @override
  Future<List<int>> downloadRemoteFile(String path) async => files[path]!;
  @override
  Future<String> downloadRemoteMd5() async => '';
  @override
  Future<void> uploadRemoteMd5(String value) async {}
  @override
  Future<void> uploadRemoteFile(
    String path,
    List<int> data, {
    String contentType = 'application/octet-stream',
  }) async {
    files[path] = data;
  }

  @override
  Future<void> deleteRemoteFiles(List<String> paths) async {
    deletes += paths.length;
    for (final path in paths) {
      files.remove(path);
    }
  }
}

const _password = 'correct horse battery staple';
late BackupProtectionProfile _fileProfile;
late String _fileCode, _fileRecovery;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final previousFatalHitTestWarnings =
      WidgetController.hitTestWarningShouldBeFatal;
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    final service = BackupProtectionService(
      deviceKeys: _DeviceKeys(supported: false),
    );
    final pending = await service.create(_password);
    _fileProfile = pending.profile;
    _fileCode = pending.recoveryCode;
    _fileRecovery = pending.recoveryFile;
    pending.dispose();
  });
  tearDownAll(() {
    WidgetController.hitTestWarningShouldBeFatal = previousFatalHitTestWarnings;
  });

  late _DeviceKeys keys;
  late _Service service;
  late _Profiles profiles;
  late BackupProtectionManager manager;
  late GlobalSettingCubit cubit;
  late ValueNotifier<String> style;
  late BackupProtectionUiDependencies dependencies;
  BackupProtectionSession? imported;
  bool? cloudUnlockResult;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform_views,
          (_) async => null,
        );
    keys = _DeviceKeys();
    service = _Service(keys);
    profiles = _Profiles();
    manager = BackupProtectionManager(
      service: service,
      profileStore: profiles,
      operationRunner: (action) => action(),
    );
    cubit = GlobalSettingCubit();
    style = ValueNotifier('breeze');
    imported = null;
    cloudUnlockResult = null;
    dependencies = BackupProtectionUiDependencies(
      manager: manager,
      createAdapter: (_) => null,
      pickRecoveryFile: () async => null,
      saveRecoveryFile: (_) async => false,
    );
  });
  tearDown(() async {
    imported?.dispose();
    manager.lock();
    style.dispose();
    await cubit.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  Future<void> cryptoSettled(WidgetTester tester) async {
    await tester.pump();
    final work = service.lastWork;
    if (work != null) {
      await tester.runAsync(() async {
        try {
          await work;
        } catch (_) {
          /* Error is presented by the real page. */
        }
      });
    }
    await tester.pumpAndSettle();
  }

  Future<void> mount(
    WidgetTester tester, {
    double scale = 1,
    double inset = 0,
    Widget? home,
  }) async {
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: AppInterfaceStyleScope(
          style: style,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                viewInsets: EdgeInsets.only(bottom: inset),
              ),
              child: child!,
            ),
            home:
                home ??
                Scaffold(
                  body: Builder(
                    builder: (context) => Column(
                      children: [
                        TextButton(
                          key: const ValueKey('host.settings'),
                          onPressed: () => showBackupProtectionSettings(
                            context,
                            dependencies: dependencies,
                          ),
                          child: const Text('Settings'),
                        ),
                        TextButton(
                          key: const ValueKey('host.file'),
                          onPressed: () async {
                            imported = await unlockFileBackupProtection(
                              context,
                              _fileProfile,
                              dependencies: dependencies,
                            );
                          },
                          child: const Text('Import protected file'),
                        ),
                        TextButton(
                          key: const ValueKey('host.cloud'),
                          onPressed: () async {
                            cloudUnlockResult =
                                await unlockCloudBackupProtection(
                                  context,
                                  dependencies: dependencies,
                                );
                          },
                          child: const Text('Unlock cloud'),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> settings(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('host.settings')));
    await tester.pumpAndSettle();
  }

  Future<void> chooseProtected(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('protection.mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.backupSecurity.protected).last);
    await tester.pumpAndSettle();
  }

  Future<void> enterPassword(
    WidgetTester tester, {
    String repeat = _password,
    bool duplicateConfirm = false,
  }) async {
    await tester.enterText(
      find.byKey(const ValueKey('protection.password')),
      _password,
    );
    await tester.enterText(
      find.byKey(const ValueKey('protection.passwordRepeat')),
      repeat,
    );
    final confirm = find.byKey(const ValueKey('protection.passwordConfirm'));
    await tester.ensureVisible(confirm);
    final element = tester.element(confirm);
    final submit = tester.widget<FilledButton>(confirm).onPressed!;
    await tester.tap(confirm);
    if (duplicateConfirm) {
      // The exiting route blocks pointers after the first valid tap. Reinvoke
      // its captured real callback before a frame/disposal to test the guard.
      expect(element.mounted, isTrue);
      submit();
    }
    await cryptoSettled(tester);
  }

  Future<void> back(WidgetTester tester) async {
    tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
    await tester.pumpAndSettle();
  }

  testWidgets(
    'password mismatch and cancelling setup never trust or persist a profile',
    (tester) async {
      await mount(tester);
      await settings(tester);
      await chooseProtected(tester);
      await enterPassword(tester, repeat: 'a mismatched repeat');
      expect(find.text(t.backupSecurity.passwordMismatch), findsOneWidget);
      expect(service.creates, 0);
      expect(keys.writes, 0);
      expect(profiles.writes, 0);
      await back(tester);
      expect(manager.mode, BackupProtectionMode.standard);
      await chooseProtected(tester);
      await enterPassword(tester);
      expect(
        find.byKey(const ValueKey('protection.recoveryCode')),
        findsOneWidget,
      );
      expect(manager.profile, isNull);
      await back(tester);
      expect(keys.writes, 0);
      expect(profiles.writes, 0);
      expect(manager.profile, isNull);
      await back(tester);
    },
  );

  testWidgets(
    'setup requires recovery verification before enabling and defaults device trust when supported',
    (tester) async {
      await mount(tester);
      await settings(tester);
      await chooseProtected(tester);
      await enterPassword(tester, duplicateConfirm: true);
      expect(service.creates, 1);
      final code = tester
          .widget<SelectableText>(
            find.byKey(const ValueKey('protection.recoveryCode')),
          )
          .data!;
      expect(profiles.writes, 0);
      expect(keys.writes, 0);
      await tester.ensureVisible(
        find.byKey(const ValueKey('protection.savedContinue')),
      );
      await tester.tap(find.byKey(const ValueKey('protection.savedContinue')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      await tester.enterText(
        find.byKey(const ValueKey('protection.verifyRecovery')),
        'BR1-invalid',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('protection.verifyConfirm')),
      );
      await tester.tap(find.byKey(const ValueKey('protection.verifyConfirm')));
      await cryptoSettled(tester);
      expect(find.text(t.backupSecurity.wrongFactor), findsOneWidget);
      expect(keys.writes, 0);
      expect(profiles.writes, 0);
      await tester.enterText(
        find.byKey(const ValueKey('protection.verifyRecovery')),
        code,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('protection.verifyConfirm')),
      );
      await tester.tap(find.byKey(const ValueKey('protection.verifyConfirm')));
      await cryptoSettled(tester);
      expect(manager.isUnlocked, isTrue);
      expect(manager.mode, BackupProtectionMode.passwordProtected);
      expect(keys.writes, 1);
      expect(profiles.writes, 1);
      await back(tester);
    },
  );

  testWidgets(
    'manual password, recovery code and recovery file unlock independent file sessions',
    (tester) async {
      keys = _DeviceKeys(supported: false);
      service = _Service(keys);
      manager = BackupProtectionManager(
        service: service,
        profileStore: profiles,
        operationRunner: (action) => action(),
      );
      dependencies = BackupProtectionUiDependencies(
        manager: manager,
        createAdapter: (_) => null,
        pickRecoveryFile: () async => _fileRecovery,
      );
      await mount(tester);
      await tester.tap(find.byKey(const ValueKey('host.file')));
      await cryptoSettled(tester);
      await tester.enterText(
        find.byKey(const ValueKey('protection.unlockValue')),
        'wrong password',
      );
      await tester.tap(find.byKey(const ValueKey('protection.unlockConfirm')));
      await cryptoSettled(tester);
      expect(find.text(t.backupSecurity.wrongFactor), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('protection.unlockValue')),
        _password,
      );
      await tester.tap(find.byKey(const ValueKey('protection.unlockConfirm')));
      await cryptoSettled(tester);
      expect(imported, isNotNull);
      imported!.dispose();
      imported = null;
      expect(manager.profile, isNull);
      expect(profiles.writes, 0);
      expect(keys.writes, 0);
      await tester.tap(find.byKey(const ValueKey('host.file')));
      await cryptoSettled(tester);
      await tester.tap(find.byKey(const ValueKey('protection.unlockMethod')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.backupSecurity.recoveryCode).last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('protection.unlockValue')),
        _fileCode,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('protection.unlockConfirm')),
      );
      await tester.tap(find.byKey(const ValueKey('protection.unlockConfirm')));
      await cryptoSettled(tester);
      expect(imported, isNotNull);
      imported!.dispose();
      imported = null;
      await tester.tap(find.byKey(const ValueKey('host.file')));
      await cryptoSettled(tester);
      await tester.tap(find.byKey(const ValueKey('protection.openRecovery')));
      await cryptoSettled(tester);
      expect(imported, isNotNull);
      expect(profiles.writes, 0);
      expect(keys.writes, 0);
      expect(manager.profile, isNull);
    },
  );

  testWidgets('file recovery never replaces a different active cloud profile', (
    tester,
  ) async {
    final cloudPending = await tester.runAsync(
      () => service.create('a separate cloud password'),
    );
    final cloudSession = await tester.runAsync(
      () => manager.confirmSetup(
        cloudPending!,
        cloudPending.recoveryCode,
        trustDevice: false,
      ),
    );
    final cloudId = cloudSession!.profile.archiveId;
    final writesBefore = profiles.writes;
    dependencies = BackupProtectionUiDependencies(
      manager: manager,
      createAdapter: (_) => null,
      pickRecoveryFile: () async => _fileRecovery,
    );
    await mount(tester);
    await tester.tap(find.byKey(const ValueKey('host.file')));
    await cryptoSettled(tester);
    await tester.tap(find.byKey(const ValueKey('protection.openRecovery')));
    await cryptoSettled(tester);
    expect(imported!.profile.archiveId, _fileProfile.archiveId);
    expect(manager.profile!.archiveId, cloudId);
    expect(manager.session, same(cloudSession));
    expect(profiles.writes, writesBefore);
    expect(keys.writes, 0);
  });

  testWidgets(
    'cloud recovery persists only after successful unlock and checked device consent',
    (tester) async {
      profiles.value = _fileProfile;
      dependencies = BackupProtectionUiDependencies(
        manager: manager,
        createAdapter: (_) => null,
        pickRecoveryFile: () async => _fileRecovery,
      );
      await mount(tester);
      await tester.tap(find.byKey(const ValueKey('host.cloud')));
      await cryptoSettled(tester);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      expect(profiles.writes, 0);
      expect(keys.writes, 0);
      await tester.tap(find.byKey(const ValueKey('protection.openRecovery')));
      await cryptoSettled(tester);
      expect(cloudUnlockResult, isTrue);
      expect(manager.profile!.archiveId, _fileProfile.archiveId);
      expect(manager.isUnlocked, isTrue);
      expect(profiles.writes, 1);
      expect(keys.writes, 1);
    },
  );

  testWidgets(
    'recovery picker is single flight, prevents back while busy and cancel has no effects',
    (tester) async {
      final selection = Completer<String?>();
      var picks = 0;
      dependencies = BackupProtectionUiDependencies(
        manager: manager,
        createAdapter: (_) => null,
        pickRecoveryFile: () {
          picks++;
          return selection.future;
        },
      );
      await mount(tester);
      await tester.tap(find.byKey(const ValueKey('host.file')));
      await cryptoSettled(tester);
      await tester.tap(find.byKey(const ValueKey('protection.openRecovery')));
      await tester.pump();
      expect(
        tester
            .widget<TextButton>(
              find.byKey(const ValueKey('protection.openRecovery')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('protection.unlockConfirm')),
            )
            .onPressed,
        isNull,
      );
      await back(tester);
      expect(
        find.byKey(const ValueKey('protection.unlockValue')),
        findsOneWidget,
      );
      expect(picks, 1);
      selection.complete(null);
      await tester.pumpAndSettle();
      await back(tester);
      expect(imported, isNull);
      expect(keys.writes, 0);
      expect(profiles.writes, 0);
      expect(tester.takeException(), isNull);
      dependencies = BackupProtectionUiDependencies(
        manager: manager,
        createAdapter: (_) => null,
        pickRecoveryFile: () async =>
            throw StateError('synthetic private file error'),
      );
      await tester.tap(find.byKey(const ValueKey('host.file')));
      await cryptoSettled(tester);
      await tester.tap(find.byKey(const ValueKey('protection.openRecovery')));
      await tester.pumpAndSettle();
      expect(find.text(t.backupSecurity.failed), findsOneWidget);
      expect(find.textContaining('synthetic private file error'), findsNothing);
      expect(tester.takeException(), isNull);
      await back(tester);
    },
  );

  testWidgets(
    'recovery save busy and failure keep setup pending and do not trust',
    (tester) async {
      final save = Completer<bool>();
      dependencies = BackupProtectionUiDependencies(
        manager: manager,
        createAdapter: (_) => null,
        saveRecoveryFile: (_) => save.future,
      );
      await mount(tester);
      await settings(tester);
      await chooseProtected(tester);
      await enterPassword(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('protection.saveRecovery')),
      );
      await tester.tap(find.byKey(const ValueKey('protection.saveRecovery')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('protection.savedContinue')),
            )
            .onPressed,
        isNull,
      );
      await back(tester);
      expect(
        find.byKey(const ValueKey('protection.recoveryCode')),
        findsOneWidget,
      );
      save.completeError(StateError('synthetic export failure'));
      await tester.pumpAndSettle();
      expect(find.text(t.backupSecurity.saveFailed), findsOneWidget);
      expect(manager.profile, isNull);
      expect(keys.writes, 0);
      expect(profiles.writes, 0);
      await back(tester);
      await back(tester);
    },
  );

  testWidgets(
    'preparing cloud transaction can resume without an unavailable profile',
    (tester) async {
      final cloud = _Cloud();
      final path =
          '${SyncArchiveContext.currentRoot}/protection_transition_${List.filled(32, 'a').join()}.json';
      cloud.files[path] = [
        123,
      ]; // Interrupted initial journal; no stage or payload mutation.
      dependencies = BackupProtectionUiDependencies(
        manager: manager,
        createAdapter: (_) => cloud,
      );
      await mount(tester);
      await settings(tester);
      expect(find.text(t.backupSecurity.resume), findsOneWidget);
      expect(manager.profile, isNull);
      await tester.tap(find.text(t.backupSecurity.resume));
      await tester.pumpAndSettle();
      expect(cloud.deletes, 1);
      expect(cloud.files, isEmpty);
      expect(
        find.byKey(const ValueKey('protection.unlockValue')),
        findsNothing,
      );
      expect(keys.writes, 0);
      expect(profiles.writes, 0);
      await back(tester);
    },
  );

  for (final interfaceStyle in ['breeze', 'system']) {
    testWidgets(
      'protection entry reads locally, retries safely and refreshes after returning in $interfaceStyle style',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        style.value = interfaceStyle;
        var cloudInspections = 0;
        dependencies = BackupProtectionUiDependencies(
          manager: manager,
          createAdapter: (_) {
            cloudInspections++;
            return null;
          },
        );
        final read = Completer<BackupProtectionProfile?>();
        profiles.readOverride = () => read.future;
        await mount(
          tester,
          scale: 2,
          home: SettingPageShell(
            grouped: true,
            title: '同步',
            child: ListView(
              children: [
                SettingSection(
                  footer: t.backupSecurity.scopeHint,
                  children: [
                    BackupProtectionSettingsTile(
                      key: const ValueKey('host.protectionEntry'),
                      dependencies: dependencies,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        final entry = find.descendant(
          of: find.byKey(const ValueKey('host.protectionEntry')),
          matching: find.byType(ListTile),
        );
        expect(find.text(t.backupSecurity.working), findsOneWidget);
        expect(find.text(t.backupSecurity.standard), findsNothing);
        expect(tester.widget<ListTile>(entry).onTap, isNull);
        expect(cloudInspections, 0);
        read.completeError(StateError('fixture local read failed'));
        await tester.pumpAndSettle();
        expect(find.text(t.backupSecurity.readFailed), findsOneWidget);
        expect(find.text(t.backupSecurity.standard), findsNothing);
        profiles.readOverride = () async => _fileProfile;
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(find.text(t.backupSecurity.protected), findsOneWidget);
        expect(cloudInspections, 0);
        expect(profiles.writes, 0);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        expect(cloudInspections, 1);
        expect(find.byKey(const ValueKey('protection.scope')), findsOneWidget);
        final unconfigured = find.byKey(
          const ValueKey('protection.cloud-unconfigured'),
        );
        await tester.scrollUntilVisible(
          unconfigured,
          160,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        expect(find.text(t.backupSecurity.cloudNotConfigured), findsOneWidget);
        expect(tester.takeException(), isNull);
        await manager.useStandardFileBackups();
        await back(tester);
        expect(find.text(t.backupSecurity.standard), findsOneWidget);
        expect(find.text(t.backupSecurity.protected), findsNothing);
        expect(cloudInspections, 1);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
    testWidgets(
      'unlock stays usable at 320pt 2x text with keyboard in $interfaceStyle style',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        style.value = interfaceStyle;
        await mount(tester, scale: 2, inset: 260);
        await tester.tap(find.byKey(const ValueKey('host.file')));
        await cryptoSettled(tester);
        final input = find.byKey(const ValueKey('protection.unlockValue'));
        await tester.ensureVisible(input);
        await tester.showKeyboard(input);
        await tester.pumpAndSettle();
        expect(tester.getRect(input).right, lessThanOrEqualTo(320));
        final button = find.byKey(const ValueKey('protection.unlockConfirm'));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        final rect = tester.getRect(button);
        expect(rect.height, greaterThanOrEqualTo(44));
        expect(rect.right, lessThanOrEqualTo(320));
        expect(rect.bottom, lessThanOrEqualTo(500));
        expect(tester.takeException(), isNull);
        await back(tester);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
