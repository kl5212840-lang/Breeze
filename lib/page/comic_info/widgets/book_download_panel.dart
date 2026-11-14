import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:objectbox/objectbox.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/main.dart';
import 'package:zephyr/object_box/model.dart';
import 'package:zephyr/object_box/objectbox.g.dart';
import 'package:zephyr/page/download/models/unified_comic_download.dart';
import 'package:zephyr/service/download/download_task_progress.dart';
import 'package:zephyr/service/download/download_task_repository.dart';
import 'package:zephyr/service/download/models/download_task_json.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'package:zephyr/page/video/video_interaction.dart'
    show showVideoTaskSheet;
import 'package:zephyr/page/comic_info/widgets/chapter_download_picker.dart';
import 'package:zephyr/page/comic_info/widgets/episode_download_controller.dart';
import 'package:zephyr/page/download/models/download_chapter.dart';

/// Shared explicit catalog entrance; rows retain their single-chapter actions.
class ChapterBatchDownloadButton extends StatefulWidget {
  const ChapterBatchDownloadButton({
    super.key,
    required this.controller,
    required this.chapters,
    required this.title,
  });
  final EpisodeDownloadController controller;
  final List<DownloadChapter> Function() chapters;
  final String title;
  @override
  State<ChapterBatchDownloadButton> createState() =>
      _ChapterBatchDownloadButtonState();
}

class _ChapterBatchDownloadButtonState
    extends State<ChapterBatchDownloadButton> {
  final panel = BookDownloadPanelController();
  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: const ValueKey('comic-info.batch-download'),
    style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
    onPressed: () => panel.selectChapters(
      context,
      controller: widget.controller,
      chapters: widget.chapters(),
      title: widget.title,
    ),
    icon: const Icon(Icons.download_outlined),
    label: Text(t.download.batchChapters),
  );
}

/// One local panel per detail owner. Never switches main tabs or pops parents.
class BookDownloadPanelController {
  bool _open = false;
  Future<void> selectChapters(
    BuildContext context, {
    required EpisodeDownloadController controller,
    required List<DownloadChapter> chapters,
    required String title,
  }) async {
    if (_open || !context.mounted || chapters.isEmpty) return;
    final owner = controller.selectionOwner;
    if (!controller.ownsSelection(owner)) return;
    _open = true;
    try {
      await showVideoTaskSheet<bool>(
        context: context,
        useRootNavigator: true,
        builder: (_) => ChapterDownloadPicker(
          controller: controller,
          owner: owner,
          chapters: List.unmodifiable(chapters),
          title: title,
        ),
      );
    } finally {
      _open = false;
    }
  }

  Future<void> open(
    BuildContext context, {
    required String source,
    required String comicId,
    required String title,
    required void Function(UnifiedComicDownload record) onRead,
  }) async {
    if (_open || !context.mounted) return;
    _open = true;
    try {
      final record = await showModalBottomSheet<UnifiedComicDownload>(
        context: context,
        useRootNavigator: false,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .8,
          ),
          child: BookDownloadPanel(
            source: source,
            comicId: comicId,
            title: title,
          ),
        ),
      );
      if (record != null && context.mounted) onRead(record);
    } finally {
      _open = false;
    }
  }
}

class BookDownloadPanel extends StatefulWidget {
  const BookDownloadPanel({
    super.key,
    required this.source,
    required this.comicId,
    required this.title,
  });
  final String source, comicId, title;
  @override
  State<BookDownloadPanel> createState() => _BookDownloadPanelState();
}

class _BookDownloadPanelState extends State<BookDownloadPanel> {
  late final Query<DownloadTask> _tasks = objectbox.downloadTaskBox
      .query(DownloadTask_.comicId.equals(widget.comicId))
      .build();
  late final Query<UnifiedComicDownload> _record = objectbox.unifiedDownloadBox
      .query(
        UnifiedComicDownload_.uniqueKey.equals(
          buildDownloadTaskKey(widget.source, widget.comicId),
        ),
      )
      .build();
  StreamSubscription<List<Type>>? _changes;
  List<DownloadTask> _rows = [];
  UnifiedComicDownload? _saved;
  static const _repository = DownloadTaskRepository();

  @override
  void initState() {
    super.initState();
    _read();
    _changes = objectbox.store.entityChanges.listen((types) {
      if (!mounted ||
          !(types.contains(DownloadTask) ||
              types.contains(UnifiedComicDownload)))
        return;
      setState(_read);
    });
  }

  void _read() {
    _rows = _tasks.find().where((task) {
      final payload = _repository.readPayload(task);
      return payload?.from == widget.source &&
          payload?.comicId == widget.comicId;
    }).toList()..sort((a, b) => b.id.compareTo(a.id));
    final record = _record.findFirst();
    _saved = record?.deleted == false ? record : null;
  }

  @override
  void dispose() {
    final changes = _changes;
    if (changes != null) unawaited(changes.cancel());
    _tasks.close();
    _record.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final saved = _saved;
    final chapters = saved == null
        ? const []
        : resolveDownloadChapters(
            saved,
          ).where((chapter) => chapter.images.isNotEmpty).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.download.bookTasks,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      widget.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              TouchHoverIntent(
                identity: 'book-download.close',
                builder: (context, hover) => IconButton(
                  key: const ValueKey('book-download.close'),
                  style: ButtonStyle(overlayColor: hover.overlayColor(null)),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
        Flexible(
          fit: FlexFit.loose,
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              if (_rows.isEmpty && chapters.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(t.download.noTasks),
                ),
              for (final task in _rows) _taskRow(task),
              if (chapters.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Text(
                    t.download.downloadedChapters,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final chapter in chapters)
                  ListTile(
                    title: Text(
                      chapter.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    leading: const Icon(Icons.menu_book_outlined),
                  ),
                TouchHoverIntent(
                  identity: 'book-download.read',
                  builder: (context, hover) => ListTile(
                    key: const ValueKey('book-download.read'),
                    hoverColor: hover.hoverColor(),
                    leading: const Icon(Icons.menu_book),
                    title: Text(t.download.offlineReading),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      final current = _record.findFirst();
                      if (current != null &&
                          !current.deleted &&
                          resolveDownloadChapters(
                            current,
                          ).any((chapter) => chapter.images.isNotEmpty)) {
                        Navigator.of(context).pop(current);
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _taskRow(DownloadTask task) {
    final payload = _repository.readPayload(task)!;
    final state = switch (payload.phaseCode) {
      'fileRemoved' => t.download.fileRemoved,
      'cancelling' => t.download.statusCancelling,
      _ => switch (payload.stateCode) {
        'completed' => t.download.notificationCompleteTitle,
        'failed' => t.download.notificationFailedTitle,
        'paused' => t.download.paused,
        'cancelled' => t.download.cancelled,
        'running' || 'downloading' => t.download.downloading,
        'queued' => t.download.pending(count: 1),
        _ => t.common.unknown,
      },
    };
    final progress =
        (task.isDownloading ||
                {'running', 'downloading'}.contains(payload.stateCode)) &&
            !{'fileRemoved', 'cancelling'}.contains(payload.phaseCode)
        ? downloadTaskPayloadProgressFraction(payload)
        : null;
    return ListTile(
      key: ValueKey('book-download.task.${task.id}'),
      title: Text(
        payload.chapterRef.title.isEmpty
            ? t.comicInfo.chapterList
            : payload.chapterRef.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(state),
          if (payload.stateCode == 'failed' &&
              payload.lastErrorMessage.isNotEmpty)
            Text(
              payload.lastErrorMessage,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          if (progress != null) ...[
            Text(downloadTaskPayloadProgressMessage(payload)),
            LinearProgressIndicator(value: progress),
          ],
        ],
      ),
    );
  }
}
