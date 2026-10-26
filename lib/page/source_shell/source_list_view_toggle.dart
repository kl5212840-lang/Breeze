import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';

class SourceListViewToggle extends StatelessWidget {
  const SourceListViewToggle({
    super.key,
    required this.detailed,
    required this.onChanged,
  });
  final bool detailed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SourceChromeIconButton(
    tooltip: detailed ? t.comicList.switchToGrid : t.comicList.switchToList,
    icon: detailed ? Icons.grid_view_rounded : Icons.view_list_rounded,
    symbol: detailed ? 'square.grid.2x2' : 'list.bullet.rectangle',
    onPressed: () => onChanged(!detailed),
  );
}
