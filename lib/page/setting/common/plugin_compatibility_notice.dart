import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/plugin/plugin_host_compatibility.dart';

/// Keep unresolved automatic-sync notices visible without interrupting playback
/// or prompting from a background operation. Acknowledgment removes only the
/// exact snapshot shown, so a concurrent newer issue is not consumed.
class PluginCompatibilityNotice extends StatelessWidget {
  const PluginCompatibilityNotice({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: PluginHostCompatibilityNotices.instance.issues,
    builder: (context, issues, _) => issues.isEmpty
        ? const SizedBox.shrink()
        : ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(t.plugin.hostCompatibilitySkippedTitle),
            subtitle: Text(
              issues.map((issue) => issue.name).join('、'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showPluginCompatibilityNotices(context),
          ),
  );
}

Future<bool> showPluginCompatibilityNotices(BuildContext context) async {
  final notices = PluginHostCompatibilityNotices.instance;
  final snapshot = notices.issues.value.toList(growable: false);
  if (!context.mounted || snapshot.isEmpty) return false;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(t.plugin.hostCompatibilitySkippedTitle),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.plugin.hostUpgradeRequired),
              const SizedBox(height: 12),
              for (final issue in snapshot)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    '${issue.name}${issue.version.isEmpty ? '' : ' · ${issue.version}'}',
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.common.ok),
        ),
      ],
    ),
  );
  notices.acknowledge(snapshot);
  return true;
}
