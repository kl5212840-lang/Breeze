import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/setting/common/setting_ui.dart';
import 'package:zephyr/widgets/interface_symbol.dart';
import 'package:zephyr/page/video/video_playback_preferences.dart';
import 'package:zephyr/widgets/action_feedback.dart';

/// The same persisted choice used by plugin and playback shortcuts.
class InterfaceStyleSetting extends StatefulWidget {
  const InterfaceStyleSetting({super.key});
  @override
  State<InterfaceStyleSetting> createState() => _InterfaceStyleSettingState();
}

class _InterfaceStyleSettingState extends State<InterfaceStyleSetting> {
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    VideoPlaybackPreferences.read().catchError((Object _) {
      if (mounted) setState(() => _error = t.error.loadFailed);
      return const VideoPlaybackPreferences();
    });
  }

  Future<void> _save(String value) async {
    if (_saving || value == VideoPlaybackPreferences.interfaceStyle.value) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await VideoPlaybackPreferences.save('controlsStyle', value);
      if ((await VideoPlaybackPreferences.read()).controlsStyle != value) {
        throw StateError('Interface style preference was not saved');
      }
      if (mounted) showActionFeedback(context, t.common.saved);
    } catch (_) {
      if (mounted) setState(() => _error = t.error.saveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: VideoPlaybackPreferences.interfaceStyle,
    builder: (context, value, _) => SettingChoiceTile<String>(
      key: const ValueKey('settings.interface-style'),
      leading: const InterfaceSymbol(
        symbol: 'square.grid.2x2',
        fallback: Icons.widgets_outlined,
      ),
      title: t.settings.interfaceStyle,
      error: _error,
      enabled: !_saving,
      value: value,
      items: {
        'system': t.videoPlayback.systemControls,
        'breeze': t.videoPlayback.breezeControls,
      },
      onChanged: _save,
    ),
  );
}
