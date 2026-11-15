import 'package:material_ui/material_ui.dart';
import 'package:zephyr/config/global/global_setting.dart';

/// 墨水屏整屏刷新。
///
/// 应用侧拿不到厂商的 EPD 刷新接口，只能插一层不透明色块逐帧换色，
/// 逼驱动做一次全屏重绘来清掉上一页的残影。
class EinkRefresh {
  const EinkRefresh._();

  static bool _running = false;

  static Future<bool> run(
    BuildContext context,
    EinkRefreshMode mode, {
    int holdMs = 120,
  }) async {
    if (_running || mode == EinkRefreshMode.none) return false;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return false;

    final stages = mode == EinkRefreshMode.fullFlash
        ? const <Color>[Colors.white, Colors.black, Colors.white]
        : const <Color>[Colors.white];

    _running = true;
    final current = ValueNotifier<Color>(stages.first);
    final entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: ValueListenableBuilder<Color>(
          valueListenable: current,
          builder: (context, color, _) =>
              ColoredBox(color: color, child: const SizedBox.expand()),
        ),
      ),
    );
    overlay.insert(entry);

    try {
      for (final color in stages) {
        if (!context.mounted || ModalRoute.of(context)?.isCurrent == false) {
          return false;
        }
        current.value = color;
        await WidgetsBinding.instance.endOfFrame;
        await Future<void>.delayed(Duration(milliseconds: holdMs));
      }
      return true;
    } finally {
      entry.remove();
      current.dispose();
      _running = false;
    }
  }
}
