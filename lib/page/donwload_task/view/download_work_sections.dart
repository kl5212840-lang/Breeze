import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/native_video_controls.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';
import 'package:zephyr/widgets/work_list_divider.dart';

enum DownloadWorkPane { saved, active }

class DownloadWorkSectionControl extends StatelessWidget {
  const DownloadWorkSectionControl({
    super.key,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });

  final DownloadWorkPane selected;
  final ValueChanged<DownloadWorkPane> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final chinese = Localizations.localeOf(context).languageCode == 'zh';
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          VideoControlAppearance(
            systemControls: usesNativeSourceChrome(context),
            child: NativeVideoSegmentedControl(
              key: const ValueKey('download-work-pane'),
              options: {
                'saved': chinese ? '已下载' : 'Downloaded',
                'active': chinese ? '下载任务' : 'Tasks',
              },
              selected: selected.name,
              onSelected: (value) =>
                  onSelected(DownloadWorkPane.values.byName(value)),
              enabled: enabled,
            ),
          ),
          const WorkListDivider(),
        ],
      ),
    );
  }
}

class DownloadWorkDetailsButton extends StatelessWidget {
  const DownloadWorkDetailsButton({
    super.key,
    required this.onPressed,
    this.visible = true,
  });

  final VoidCallback onPressed;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final extent = CollectionToolbarMetrics.actionExtentOf(context);
    return Visibility(
      visible: visible,
      maintainAnimation: true,
      maintainState: true,
      maintainSize: true,
      child: Tooltip(
        message: t.download.workDetails,
        excludeFromSemantics: true,
        child: TextButton(
          key: const ValueKey('download-work-details'),
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            minimumSize: Size.square(extent),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: Text(t.common.detail, semanticsLabel: t.download.workDetails),
        ),
      ),
    );
  }
}
