import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/page/video/native_video_controls.dart';

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
    return VideoControlAppearance(
      systemControls: usesNativeSourceChrome(context),
      child: NativeVideoSegmentedControl(
        key: const ValueKey('download-work-pane'),
        options: {
          'saved': chinese ? '已下载' : 'Downloaded',
          'active': chinese ? '正在下载' : 'Downloading',
        },
        selected: selected.name,
        onSelected: (value) =>
            onSelected(DownloadWorkPane.values.byName(value)),
        enabled: enabled,
      ),
    );
  }
}
