import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart' as sdk;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_layout.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_toolbar.dart';
import 'package:zephyr/page/setting/global/appearance_setting_page.dart';
import 'package:zephyr/page/source_shell/source_back_button.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import 'package:zephyr/widgets/collection_cover_settings.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationSupportPath() async => path;
}

class _Routes extends NavigatorObserver {
  Route<dynamic>? latest;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    latest = route;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late PathProviderPlatform previousPaths;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final nativeChannels = <MethodChannel>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    temporary = await Directory.systemTemp.createTemp('cover-settings-host-');
    previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Paths(temporary.path);
    await LocalAppearanceImages.instance.load();
  });
  tearDownAll(() async {
    PathProviderPlatform.instance = previousPaths;
    await temporary.delete(recursive: true);
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final args = call.arguments as Map;
        final channel = MethodChannel('${args['viewType']}.${args['id']}');
        nativeChannels.add(channel);
        messenger.setMockMethodCallHandler(channel, (_) async => null);
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in nativeChannels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    nativeChannels.clear();
  });

  for (final style in ['system', 'breeze']) {
    for (final host in ['source-tab', 'bookshelf-tab', 'standalone', 'auto-route']) {
      testWidgets(
        '$style $host opens the shared cover group and preserves its parent',
        (tester) async {
          final preference = ValueNotifier(style);
          addTearDown(preference.dispose);
          final controller = CollectionCoverPrivacyController.instance;
          final previous = controller.state.value;
          controller.state.value = const CollectionCoverPrivacySettings(
            ready: true,
            enabled: true,
          );
          addTearDown(() => controller.state.value = previous);
          Widget content() => switch (host) {
            'source-tab' => const SourceMoreButton(showCoverSettings: true),
            'bookshelf-tab' => const BookshelfContentToolbar(
              title: 'folder',
              subtitle: '1',
              view: BookshelfContentView.grid,
              privacyAction: CollectionCoverPrivacyButton(),
              onToggleView: null,
              onManage: null,
            ),
            _ => const CollectionCoverSettingsMoreButton(),
          };
          final routes = _Routes();
          final contentPage = Scaffold(
            appBar: host == 'standalone' || host == 'auto-route'
                ? AppBar(actions: [content()])
                : null,
            body: IndexedStack(
              children: [
                Column(
                  children: [
                    const Text('retained records'),
                    if (host == 'source-tab' || host == 'bookshelf-tab') content(),
                  ],
                ),
              ],
            ),
          );
          final router = host == 'auto-route'
              ? RootStackRouter.build(
                  routes: [
                    NamedRouteDef(
                      name: 'ComicFollowRoute',
                      path: '/',
                      initial: true,
                      builder: (_, _) => contentPage,
                    ),
                  ],
                )
              : null;
          if (router != null) addTearDown(router.dispose);
          await tester.pumpWidget(
            AppInterfaceStyleScope(
              style: preference,
              child: router == null
                  ? MaterialApp(navigatorObservers: [routes], home: contentPage)
                  : MaterialApp.router(
                      routerConfig: router.config(
                        navigatorObservers: () => [routes],
                      ),
                  ),
            ),
          );
          await tester.pumpAndSettle();
          final sourcePage = routes.latest! as PageRoute<dynamic>;
          final target = find.byWidgetPredicate(
            (widget) =>
                widget is NativeVideoMenu &&
                widget.options.containsKey(collectionCoverSettingsAction),
          );
          expect(target, findsOneWidget);
          final menu = tester.widget<NativeVideoMenu>(target);
          if (style == 'breeze') {
            await tester.tap(target);
            await tester.pumpAndSettle();
            final popup = routes.latest! as PopupRoute<dynamic>;
            await tester.tap(
              find.text(menu.options[collectionCoverSettingsAction]!),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 32));
            expect(popup.animation!.status, AnimationStatus.reverse);
            expect(routes.latest, same(popup));
            await tester.pump(popup.reverseTransitionDuration);
          } else {
            final view = find.descendant(
              of: target,
              matching: find.byType(UiKitView),
            );
            final control = tester.widget<UiKitView>(view);
            final parameters = control.creationParams! as Map;
            expect(
              parameters['selectAfterDismissal'],
              contains(collectionCoverSettingsAction),
            );
            final renders = <RenderUiKitView>[];
            void visit(RenderObject render) {
              if (render is RenderUiKitView) renders.add(render);
              render.visitChildren(visit);
            }
            visit(tester.element(view).findRenderObject()!);
            final id = renders.single.viewController.id;
            Future<void> send(String method, Object value) =>
                messenger.handlePlatformMessage(
                  '${control.viewType}.$id',
                  const StandardMethodCodec().encodeMethodCall(
                    MethodCall(method, value),
                  ),
                  (_) {},
                );
            await send('menuOpened', {'generation': 1});
            expect(routes.latest, same(sourcePage));
            await send('menuClosed', {'generation': 1});
            await send('select', collectionCoverSettingsAction);
          }
          await tester.pump();
          final destination = routes.latest! as PageRoute<dynamic>;
          expect(destination.settings.name, collectionCoverSettingsRouteName);
          expect(destination.navigator, same(sourcePage.navigator));
          if (router == null) {
            expect(destination, isA<sdk.CupertinoPageRoute<void>>());
          } else {
            expect(sourcePage.settings, isA<AutoRoutePage>());
            expect(sourcePage.canTransitionTo(destination), isTrue);
            await tester.pump(const Duration(milliseconds: 80));
            expect(sourcePage.secondaryAnimation!.value, inExclusiveRange(0, 1));
          }
          await tester.pumpAndSettle();
          await tester.pumpAndSettle();
          expect(
            find.byType(CollectionCoverAppearanceSettings),
            findsOneWidget,
          );
          expect(controller.state.value.enabled, isTrue);
          expect(find.byType(AppearanceSettingPage), findsNothing);
          expect(tester.takeException(), isNull);
          if (style == 'system') {
            // Native views are channel fixtures here; execute the same Back
            // command rather than pretending a Flutter tap reached UIKit.
            tester
                .widget<SourceChromeIconButton>(
                  find.descendant(
                    of: find.byType(SourceBackButton),
                    matching: find.byType(SourceChromeIconButton),
                  ),
                )
                .onPressed
                ?.call();
          } else {
            await tester.tap(find.byType(SourceBackButton));
          }
          await tester.pumpAndSettle();
          expect(find.text('retained records'), findsOneWidget);
          expect(controller.state.value.enabled, isTrue);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          // The actual group performs filesystem reads. Give those operations
          // the real event loop, then drain their fake-zone continuations before
          // starting another host. Do not await its serial queue from runAsync.
          for (var i = 0; i < 3; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump();
          }
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }
}
