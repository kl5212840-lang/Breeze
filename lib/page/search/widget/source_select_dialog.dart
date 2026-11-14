import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/widgets/breeze_switch.dart';

Future<Map<String, bool>?> showSourceSelectDialog(
  BuildContext context, {
  required Map<String, bool> initial,
  required List<({String pluginId, String title})> sourceOptions,
}) {
  final next = Map<String, bool>.from(initial);
  return showDialog<Map<String, bool>>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(t.search.selectSource),
            contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            content: SizedBox(
              width: 320,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: (MediaQuery.sizeOf(context).height * .52).clamp(
                    120.0,
                    440.0,
                  ),
                ),
                child: ListView.separated(
                  key: const ValueKey('search-source-options'),
                  primary: false,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: sourceOptions.length,
                  separatorBuilder: (context, _) => Divider(
                    height: 1,
                    thickness: .5,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  itemBuilder: (context, index) {
                    final source = sourceOptions[index];
                    return BreezeSwitchListTile(
                      SwitchListTile.adaptive(
                        key: ValueKey('search-source.${source.pluginId}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(source.title),
                        value: next[source.pluginId] ?? true,
                        onChanged: (selected) =>
                            setState(() => next[source.pluginId] = selected),
                      ),
                    );
                  },
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(t.common.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(next),
                child: Text(t.common.apply),
              ),
            ],
          );
        },
      );
    },
  );
}
