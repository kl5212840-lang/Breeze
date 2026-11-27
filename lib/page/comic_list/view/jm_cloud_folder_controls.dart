import 'package:zephyr/page/bookshelf/widgets/bookshelf_management_island.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';

/// Selection exists only while the JM account collection is being organized.
class JmCloudSelection extends InheritedWidget {
  const JmCloudSelection({
    super.key,
    required this.active,
    required this.enabled,
    required this.ids,
    required this.toggle,
    required super.child,
  });

  final bool active;
  final bool enabled;
  final Set<String> ids;
  final ValueChanged<String> toggle;

  static JmCloudSelection? maybeOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<JmCloudSelection>();
    return scope?.active == true ? scope : null;
  }

  @override
  bool updateShouldNotify(JmCloudSelection oldWidget) =>
      active != oldWidget.active ||
      enabled != oldWidget.enabled ||
      ids != oldWidget.ids ||
      toggle != oldWidget.toggle;

  Widget row(String id, String title, Widget tile) {
    final selected = ids.contains(id);
    void toggleRow() => toggle(id);
    return Semantics(
      label: title,
      enabled: enabled,
      checked: selected,
      onTap: enabled ? toggleRow : null,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: enabled ? toggleRow : null,
          child: Row(
            children: [
              Expanded(child: IgnorePointer(child: tile)),
              Checkbox(
                value: selected,
                onChanged: enabled ? (_) => toggleRow() : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class JmCloudSelectionBar extends StatelessWidget {
  const JmCloudSelectionBar({
    super.key,
    required this.count,
    required this.busy,
    required this.moving,
    required this.moveLabel,
    required this.onCreate,
    required this.onMove,
    required this.onCancel,
  });

  final int count;
  final bool busy, moving;
  final String moveLabel;
  final VoidCallback onCreate, onMove, onCancel;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: CollectionToolbarMetrics.contentPaddingOf(context),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          TextButton.icon(
            label: Text(t.bookshelf.createFolder),
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: busy ? null : onCreate,
          ),
          TextButton.icon(
            icon: moving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.drive_file_move_outline),
            onPressed: busy || count == 0 ? null : onMove,
            label: Text(moveLabel),
          ),
          TextButton(
            onPressed: busy ? null : onCancel,
            child: Text(t.bookshelf.cancelSelect),
          ),
        ],
      ),
    ),
  );
}

class JmCloudFolderButton extends StatelessWidget {
  const JmCloudFolderButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: t.videoSource.manageFolders,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        alignment: AlignmentDirectional.centerStart,
        minimumSize: Size(0, CollectionToolbarMetrics.actionExtentOf(context)),
        padding: const EdgeInsetsDirectional.only(end: 4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_outlined, size: 18),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          const Icon(Icons.expand_more, size: 16),
        ],
      ),
    ),
  );
}

typedef JmFolderManagerAction =
    Future<void> Function(
      String action,
      String? target,
      void Function(String message, String? openId) feedback,
    );

class JmCloudFolderManager extends StatefulWidget {
  const JmCloudFolderManager({
    super.key,
    required this.options,
    required this.currentId,
    required this.onAction,
  });
  final Map<String, String> Function() options;
  final String Function() currentId;
  final JmFolderManagerAction onAction;
  @override
  State<JmCloudFolderManager> createState() => _JmCloudFolderManagerState();
}

class _JmCloudFolderManagerState extends State<JmCloudFolderManager> {
  static const _contentInset = EdgeInsets.symmetric(horizontal: 16);
  String? _message, _openId;
  String? _pendingAction;
  bool get _busy => _pendingAction != null;

  Future<void> _act(String action, [String? id]) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final island = BookshelfManagementIslandScope.maybeOf(context);
    island?.setBusy(true);
    setState(() {
      _pendingAction = action;
      _message = null;
      _openId = null;
    });
    try {
      await widget.onAction(action, id, (message, openId) {
        if (!mounted) return;
        setState(() {
          _message = message;
          _openId = openId;
        });
      });
    } finally {
      if (mounted) {
        island?.setBusy(false);
        setState(() => _pendingAction = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.options();
    final selectedId = widget.currentId();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final rows = options.entries.toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.videoSource.manageFolders,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: t.sourceProfile.jmRefreshFolders,
                onPressed: _busy ? null : () => _act('refresh'),
                icon: _pendingAction == 'refresh'
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: t.common.close,
                onPressed: _busy ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Flexible(
          child: CustomScrollView(
            primary: false,
            shrinkWrap: true,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: _contentInset.add(const EdgeInsets.only(bottom: 4)),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.create_new_folder_outlined),
                          label: Text(t.bookshelf.createFolder),
                          onPressed: _busy ? null : () => _act('create'),
                        ),
                      ),
                      if (_message case final message?)
                        Row(
                          children: [
                            Expanded(
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  message,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ),
                            if (_openId != null)
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, _openId),
                                child: Text(t.videoLibrary.viewFolder),
                              ),
                          ],
                        ),
                      if (rows.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(t.comicList.noMatchingOptions),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                sliver: SliverList.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final selected = row.key == selectedId;
                    final isDefault = row.key.isEmpty || row.key == '0';
                    return ListTile(
                      key: ValueKey('jm-folder.open.${row.key}'),
                      contentPadding: const EdgeInsetsDirectional.only(
                        start: 8,
                        end: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      selected: selected,
                      selectedTileColor: colors.secondaryContainer,
                      selectedColor: colors.onSecondaryContainer,
                      enabled: !_busy,
                      leading: const Icon(Icons.folder_outlined, size: 20),
                      minLeadingWidth: 20,
                      horizontalTitleGap: 12,
                      title: Text(
                        row.value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.pop(context, row.key),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected) const Icon(Icons.check, size: 18),
                          if (isDefault)
                            SizedBox(
                              width: CollectionToolbarMetrics.actionExtentOf(
                                context,
                              ),
                            )
                          else
                            PopupMenuButton<String>(
                              key: ValueKey('jm-folder.edit.${row.key}'),
                              enabled: !_busy,
                              tooltip: '${t.bookshelf.manage} · ${row.value}',
                              icon: const Icon(Icons.more_horiz),
                              onSelected: (action) => _act(action, row.key),
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'rename',
                                  child: Text(t.bookshelf.renameFolder),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    t.videoLibrary.deleteFolder,
                                    style: TextStyle(color: colors.error),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
