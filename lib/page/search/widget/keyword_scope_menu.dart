import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/video/native_video_controls.dart';

class KeywordScopeMenu extends StatelessWidget {
  const KeywordScopeMenu({
    super.key,
    required this.scope,
    required this.onChanged,
    this.compact = false,
    this.scopes = defaultKeywordSearchScopes,
    this.copyTopics = false,
  });

  final KeywordSearchScope scope;
  final ValueChanged<KeywordSearchScope> onChanged;
  final bool compact;
  final List<KeywordSearchScope> scopes;
  final bool copyTopics;

  static double leadingWidth(BuildContext context) =>
      _width(context, [t.common.all, t.sourceShell.searchScopeTitle]);

  static double _width(BuildContext context, Iterable<String> labels) {
    var width = 0.0;
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: Theme.of(context).textTheme.labelMedium,
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      if (painter.width > width) width = painter.width;
      painter.dispose();
    }
    return (width + 34).clamp(44.0, 104.0);
  }

  @override
  Widget build(BuildContext context) {
    final options = <KeywordSearchScope, String>{
      for (final item in scopes)
        item: switch (item) {
          KeywordSearchScope.title => t.sourceShell.searchScopeTitle,
          KeywordSearchScope.all => t.common.all,
          KeywordSearchScope.author => t.sourceShell.searchScopeAuthor,
          KeywordSearchScope.tags =>
            copyTopics ? t.videoLibrary.genres : t.sourceShell.searchScopeTags,
          KeywordSearchScope.team => t.sourceShell.searchScopeTeam,
        },
    };
    final selected = options.containsKey(scope)
        ? scope
        : options.containsKey(KeywordSearchScope.all)
        ? KeywordSearchScope.all
        : scopes.first;
    final label = options[selected]!;
    // Records and narrow search toolbars must leave room to edit the query.
    final width = compact
        ? _width(context, [label]).clamp(
            44.0,
            (MediaQuery.sizeOf(context).width - 270).clamp(44.0, 80.0),
          )
        : _width(context, options.values);
    return LayoutBuilder(
      builder: (context, constraints) => NativeVideoMenu(
        hostPresentation: true,
        bare: true,
        compactTextChoice: true,
        width: width.clamp(0.0, constraints.maxWidth),
        label: label,
        tooltip: t.comicList.scope,
        selected: selected.name,
        options: {
          for (final option in options.entries) option.key.name: option.value,
        },
        onSelected: (value) {
          final next = parseSourceKeywordSearchScope(value);
          if (next != null && options.containsKey(next) && next != selected) {
            onChanged(next);
          }
        },
      ),
    );
  }
}
