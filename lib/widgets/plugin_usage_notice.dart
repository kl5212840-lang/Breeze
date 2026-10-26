import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';

Future<void> showPluginUsageNotice(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const PluginUsageNoticeDialog(),
);

/// The same on-demand notice is available from About and every plugin's settings.
class PluginUsageNoticeDialog extends StatelessWidget {
  const PluginUsageNoticeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final available = math.max(
      0.0,
      media.size.height -
          media.padding.vertical -
          media.viewInsets.vertical -
          48,
    );
    final theme = Theme.of(context);
    final sections = [
      (t.about.disclaimerItem1Title, t.about.disclaimerItem1Content),
      (t.about.disclaimerItem2Title, t.about.disclaimerItem2Content),
      (t.about.disclaimerItem3Title, t.about.disclaimerItem3Content),
      (t.about.disclaimerItem4Title, t.about.disclaimerItem4Content),
      (t.about.disclaimerItem5Title, t.about.disclaimerItem5Content),
      (t.about.disclaimerItem6Title, t.about.disclaimerItem6Content),
      (t.about.disclaimerItem7Title, t.about.disclaimerItem7Content),
      (t.about.disclaimerItem8Title, t.about.disclaimerItem8Content),
      (t.about.disclaimerImportant, t.about.disclaimerImportantContent),
    ];
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 640, maxHeight: available),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t.about.disclaimerTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: t.common.close,
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                key: const ValueKey('plugin-usage-notice-content'),
                shrinkWrap: true,
                padding: const EdgeInsets.all(20),
                children: [
                  for (final (title, content) in sections)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(content, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
