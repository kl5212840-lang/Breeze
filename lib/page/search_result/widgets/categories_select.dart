import 'package:auto_route/auto_route.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/task_dialog.dart';
import 'package:zephyr/type/pipe.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/util/text/chinese_convert.dart';

Future<Map<String, bool>?> showCategoryDialog(
  BuildContext context,
  Map<String, bool> initialMap,
) {
  final Map<String, bool> tempMap = Map<String, bool>.from(initialMap);

  return showDialog<Map<String, bool>>(
    context: context,
    builder: (BuildContext context) {
      return TaskDialog(
        title: t.search.selectCategory,
        scrollBody: false,
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .6,
              ),
              child: ListView(
                primary: false,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final entry in tempMap.entries)
                    CheckboxListTile(
                      title: Text(entry.key.let(convertChineseForDisplay)),
                      value: entry.value,
                      onChanged: (bool? newValue) {
                        setState(() {
                          tempMap[entry.key] = newValue ?? false;
                        });
                      },
                    ),
                ],
              ),
            );
          },
        ),
        actions: <Widget>[
          TextButton(
            child: Text(t.common.cancel),
            onPressed: () => context.pop(),
          ),
          TextButton(
            child: Text(t.common.ok),
            onPressed: () => context.pop(tempMap),
          ),
        ],
      );
    },
  );
}
