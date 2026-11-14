import 'package:material_ui/material_ui.dart';

/// Flat content actions retain their labels and touch areas at larger text sizes.
class VideoDetailAction extends StatelessWidget {
  const VideoDetailAction({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.caption,
    this.mirrored = false,
    this.busy = false,
    this.buttonKey,
    this.compact = false,
  });
  final IconData icon;
  final String label;
  final String? caption;
  final bool selected, mirrored, busy, compact;
  final Key? buttonKey;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    value: caption,
    selected: selected,
    child: TextButton(
      key: buttonKey,
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
        minimumSize: Size(double.infinity, compact ? 44 : 64),
        padding: EdgeInsets.symmetric(
          horizontal: 4,
          vertical: compact ? 4 : 10,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: compact ? 22 : 26,
            child: busy && !MediaQuery.disableAnimationsOf(context)
                ? const Padding(
                    padding: EdgeInsets.all(3),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Transform.flip(
                    flipX: mirrored,
                    child: Icon(
                      busy ? Icons.hourglass_empty_rounded : icon,
                      size: compact ? 22 : 26,
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(caption ?? label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
