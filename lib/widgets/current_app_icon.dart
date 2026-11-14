import 'package:material_ui/material_ui.dart';
import 'package:zephyr/service/app_icon_controller.dart';

/// Uses the same high-resolution artwork as the selected launcher icon.
/// The launcher applies its own home screen styling independently.
class CurrentAppIcon extends StatefulWidget {
  const CurrentAppIcon({super.key, this.size = 88, this.controller});
  final double size;
  final AppIconController? controller;

  @override
  State<CurrentAppIcon> createState() => _CurrentAppIconState();
}

class _CurrentAppIconState extends State<CurrentAppIcon> {
  AppIconController get controller =>
      widget.controller ?? AppIconController.instance;

  @override
  void initState() {
    super.initState();
    controller.ensureLoaded();
  }

  @override
  void didUpdateWidget(covariant CurrentAppIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) controller.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final bytes = controller.preview;
      final pixels = (widget.size * MediaQuery.devicePixelRatioOf(context))
          .ceil();
      return ClipRRect(
        borderRadius: BorderRadius.circular(widget.size * 24 / 88),
        child: SizedBox.square(
          dimension: widget.size,
          child: bytes != null
              ? Image.memory(
                  bytes,
                  width: widget.size,
                  height: widget.size,
                  cacheWidth: pixels,
                  cacheHeight: pixels,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                )
              : controller.isIOS
              ? const SizedBox.shrink()
              : Image.asset(
                  'asset/image/app-icon.png',
                  fit: BoxFit.contain,
                  cacheWidth: pixels,
                  cacheHeight: pixels,
                  excludeFromSemantics: true,
                ),
        ),
      );
    },
  );
}
