import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_cubit.freezed.dart';
part 'search_cubit.g.dart';
part 'search_states.dart';

class SearchCubit extends Cubit<SearchStates> {
  SearchCubit(super.initialState);

  final _queryRevision = ValueNotifier<int>(0);
  ValueListenable<int> get queryRevision => _queryRevision;

  void update(SearchStates states) {
    emit(states);
  }

  void submit(SearchStates states) {
    update(states);
    _queryRevision.value++;
  }

  @override
  Future<void> close() {
    _queryRevision.dispose();
    return super.close();
  }
}
