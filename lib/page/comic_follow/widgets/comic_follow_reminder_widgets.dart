import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';
import 'package:zephyr/service/comic_follow/comic_follow_reminders.dart';

/// Badge visibility is an attention preference, independent of real list data.
/// Unknown preferences stay hidden until loaded, avoiding a silent-mode flash.
class ComicFollowReminderBadge extends StatefulWidget {
  const ComicFollowReminderBadge({
    super.key,
    required this.child,
    this.controller,
  });
  final Widget child;
  final ComicFollowReminderController? controller;
  @override
  State<ComicFollowReminderBadge> createState() =>
      _ComicFollowReminderBadgeState();
}

class _ComicFollowReminderBadgeState extends State<ComicFollowReminderBadge> {
  ComicFollowReminderController get _controller =>
      widget.controller ?? ComicFollowReminderController.instance;
  @override
  void initState() {
    super.initState();
    _controller.load().catchError((Object _) {});
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<ComicFollowReminderMode?>(
        valueListenable: _controller.mode,
        builder: (_, mode, _) =>
            mode == null || mode == ComicFollowReminderMode.silent
            ? const SizedBox.shrink()
            : widget.child,
      );
}

Future<void> showComicFollowReminderSettings(
  BuildContext context, {
  ComicFollowReminderController? controller,
}) => showDialog<void>(
  context: context,
  builder: (_) => _ComicFollowReminderSettings(
    controller: controller ?? ComicFollowReminderController.instance,
  ),
);

class _ComicFollowReminderSettings extends StatefulWidget {
  const _ComicFollowReminderSettings({required this.controller});
  final ComicFollowReminderController controller;
  @override
  State<_ComicFollowReminderSettings> createState() =>
      _ComicFollowReminderSettingsState();
}

class _ComicFollowReminderSettingsState
    extends State<_ComicFollowReminderSettings> {
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await widget.controller.load();
      if (mounted) setState(() => _error = null);
    } catch (_) {
      if (mounted) setState(() => _error = t.followReminders.loadFailed);
    }
  }

  Future<void> _select(ComicFollowReminderMode value) async {
    if (_busy || value == widget.controller.mode.value) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.controller.setMode(value);
    } catch (_) {
      if (mounted) setState(() => _error = t.followReminders.saveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _label(ComicFollowReminderMode value) => switch (value) {
    ComicFollowReminderMode.silent => t.followReminders.modeSilent,
    ComicFollowReminderMode.badge => t.followReminders.modeBadge,
    ComicFollowReminderMode.inApp => t.followReminders.modeInApp,
  };
  String _hint(ComicFollowReminderMode value) => switch (value) {
    ComicFollowReminderMode.silent => t.followReminders.silentHint,
    ComicFollowReminderMode.badge => t.followReminders.badgeHint,
    ComicFollowReminderMode.inApp => t.followReminders.inAppHint,
  };
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(t.followReminders.title),
    content: ValueListenableBuilder<ComicFollowReminderMode?>(
      valueListenable: widget.controller.mode,
      builder: (context, selected, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.followReminders.scope),
          const SizedBox(height: 8),
          for (final value in ComicFollowReminderMode.values)
            Semantics(
              checked: selected == value,
              inMutuallyExclusiveGroup: true,
              child: TouchHoverIntent(
                identity: ('follow-reminder', value),
                builder: (context, hover) => ListTile(
                  hoverColor: hover.hoverColor(),
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: 44,
                  leading: Icon(
                    selected == value
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected == value
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(_label(value)),
                  subtitle: Text(_hint(value)),
                  enabled: !_busy && selected != null,
                  onTap: () => _select(value),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            t.followReminders.capability,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            if (selected == null)
              TextButton(onPressed: _load, child: Text(t.common.retry)),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(t.common.done),
      ),
    ],
  );
}
