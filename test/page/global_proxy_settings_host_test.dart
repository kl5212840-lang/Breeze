import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/global/widgets.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/toast.dart';

import '../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await TestObjectBoxHelper.setUpTestObjectBox();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  for (final style in ['system', 'breeze']) {
    testWidgets(
      'proxy controls apply saved routes to both clients and cancel is inert $style',
      (tester) async {
        final cubit = GlobalSettingCubit()
          ..updateALl(
            const GlobalSettingState(
              proxySetting: ProxySettingState(address: '127.0.0.1:8118'),
            ),
          );
        final preference = ValueNotifier(style);
        addTearDown(cubit.close);
        addTearDown(preference.dispose);
        final routes = <String>[];
        var failApply = false;
        final notices = <ToastEvent>[];
        final subscription = eventBus.on<ToastEvent>().listen(notices.add);
        addTearDown(subscription.cancel);
        await tester.pumpWidget(
          AppInterfaceStyleScope(
            style: preference,
            child: BlocProvider.value(
              value: cubit,
              child: MaterialApp(
                home: Scaffold(
                  body: Builder(
                    builder: (context) {
                      final setting = context
                          .watch<GlobalSettingCubit>()
                          .state
                          .proxySetting;
                      return proxyToggle(
                        context,
                        enabled: setting.enabled,
                        type: setting.type,
                        currentProxy: setting.address,
                        applyProxy: (saved) {
                          expect(
                            objectbox.userSettingBox
                                .get(1)!
                                .globalSetting
                                .proxySetting,
                            saved,
                          );
                          if (failApply)
                            throw StateError('fixture apply failed');
                          applyGlobalProxySetting(
                            saved,
                            setHttp: (value) => routes.add('rust-http:$value'),
                            setSocks: (value) =>
                                routes.add('rust-socks:$value'),
                            setDart: (value) => routes.add('dart:$value'),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged!(
          true,
        );
        await tester.pumpAndSettle();
        expect(routes, [
          'rust-http:http://127.0.0.1:8118',
          'dart:PROXY 127.0.0.1:8118',
        ]);
        tester
            .widget<SettingChoiceTile<ProxyType>>(
              find.byType(SettingChoiceTile<ProxyType>),
            )
            .onChanged(ProxyType.socks5);
        await tester.pumpAndSettle();
        expect(routes.sublist(2), [
          'rust-socks:127.0.0.1:8118',
          'dart:SOCKS5 127.0.0.1:8118',
        ]);
        await tester.tap(find.text(t.settings.proxyAddress));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField), '127.0.0.1:9000');
        await tester.tap(find.text(t.common.cancel));
        await tester.pumpAndSettle();
        expect(routes, hasLength(4));
        expect(cubit.state.proxySetting.address, '127.0.0.1:8118');
        await tester.tap(find.text(t.settings.proxyAddress));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextFormField),
          'socks5://127.0.0.1:1080',
        );
        await tester.tap(find.text(t.common.ok));
        await tester.pumpAndSettle();
        expect(cubit.state.proxySetting.address, '127.0.0.1:1080');
        expect(routes.sublist(4), [
          'rust-socks:127.0.0.1:1080',
          'dart:SOCKS5 127.0.0.1:1080',
        ]);
        tester
            .widget<SettingChoiceTile<ProxyType>>(
              find.byType(SettingChoiceTile<ProxyType>),
            )
            .onChanged(ProxyType.http);
        await tester.pumpAndSettle();
        expect(routes.sublist(6), [
          'rust-http:http://127.0.0.1:1080',
          'dart:PROXY 127.0.0.1:1080',
        ]);
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged!(
          false,
        );
        await tester.pumpAndSettle();
        expect(routes.sublist(8), ['rust-socks:', 'dart:DIRECT']);
        final savedCount = notices
            .where((event) => event.type == ToastType.success)
            .length;
        failApply = true;
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged!(
          true,
        );
        await tester.pumpAndSettle();
        expect(
          notices.where((event) => event.type == ToastType.success),
          hasLength(savedCount),
        );
        expect(notices.last.type, ToastType.error);
        expect(routes, hasLength(10));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
