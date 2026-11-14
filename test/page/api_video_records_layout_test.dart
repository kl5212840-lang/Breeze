import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/page/video/api_video_collection.dart';
import 'package:zephyr/page/video/api_video_favorites.dart';
import 'package:zephyr/page/video/api_video_history.dart';
import 'package:zephyr/page/video/api_video_models.dart';
import 'package:zephyr/page/video/video_library_store.dart';
import 'package:zephyr/page/video/video_watch_history.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final channels = <MethodChannel>[];
  const connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');
  const connectivityChanges = MethodChannel(
    'dev.fluttercommunity.plus/connectivity_status',
  );
  setUp(() {
    messenger.setMockMethodCallHandler(connectivity, (_) async => ['wifi']);
    messenger.setMockMethodCallHandler(connectivityChanges, (_) async => null);
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
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(connectivity, null);
    messenger.setMockMethodCallHandler(connectivityChanges, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in channels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    channels.clear();
  });
  for (final history in [false, true]) {
    for (final styleName in ['system', 'breeze']) {
      for (final brightness in Brightness.values) {
        testWidgets(
          'record layout history=$history $styleName ${brightness.name} keeps search and one privacy slot on small iPhone large text',
          (tester) async {
            final store = VideoLibraryStore(
              deviceId: 'layout',
              storageKey: 'layout',
            );
            addTearDown(store.dispose);
            await tester.runAsync(() async {
              SharedPreferences.setMockInitialValues({});
              await store.importFavorites('layout', [
                ApiVideoItem(
                  id: '1',
                  title: 'A public record with a long title',
                  genres: 'Mystery Genre',
                  detailUrl: Uri.parse('https://module.test/voddetail/1.html'),
                ),
              ]);
              await VideoWatchHistory.record(
                'layout',
                VideoWatchRecord(
                  watchUrl: Uri.parse(
                    'https://module.test/voddetail/1.html?line=1&episode=1',
                  ),
                  title: 'A public record with a long title',
                  metadata: const {'genres': 'Mystery Genre'},
                  position: const Duration(seconds: 30),
                  duration: const Duration(minutes: 10),
                  updatedAt: DateTime.utc(2026),
                  completed: false,
                ),
              );
            });
            tester.view.physicalSize = const Size(320, 740);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final style = ValueNotifier(styleName);
            addTearDown(style.dispose);
            await tester.pumpWidget(
              BlocProvider(
                create: (_) => GlobalSettingCubit(),
                child: AppInterfaceStyleScope(
                  style: style,
                  child: MaterialApp(
                    theme: ThemeData(brightness: brightness),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: const TextScaler.linear(1.8)),
                      child: child!,
                    ),
                    home: Scaffold(
                      body: history
                          ? ApiVideoHistory(
                              source: 'layout',
                              home: Uri.parse('https://module.test'),
                              mode: ApiVideoView.grid,
                              onOpen: (_, _) async {},
                            )
                          : ApiVideoFavorites(
                              source: 'layout',
                              store: store,
                              mode: ApiVideoView.grid,
                              onOpen: (_) async {},
                            ),
                    ),
                  ),
                ),
              ),
            );
            for (var i = 0; i < 8; i++) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 15)),
              );
              await tester.pump(const Duration(milliseconds: 100));
            }
            final search = find.byType(TextField).first;
            final privacy = find.byKey(
              ValueKey(
                history
                    ? 'api-history.cover-privacy'
                    : 'local-favorites.cover-privacy',
              ),
            );
            expect(privacy, findsOneWidget);
            expect(tester.getSize(privacy), const Size(44, 44));
            final input = tester.getRect(search), eye = tester.getRect(privacy);
            final scope = find.byType(KeywordScopeMenu);
            final scopeRect = tester.getRect(scope);
            expect(input.right + 8, closeTo(scopeRect.left, .01));
            expect(scopeRect.right, closeTo(eye.left, .01));
            expect(scopeRect.center.dy, closeTo(eye.center.dy, .01));
            expect(input.center.dy, closeTo(eye.center.dy, .01));
            expect(input.width, greaterThanOrEqualTo(185));
            expect(
              tester.widget<TextField>(search).focusNode?.hasFocus,
              isNot(true),
              reason:
                  'A records view must not summon the keyboard on entry or while hidden',
            );
            if (styleName == 'system') {
              expect(find.byType(UiKitView), findsWidgets);
            } else {
              expect(find.byType(UiKitView), findsNothing);
            }
            NativeVideoMenu menu() => tester.widget<NativeVideoMenu>(
              find.descendant(
                of: scope,
                matching: find.byType(NativeVideoMenu),
              ),
            );
            expect(menu().selected, 'all');
            await tester.enterText(search, 'Mystery Genre');
            await tester.pumpAndSettle();
            expect(
              find.text('A public record with a long title'),
              findsOneWidget,
            );
            menu().onSelected('title');
            await tester.pumpAndSettle();
            expect(
              find.text('A public record with a long title'),
              findsNothing,
            );
            menu().onSelected('all');
            await tester.pumpAndSettle();
            expect(
              find.text('A public record with a long title'),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          },
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        );
      }
    }
  }
}
