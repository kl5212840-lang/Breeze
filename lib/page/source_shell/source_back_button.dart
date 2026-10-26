import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';

export 'package:zephyr/page/source_shell/source_native_controls.dart'
    show exitSourceToDiscover;

/// Ordinary source navigation. Explicit plugin exit lives in the More menu.
class SourceBackButton extends StatelessWidget {
  const SourceBackButton({super.key, this.onPressed, this.tooltip});
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => SourceChromeIconButton(
    tooltip: tooltip ?? t.common.back,
    icon: Icons.arrow_back,
    symbol: 'chevron.left',
    onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
  );
}
