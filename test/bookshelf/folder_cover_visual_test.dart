import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_content_layout.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_folder_card.dart';
import 'package:zephyr/page/bookshelf/widgets/bookshelf_folder_visual.dart';
import 'package:zephyr/service/folder_cover_identity.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/widgets/collection_cover_privacy.dart';

Future<void> _decodeArtwork(
  WidgetTester tester,
  BuildContext context,
  Iterable<ImageProvider<Object>> providers,
) async {
  // Call before mounting any file-backed Image: a pending load started in the
  // test's fake-async zone cannot be repaired by precaching that key later.
  // File/codec work is entirely on the real event loop, with a finite deadline.
  Object? failure;
  await tester.runAsync(() async {
    try {
      await Future.wait([
        for (final provider in providers) precacheImage(provider, context),
      ]).timeout(const Duration(seconds: 3));
    } catch (error) {
      failure = error;
    }
  });
  expect(
    failure,
    isNull,
    reason: 'Real file artwork must decode before the card mounts.',
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

RenderImage _artworkLayer(
  WidgetTester tester,
  String cardKey,
  String expectedPath,
) {
  final card = find.byKey(ValueKey(cardKey));
  final image = find.descendant(of: card, matching: find.byType(Image));
  // A global replacement overlay would introduce a second image in this card.
  expect(image, findsOneWidget);
  ImageProvider<Object> provider = tester.widget<Image>(image).image;
  if (provider is ResizeImage) provider = provider.imageProvider;
  expect(
    provider,
    isA<FileImage>().having((value) => value.file.path, 'file', expectedPath),
  );
  final raw = find.descendant(of: card, matching: find.byType(RawImage));
  expect(raw, findsOneWidget);
  final layer = tester.renderObject<RenderImage>(raw);
  // This inspects the image the render pipeline can actually paint, rather
  // than only asserting that an Image widget with the right name was built.
  expect(layer.image, isNotNull);
  expect(layer.image!.width, greaterThan(0));
  expect(layer.image!.height, greaterThan(0));
  expect(layer.attached, isTrue);
  expect(layer.size.width, greaterThan(0));
  expect(layer.size.height, greaterThan(0));
  expect(layer.debugNeedsPaint, isFalse);
  tester.element(raw).visitAncestorElements((ancestor) {
    expect(
      ancestor.widget,
      isNot(isA<ImageFiltered>()),
      reason: 'Folder artwork must not inherit a work-cover privacy filter.',
    );
    return true;
  });
  return layer;
}

void main() {
  for (final brightness in Brightness.values) {
    for (final view in BookshelfContentView.values) {
      testWidgets(
        'folder silhouette and caption remain usable in $brightness/$view with large text',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 700),
                  textScaler: TextScaler.linear(1.6),
                ),
                child: Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: view == BookshelfContentView.grid ? 92 : 280,
                      child: BookshelfFolderCard(
                        title: '文件夹 Folder',
                        view: view,
                        menu: const SizedBox(width: 44, height: 44),
                        onTap: () {},
                        selectionMode: true,
                        isSelected: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(find.byType(BookshelfFolderVisual), findsOneWidget);
          expect(find.byType(ClipPath), findsWidgets);
          expect(find.text('文件夹 Folder'), findsOneWidget);
          final visual = tester.getSize(find.byType(BookshelfFolderVisual));
          expect(
            visual.width / visual.height,
            closeTo(BookshelfContentLayout.coverAspectRatio, .001),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final view in BookshelfContentView.values) {
    testWidgets(
      'comic and video folder artwork stays independent of every privacy style in $view',
      (tester) async {
        final controller = CollectionCoverPrivacyController.instance;
        final images = LocalAppearanceImages.instance.paths;
        final oldSettings = controller.state.value;
        final oldPrivacyPath = controller.localImagePath.value;
        final oldPaths = images.value;
        final root = Directory.systemTemp.createTempSync(
          'folder-cover-visual-',
        );
        File artwork(String name, img.Color color) {
          final image = img.Image(width: 16, height: 24);
          img.fill(image, color: color);
          return File('${root.path}/$name.png')
            ..writeAsBytesSync(Uint8List.fromList(img.encodePng(image)));
        }

        final comic = artwork('comic', img.ColorRgb8(220, 20, 30));
        final video = artwork('video', img.ColorRgb8(20, 190, 40));
        final privacy = artwork('privacy', img.ColorRgb8(10, 20, 230));
        final comicKey = FolderCoverIdentity.comic('same-folder-id');
        final videoKey = FolderCoverIdentity.video('same-folder-id');
        images.value = {comicKey: comic.path, videoKey: video.path};
        controller.state.value = const CollectionCoverPrivacySettings(
          ready: true,
        );
        controller.localImagePath.value = privacy.path;
        addTearDown(() async {
          // Unmount before deleting files and releasing the temporary mapping.
          await tester.pumpWidget(const SizedBox.shrink());
          images.value = oldPaths;
          controller.state.value = oldSettings;
          controller.localImagePath.value = oldPrivacyPath;
          root.deleteSync(recursive: true);
        });

        Widget card(String key, String? imageKey) => SizedBox(
          key: ValueKey(key),
          width: view == BookshelfContentView.grid ? 92 : 280,
          child: BookshelfFolderCard(
            title: '同名文件夹',
            imageKey: imageKey,
            view: view,
            selectionMode: true,
            isSelected: true,
            onTap: () {},
          ),
        );

        final cards = [
          card('comic', comicKey),
          card('video', videoKey),
          card('default', null),
        ];
        const decodeHostKey = ValueKey('folder-cover.decode-host');
        await tester.pumpWidget(
          const MaterialApp(home: SizedBox(key: decodeHostKey)),
        );
        final decodeContext = tester.element(find.byKey(decodeHostKey));
        // Match Image.file's resize provider exactly: this host fixes DPR to 1;
        // grid artwork is 92pt wide and the detailed-list thumbnail is 80pt.
        final artworkWidth = view == BookshelfContentView.grid ? 92 : 80;
        await _decodeArtwork(tester, decodeContext, [
          FileImage(privacy),
          ResizeImage.resizeIfNeeded(artworkWidth, null, FileImage(comic)),
          ResizeImage.resizeIfNeeded(artworkWidth, null, FileImage(video)),
        ]);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(320, 700)),
              child: Scaffold(
                body: Center(
                  // Match both shelves' collection scope and card branches.
                  child: CollectionCoverPrivacyScope(
                    child: view == BookshelfContentView.grid
                        ? Row(mainAxisSize: MainAxisSize.min, children: cards)
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: cards,
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final comicDecoded = _artworkLayer(tester, 'comic', comic.path).image;
        final videoDecoded = _artworkLayer(tester, 'video', video.path).image;
        expect(videoDecoded, isNot(same(comicDecoded)));
        final comicImage = tester.state(
          find
              .descendant(
                of: find.byKey(const ValueKey('comic')),
                matching: find.byType(Image),
              )
              .first,
        );

        for (final style in [
          CollectionCoverStyle.custom,
          ...CollectionCoverStyle.values.where(
            (style) => style != CollectionCoverStyle.custom,
          ),
        ]) {
          controller.state.value = CollectionCoverPrivacySettings(
            ready: true,
            enabled: true,
            style: style,
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200));
          expect(
            _artworkLayer(tester, 'comic', comic.path).image,
            same(comicDecoded),
          );
          expect(
            _artworkLayer(tester, 'video', video.path).image,
            same(videoDecoded),
          );
          expect(find.byIcon(Icons.folder_outlined), findsNWidgets(3));
          expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
          expect(find.text('同名文件夹'), findsNWidgets(3));
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('default')),
              matching: find.byType(Image),
            ),
            findsNothing,
          );
        }
        controller.state.value = controller.state.value.copyWith(
          enabled: false,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          tester.state(
            find
                .descendant(
                  of: find.byKey(const ValueKey('comic')),
                  matching: find.byType(Image),
                )
                .first,
          ),
          same(comicImage),
        );
        expect(
          _artworkLayer(tester, 'comic', comic.path).image,
          same(comicDecoded),
        );
        expect(
          _artworkLayer(tester, 'video', video.path).image,
          same(videoDecoded),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
