import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:zephyr/i18n/strings.g.dart';
import 'package:zephyr/page/search/cubit/search_cubit.dart';

class JmSearchDateChip extends StatelessWidget {
  const JmSearchDateChip({super.key, this.onCleared, this.inline = false});

  final ValueChanged<SearchStates>? onCleared;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final searchCubit = context.watch<SearchCubit>();
    final search = searchCubit.state;
    final year = int.tryParse('${search.pluginExtern['y']}');
    if (year == null || year < 1 || year > 9999) {
      return const SizedBox.shrink();
    }
    final month = int.tryParse('${search.pluginExtern['m']}');
    final label = month != null && month >= 1 && month <= 12
        ? MaterialLocalizations.of(
            context,
          ).formatMonthYear(DateTime(year, month))
        : t.search.jmSearchYear(year: year);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: inline
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 16),
        child: InputChip(
          label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          deleteButtonTooltipMessage: t.comicList.clearFilters,
          materialTapTargetSize: MaterialTapTargetSize.padded,
          onDeleted: () {
            final current = searchCubit.state;
            final next = current.copyWith(
              pluginExtern: {...current.pluginExtern}
                ..remove('y')
                ..remove('m'),
            );
            searchCubit.update(next);
            onCleared?.call(next);
          },
        ),
      ),
    );
  }
}
