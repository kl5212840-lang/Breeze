import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/util/context/context_extensions.dart';

class ComicDescription extends StatefulWidget {
  const ComicDescription({super.key, required this.description});

  final String description;

  @override
  State<ComicDescription> createState() => _ComicDescriptionState();
}

class _ComicDescriptionState extends State<ComicDescription> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final descriptionStyle = DefaultTextStyle.of(context).style.merge(
      context.theme.textTheme.bodyMedium?.copyWith(
        height: 1.65,
        color: context.textColor.withValues(alpha: 0.9),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final preview = TextPainter(
            text: TextSpan(text: widget.description, style: descriptionStyle),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            locale: Localizations.maybeLocaleOf(context),
            maxLines: 2,
          )..layout(maxWidth: constraints.maxWidth);
          final hasMore = preview.didExceedMaxLines;
          preview.dispose();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.comicInfo.description,
                style: context.theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              SelectableText(
                widget.description,
                style: descriptionStyle,
                maxLines: hasMore && !_expanded ? 2 : null,
              ),
              if (hasMore) ...[
                const SizedBox(height: 2),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 40),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                  label: Text(
                    _expanded
                        ? t.comicInfo.collapse
                        : t.comicInfo.expandFullText,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
