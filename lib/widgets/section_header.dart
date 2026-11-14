import 'package:material_ui/material_ui.dart';
import 'package:zephyr/util/context/context_extensions.dart';
import 'package:zephyr/widgets/touch_hover_intent.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle = '',
    this.onTap,
    this.margin = const EdgeInsets.all(5),
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final canNavigate = onTap != null;
    final colors = context.theme.colorScheme;
    final background = colors.secondaryFixed.withValues(alpha: 0.1);
    const radius = BorderRadius.all(Radius.circular(8));
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
          ),
          if (subtitle.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                subtitle,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ),
          if (canNavigate) ...[
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 5),
          ],
        ],
      ),
    );

    return Padding(
      padding: margin,
      child: canNavigate
          ? TouchHoverIntent(
              identity: (title, subtitle),
              builder: (context, hover) => Material(
                color: background,
                borderRadius: radius,
                child: InkWell(
                  borderRadius: radius,
                  onTap: onTap,
                  hoverColor: hover.hoverColor(),
                  highlightColor: colors.primary.withValues(alpha: .10),
                  focusColor: colors.primary.withValues(alpha: .14),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Center(child: content),
                  ),
                ),
              ),
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                color: background,
                borderRadius: radius,
              ),
              child: content,
            ),
    );
  }
}
