import 'package:zephyr/widgets/collection_command_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';

class SourceListViewToggle extends StatelessWidget {
  const SourceListViewToggle({
    super.key,
    required this.detailed,
    required this.onChanged,
    this.bare = true,
  });
  final bool detailed, bare;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SourceChromeIconButton(
    tooltip: detailed ? t.comicList.switchToGrid : t.comicList.switchToList,
    icon: CollectionCommandIcons.toggleTarget(!detailed).icon,
    symbol: CollectionCommandIcons.toggleTarget(!detailed).symbol,
    onPressed: () => onChanged(!detailed),
    bare: bare,
  );
}
