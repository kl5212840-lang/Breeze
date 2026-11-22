import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_native_controls.dart';
import 'package:zephyr/widgets/collection_toolbar_metrics.dart';

export 'package:zephyr/page/source_shell/source_native_controls.dart'
    show exitSourceToDiscover;

/// Ordinary source navigation. Explicit plugin exit lives in the More menu.
class SourceBackButton extends StatelessWidget {
  const SourceBackButton({
    super.key,
    this.onPressed,
    this.tooltip,
    this.bare = false,
  });
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool bare;

  @override
  Widget build(BuildContext context) => SourceChromeIconButton(
    tooltip: tooltip ?? t.common.back,
    icon: bare ? Icons.arrow_back_ios_new_rounded : Icons.arrow_back,
    symbol: 'chevron.left',
    bare: bare,
    onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
  );
}

AppBar sourceSecondaryAppBar(
  BuildContext context, {
  required String title,
  VoidCallback? onBack,
  bool showBack = true,
  List<Widget> actions = const [],
}) {
  final style =
      AppBarTheme.of(context).titleTextStyle ??
      Theme.of(context).textTheme.titleLarge;
  final scaler = MediaQuery.textScalerOf(context);
  final height =
      (scaler.scale(style?.fontSize ?? 22) * (style?.height ?? 1.3) + 16).clamp(
        56.0,
        double.infinity,
      );
  return AppBar(
    automaticallyImplyLeading: false,
    leadingWidth: CollectionToolbarMetrics.leadingExtentOf(context),
    leading: CollectionToolbarMetrics.leading(
      context,
      showBack
          ? SourceBackButton(bare: true, onPressed: onBack)
          : const SizedBox.shrink(),
    ),
    toolbarHeight: height,
    centerTitle: false,
    titleSpacing: 0,
    title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    actionsPadding: CollectionToolbarMetrics.trailingPadding,
    actions: actions,
  );
}
