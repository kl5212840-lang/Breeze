import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/webdav_sync/view/webdav_sync_page.dart';
import 'package:zephyr/service/sync_connection_transfer.dart';
import 'package:zephyr/src/rust/api/http.dart' as rust_http;
import 'package:zephyr/src/rust/frb_generated.dart';
import 'package:zephyr/util/event/event.dart';
import 'package:zephyr/widgets/toast.dart';

import '../test_helper.dart';

class _FailingCubit extends GlobalSettingCubit {
  @override
  void resetState(GlobalSettingState Function(GlobalSettingState, GlobalSettingState) updates) {
    throw StateError('synthetic write failure');
  }
}

class _WebDavCheckClient implements rust_http.HttpClient {
  final release = Completer<void>();
  final methods = <String?>[];

  @override
  Future<rust_http.FetchResponse> fetch({
    required String url,
    rust_http.FetchInit? init,
  }) async {
    final method = init?.method;
    methods.add(method);
    await release.future;
    return rust_http.FetchResponse(
      status: method == 'OPTIONS' ? 200 : 207,
      statusText: 'OK',
      ok: true,
      headers: const {},
      body: Uint8List(0),
      url: url,
      redirected: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _WebDavCheckApi extends RustLibApi {
  final client = _WebDavCheckClient();
  rust_http.HttpClientOptions? requested;

  @override
  rust_http.HttpClient crateApiHttpHttpClientCreate({
    rust_http.HttpClientOptions? options,
  }) {
    requested = options;
    return client;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _webdav = WebDavSettingState(host: 'https://fixture.invalid', username: 'synthetic', password: 'synthetic-password');
const _s3 = S3SettingState(endpoint: 's3.fixture.invalid', bucket: 'synthetic', accessKey: 'synthetic-access', secretKey: 'synthetic-secret');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  late GlobalSettingCubit cubit;
  late StreamSubscription<ToastEvent> toasts;
  final messages = <String>[];
  setUp(() {
    messages.clear();
    objectbox.pluginConfigBox.removeAll();
    objectbox.pluginConfigBox.put(PluginConfig(name: 'synthetic-site', config: '{"account":"synthetic"}'));
    toasts = eventBus.on<ToastEvent>().listen((event) { messages.add(event.message); });
  });
  tearDown(() async { await toasts.cancel(); await cubit.close(); });
  Future<void> mount(WidgetTester tester, SyncServiceType type, {bool fail = false}) async {
    final row = objectbox.userSettingBox.get(1)!;
    row.globalSetting = GlobalSettingState(syncSetting: SyncSettingState(
      syncServiceType: type, webdavSetting: _webdav, s3Setting: _s3, syncSettings: true, syncPlugins: true));
    objectbox.userSettingBox.put(row);
    cubit = fail ? _FailingCubit() : GlobalSettingCubit();
    await cubit.initBox();
    await tester.pumpWidget(BlocProvider.value(value: cubit,
      child: const MaterialApp(home: WebDavSyncPage())));
    await tester.pumpAndSettle();
  }
  Future<void> open(WidgetTester tester) async {
    final button = find.widgetWithText(ElevatedButton, t.webdavSync.deleteConfig);
    await tester.scrollUntilVisible(button, 240,
      scrollable: find.byType(Scrollable).first, maxScrolls: 8);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text(t.webdavSync.deleteConfigTitle), findsOneWidget);
    expect(find.text(t.webdavSync.deleteConfigPrompt), findsOneWidget);
  }
  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(t.webdavSync.deleteConfig)));
    await tester.pumpAndSettle();
  }
  Object saved(SyncServiceType type) => type == SyncServiceType.webdav
      ? cubit.state.syncSetting.webdavSetting : cubit.state.syncSetting.s3Setting;

  for (final type in [SyncServiceType.webdav, SyncServiceType.s3]) {
    testWidgets('cancel, barrier and back leave $type config and site accounts intact', (tester) async {
      await mount(tester, type);
      final before = saved(type), beforeDb = objectbox.userSettingBox.get(1)!.globalSetting;
      await open(tester);
      expect(saved(type), before);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(t.common.cancel)));
      await tester.pumpAndSettle();
      expect(saved(type), before);
      await open(tester);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(saved(type), before);
      await open(tester);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      expect(saved(type), before);
      expect(objectbox.userSettingBox.get(1)!.globalSetting, beforeDb);
      expect(objectbox.pluginConfigBox.getAll().single.config, '{"account":"synthetic"}');
      expect(tester.takeException(), isNull);
    });

    testWidgets('confirmed $type clear affects only that saved connection', (tester) async {
      await mount(tester, type);
      await open(tester);
      await confirm(tester);
      final sync = objectbox.userSettingBox.get(1)!.globalSetting.syncSetting;
      expect(sync.webdavSetting, type == SyncServiceType.webdav ? const WebDavSettingState() : _webdav);
      expect(sync.s3Setting, type == SyncServiceType.s3 ? const S3SettingState() : _s3);
      expect(sync.syncPlugins, isTrue);
      expect(sync.syncSettings, isFalse);
      expect(objectbox.pluginConfigBox.getAll().single.config, '{"account":"synthetic"}');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('confirmation cannot clear a newer saved config', (tester) async {
    await mount(tester, SyncServiceType.webdav);
    await open(tester);
    cubit.updateWebDavSetting((previous) => previous.copyWith(host: 'https://new.fixture.invalid'));
    final updated = cubit.state.syncSetting;
    await confirm(tester);
    expect(cubit.state.syncSetting, updated);
    expect(objectbox.userSettingBox.get(1)!.globalSetting.syncSetting, updated);
    expect(messages, contains(t.webdavSync.configChanged));
  });

  testWidgets('confirmation cannot clear config after the selected backend changes', (tester) async {
    await mount(tester, SyncServiceType.webdav);
    await open(tester);
    cubit.updateSyncSetting((previous) => previous.copyWith(syncServiceType: SyncServiceType.s3));
    final updated = cubit.state.syncSetting;
    await confirm(tester);
    expect(cubit.state.syncSetting, updated);
    expect(cubit.state.syncSetting.webdavSetting, _webdav);
    expect(cubit.state.syncSetting.s3Setting, _s3);
    expect(messages, contains(t.webdavSync.configChanged));
  });

  testWidgets('confirmation cannot discard a changed draft', (tester) async {
    await mount(tester, SyncServiceType.webdav);
    await open(tester);
    final host = tester.widgetList<TextField>(find.byType(TextField, skipOffstage: false)).first.controller!;
    host.text = 'https://edited.fixture.invalid';
    await confirm(tester);
    expect(cubit.state.syncSetting.webdavSetting, _webdav);
    expect(host.text, 'https://edited.fixture.invalid');
    expect(messages, contains(t.webdavSync.configChanged));
  });

  testWidgets('failed clear keeps saved config and input and reports only a fixed error', (tester) async {
    await mount(tester, SyncServiceType.webdav, fail: true);
    await open(tester);
    await confirm(tester);
    expect(cubit.state.syncSetting.webdavSetting, _webdav);
    expect(objectbox.userSettingBox.get(1)!.globalSetting.syncSetting.webdavSetting, _webdav);
    expect(tester.widgetList<TextField>(find.byType(TextField)).first.controller!.text, _webdav.host);
    expect(messages, contains(t.webdavSync.clearConfigFailed));
    expect(tester.takeException(), isNull);
  });

  for (final outcome in ['saved', 'changed', 'dismissed', 'failed']) {
    testWidgets('WebDAV only commits a current successful connection check ($outcome)', (
      tester,
    ) async {
      final api = _WebDavCheckApi();
      RustLib.initMock(api: api);
      addTearDown(RustLib.dispose);
      final syncRequests = <NoticeSync>[];
      final subscription = eventBus.on<NoticeSync>().listen(syncRequests.add);
      addTearDown(subscription.cancel);
      await mount(tester, SyncServiceType.webdav);

      final host = tester.widget<TextField>(find.byType(TextField).first).controller!;
      host.text = ' https://checked.fixture.invalid ';
      final save = find.widgetWithText(ElevatedButton, t.webdavSync.testAndSave);
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
      expect(find.text(t.webdavSync.connectingWebdav), findsOneWidget);
      expect(api.requested?.baseUrl, 'https://checked.fixture.invalid');
      expect(api.client.methods, ['OPTIONS']);
      expect(saved(SyncServiceType.webdav), _webdav);

      if (outcome == 'changed') host.text = 'https://changed.fixture.invalid';
      if (outcome == 'dismissed') {
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
      }
      if (outcome == 'failed') {
        api.client.release.completeError(StateError('private fixture value'));
      } else {
        api.client.release.complete();
      }
      await tester.pumpAndSettle();

      expect(find.byType(WebDavSyncPage), findsOneWidget);
      expect(find.textContaining('private fixture value'), findsNothing);
      final sync = objectbox.userSettingBox.get(1)!.globalSetting.syncSetting;
      if (outcome == 'saved') {
        expect(sync.webdavSetting, _webdav.copyWith(host: 'https://checked.fixture.invalid'));
        expect(syncRequests, hasLength(1));
        expect(find.text(t.webdavSync.webdavConnected), findsOneWidget);
      } else {
        expect(sync.webdavSetting, _webdav);
        expect(syncRequests, isEmpty);
      }
      expect(
        find.text(t.webdavSync.connectionCheckFailed),
        outcome == 'failed' ? findsOneWidget : findsNothing,
      );
      expect(sync.s3Setting, _s3);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the first save of an imported WebDAV draft stays local', (
    tester,
  ) async {
    const imported = WebDavSettingState(
      host: 'https://imported.fixture.invalid/dav',
      username: 'imported-fixture',
      password: 'imported-fixture-password',
    );
    final code = const SyncConnectionConfig.webdav(imported).encode();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': code};
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    final api = _WebDavCheckApi();
    RustLib.initMock(api: api);
    addTearDown(RustLib.dispose);
    final syncRequests = <NoticeSync>[];
    final subscription = eventBus.on<NoticeSync>().listen(syncRequests.add);
    addTearDown(subscription.cancel);
    await mount(tester, SyncServiceType.webdav);

    await tester.tap(find.byKey(const ValueKey('sync-config.import')));
    await tester.pumpAndSettle();
    expect(
      tester.widgetList<TextField>(find.byType(TextField)).map(
        (field) => field.controller!.text,
      ),
      [imported.host, imported.username, imported.password],
    );
    expect(saved(SyncServiceType.webdav), _webdav);
    expect(api.client.methods, isEmpty);
    expect(syncRequests, isEmpty);

    final save = find.widgetWithText(ElevatedButton, t.webdavSync.testAndSave);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    expect(api.requested?.baseUrl, imported.host);
    expect(api.client.methods, ['OPTIONS']);
    expect(saved(SyncServiceType.webdav), _webdav);

    api.client.release.complete();
    await tester.pumpAndSettle();
    expect(api.client.methods, ['OPTIONS', 'PROPFIND']);
    expect(saved(SyncServiceType.webdav), imported);
    final persisted = objectbox.userSettingBox.get(1)!.globalSetting.syncSetting;
    expect(persisted.webdavSetting, imported);
    expect(persisted.s3Setting, _s3);
    expect(syncRequests, isEmpty);
    expect(find.text(t.webdavSync.webdavConnected), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 6));
  });
}
