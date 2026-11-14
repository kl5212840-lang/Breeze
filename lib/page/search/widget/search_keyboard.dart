import 'package:flutter/widgets.dart';

/// An explicit search/open gesture must reopen the IME even when focus stayed
/// on the editor after the platform keyboard was dismissed. Never call this
/// from query listeners, refreshes or ordinary builds.
void requestSearchKeyboard(
  FocusNode node, {
  required bool Function() isCurrent,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!isCurrent() || !node.canRequestFocus) return;
    final context = node.context;
    if (context == null ||
        !context.mounted ||
        ModalRoute.of(context)?.isCurrent == false)
      return;
    EditableTextState? editor = context
        .findAncestorStateOfType<EditableTextState>();
    if (editor != null && !identical(editor.widget.focusNode, node))
      editor = null;
    if (editor == null) {
      void find(Element element) {
        if (editor != null) return;
        if (element is StatefulElement && element.state is EditableTextState) {
          final state = element.state as EditableTextState;
          if (identical(state.widget.focusNode, node)) {
            editor = state;
            return;
          }
        }
        element.visitChildren(find);
      }

      context.visitChildElements(find);
    }
    if (editor != null) {
      if (!editor!.widget.readOnly) editor!.requestKeyboard();
    }
  });
  WidgetsBinding.instance.scheduleFrame();
}
