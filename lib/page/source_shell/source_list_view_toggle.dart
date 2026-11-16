import 'package:zephyr/widgets/collection_command_icons.dart';
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
    icon: CollectionCommandIcons.grid.icon,
    symbol: CollectionCommandIcons.grid.symbol,
    onPressed: () => onChanged(!detailed),
  );
}
