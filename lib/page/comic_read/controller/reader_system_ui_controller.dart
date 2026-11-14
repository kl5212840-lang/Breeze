import 'dart:async';

import 'package:zephyr/service/reader/reader_system_ui_service.dart';

/// 系统 UI（状态栏/导航栏）显隐控制器。
///
/// 现在仅作为 [ReaderSystemUiService] 的薄壳协调器存在，
/// 所有平台调用与定时器逻辑均已下沉到服务层。
class ReaderSystemUiController {
  ReaderSystemUiController()
    : _owner = ReaderSystemUiService.instance.acquire();

  final _service = ReaderSystemUiService.instance;
  final int _owner;

  void scheduleSync(
    void Function() syncFn, {
    Duration delay = const Duration(milliseconds: 24),
  }) => _service.scheduleSync(_owner, syncFn, delay: delay);

  Future<void> applyVisibility(bool isMenuVisible, {bool force = false}) async {
    await _service.applyVisibility(_owner, isMenuVisible, force: force);
  }

  Future<void> close() => _service.release(_owner);
}
