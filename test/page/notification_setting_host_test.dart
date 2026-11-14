import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/global/global_setting.dart';
import 'package:zephyr/page/setting/global/notification_setting_page.dart';
import 'package:zephyr/service/checkin/auto_checkin_notices.dart';
import 'package:zephyr/service/comic_follow/comic_follow_reminders.dart';
import 'package:zephyr/service/update/app_update_reminder_preferences.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

import '../test_helper.dart';
import '../ui_preview_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await TestObjectBoxHelper.setUpTestObjectBox();
    SharedPreferences.setMockInitialValues({
      ComicFollowReminderController.modeKey: ComicFollowReminderMode.inApp.name,
    });
    await ComicFollowReminderController.instance.load();
    await loadUiPreviewFonts();
  });
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    SharedPreferences.setMockInitialValues({
      ComicFollowReminderController.modeKey: ComicFollowReminderMode.inApp.name,
    });
    messenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (_) async => null,
    );
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  for (final style in ['system', 'breeze']) {
    testWidgets(
      'settings opens one notification page with local auto check-in and the existing preferences ($style)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        expect(
          (await SharedPreferences.getInstance()).getBool(
            AutoCheckinNotices.enabledKey,
          ),
          isNull,
        );
        final cubit = GlobalSettingCubit()
          ..updateALl(const GlobalSettingState());
        final preference = ValueNotifier(style);
        final textScale = ValueNotifier(2.0);
        const previewKey = ValueKey('notification-settings.preview');
        addTearDown(cubit.close);
        addTearDown(preference.dispose);
        addTearDown(textScale.dispose);
        await tester.pumpWidget(
          BlocProvider.value(
            value: cubit,
            child: AppInterfaceStyleScope(
              style: preference,
              child: MaterialApp(
                theme: ThemeData(
                  fontFamily: uiPreviewDirectory == null
                      ? null
                      : 'AccountPreview',
                ),
                builder: (context, child) => ValueListenableBuilder<double>(
                  valueListenable: textScale,
                  child: RepaintBoundary(key: previewKey, child: child!),
                  builder: (context, scale, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                ),
                home: const GlobalSettingPage(),
              ),
            ),
          ),
        );
        final entry = find.text(t.notification.settingsTitle);
        await tester.ensureVisible(entry);
        await tester.tap(entry);
        await tester.pumpAndSettle();
        final page = find.byType(NotificationSettingPage);
        expect(page, findsOneWidget);
        final notificationContext = tester.element(page);
        expect(
          ModalRoute.of(notificationContext)?.settings.name,
          'breeze.notifications.settings',
        );

        final update = find.byKey(
          const ValueKey('notification-settings.app-update'),
        );
        expect(tester.widget<SwitchListTile>(update).value, isTrue);
        await tester.tap(update);
        await tester.pumpAndSettle();
        expect((await AppUpdateReminderPreferences.load()).enabled, isFalse);

        final downloads = find.byKey(
          const ValueKey('notification-settings.download-completion'),
        );
        final completion = tester.widget<SettingChoiceTile<String>>(downloads);
        expect(completion.value, 'work');
        expect(completion.items.keys, containsAll(['episode', 'work', 'off']));
        completion.onChanged('off');
        await tester.pumpAndSettle();
        expect(cubit.state.downloadCompletionNotice, 'off');

        final following = find.byKey(
          const ValueKey('notification-settings.comic-follow'),
        );
        await tester.ensureVisible(following);
        await tester.pumpAndSettle();
        final summary = find.text(t.followReminders.modeInAppSummary);
        expect(summary, findsOneWidget);
        expect(tester.widget<ListTile>(following).subtitle, isNotNull);
        expect(find.text(t.followReminders.modeInApp), findsNothing);
        await writeUiPreview(tester, previewKey, 'notifications-$style-large');
        tester.view.physicalSize = const Size(430, 932);
        textScale.value = 1;
        await tester.pumpAndSettle();
        expect(tester.widget<ListTile>(following).subtitle, isNull);
        expect(summary, findsOneWidget);
        await writeUiPreview(tester, previewKey, 'notifications-$style-inline');
        tester.view.physicalSize = const Size(320, 760);
        textScale.value = 2;
        await tester.pumpAndSettle();
        await tester.ensureVisible(following);
        await tester.tap(following);
        await tester.pumpAndSettle();
        final reminderDialog = find.byType(AlertDialog);
        expect(reminderDialog, findsOneWidget);
        expect(find.text(t.followReminders.scope), findsOneWidget);
        expect(find.text(t.followReminders.modeSilent), findsOneWidget);
        expect(find.text(t.followReminders.modeBadge), findsWidgets);
        expect(find.text(t.followReminders.modeInApp), findsOneWidget);
        Navigator.of(notificationContext).pop();
        await tester.pumpAndSettle();

        final checkin = find.byKey(
          const ValueKey('notification-settings.auto-checkin'),
        );
        await tester.scrollUntilVisible(
          checkin,
          120,
          scrollable: find.descendant(
            of: page,
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(checkin).value, isTrue);
        expect(find.text(t.notification.checkinResult), findsOneWidget);
        expect(
          find.text(t.notification.checkinResultDescription),
          findsOneWidget,
        );
        await tester.tap(checkin);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(checkin).value, isFalse);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(AutoCheckinNotices.enabledKey), isFalse);

        final sync = find.byKey(const ValueKey('notification-settings.sync'));
        await tester.ensureVisible(sync);
        await tester.pumpAndSettle();
        expect(tester.widget<SwitchListTile>(sync).value, isTrue);
        await tester.tap(sync);
        await tester.pumpAndSettle();
        expect(cubit.state.syncSetting.syncNotify, isFalse);

        final stored = GlobalSettingCubit();
        await stored.initBox();
        expect(stored.state.downloadCompletionNotice, 'off');
        expect(stored.state.syncSetting.syncNotify, isFalse);
        await stored.close();
        Navigator.of(notificationContext).pop();
        await tester.pumpAndSettle();
        expect(find.byType(GlobalSettingPage), findsOneWidget);
        expect(find.byType(NotificationSettingPage), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
