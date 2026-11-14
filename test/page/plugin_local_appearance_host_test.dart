import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/plugin_settings/cubit/plugin_settings_cubit.dart';
import 'package:zephyr/page/plugin_settings/widgets/plugin_settings_content.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

class _LocalIconImages extends LocalAppearanceImages {
  int removals = 0;
  @override
  Future<void> load() async {}
  @override
  Future<bool> removeIfUnchanged(String key, String expectedPath) async {
    removals++;
    if (paths.value[key] != expectedPath) return false;
    paths.value = Map.unmodifiable({...paths.value}..remove(key));
    return true;
  }
}

void main() {
  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'settings local icon preview and scoped reset: $style $brightness narrow/large',
        (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          SharedPreferences.setMockInitialValues({});
          const a = '89f5990d-4ce1-44f1-80f2-6da72f765234',
              b = '2c24bf10-d5e9-4f80-a2a9-a3e3fdd95bbb';
          final directory = Directory.systemTemp.createTempSync(
            'breeze_local_icon_host_',
          );
          final image = File('${directory.path}/icon.png')
            ..writeAsBytesSync(
              base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=',
              ),
            );
          final images = _LocalIconImages();
          images.paths.value = {
            LocalAppearanceImages.pluginIconKey(a)!: image.path,
            LocalAppearanceImages.pluginIconKey(b)!: image.path,
          };
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
                    body: PluginSettingsContent(
                      from: a,
                      pluginUuid: a,
                      pluginRuntimeName: a,
                      state: const PluginSettingsState(
                        loading: false,
                        hasLoadedSettings: true,
                      ),
                      debugEnabled: false,
                      debugUrl: '',
                      deleted: false,
                      pluginVersion: '1.0',
                      colorScheme: ColorScheme.fromSeed(
                        seedColor: Colors.blue,
                        brightness: brightness,
                      ),
                      scope: PluginSettingsScope.preferences,
                      showAccount: false,
                      appearanceImages: images,
                      onUpdateDebugConfig:
                          ({
                            required bool enabled,
                            required String url,
                          }) async {},
                      onConfirmDeletePlugin: () async {},
                      onUpdatePlugin: () async {},
                      onOpenLoginPage: () async {},
                      onOpenDetailPage: () async {},
                      onCommitField: (_, _) async {},
                      onRunAction: (_) async {},
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(find.text(t.pluginAppearance.icon), findsOneWidget);
            expect(
              find.byKey(
                ValueKey(
                  'plugin-icon.local:${LocalAppearanceImages.pluginIconKey(a)}:${image.path}',
                ),
              ),
              findsOneWidget,
            );
            Future<void> openRestoreConfirmation() async {
              final restore = find.widgetWithText(
                ListTile,
                t.pluginAppearance.restoreIcon,
              );
              await tester.ensureVisible(restore);
              // ensureVisible updates ScrollPosition; the viewport's new
              // layout/hit-test geometry is applied on the following frame.
              // Tapping before this frame still targets the old offscreen y.
              await tester.pumpAndSettle();
              expect(restore.hitTestable(), findsOneWidget);
              await tester.tap(restore);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 350));
            }

            await openRestoreConfirmation();
            expect(
              find.text(t.pluginAppearance.restoreConfirm),
              findsOneWidget,
            );
            expect(images.removals, 0);
            await tester.tap(find.text(t.common.cancel));
            await tester.pumpAndSettle();
            expect(images.pluginIconPath(a), image.path);
            expect(images.removals, 0);
            await openRestoreConfirmation();
            expect(
              find.text(t.pluginAppearance.restoreConfirm),
              findsOneWidget,
            );
            expect(images.removals, 0);
            await tester.tap(find.text(t.common.remove));
            await tester.pumpAndSettle();
            expect(images.removals, 1);
            expect(images.pluginIconPath(a), isNull);
            expect(images.pluginIconPath(b), image.path);
            expect(find.text(t.pluginAppearance.restoreIcon), findsNothing);
            expect(image.existsSync(), isTrue);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          } finally {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            debugDefaultTargetPlatformOverride = null;
            images.paths.dispose();
            preference.dispose();
            directory.deleteSync(recursive: true);
          }
        },
      );
    }
  }
}
