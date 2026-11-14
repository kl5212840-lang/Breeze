import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/video/native_video_controls.dart';

/// Short, immediate choices share the source More menu's native presentation
/// and its Flutter fallback. The trigger stays flat in a content toolbar.
class SourceChoiceMenu<T> extends StatelessWidget {
  const SourceChoiceMenu({
    super.key,
    required this.label,
    required this.tooltip,
    required this.value,
    required this.options,
    required this.onChanged,
    this.fitToOptions = false,
    this.notifyOnReselect = false,
    this.selectionIndicator = false,
    this.controller,
    this.maximumWidth = 180,
    this.fillAvailableWidth = false,
    this.optionIcons = const {},
    this.optionDetails = const {},
    this.optionBadges = const {},
    this.optionCopyText = const {},
  });

  final String label, tooltip;
  final T value;
  final Map<T, String> options;
  final Map<T, ({IconData icon, String symbol})> optionIcons;
  final Map<T, String> optionDetails, optionBadges, optionCopyText;
  final ValueChanged<T>? onChanged;

  /// Settings keep the trigger stable while changing between short/long values.
  /// Other content menus retain their current-label sizing by default.
  final bool fitToOptions;

  /// A displayed fallback may differ from the stored setting. In that case,
  /// explicitly selecting it must still commit the value.
  final bool notifyOnReselect;
  final bool selectionIndicator;
  final NativeVideoMenuController? controller;
  final double maximumWidth;
  final bool fillAvailableWidth;

  static double triggerWidth(
    BuildContext context,
    Iterable<String> labels, {
    bool selectionIndicator = false,
    double maximumWidth = 180,
  }) {
    var measured = 0.0;
    for (final text in labels) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: selectionIndicator
              ? Theme.of(context).textTheme.bodyLarge
              : Theme.of(context).textTheme.bodyMedium,
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      if (painter.width > measured) measured = painter.width;
      painter.dispose();
    }
    final extra = selectionIndicator
        ? (21 +
                  MediaQuery.textScalerOf(context).scale(
                    Theme.of(context).textTheme.bodyLarge?.fontSize ?? 16,
                  ))
              .clamp(40.0, double.infinity)
        : 32.0;
    return (measured + extra).clamp(44.0, maximumWidth);
  }

  @override
  Widget build(BuildContext context) {
    final entries = options.entries.toList();
    final preferredWidth = triggerWidth(
      context,
      [label, if (fitToOptions) ...options.values],
      selectionIndicator: selectionIndicator,
      maximumWidth: maximumWidth,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = fillAvailableWidth && constraints.hasBoundedWidth
            ? constraints.maxWidth
            : preferredWidth.clamp(0.0, constraints.maxWidth);
        if (onChanged == null || entries.isEmpty) {
          return SizedBox(
            width: width,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: TextButton(onPressed: null, child: Text(label)),
            ),
          );
        }
        return NativeVideoMenu(
          hostPresentation: true,
          bare: true,
          controller: controller,
          selectionIndicator: selectionIndicator,
          width: width,
          label: label,
          tooltip: tooltip,
          selected: entries
              .indexWhere((entry) => entry.key == value)
              .toString(),
          options: {
            for (var index = 0; index < entries.length; index++)
              index.toString(): entries[index].value,
          },
          optionIcons: {
            for (final entry in optionIcons.entries)
              if (options.containsKey(entry.key))
                entries
                        .indexWhere((option) => option.key == entry.key)
                        .toString():
                    entry.value,
          },
          optionDetails: {
            for (var index = 0; index < entries.length; index++)
              if (optionDetails[entries[index].key] case final text?)
                index.toString(): text,
          },
          optionBadges: {
            for (var index = 0; index < entries.length; index++)
              if (optionBadges[entries[index].key] case final text?)
                index.toString(): text,
          },
          optionCopyText: {
            for (var index = 0; index < entries.length; index++)
              if (optionCopyText[entries[index].key] case final text?)
                index.toString(): text,
          },
          onSelected: (id) {
            final index = int.tryParse(id);
            if (index == null || index < 0 || index >= entries.length) return;
            final picked = entries[index].key;
            if (notifyOnReselect || picked != value) onChanged?.call(picked);
          },
        );
      },
    );
  }
}
