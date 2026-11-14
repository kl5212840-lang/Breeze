import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/widgets/toast.dart';
import 'package:zephyr/widgets/user_image_editor.dart';

Future<Uint8List?> pickUserImageBytes() async {
  final file = Platform.isIOS || Platform.isAndroid
      ? await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 88,
          requestFullMetadata: false,
        )
      : await openFile(
          acceptedTypeGroups: const [
            XTypeGroup(
              label: 'Images',
              extensions: ['jpg', 'jpeg', 'png', 'webp'],
              uniformTypeIdentifiers: ['public.image'],
            ),
          ],
        );
  if (file == null) return null;
  if (await file.length() > LocalAppearanceImages.maximumInputBytes) {
    throw const FormatException('Image too large');
  }
  return file.readAsBytes();
}

/// Resize in the platform decoder before bringing pixels into the Dart heap.
/// The editor and image-package export only ever receive at most 1600px edges.
Future<Uint8List> prepareUserImageForEditing(Uint8List bytes) async {
  if (bytes.isEmpty || bytes.length > LocalAppearanceImages.maximumInputBytes) {
    throw const FormatException('Invalid image size');
  }
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width <= 0 ||
        descriptor.height <= 0 ||
        descriptor.width * descriptor.height > 24000000) {
      throw const FormatException('Invalid image dimensions');
    }
    final ratio = math.min(
      1.0,
      1600 / math.max(descriptor.width, descriptor.height),
    );
    codec = await descriptor.instantiateCodec(
      targetWidth: math.max(1, (descriptor.width * ratio).round()),
      targetHeight: math.max(1, (descriptor.height * ratio).round()),
    );
    image = (await codec.getNextFrame()).image;
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw const FormatException('Invalid image');
    return await compute(
      prepareLocalAppearanceImage,
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}

/// Nothing is persisted until the bounded, metadata-free preview is confirmed.
/// The optional boundaries allow host tests without opening the OS photo library.
Future<String?> pickLocalAppearanceImage(
  BuildContext context, {
  required String imageKey,
  required String title,
  double aspectRatio = 2 / 3,
  String? notice,
  bool Function()? canCommit,
  Future<Uint8List?> Function()? pickBytes,
  Future<Uint8List> Function(Uint8List)? prepare,
  Future<String> Function(String, Uint8List)? save,
}) async {
  Uint8List preview;
  try {
    final bytes = await (pickBytes ?? pickUserImageBytes)();
    if (bytes == null || !context.mounted) return null;
    if (bytes.isEmpty ||
        bytes.length > LocalAppearanceImages.maximumInputBytes) {
      throw const FormatException('Invalid image size');
    }
    preview = await (prepare ?? prepareUserImageForEditing)(bytes);
  } catch (_) {
    if (context.mounted) showErrorToast(t.coverPrivacy.invalidImage);
    return null;
  }
  if (!context.mounted || canCommit?.call() == false) return null;
  final edited = await showUserImageEditor(
    context,
    bytes: preview,
    title: title,
    aspectRatio: aspectRatio,
    notice: notice ?? t.coverPrivacy.imageLocalOnly,
  );
  if (edited == null || !context.mounted || canCommit?.call() == false) {
    return null;
  }
  try {
    return await (save ?? LocalAppearanceImages.instance.save)(
      imageKey,
      edited,
    );
  } catch (_) {
    if (context.mounted) showErrorToast(t.coverPrivacy.imageSaveFailed);
    return null;
  }
}

/// Shared confirmation for local protection images and profile wallpapers.
/// Dismissing the dialog has exactly the same result as pressing Cancel.
Future<bool> confirmLocalAppearanceImageRemoval(
  BuildContext context, {
  required String title,
  required String description,
}) async {
  var decided = false;
  void finish(BuildContext dialog, bool value) {
    if (decided ||
        !dialog.mounted ||
        ModalRoute.of(dialog)?.isCurrent != true) {
      return;
    }
    decided = true;
    Navigator.pop(dialog, value);
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      scrollable: true,
      title: Text(title),
      content: Text(description),
      actions: [
        TextButton(
          onPressed: () => finish(dialog, false),
          child: Text(t.common.cancel),
        ),
        TextButton(
          onPressed: () => finish(dialog, true),
          child: Text(
            t.common.remove,
            style: TextStyle(color: Theme.of(dialog).colorScheme.error),
          ),
        ),
      ],
    ),
  );
  return confirmed == true && context.mounted;
}
