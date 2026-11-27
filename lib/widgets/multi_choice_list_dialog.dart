import 'package:flutter/foundation.dart' show setEquals;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/video/video_interaction.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

class MultiChoiceDialogOption {
  const MultiChoiceDialogOption({
    required this.label,
    required this.value,
    this.enabled = true,
  });

  final String label;
  final String value;
  final bool enabled;
}

Future<Set<String>?> showMultiChoiceListDialog(
  BuildContext context, {
  required String title,
  required List<MultiChoiceDialogOption> options,
  Iterable<String> initialSelected = const <String>[],
  String? cancelText,
  String? confirmText,
  bool useFilledConfirmButton = true,
  double width = 520,
  double height = 420,
}) {
  return showVideoTaskSheet<Set<String>>(
    context: context,
    useRootNavigator: true,
    systemStyle: AppInterfaceStyleScope.usesSystem(context),
    builder: (_) => _MultiChoiceListDialog(
      title: title,
      options: options,
      initialSelected: initialSelected,
      cancelText: cancelText,
      confirmText: confirmText,
      useFilledConfirmButton: useFilledConfirmButton,
      width: width,
      height: height,
    ),
  );
}

class _MultiChoiceListDialog extends StatefulWidget {
  const _MultiChoiceListDialog({
    required this.title,
    required this.options,
    required this.initialSelected,
    required this.cancelText,
    required this.confirmText,
    required this.useFilledConfirmButton,
    required this.width,
    required this.height,
  });
  final String title;
  final List<MultiChoiceDialogOption> options;
  final Iterable<String> initialSelected;
  final String? cancelText, confirmText;
  final bool useFilledConfirmButton;
  final double width, height;

  @override
  State<_MultiChoiceListDialog> createState() => _MultiChoiceListDialogState();
}

class _MultiChoiceListDialogState extends State<_MultiChoiceListDialog> {
  late final _initial = widget.initialSelected.toSet();
  late final _selected = {..._initial};
  // Keep one controller for the list and scrollbar until the route's exit
  // transition actually unmounts them, rather than until its result completes.
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final display = watchChineseDisplayConverter(context);
    final confirm = setEquals(_initial, _selected)
        ? null
        : () => Navigator.of(context).pop({..._selected});
    final confirmation = Text(widget.confirmText ?? t.common.ok);
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.width),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                spacing: 12,
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                  ),
                  if (_selected.isNotEmpty)
                    Flexible(
                      child: Text(
                        t.search.selectedCount(count: _selected.length),
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: widget.height),
                child: Scrollbar(
                  controller: _scrollController,
                  child: ListView.builder(
                    controller: _scrollController,
                    primary: false,
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: widget.options.length,
                    itemBuilder: (context, index) {
                      final option = widget.options[index];
                      return CheckboxListTile(
                        key: ValueKey(option.value),
                        minTileHeight: 48,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        value: _selected.contains(option.value),
                        title: Text(display(option.label)),
                        onChanged: !option.enabled
                            ? null
                            : (checked) => setState(() {
                                if (checked == true) {
                                  _selected.add(option.value);
                                } else {
                                  _selected.remove(option.value);
                                }
                              }),
                      );
                    },
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: OverflowBar(
                spacing: 10,
                overflowSpacing: 6,
                alignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(widget.cancelText ?? t.common.cancel),
                  ),
                  if (widget.useFilledConfirmButton)
                    FilledButton(onPressed: confirm, child: confirmation)
                  else
                    TextButton(onPressed: confirm, child: confirmation),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
