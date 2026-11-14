import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';

void showSearchHelp(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 24),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.search.tipsTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              _buildTipCard(
                title: t.search.exactSearchTitle,
                example: t.search.exactSearchExample,
                desc: t.search.exactSearchDesc,
                color: Theme.of(ctx).colorScheme.primaryContainer,
                foreground: Theme.of(ctx).colorScheme.onPrimaryContainer,
              ),
              _buildTipCard(
                title: t.search.excludeSearchTitle,
                example: t.search.excludeSearchExample,
                desc: t.search.excludeSearchDesc,
                color: Theme.of(ctx).colorScheme.secondaryContainer,
                foreground: Theme.of(ctx).colorScheme.onSecondaryContainer,
              ),
              _buildTipCard(
                title: t.search.fuzzySearchTitle,
                example: t.search.fuzzySearchExample,
                desc: t.search.fuzzySearchDesc,
                color: Theme.of(ctx).colorScheme.tertiaryContainer,
                foreground: Theme.of(ctx).colorScheme.onTertiaryContainer,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildTipCard({
  required String title,
  required String example,
  required String desc,
  required Color color,
  required Color foreground,
}) {
  return Container(
    margin: EdgeInsets.only(bottom: 12),
    padding: EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
    ),
    child: DefaultTextStyle.merge(
      style: TextStyle(color: foreground),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 6),
          Text(
            example,
            style: TextStyle(
              backgroundColor: foreground.withValues(alpha: .08),
              fontSize: 15,
            ),
          ),
          SizedBox(height: 4),
          Text(desc, style: TextStyle(fontSize: 14)),
        ],
      ),
    ),
  );
}
