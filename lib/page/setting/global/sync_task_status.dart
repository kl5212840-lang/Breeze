import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/network/sync/sync_task_progress.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';

/// A known image batch may have a fraction. Other phases intentionally retain
/// an indeterminate indicator instead of estimating a round-wide percentage.
class SyncTaskStatusCard extends StatelessWidget {
  const SyncTaskStatusCard({
    super.key,
    required this.task,
    required this.title,
    required this.phase,
    this.foregroundHint,
  });
  final SyncTaskSnapshot? task;
  final String title, phase;
  final String? foregroundHint;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final running = task?.running == true;
      final inset = SettingSection.horizontalInsetOf(context) + 16;
      final style = settingNoteTextStyle(context);
      final hint = foregroundHint == null ? '' : ' · $foregroundHint';
      final text = running ? '$phase$hint' : phase;
      // Measure stable localized samples, rather than the changing task. Starting
      // or finishing a round must not insert a card or move the action buttons.
      final samples = [
        t.settings.syncMergeNote,
        '${t.settings.syncTaskImageProgress(action: t.settings.syncTaskImageUpload, done: 99999, total: 99999, percent: 100)}$hint',
        '${t.settings.syncTaskWaiting}$hint',
        t.settings.syncConnectionFailed,
      ];
      var extent = 0.0;
      for (final sample in samples) {
        final painter =
            TextPainter(
              text: TextSpan(text: sample, style: style),
              textScaler: MediaQuery.textScalerOf(context),
              textDirection: Directionality.of(context),
            )..layout(
              maxWidth: (constraints.maxWidth - inset * 2).clamp(
                1.0,
                double.infinity,
              ),
            );
        if (painter.height > extent) extent = painter.height;
        painter.dispose();
      }
      return Semantics(
        liveRegion: running,
        label: task == null ? null : title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: extent + 4,
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: SettingNote.section(
                  text,
                  key: ValueKey(
                    task == null ? 'sync.direction-note' : 'sync.task-phase',
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: inset),
              child: SizedBox(
                height: 4,
                child: running
                    ? LinearProgressIndicator(
                        key: const ValueKey('sync.task-progress'),
                        value: task!.fraction,
                        semanticsLabel: phase,
                      )
                    : null,
              ),
            ),
          ],
        ),
      );
    },
  );
}
