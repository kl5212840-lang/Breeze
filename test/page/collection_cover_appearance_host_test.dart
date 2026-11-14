import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'dart:io';

import 'package:zephyr/page/video/native_video_controls.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/page/setting/global/appearance_setting_page.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';
import '../ui_preview_helper.dart';

// This host fixture replaces only disk loading; persistence has dedicated tests.
class _LoadedAppearanceImages extends LocalAppearanceImages {
  int removals = 0;
  bool failRemoval = false;
  @override
  Future<bool> selectCollectionCover(String key, String expectedPath) async {
    if (collectionCovers[key] != expectedPath) return false;
    paths.value = Map.unmodifiable({
      ...paths.value,
      'collection-cover': expectedPath,
    });
    return true;
  }

  @override
  Future<void> load() async {}
  @override
  Future<bool> removeCollectionCover(String key, String expectedPath) async {
    removals++;
    if (failRemoval) throw const FileSystemException('fixture write failure');
    if (collectionCovers[key] != expectedPath) return false;
    final next = {...paths.value}..remove(key);
    if (next['collection-cover'] == expectedPath) {
      next.remove('collection-cover');
      final remaining = next.entries.where(
        (entry) => entry.key.startsWith('collection-cover:'),
      );
      if (remaining.isNotEmpty)
        next['collection-cover'] = remaining.first.value;
    }
    paths.value = Map.unmodifiable(next);
    return true;
  }
}

// Flutter checks foundation variables before package:test tearDown runs.
// Restore the override inside the test callback, including assertion failures.
void _iosHostTest(
  String description,
  Future<void> Function(WidgetTester) body,
) {
  testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

// Engine codecs, file I/O and isolate replies need the real event loop. Fake
// pumpAndSettle advances virtual frames and can starve these completions while
// an intentional loading indicator is animating.
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() ready,
  String reason,
) async {
  final elapsed = Stopwatch()..start();
  while (!ready() && elapsed.elapsed < const Duration(seconds: 5)) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await tester.pump();
  expect(ready(), isTrue, reason: reason);
  await tester.pumpAndSettle();
}

// The real shared menu supplies these callbacks to UIKit and the Breeze route.
// Invoke its command boundary because this fixture has no native menu renderer.
Future<void> _menuCommand(
  WidgetTester tester,
  String key,
  String command,
) async {
  final target = find.byKey(ValueKey('cover-privacy.menu:$key'));
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      100,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.right,
      ),
    );
  }
  await tester.ensureVisible(target);
  tester.widget<NativeVideoMenu>(target).onSelected(command);
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadUiPreviewFonts);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final nativeChannels = <MethodChannel>[];
  setUp(() {
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
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final channel in nativeChannels) {
      messenger.setMockMethodCallHandler(channel, null);
    }
    nativeChannels.clear();
  });
  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      _iosHostTest(
        'appearance section keeps readable controls: $style $brightness',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final images = _LoadedAppearanceImages();
          final controller = CollectionCoverPrivacyController.forTesting();
          final previous = controller.state.value;
          controller.state.value = const CollectionCoverPrivacySettings(
            ready: true,
          );
          final preference = ValueNotifier(style);
          addTearDown(() {
            controller.state.value = previous;
            controller.state.dispose();
            controller.localImagePath.dispose();
            preference.dispose();
            images.paths.dispose();
          });
          tester.view.physicalSize = const Size(400, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
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
                home: SettingPageShell(
                  grouped: true,
                  title: t.settings.appearance,
                  child: ListView(
                    children: [
                      CollectionCoverAppearanceSettings(
                        imageStore: images,
                        privacyController: controller,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text(t.coverPrivacy.title), findsOneWidget);
          expect(find.text(t.coverPrivacy.customEmpty), findsNothing);
          final choice = tester.widget<SettingChoiceTile<CollectionCoverStyle>>(
            find.byType(SettingChoiceTile<CollectionCoverStyle>),
          );
          expect(choice.items.keys, CollectionCoverStyle.values);
          expect(choice.value, CollectionCoverStyle.blur);
          final tile = find.ancestor(
            of: find.text(t.coverPrivacy.enable),
            matching: find.byType(SwitchListTile),
          );
          expect(tester.getSize(tile).height, greaterThanOrEqualTo(44));
          final title = tester.getRect(find.text(t.coverPrivacy.enable));
          final bounds = tester.getRect(tile);
          expect(title.top - bounds.top, greaterThan(0));
          expect(bounds.bottom - title.bottom, greaterThan(0));
          await tester.ensureVisible(find.text(t.coverPrivacy.localOnly));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          controller.state.value = controller.state.value.copyWith(
            style: CollectionCoverStyle.custom,
          );
          await tester.pumpAndSettle();
          expect(
            find.text(
              '${t.coverPrivacy.localOnly}\n${t.coverPrivacy.customEmpty}',
            ),
            findsOneWidget,
          );
          expect(controller.state.value.enabled, isFalse);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      _iosHostTest(
        'compact gallery previews on request and confirms removal: $style $brightness',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final directory = Directory.systemTemp.createTempSync(
            'breeze_cover_preview_',
          );
          final source = File('${directory.path}/selected.png');
          source.writeAsBytesSync(
            img.encodePng(
              img.fill(img.Image(
                width: brightness == Brightness.light ? 600 : 90,
                height: brightness == Brightness.light ? 90 : 600,
              ), color: img.ColorRgb8(230, 20, 35)),
            ),
          );
          final images = _LoadedAppearanceImages();
          images.paths.value = {
            'collection-cover': source.path,
            'collection-cover:${'a' * 64}': source.path,
          };
          final controller = CollectionCoverPrivacyController.forTesting();
          final previous = controller.state.value;
          final enabled = style == 'system';
          controller.state.value = CollectionCoverPrivacySettings(
            ready: true,
            enabled: enabled,
            style: CollectionCoverStyle.custom,
          );
          final preference = ValueNotifier(style);
          addTearDown(() {
            controller.state.value = previous;
            controller.state.dispose();
            controller.localImagePath.dispose();
            images.paths.dispose();
            preference.dispose();
            directory.deleteSync(recursive: true);
          });
          tester.view.physicalSize = const Size(320, 760);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            AppInterfaceStyleScope(
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
                  ).copyWith(textScaler: TextScaler.linear(2)),
                  child: child!,
                ),
                home: RepaintBoundary(
                  key: const ValueKey('cover-privacy.preview'),
                  child: SettingPageShell(
                    grouped: true,
                    title: t.settings.appearance,
                    child: ListView(
                      children: [
                        CollectionCoverAppearanceSettings(
                          imageStore: images,
                          privacyController: controller,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final imageKey = 'collection-cover:${'a' * 64}';
          final thumbnail = find.byKey(
            ValueKey('cover-privacy.gallery:$imageKey'),
          );
          final menu = find.byKey(ValueKey('cover-privacy.menu:$imageKey'));
          await tester.ensureVisible(thumbnail);
          await tester.pumpAndSettle();
          final raw = find.descendant(of: thumbnail, matching: find.byType(RawImage));
          expect(raw, findsOneWidget);
          await _pumpUntil(tester, () => tester.widget<RawImage>(raw).image != null,
            'gallery decodes the actual source PNG');
          final decoded = tester.widget<RawImage>(raw).image!;
          final originalRatio = brightness == Brightness.light ? 600 / 90 : 90 / 600;
          expect(decoded.width / decoded.height, closeTo(originalRatio, .3));
          // Measure the actual red pixels painted in the gallery, not just fit.
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('cover-privacy.preview')));
          final thumbRect = tester.getRect(thumbnail).shift(-tester.getTopLeft(
            find.byKey(const ValueKey('cover-privacy.preview'))));
          await tester.runAsync(() async {
          final painted = await boundary.toImage(pixelRatio: 1);
          final data = (await painted.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          var minX = painted.width, minY = painted.height, maxX = -1, maxY = -1;
          for (var y = thumbRect.top.ceil(); y < thumbRect.bottom.floor(); y++) {
            for (var x = thumbRect.left.ceil(); x < thumbRect.right.floor(); x++) {
              final offset = (y * painted.width + x) * 4;
              if (data.getUint8(offset) > 200 && data.getUint8(offset + 1) < 60 && data.getUint8(offset + 2) < 80) {
                if (x < minX) minX = x; if (x > maxX) maxX = x;
                if (y < minY) minY = y; if (y > maxY) maxY = y;
              }
            }
          }
          painted.dispose();
          expect(maxX, greaterThan(minX)); expect(maxY, greaterThan(minY));
          expect((maxX - minX + 1) / (maxY - minY + 1), closeTo(originalRatio, originalRatio * .15));
          });
          expect(find.text(t.coverPrivacy.currentImage), findsNothing);
          expect(
            find.byKey(ValueKey('cover-privacy.preview-image:${source.path}')),
            findsNothing,
          );
          expect(find.text(t.coverPrivacy.replaceImage), findsNothing);
          expect(find.text(t.coverPrivacy.removeImage), findsNothing);
          expect(tester.getSize(menu).width, greaterThanOrEqualTo(44));
          expect(tester.getSize(menu).height, greaterThanOrEqualTo(44));
          expect(
            tester.getRect(menu).overlaps(tester.getRect(thumbnail)),
            isFalse,
          );
          await _menuCommand(tester, imageKey, 'preview');
          final preview = find.byKey(
            ValueKey('cover-privacy.preview-image:${source.path}'),
          );
          expect(tester.widget<Image>(preview).fit, BoxFit.contain);
          expect(tester.getSize(preview).width, lessThanOrEqualTo(320));
          expect(images.paths.value['collection-cover'], source.path);
          expect(controller.state.value.enabled, enabled);
          await tester.tap(find.text(t.common.close));
          await tester.pumpAndSettle();
          expect(preview, findsNothing);
          expect(tester.takeException(), isNull);
          await writeUiPreview(
            tester,
            const ValueKey('cover-privacy.preview'),
            'settings-cover-gallery-$style-${brightness.name}',
          );
          await _menuCommand(tester, imageKey, 'remove');
          expect(find.text(t.coverPrivacy.removeImageConfirm), findsOneWidget);
          expect(images.removals, 0);
          await tester.tap(find.text(t.common.cancel));
          await tester.pumpAndSettle();
          expect(images.removals, 0);
          expect(images.paths.value['collection-cover'], source.path);
          expect(controller.state.value.style, CollectionCoverStyle.custom);
          images.failRemoval =
              style == 'breeze' && brightness == Brightness.dark;
          await _menuCommand(tester, imageKey, 'remove');
          await tester.tap(find.text(t.common.remove));
          await _pumpUntil(
            tester,
            () =>
                images.removals == 1 &&
                find.byType(CircularProgressIndicator).evaluate().isEmpty,
            'confirmed removal and style persistence release the host',
          );
          expect(images.removals, 1);
          if (images.failRemoval) {
            expect(images.paths.value['collection-cover'], source.path);
            expect(controller.state.value.style, CollectionCoverStyle.custom);
            expect(
              find.byKey(ValueKey('cover-privacy.gallery:$imageKey')),
              findsOneWidget,
            );
          } else {
            expect(images.paths.value, isEmpty);
            expect(controller.state.value.style, CollectionCoverStyle.blur);
            expect(find.text(t.coverPrivacy.currentImage), findsNothing);
          }
          expect(controller.state.value.enabled, enabled);
          expect(source.existsSync(), isTrue);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  for (final style in ['system', 'breeze']) {
    for (final brightness in Brightness.values) {
      _iosHostTest(
        'seven image gallery switches and binds confirmations: $style $brightness',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final directory = Directory.systemTemp.createTempSync(
            'breeze_cover_gallery_',
          );
          final covers = <String, String>{};
          for (var index = 1; index <= 7; index++) {
            final file = File('${directory.path}/$index.png');
            file.writeAsBytesSync(
              img.encodePng(img.Image(width: 20, height: 30)),
            );
            covers['collection-cover:${index.toRadixString(16).padLeft(64, '0')}'] =
                file.path;
          }
          final images = _LoadedAppearanceImages();
          images.paths.value = {
            ...covers,
            'collection-cover': covers.values.first,
          };
          final controller = CollectionCoverPrivacyController.forTesting();
          controller.state.value = const CollectionCoverPrivacySettings(
            ready: true,
            enabled: true,
            style: CollectionCoverStyle.custom,
          );
          final preference = ValueNotifier(style);
          addTearDown(() {
            controller.state.dispose();
            controller.localImagePath.dispose();
            images.paths.dispose();
            preference.dispose();
            directory.deleteSync(recursive: true);
          });
          tester.view.physicalSize = const Size(320, 760);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
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
                home: SettingPageShell(
                  grouped: true,
                  title: t.settings.appearance,
                  child: ListView(
                    children: [
                      CollectionCoverAppearanceSettings(
                        imageStore: images,
                        privacyController: controller,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text(t.coverPrivacy.addImage));
          final addTile = tester.widget<ListTile>(
            find.ancestor(
              of: find.text(t.coverPrivacy.addImage),
              matching: find.byType(ListTile),
            ),
          );
          expect(addTile.enabled, isFalse);
          final secondKey = covers.keys.elementAt(1);
          final second = find.byKey(
            ValueKey('cover-privacy.gallery:$secondKey'),
          );
          await tester.ensureVisible(second);
          await tester.pumpAndSettle();
          final secondMenu = find.byKey(
            ValueKey('cover-privacy.menu:$secondKey'),
          );
          expect(
            tester.getRect(second).overlaps(tester.getRect(secondMenu)),
            isFalse,
          );
          expect(tester.getSize(secondMenu).width, greaterThanOrEqualTo(44));
          expect(tester.getSize(secondMenu).height, greaterThanOrEqualTo(44));
          await tester.tap(secondMenu);
          await tester.pump(const Duration(milliseconds: 350));
          expect(images.paths.value['collection-cover'], covers.values.first);
          if (style == 'breeze') {
            expect(find.text(t.coverPrivacy.replaceImage), findsOneWidget);
            expect(find.text(t.common.delete), findsOneWidget);
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
          }
          await _menuCommand(tester, secondKey, 'preview');
          expect(images.paths.value['collection-cover'], covers.values.first);
          expect(controller.state.value.enabled, isTrue);
          await tester.tap(find.text(t.common.close));
          await tester.pumpAndSettle();
          expect(tester.getSize(second).width, greaterThanOrEqualTo(44));
          expect(tester.getSize(second).height, greaterThanOrEqualTo(44));
          await tester.tap(second);
          await tester.pumpAndSettle();
          expect(images.paths.value['collection-cover'], covers[secondKey]);
          expect(
            find.byKey(ValueKey('cover-privacy.selected:$secondKey')),
            findsOneWidget,
          );
          expect(controller.state.value.enabled, isTrue);
          expect(controller.state.value.style, CollectionCoverStyle.custom);
          await _menuCommand(tester, secondKey, 'replace');
          // The host deliberately remains busy while the confirmation is open;
          // its indeterminate progress cannot settle until the dialog completes.
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.text(t.coverPrivacy.replaceImageConfirm), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          await tester.tap(find.text(t.common.cancel));
          await _pumpUntil(
            tester,
            () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
            'cancel releases the gallery host',
          );
          expect(images.collectionCovers.length, 7);
          expect(images.paths.value['collection-cover'], covers[secondKey]);
          await _menuCommand(tester, secondKey, 'remove');
          expect(find.text(t.coverPrivacy.removeImageConfirm), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          // A sync/import may replace the selected artwork while confirmation is
          // open. Confirming the old target must never remove that newer artwork.
          final replacementFile = File('${directory.path}/replacement.png');
          replacementFile.writeAsBytesSync(
            img.encodePng(img.Image(width: 30, height: 20)),
          );
          final replacementKey = secondKey;
          final updated = {...images.paths.value}..remove(secondKey);
          images.paths.value = {
            ...updated,
            replacementKey: replacementFile.path,
            'collection-cover': replacementFile.path,
          };
          await tester.tap(find.text(t.common.remove));
          await _pumpUntil(
            tester,
            () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
            'stale removal releases the host without removing the replacement',
          );
          expect(images.removals, 0);
          expect(images.collectionCovers.length, 7);
          expect(images.paths.value['collection-cover'], replacementFile.path);
          // A stale replacement confirmation must stop before opening the picker.
          await _menuCommand(tester, secondKey, 'replace');
          expect(find.text(t.coverPrivacy.replaceImageConfirm), findsOneWidget);
          images.paths.value = {
            ...images.paths.value,
            secondKey: covers[secondKey]!,
            'collection-cover': covers[secondKey]!,
          };
          await tester.tap(find.text(t.common.confirm));
          await _pumpUntil(
            tester,
            () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
            'stale replacement confirmation never opens a picker or overwrites newer data',
          );
          expect(images.paths.value['collection-cover'], covers[secondKey]);
          expect(images.collectionCovers.length, 7);
          expect(images.removals, 0);
          await _menuCommand(tester, secondKey, 'remove');
          expect(find.text(t.coverPrivacy.removeImageConfirm), findsOneWidget);
          await tester.tap(find.text(t.common.remove));
          await _pumpUntil(
            tester,
            () =>
                images.removals == 1 &&
                find.byType(CircularProgressIndicator).evaluate().isEmpty,
            'confirmed current-image removal releases the gallery host',
          );
          expect(images.collectionCovers.length, 6);
          expect(images.paths.value['collection-cover'], covers.values.first);
          expect(controller.state.value.enabled, isTrue);
          expect(controller.state.value.style, CollectionCoverStyle.custom);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
