import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/source_return_preferences.dart';
import 'package:zephyr/widgets/fluent_dropdown.dart';
import 'package:zephyr/widgets/toast.dart';

class SourceReturnModeTile extends StatefulWidget {
  const SourceReturnModeTile({super.key});

  @override
  State<SourceReturnModeTile> createState() => _SourceReturnModeTileState();
}

class _SourceReturnModeTileState extends State<SourceReturnModeTile> {
  @override
  void initState() {
    super.initState();
    unawaited(SourceReturnPreferences.load());
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: SourceReturnPreferences.changes,
    builder: (context, mode, _) => ListTile(
      leading: const Icon(Icons.keyboard_return_rounded),
      title: Text(t.sourceShell.returnMode),
      subtitle: Text(t.sourceShell.returnModeDescription),
      trailing: FluentDropdown<SourceReturnMode>(
        value: mode,
        displayValue: mode == SourceReturnMode.byFunction
            ? t.sourceShell.returnByFunction
            : t.sourceShell.returnStepByStep,
        items: {
          SourceReturnMode.byFunction: t.sourceShell.returnByFunction,
          SourceReturnMode.stepByStep: t.sourceShell.returnStepByStep,
        },
        onChanged: (value) async {
          try {
            await SourceReturnPreferences.setMode(value);
          } catch (_) {
            if (context.mounted) {
              showErrorToast(t.sourceShell.returnModeSaveFailed);
            }
          }
        },
      ),
    ),
  );
}
