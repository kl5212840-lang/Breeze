import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:zephyr/widgets/task_dialog.dart';
import 'package:zephyr/i18n/strings.g.dart';

Future<int?> showNumberInputDialog({
  required BuildContext context,
  String? title,
  String? hintText,
  int? initialValue,
}) async {
  final text = initialValue?.toString() ?? '';
  final inputController = TextEditingController.fromValue(
    TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: 0, extentOffset: text.length),
    ),
  );
  ModalRoute<int>? route;
  final result = await showDialog<int>(
    context: context,
    builder: (BuildContext innerContext) {
      route = ModalRoute.of<int>(innerContext);
      return TaskDialog(
        title: title ?? t.searchResult.enterPageNumber,
        content: TextField(
          autofocus: true,
          controller: inputController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: hintText ?? t.searchResult.pleaseEnterNumber,
          ),
          onSubmitted: (value) {
            final int? result = int.tryParse(value);
            if (result != null) Navigator.of(innerContext).pop(result);
          },
        ),
        actions: <Widget>[
          TextButton(
            child: Text(t.common.cancel),
            onPressed: () => Navigator.of(innerContext).pop(),
          ),
          TextButton(
            child: Text(t.common.ok),
            onPressed: () {
              final int? result = int.tryParse(inputController.text);
              Navigator.of(innerContext).pop(result);
            },
          ),
        ],
      );
    },
  );
  await route?.completed;
  inputController.dispose();
  return result;
}
