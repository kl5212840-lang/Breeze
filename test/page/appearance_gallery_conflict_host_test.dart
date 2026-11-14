import 'dart:async';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr/config/global/global_setting.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/network/sync/appearance_image_sync.dart';
import 'package:zephyr/network/sync/sync_archive_context.dart';
import 'package:zephyr/network/sync/sync_task_progress.dart';
import 'package:zephyr/page/comic_follow/cubit/comic_follow_cubit.dart';
import 'package:zephyr/page/setting/global/sync_setting_page.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/widgets/app_interface_style.dart';
import '../test_helper.dart';

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() ready, {
  required String reason,
}) async {
  final deadline = Stopwatch()..start();
  while (!ready() && deadline.elapsed < const Duration(seconds: 3)) {
    // Native image decoding completes outside the widget test's fake clock.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(ready(), isTrue, reason: reason);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TestObjectBoxHelper.setUpTestObjectBox);
  tearDownAll(TestObjectBoxHelper.tearDownTestObjectBox);
  for (final style in ['system', 'breeze']) {
    testWidgets(
      'manual sync conflict supports cancel and explicit selection in real host $style',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final setting = objectbox.userSettingBox.get(1)!;
        setting.globalSetting = GlobalSettingState(
          syncSetting: SyncSettingState(
            syncServiceType: SyncServiceType.webdav,
            syncSettings: true,
            syncPlugins: false,
            webdavSetting: const WebDavSettingState(
              host: 'https://fixture.invalid',
              username: 'synthetic',
              password: 'synthetic',
            ),
          ),
        );
        objectbox.userSettingBox.put(setting);
        final cubit = GlobalSettingCubit();
        await cubit.initBox();
        final follows = ComicFollowCubit();
        final preference = ValueNotifier(style);
        addTearDown(cubit.close);
        addTearDown(follows.close);
        addTearDown(preference.dispose);
        final records = <LocalAppearanceSyncRecord>[];
        final bytes = <String, Uint8List>{};
        for (var i = 0; i < 8; i++) {
          final image = img.Image(width: 2, height: 2)
            ..setPixelRgb(0, 0, i * 30, 0, 0);
          final data = Uint8List.fromList(img.encodeJpg(image));
          final digest = sha256.convert(data).toString();
          records.add(
            LocalAppearanceSyncRecord(
              key: 'collection-cover:$digest',
              digest: digest,
              size: data.length,
              modifiedAt: 1,
              deleted: false,
            ),
          );
          bytes[digest] = data;
        }
        final conflict = AppearanceGalleryConflict(
          candidates: records,
          bytesByDigest: bytes,
          localKeys: records.take(4).map((r) => r.key).toSet(),
          cloudKeys: records.skip(4).map((r) => r.key).toSet(),
        );
        Set<String>? decision;
        var calls = 0;
        var badPreview = false;
        var attemptFinished = Completer<void>();
        final abort = Completer<Set<String>?>();
        final actions = SyncArchiveActions(
          synchronize:
              ({
                required state,
                required direction,
                globalSettingCubit,
                comicFollowCubit,
                resolveGalleryConflict,
              }) async {
                calls++;
                try {
                  final resolving = resolveGalleryConflict!(
                    badPreview
                        ? AppearanceGalleryConflict(
                            candidates: records,
                            bytesByDigest: {
                              ...bytes,
                              records.first.digest: Uint8List.fromList([1, 2]),
                            },
                            localKeys: conflict.localKeys,
                            cloudKeys: conflict.cloudKeys,
                          )
                        : conflict,
                  );
                  decision = await Future.any([resolving, abort.future]);
                  if (decision == null) {
                    throw AppearanceGalleryResolutionCancelled();
                  }
                  return const SyncRunResult(newArchiveSynced: true);
                } finally {
                  if (!attemptFinished.isCompleted) attemptFinished.complete();
                }
              },
        );
        final galleryTitle = find.text(
          t.settings.appearanceGalleryConflictTitle,
        );
        final galleryConfirm = find.byKey(
          const ValueKey('sync.gallery.confirm'),
        );
        final galleryCancel = find.byKey(const ValueKey('sync.gallery.cancel'));
        final confirmation = find.byType(AlertDialog);
        const routeTransition = Duration(milliseconds: 350);

        Future<void> openGallery(Finder sync) async {
          await tester.tap(sync);
          await _pumpUntil(
            tester,
            () => galleryTitle.evaluate().isNotEmpty,
            reason: 'the actual conflict sheet should open after decoding',
          );
          // The task intentionally keeps an indeterminate progress animation
          // running below the sheet. Advance only the sheet transition.
          await tester.pump(routeTransition);
        }

        Future<void> finishAttempt() async {
          await _pumpUntil(
            tester,
            () => attemptFinished.isCompleted && !syncTaskProgress.running,
            reason: 'the sync action and its task must both finish',
          );
          await tester.pumpAndSettle();
        }

        try {
          await tester.pumpWidget(
            MultiBlocProvider(
              providers: [
                BlocProvider.value(value: cubit),
                BlocProvider.value(value: follows),
              ],
              child: AppInterfaceStyleScope(
                style: preference,
                child: MaterialApp(
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(1.8)),
                    child: child!,
                  ),
                  home: SyncSettingPage(archiveActions: actions),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final sync = find.byKey(const ValueKey('sync.upload'));
          await tester.scrollUntilVisible(
            sync,
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await openGallery(sync);
          expect(galleryTitle, findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(tester.widget<FilledButton>(sync).onPressed, isNull);
          expect(
            find.text(t.settings.appearanceGallerySelected(count: 0)),
            findsOneWidget,
          );
          await tester.tap(galleryCancel);
          await finishAttempt();
          expect(galleryTitle, findsNothing);
          expect(decision, isNull);
          expect(calls, 1);
          expect(
            find.text(t.settings.appearanceGalleryCancelled),
            findsOneWidget,
          );

          attemptFinished = Completer<void>();
          await openGallery(sync);
          for (final row in records.take(7)) {
            final tile = find.byKey(ValueKey('sync.gallery.${row.key}'));
            await tester.scrollUntilVisible(
              tile,
              120,
              scrollable: find.byType(Scrollable).last,
            );
            await tester.tap(tile);
            await tester.pump();
          }
          final last = find.byKey(ValueKey('sync.gallery.${records.last.key}'));
          await tester.scrollUntilVisible(
            last,
            120,
            scrollable: find.byType(Scrollable).last,
          );
          expect(tester.widget<CheckboxListTile>(last).onChanged, isNull);
          expect(
            find.text(t.settings.appearanceGallerySelected(count: 7)),
            findsOneWidget,
          );

          Future<void> openConfirmation() async {
            await tester.tap(galleryConfirm);
            await _pumpUntil(
              tester,
              () => confirmation.evaluate().isNotEmpty,
              reason: 'the explicit deletion confirmation must open',
            );
            await tester.pump(routeTransition);
          }

          await openConfirmation();
          expect(
            decision,
            isNull,
            reason: 'choosing a scope must not delete images',
          );
          await tester.tap(
            find.descendant(
              of: confirmation,
              matching: find.text(t.common.cancel),
            ),
          );
          await _pumpUntil(
            tester,
            () => confirmation.evaluate().isEmpty,
            reason: 'cancel should close only the confirmation',
          );
          expect(galleryTitle, findsOneWidget);
          expect(decision, isNull);
          await openConfirmation();
          await tester.tap(
            find.descendant(
              of: confirmation,
              matching: find.text(t.common.remove),
            ),
          );
          await finishAttempt();
          expect(galleryTitle, findsNothing);
          expect(decision, records.take(7).map((r) => r.key).toSet());
          expect(find.byKey(const ValueKey('sync.error')), findsNothing);

          badPreview = true;
          attemptFinished = Completer<void>();
          await tester.ensureVisible(sync);
          await tester.pumpAndSettle();
          await tester.tap(sync);
          await finishAttempt();
          expect(galleryTitle, findsNothing);
          expect(
            find.text(t.settings.appearanceGalleryUnavailable),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);

          // Leave a real sheet pending to exercise the same cleanup path
          // that runs if an assertion interrupts the interaction above.
          badPreview = false;
          attemptFinished = Completer<void>();
          await openGallery(sync);
          expect(syncTaskProgress.running, isTrue);
        } finally {
          // An assertion must not leave a fake task waiting for a sheet choice
          // and keep the process-wide progress animation alive in the next test.
          abort.complete(null);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          expect(syncTaskProgress.running, isFalse);
        }
      },
    );
  }
}
