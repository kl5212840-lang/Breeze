import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/page/comic_follow/view/comic_follow_page.dart';
import 'package:zephyr/page/comic_follow/widgets/comic_follow_reminder_widgets.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/service/comic_follow/comic_follow_reminders.dart';
import 'package:zephyr/service/comic_follow/comic_follow_service.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/collection_cover_settings.dart';

class _EmptyFollowRepository implements ComicFollowRepository {
  @override
  List<ComicFollow> listActiveFollows() => [];
  @override
  Map<String, UnifiedComicHistory> listActiveHistories() => {};
  @override
  UnifiedComicHistory? getActiveHistoryByUniqueKey(String key) => null;
  @override
  ComicFollow? getFollowByUniqueKey(String key) => null;
  @override
  void putFollow(ComicFollow value) {}
  @override
  Future<ComicFollowDetection?> detectChapter(
    ComicFollow value, {
    bool Function()? canContinue,
  }) async => null;
  @override
  Future<void> notifyUpdate(
    int count, {
    Map<String, int> updates = const {},
    bool Function(String key, int count)? canDeliver,
  }) async {}
}

void main() {
  for (final style in ['system', 'breeze']) {
    testWidgets('real follow menu opens reminder settings in $style', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final cubit = ComicFollowCubit(repository: _EmptyFollowRepository());
      final preference = ValueNotifier(style);
      addTearDown(cubit.close);
      addTearDown(preference.dispose);
      final messenger = tester.binding.defaultBinaryMessenger;
      final channels = <MethodChannel>[];
      MethodChannel? moreChannel;
      Map<Object?, Object?>? moreParams;
      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final arguments = call.arguments as Map;
          final channel = MethodChannel(
            '${arguments['viewType']}.${arguments['id']}',
          );
          channels.add(channel);
          messenger.setMockMethodCallHandler(channel, (_) async => null);
          final bytes = arguments['params'] as Uint8List?;
          if (bytes != null) {
            final params = const StandardMessageCodec().decodeMessage(
              ByteData.sublistView(bytes),
            );
            if (params is Map<Object?, Object?> &&
                params['symbol'] == 'ellipsis') {
              moreChannel = channel;
              moreParams = params;
            }
          }
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in channels) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });

      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: AppInterfaceStyleScope(
            style: preference,
            child: const MaterialApp(home: ComicFollowPage()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final more = find.byKey(const ValueKey('follow-more'));
      final menu = tester.widget<NativeVideoMenu>(more);
      final reminder = menu.options.entries
          .singleWhere((entry) => entry.value == t.followReminders.title)
          .key;
      expect(menu.options, contains(collectionCoverSettingsAction));
      expect(menu.optionIcons[reminder]!.icon, Icons.notifications_outlined);
      expect(find.byType(CollectionCoverPrivacyButton), findsOneWidget);
      expect(find.byTooltip(t.followReminders.title), findsNothing);

      if (style == 'system') {
        final params = moreParams!;
        expect(params['tooltip'], t.common.more);
        expect(
          params['selectAfterDismissal'],
          containsAll([collectionCoverSettingsAction, reminder]),
        );
        expect(
          params['options'],
          contains(
            equals({
              'value': reminder,
              'title': t.followReminders.title,
              'symbol': 'bell',
            }),
          ),
        );
        await messenger.handlePlatformMessage(
          moreChannel!.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('select', reminder),
          ),
          (_) {},
        );
      } else {
        await tester.tap(more);
        await tester.pumpAndSettle();
        expect(
          find.text(menu.options[collectionCoverSettingsAction]!),
          findsOneWidget,
        );
        await tester.tap(find.text(t.followReminders.title));
        await tester.pump();
        expect(find.byType(AlertDialog), findsNothing);
      }
      await tester.pumpAndSettle();
      expect(find.text(t.followReminders.scope), findsOneWidget);
      await tester.tap(find.text(t.common.done));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(more, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    for (final brightness in Brightness.values) {
      testWidgets(
        'in-app reminder choices persist and badges react: $style $brightness narrow/large',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final controller = ComicFollowReminderController(emit: (_) {});
          final preference = ValueNotifier(style);
          try {
            tester.view.physicalSize = const Size(320, 900);
            tester.view.devicePixelRatio = 1;
            await tester.pumpWidget(
              AppInterfaceStyleScope(
                style: preference,
                child: MaterialApp(
                  theme: ThemeData(brightness: brightness),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(2)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Column(
                      children: [
                        ComicFollowReminderBadge(
                          controller: controller,
                          child: const Text('Unread badge'),
                        ),
                        Builder(
                          builder: (context) => TextButton(
                            onPressed: () => showComicFollowReminderSettings(
                              context,
                              controller: controller,
                            ),
                            child: const Text('Open settings'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(controller.mode.value, ComicFollowReminderMode.badge);
            expect(find.text('Unread badge'), findsOneWidget);
            await tester.tap(find.text('Open settings'));
            await tester.pumpAndSettle();
            expect(find.text(t.followReminders.scope), findsOneWidget);
            await tester.ensureVisible(find.text(t.followReminders.modeSilent));
            await tester.tap(find.text(t.followReminders.modeSilent));
            await tester.pumpAndSettle();
            expect(controller.mode.value, ComicFollowReminderMode.silent);
            expect(find.text('Unread badge'), findsNothing);
            await tester.ensureVisible(find.text(t.followReminders.modeInApp));
            await tester.tap(find.text(t.followReminders.modeInApp));
            await tester.pumpAndSettle();
            expect(controller.mode.value, ComicFollowReminderMode.inApp);
            expect(controller.showsBadge, isTrue);
            expect(find.text(t.followReminders.capability), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.tap(find.text(t.common.done));
            await tester.pumpAndSettle();
            expect(find.text('Unread badge'), findsOneWidget);
            expect(
              (await SharedPreferences.getInstance()).getString(
                ComicFollowReminderController.modeKey,
              ),
              'inApp',
            );
            await tester.pumpWidget(const SizedBox.shrink());
          } finally {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            controller.dispose();
            preference.dispose();
          }
        },
      );
    }
  }
}
