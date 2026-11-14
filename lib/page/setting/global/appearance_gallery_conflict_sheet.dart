import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/sync/appearance_image_sync.dart';

/// Shown only after all conflict previews have been authenticated. Dismissal
/// returns null; no image decision or mutation is made by opening this sheet.
Future<Set<String>?> showAppearanceGalleryConflictSheet(
  BuildContext context,
  AppearanceGalleryConflict conflict,
) async {
  // Digest/authentication validates bytes, while the UI must also confirm that
  // every candidate can actually be previewed before accepting a deletion.
  for (final bytes in conflict.bytesByDigest.values) {
    if (!context.mounted) return null;
    Object? failure;
    await precacheImage(
      ResizeImage.resizeIfNeeded(168, 168, MemoryImage(bytes)),
      context,
      onError: (error, stack) {
        failure = error;
      },
    );
    if (failure != null) throw AppearanceGalleryPreviewUnavailable(failure!);
  }
  if (!context.mounted) return null;
  return showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _GalleryConflictSheet(conflict: conflict),
  );
}

class _GalleryConflictSheet extends StatefulWidget {
  const _GalleryConflictSheet({required this.conflict});
  final AppearanceGalleryConflict conflict;
  @override
  State<_GalleryConflictSheet> createState() => _GalleryConflictSheetState();
}

class _GalleryConflictSheetState extends State<_GalleryConflictSheet> {
  final _selected = <String>{};
  bool _confirming = false;

  Future<void> _confirmSelection() async {
    if (_confirming) return;
    _confirming = true;
    try {
      final selection = Set<String>.of(_selected);
      final removed = widget.conflict.candidates.length - selection.length;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(t.settings.appearanceGalleryConfirmTitle),
          content: Text(
            t.settings.appearanceGalleryConfirmHint(count: removed),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(t.common.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(t.common.remove),
            ),
          ],
        ),
      );
      if (confirmed == true &&
          mounted &&
          ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop(selection);
      }
    } finally {
      _confirming = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final conflict = widget.conflict;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                t.settings.appearanceGalleryConflictTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                t.settings.appearanceGalleryConflictHint(
                  count: conflict.candidates.length,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: conflict.candidates.length,
                itemBuilder: (context, index) {
                  final record = conflict.candidates[index];
                  final local = conflict.localKeys.contains(record.key);
                  final cloud = conflict.cloudKeys.contains(record.key);
                  final origin = local && cloud
                      ? t.settings.appearanceGalleryBoth
                      : local
                      ? t.settings.appearanceGalleryLocal
                      : t.settings.appearanceGalleryCloud;
                  return CheckboxListTile(
                    key: ValueKey('sync.gallery.${record.key}'),
                    value: _selected.contains(record.key),
                    onChanged:
                        _selected.length >= 7 && !_selected.contains(record.key)
                        ? null
                        : (checked) => setState(() {
                            if (checked == true) {
                              _selected.add(record.key);
                            } else {
                              _selected.remove(record.key);
                            }
                          }),
                    secondary: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        conflict.bytesByDigest[record.digest]!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        cacheWidth: 168,
                        gaplessPlayback: true,
                      ),
                    ),
                    title: Text(origin),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    t.settings.appearanceGallerySelected(
                      count: _selected.length,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    key: const ValueKey('sync.gallery.confirm'),
                    onPressed: _confirmSelection,
                    child: Text(t.settings.appearanceGalleryKeepSelected),
                  ),
                  TextButton(
                    key: const ValueKey('sync.gallery.cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t.common.cancel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
