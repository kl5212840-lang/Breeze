import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';
import 'package:zephyr/page/search/method/keyword_search_scope.dart';
import 'package:zephyr/page/search/widget/keyword_scope_menu.dart';

class SourceSearchScopeControl extends StatelessWidget {
  const SourceSearchScopeControl({
    super.key,
    this.onChanged,
    this.compact = false,
    this.aggregate = false,
    this.fitCurrentLabel = false,
  });

  final ValueChanged<KeywordSearchScope>? onChanged;
  final bool compact;
  final bool aggregate;
  final bool fitCurrentLabel;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SearchCubit>().state;
    return KeywordScopeMenu(
      scope: aggregate
          ? keywordSearchScope(state.pluginExtern)
          : sourceKeywordSearchScope(state.from, state.pluginExtern),
      scopes: aggregate
          ? defaultKeywordSearchScopes
          : sourceKeywordSearchScopes(state.from),
      copyTopics: !aggregate && state.from == copyComicSourceId,
      compact: compact,
      fitCurrentLabel: fitCurrentLabel,
      onChanged: (value) {
        final cubit = context.read<SearchCubit>();
        final current = cubit.state;
        if (current.from != state.from ||
            (aggregate
                    ? keywordSearchScope(current.pluginExtern)
                    : sourceKeywordSearchScope(
                        current.from,
                        current.pluginExtern,
                      )) ==
                value) {
          return;
        }
        cubit.update(
          current.copyWith(
            pluginExtern: changeKeywordSearchScope(
              aggregate
                  ? current.pluginExtern
                  : migrateBikaKeywordSearchDraft(
                      current.from,
                      current.pluginExtern,
                    ),
              value,
            ),
          ),
        );
        onChanged?.call(value);
      },
    );
  }
}
