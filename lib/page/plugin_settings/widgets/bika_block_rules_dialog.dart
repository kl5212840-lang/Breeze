import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/source_shell/bika_content_block_rules.dart';
import 'package:zephyr/widgets/task_dialog.dart';

Future<List<String>?> showBikaBlockRulesDialog(
  BuildContext context, {
  required String title,
  required List<String> initial,
}) => showDialog<List<String>>(
  context: context,
  builder: (_) => _BikaBlockRulesDialog(title: title, initial: initial),
);

class _BikaBlockRulesDialog extends StatefulWidget {
  const _BikaBlockRulesDialog({required this.title, required this.initial});

  final String title;
  final List<String> initial;

  @override
  State<_BikaBlockRulesDialog> createState() => _BikaBlockRulesDialogState();
}

class _BikaBlockRulesDialogState extends State<_BikaBlockRulesDialog> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();
  late List<String> _rules = [...widget.initial];

  List<String> get _withPending =>
      bikaContentBlockValues([..._rules, _input.text]);

  void _addRule() {
    final next = _withPending;
    if (next.length == _rules.length) return;
    setState(() {
      _rules = next;
      _input.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  void _close([List<String>? rules]) {
    _inputFocus.unfocus();
    Navigator.of(context).pop(rules);
  }

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final next = _withPending;
    final canAdd = next.length > _rules.length;
    final duplicate = _input.text.trim().isNotEmpty && !canAdd;
    final theme = Theme.of(context);
    return TaskDialog(
      title: widget.title,
      maxHeight: math.min(520, MediaQuery.sizeOf(context).height * .66),
      scrollBody: false,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: 8,
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('bika-block-rule-input'),
                  controller: _input,
                  focusNode: _inputFocus,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: t.searchResult.bikaBlockRuleInput,
                  ),
                  onChanged: (_) => setState(() {}),
                  onEditingComplete: () {},
                  onSubmitted: (_) => _addRule(),
                ),
              ),
              TextButton(
                key: const ValueKey('bika-block-rule-add'),
                onPressed: canAdd ? _addRule : null,
                style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
                child: Text(t.common.add),
              ),
            ],
          ),
          if (duplicate)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                t.searchResult.bikaBlockRuleDuplicate,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          if (_rules.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            Flexible(
              child: TextFieldTapRegion(
                child: Scrollbar(
                  controller: _scroll,
                  thumbVisibility: true,
                  interactive: true,
                  child: ListView.separated(
                    key: const ValueKey('bika-block-rule-list'),
                    controller: _scroll,
                    shrinkWrap: true,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.manual,
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    itemCount: _rules.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant,
                    ),
                    itemBuilder: (context, index) {
                      final rule = _rules[index];
                      return Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                rule,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ),
                          IconButton(
                            key: ValueKey(('bika-block-rule-remove', rule)),
                            tooltip: t.searchResult.bikaRemoveBlockRule(
                              rule: rule,
                            ),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(44, 44),
                              foregroundColor:
                                  theme.colorScheme.onSurfaceVariant,
                            ),
                            iconSize: 18,
                            onPressed: () =>
                                setState(() => _rules.remove(rule)),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: _close, child: Text(t.common.cancel)),
        FilledButton(
          onPressed: listEquals(widget.initial, next)
              ? null
              : () => _close(next),
          child: Text(t.common.save),
        ),
      ],
    );
  }
}
