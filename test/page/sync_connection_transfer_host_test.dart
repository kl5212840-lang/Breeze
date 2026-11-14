import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/webdav_sync/view/webdav_sync_page.dart';
import 'package:zephyr/service/sync_connection_transfer.dart';

import '../test_helper.dart';

const _s3 = S3SettingState(
  endpoint: 's3.fixture.invalid',
  accessKey: 'fixture-access',
  secretKey: 'fixture-secret',
  bucket: 'fixture-bucket',
  region: 'fixture-region',
  port: 9443,
  useSSL: false,
  pathStyle: true,
);
const _webdav = WebDavSettingState(
  host: 'https://fixture.invalid/dav',
  username: 'fixture-user',
  password: 'fixture-password',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  const copyKey = ValueKey('sync-config.copy');
  const importKey = ValueKey('sync-config.import');
  late GlobalSettingCubit cubit;
  String? clipboard;
  int writes = 0;
  int reads = 0;

  setUp(() {
    clipboard = null;
    writes = 0;
    reads = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
            writes++;
          }
          if (call.method == 'Clipboard.getData') {
            reads++;
            return clipboard == null ? null : {'text': clipboard};
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    await cubit.close();
  });

  Future<void> mount(
    WidgetTester tester,
    SyncServiceType type, {
    bool configured = false,
  }) async {
    final row = objectbox.userSettingBox.get(1)!;
    row.globalSetting = GlobalSettingState(
      syncSetting: SyncSettingState(
        syncServiceType: type,
        webdavSetting: configured ? _webdav : const WebDavSettingState(),
        s3Setting: configured ? _s3 : const S3SettingState(),
      ),
    );
    objectbox.userSettingBox.put(row);
    cubit = GlobalSettingCubit();
    await cubit.initBox();
    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: const MaterialApp(home: WebDavSyncPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> closeHost(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));
  }

  for (final type in [SyncServiceType.s3, SyncServiceType.webdav]) {
    final config = type == SyncServiceType.s3
        ? const SyncConnectionConfig.s3(_s3)
        : const SyncConnectionConfig.webdav(_webdav);

    testWidgets('copy $type requests consent and writes only the code', (
      tester,
    ) async {
      await mount(tester, type, configured: true);
      final previous = cubit.state.syncSetting;
      expect(reads, 0);
      await tester.tap(find.byKey(copyKey));
      await tester.pumpAndSettle();
      expect(find.text(t.webdavSync.copyConfigCodePrompt), findsOneWidget);
      expect(writes, 0);
      await tester.tap(find.text(t.common.cancel));
      await tester.pumpAndSettle();
      expect(writes, 0);

      await tester.tap(find.byKey(copyKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.copy));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(clipboard, config.encode());
      expect(clipboard, isNot(contains('fixture-')));
      expect(cubit.state.syncSetting, previous);
      await closeHost(tester);
    });

    testWidgets('import $type fills the form without saving', (tester) async {
      await mount(tester, type);
      final previous = cubit.state.syncSetting;
      clipboard = config.encode();
      expect(reads, 0);
      await tester.tap(find.byKey(importKey));
      await tester.pumpAndSettle();
      expect(reads, 1);
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      final values = fields.map((field) => field.controller!.text);
      if (type == SyncServiceType.s3) {
        expect(values, [
          _s3.endpoint,
          _s3.accessKey,
          _s3.secretKey,
          _s3.bucket,
          _s3.region,
          _s3.port.toString(),
        ]);
        expect(
          tester
              .widgetList<SwitchListTile>(find.byType(SwitchListTile))
              .map((tile) => tile.value),
          [_s3.useSSL, _s3.pathStyle],
        );
      } else {
        expect(values, [_webdav.host, _webdav.username, _webdav.password]);
      }
      expect(fields.where((field) => field.obscureText), hasLength(1));
      expect(cubit.state.syncSetting, previous);
      expect(
        objectbox.userSettingBox.get(1)!.globalSetting.syncSetting,
        previous,
      );
      await closeHost(tester);
    });
  }

  testWidgets('a code for another service keeps the existing draft', (
    tester,
  ) async {
    await mount(tester, SyncServiceType.webdav, configured: true);
    clipboard = const SyncConnectionConfig.s3(_s3).encode();
    await tester.tap(find.byKey(importKey));
    await tester.pumpAndSettle();
    final host = tester.widget<TextField>(find.byType(TextField).first);
    expect(host.controller!.text, _webdav.host);
    expect(cubit.state.syncSetting.webdavSetting, _webdav);
    await closeHost(tester);
  });
}
