import 'package:material_ui/material_ui.dart';
import 'package:zephyr/widgets/toast.dart';

/// A completed write uses the same readable top notice as plugin actions.
void showActionFeedback(BuildContext context, String message) {
  if (!context.mounted || message.isEmpty) return;
  showSuccessToast(message, context: context);
}
