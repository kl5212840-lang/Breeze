import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/service/local_appearance_images.dart';
import 'package:zephyr/service/folder_cover_service.dart';
import 'package:zephyr/widgets/local_appearance_image_picker.dart';
import 'package:zephyr/widgets/toast.dart';

class FolderCoverMenu extends StatelessWidget {
  const FolderCoverMenu({
    super.key,
    required this.target,
    this.canRun,
    this.onCover = false,
    this.extraOptions = const {},
    this.onCommand,
  });
  final FolderCoverTarget target;
  final bool Function()? canRun;
  final bool onCover;
  final Map<String, String> extraOptions;
  final ValueChanged<String>? onCommand;
  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<Map<String, String>>(
    valueListenable: LocalAppearanceImages.instance.paths,
    builder: (context, paths, _) {
      final hasImage = paths[target.key] != null;
      final revision = LocalAppearanceImages.instance.revisionOf(target.key);
      return VideoControlAppearance(
        systemControls: usesNativeSourceChrome(context),
        child: NativeVideoMenu(
          key: ValueKey('folder-cover.menu:${target.key}'),
          label: '',
          tooltip: '${target.name} · ${t.bookshelf.folderCover.title}',
          selected: '',
          symbol: onCover ? 'breeze.more.on-cover' : 'breeze.more.vertical',
          icon: onCover ? Icons.more_horiz : Icons.more_vert,
          secondary: true,
          overArtwork: onCover,
          bare: true,
          width: 44,
          hostPresentation: true,
          options: {
            for (final entry in extraOptions.entries)
              if (entry.key != 'delete') entry.key: entry.value,
            if (hasImage) 'preview': t.comicInfo.preview,
            'replace': hasImage
                ? t.bookshelf.folderCover.replace
                : t.bookshelf.folderCover.choose,
            if (hasImage) 'restore': t.bookshelf.folderCover.restore,
            if (extraOptions.containsKey('delete'))
              'delete': extraOptions['delete']!,
          },
          optionIcons: const {
            'rename': (icon: Icons.drive_file_rename_outline, symbol: 'pencil'),
            'move': (icon: Icons.drive_file_move_outline, symbol: 'folder'),
            'delete': (icon: Icons.delete_outline, symbol: 'trash'),
            'preview': (icon: Icons.visibility_outlined, symbol: 'eye'),
            'replace': (icon: Icons.image_outlined, symbol: 'photo'),
            'restore': (icon: Icons.restore, symbol: 'arrow.counterclockwise'),
          },
          groups: [
            if (extraOptions.isNotEmpty)
              extraOptions.keys.where((key) => key != 'delete').toList(),
            ['preview', 'replace'],
            ['restore'],
            ['delete'],
          ],
          onSelected: (action) {
            if (canRun?.call() == false) return;
            if (extraOptions.containsKey(action)) {
              onCommand?.call(action);
              return;
            }
            unawaited(
              runFolderCoverAction(
                context,
                target,
                action,
                expectedRevision: revision,
              ),
            );
          },
        ),
      );
    },
  );
}

Map<String, String> folderCoverOptions(FolderCoverTarget target) {
  final hasImage =
      LocalAppearanceImages.instance.paths.value[target.key] != null;
  return {
    if (hasImage) 'preview': t.comicInfo.preview,
    'replace': hasImage
        ? t.bookshelf.folderCover.replace
        : t.bookshelf.folderCover.choose,
    if (hasImage) 'restore': t.bookshelf.folderCover.restore,
  };
}

final _activeFolderCoverTasks = <String>{};

Future<void> runFolderCoverAction(
  BuildContext context,
  FolderCoverTarget target,
  String action, {
  required int expectedRevision,
}) async {
  if (!_activeFolderCoverTasks.add(target.key)) return;
  try {
    await _runFolderCoverAction(
      context,
      target,
      action,
      expectedRevision: expectedRevision,
    );
  } finally {
    _activeFolderCoverTasks.remove(target.key);
  }
}

Future<void> _runFolderCoverAction(
  BuildContext context,
  FolderCoverTarget target,
  String action, {
  required int expectedRevision,
}) async {
  final store = LocalAppearanceImages.instance;
  bool current() =>
      context.mounted &&
      target.isCurrent() &&
      store.revisionOf(target.key) == expectedRevision;
  if (!current()) {
    if (context.mounted) showErrorToast(t.bookshelf.folderCover.expired);
    return;
  }
  final path = store.paths.value[target.key];
  if (action == 'preview' && path != null) {
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(target.name),
        content: SizedBox(
          width: MediaQuery.sizeOf(dialog).width,
          height: MediaQuery.sizeOf(dialog).height * .5,
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                Center(child: Text(t.coverPrivacy.previewUnavailable)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: Text(t.common.close),
          ),
        ],
      ),
    );
  } else if (action == 'replace') {
    await pickLocalAppearanceImage(
      context,
      imageKey: target.key,
      title: t.bookshelf.folderCover.title,
      notice: t.bookshelf.folderCover.portableNotice,
      canCommit: current,
      save: (_, bytes) => target.save(bytes, expectedRevision),
    );
  } else if (action == 'restore' && path != null) {
    final confirmed = await confirmLocalAppearanceImageRemoval(
      context,
      title: t.bookshelf.folderCover.restoreTitle,
      description: t.bookshelf.folderCover.restoreDescription(
        name: target.name,
      ),
    );
    if (!confirmed) return;
    if (!current()) {
      if (context.mounted) showErrorToast(t.bookshelf.folderCover.expired);
      return;
    }
    try {
      if (!await target.restore(expectedRevision) && context.mounted)
        showErrorToast(t.bookshelf.folderCover.expired);
    } catch (_) {
      if (context.mounted) showErrorToast(t.coverPrivacy.imageSaveFailed);
    }
  }
}
