import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/type/pipe.dart';
import 'package:zephyr/util/text/chinese_convert.dart';
import 'package:zephyr/widgets/app_interface_style.dart';

class MultiChoiceDialogOption {
  const MultiChoiceDialogOption({required this.label, required this.value});

  final String label;
  final String value;
}

Future<Set<String>?> showMultiChoiceListDialog(
  BuildContext context, {
  required String title,
  required List<MultiChoiceDialogOption> options,
  Iterable<String> initialSelected = const <String>[],
  String? cancelText,
  String? confirmText,
  bool useFilledConfirmButton = false,
  double width = 520,
  double height = 420,
}) {
  return showDialog<Set<String>>(
    context: context,
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
  late final selected = Set<String>.from(widget.initialSelected);
  // Keep one controller for the list and scrollbar until the route's exit
  // transition actually unmounts them, rather than until its result completes.
  final scrollController = ScrollController();

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final breeze = !AppInterfaceStyleScope.usesSystem(context);
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: breeze ? colors.surfaceContainerLowest : null,
      surfaceTintColor: breeze ? Colors.transparent : null,
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: widget.height),
        child: SizedBox(
          width: widget.width,
          child: Scrollbar(
            controller: scrollController,
            thumbVisibility: true,
            child: ListView.builder(
              controller: scrollController,
              shrinkWrap: true,
              itemCount: widget.options.length,
              itemBuilder: (context, index) {
                final option = widget.options[index];
                final isSelected = selected.contains(option.value);
                return CheckboxListTile(
                  key: ValueKey(option.value),
                  dense: true,
                  minTileHeight: 44,
                  selected: breeze && isSelected,
                  selectedTileColor: breeze
                      ? colors.surfaceContainerHigh
                      : null,
                  shape: breeze
                      ? RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        )
                      : null,
                  visualDensity: VisualDensity.standard,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: isSelected,
                  title: Text(option.label.let(convertChineseForDisplay)),
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        selected.add(option.value);
                      } else {
                        selected.remove(option.value);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelText ?? t.common.cancel),
        ),
        if (widget.useFilledConfirmButton)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(selected),
            child: Text(widget.confirmText ?? t.common.ok),
          )
        else
          TextButton(
            onPressed: () => Navigator.of(context).pop(selected),
            child: Text(widget.confirmText ?? t.common.ok),
          ),
      ],
    );
  }
}
