// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'comic_follow_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ComicFollowState {

 ComicFollowStatus get status; List<ComicFollow> get items; bool get isCheckingUpdates; Set<String> get checkingKeys; Map<String, ComicFollowCheckFailure> get checkErrors; Map<String, DateTime> get lastAttempts; String get result; int get revision; Map<String, UnifiedComicHistory> get histories; ComicFollowFilter get filter; ComicFollowSort get sort;
/// Create a copy of ComicFollowState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ComicFollowStateCopyWith<ComicFollowState> get copyWith => _$ComicFollowStateCopyWithImpl<ComicFollowState>(this as ComicFollowState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ComicFollowState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ComicFollowState&&(identical(other.status, _this.status) || other.status == _this.status)&&const DeepCollectionEquality().equals(other.items, _this.items)&&(identical(other.isCheckingUpdates, _this.isCheckingUpdates) || other.isCheckingUpdates == _this.isCheckingUpdates)&&const DeepCollectionEquality().equals(other.checkingKeys, _this.checkingKeys)&&const DeepCollectionEquality().equals(other.checkErrors, _this.checkErrors)&&const DeepCollectionEquality().equals(other.lastAttempts, _this.lastAttempts)&&(identical(other.result, _this.result) || other.result == _this.result)&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&const DeepCollectionEquality().equals(other.histories, _this.histories)&&(identical(other.filter, _this.filter) || other.filter == _this.filter)&&(identical(other.sort, _this.sort) || other.sort == _this.sort));
}


@override
int get hashCode {
  final _this = this as ComicFollowState;
  return Object.hash(runtimeType,_this.status,const DeepCollectionEquality().hash(_this.items),_this.isCheckingUpdates,const DeepCollectionEquality().hash(_this.checkingKeys),const DeepCollectionEquality().hash(_this.checkErrors),const DeepCollectionEquality().hash(_this.lastAttempts),_this.result,_this.revision,const DeepCollectionEquality().hash(_this.histories),_this.filter,_this.sort);
}

@override
String toString() {
  final _this = this as ComicFollowState;
  return 'ComicFollowState(status: ${_this.status}, items: ${_this.items}, isCheckingUpdates: ${_this.isCheckingUpdates}, checkingKeys: ${_this.checkingKeys}, checkErrors: ${_this.checkErrors}, lastAttempts: ${_this.lastAttempts}, result: ${_this.result}, revision: ${_this.revision}, histories: ${_this.histories}, filter: ${_this.filter}, sort: ${_this.sort})';
}


}

/// @nodoc
abstract mixin class $ComicFollowStateCopyWith<$Res>  {
  factory $ComicFollowStateCopyWith(ComicFollowState value, $Res Function(ComicFollowState) _then) = _$ComicFollowStateCopyWithImpl;
@useResult
$Res call({
 ComicFollowStatus status, List<ComicFollow> items, bool isCheckingUpdates, Set<String> checkingKeys, Map<String, ComicFollowCheckFailure> checkErrors, Map<String, DateTime> lastAttempts, String result, int revision, Map<String, UnifiedComicHistory> histories, ComicFollowFilter filter, ComicFollowSort sort
});




}
/// @nodoc
class _$ComicFollowStateCopyWithImpl<$Res>
    implements $ComicFollowStateCopyWith<$Res> {
  _$ComicFollowStateCopyWithImpl(this._self, this._then);

  final ComicFollowState _self;
  final $Res Function(ComicFollowState) _then;

/// Create a copy of ComicFollowState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? items = null,Object? isCheckingUpdates = null,Object? checkingKeys = null,Object? checkErrors = null,Object? lastAttempts = null,Object? result = null,Object? revision = null,Object? histories = null,Object? filter = null,Object? sort = null,}) {
  return _then(ComicFollowState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ComicFollowStatus,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<ComicFollow>,isCheckingUpdates: null == isCheckingUpdates ? _self.isCheckingUpdates : isCheckingUpdates // ignore: cast_nullable_to_non_nullable
as bool,checkingKeys: null == checkingKeys ? _self.checkingKeys : checkingKeys // ignore: cast_nullable_to_non_nullable
as Set<String>,checkErrors: null == checkErrors ? _self.checkErrors : checkErrors // ignore: cast_nullable_to_non_nullable
as Map<String, ComicFollowCheckFailure>,lastAttempts: null == lastAttempts ? _self.lastAttempts : lastAttempts // ignore: cast_nullable_to_non_nullable
as Map<String, DateTime>,result: null == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,histories: null == histories ? _self.histories : histories // ignore: cast_nullable_to_non_nullable
as Map<String, UnifiedComicHistory>,filter: null == filter ? _self.filter : filter // ignore: cast_nullable_to_non_nullable
as ComicFollowFilter,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as ComicFollowSort,
  ));
}

}


/// Adds pattern-matching-related methods to [ComicFollowState].
extension ComicFollowStatePatterns on ComicFollowState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ComicFollowState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ComicFollowState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ComicFollowState value)  $default,){
final _that = this;
switch (_that) {
case _ComicFollowState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ComicFollowState value)?  $default,){
final _that = this;
switch (_that) {
case _ComicFollowState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ComicFollowStatus status,  List<ComicFollow> items,  bool isCheckingUpdates,  Set<String> checkingKeys,  Map<String, ComicFollowCheckFailure> checkErrors,  Map<String, DateTime> lastAttempts,  String result,  int revision,  Map<String, UnifiedComicHistory> histories,  ComicFollowFilter filter,  ComicFollowSort sort)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ComicFollowState() when $default != null:
return $default(_that.status,_that.items,_that.isCheckingUpdates,_that.checkingKeys,_that.checkErrors,_that.lastAttempts,_that.result,_that.revision,_that.histories,_that.filter,_that.sort);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ComicFollowStatus status,  List<ComicFollow> items,  bool isCheckingUpdates,  Set<String> checkingKeys,  Map<String, ComicFollowCheckFailure> checkErrors,  Map<String, DateTime> lastAttempts,  String result,  int revision,  Map<String, UnifiedComicHistory> histories,  ComicFollowFilter filter,  ComicFollowSort sort)  $default,) {final _that = this;
switch (_that) {
case _ComicFollowState():
return $default(_that.status,_that.items,_that.isCheckingUpdates,_that.checkingKeys,_that.checkErrors,_that.lastAttempts,_that.result,_that.revision,_that.histories,_that.filter,_that.sort);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ComicFollowStatus status,  List<ComicFollow> items,  bool isCheckingUpdates,  Set<String> checkingKeys,  Map<String, ComicFollowCheckFailure> checkErrors,  Map<String, DateTime> lastAttempts,  String result,  int revision,  Map<String, UnifiedComicHistory> histories,  ComicFollowFilter filter,  ComicFollowSort sort)?  $default,) {final _that = this;
switch (_that) {
case _ComicFollowState() when $default != null:
return $default(_that.status,_that.items,_that.isCheckingUpdates,_that.checkingKeys,_that.checkErrors,_that.lastAttempts,_that.result,_that.revision,_that.histories,_that.filter,_that.sort);case _:
  return null;

}
}

}

/// @nodoc


class _ComicFollowState extends ComicFollowState {
  const _ComicFollowState({this.status = ComicFollowStatus.initial,  List<ComicFollow> items = const <ComicFollow>[], this.isCheckingUpdates = false,  Set<String> checkingKeys = const <String>{},  Map<String, ComicFollowCheckFailure> checkErrors = const <String, ComicFollowCheckFailure>{},  Map<String, DateTime> lastAttempts = const <String, DateTime>{}, this.result = '', this.revision = 0,  Map<String, UnifiedComicHistory> histories = const <String, UnifiedComicHistory>{}, this.filter = ComicFollowFilter.all, this.sort = ComicFollowSort.lastRead}): _items = items,_checkingKeys = checkingKeys,_checkErrors = checkErrors,_lastAttempts = lastAttempts,_histories = histories,super._();
  

@override@JsonKey() final  ComicFollowStatus status;
 final  List<ComicFollow> _items;
@override@JsonKey() List<ComicFollow> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override@JsonKey() final  bool isCheckingUpdates;
 final  Set<String> _checkingKeys;
@override@JsonKey() Set<String> get checkingKeys {
  if (_checkingKeys is EqualUnmodifiableSetView) return _checkingKeys;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_checkingKeys);
}

 final  Map<String, ComicFollowCheckFailure> _checkErrors;
@override@JsonKey() Map<String, ComicFollowCheckFailure> get checkErrors {
  if (_checkErrors is EqualUnmodifiableMapView) return _checkErrors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_checkErrors);
}

 final  Map<String, DateTime> _lastAttempts;
@override@JsonKey() Map<String, DateTime> get lastAttempts {
  if (_lastAttempts is EqualUnmodifiableMapView) return _lastAttempts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_lastAttempts);
}

@override@JsonKey() final  String result;
@override@JsonKey() final  int revision;
 final  Map<String, UnifiedComicHistory> _histories;
@override@JsonKey() Map<String, UnifiedComicHistory> get histories {
  if (_histories is EqualUnmodifiableMapView) return _histories;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_histories);
}

@override@JsonKey() final  ComicFollowFilter filter;
@override@JsonKey() final  ComicFollowSort sort;

/// Create a copy of ComicFollowState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ComicFollowStateCopyWith<_ComicFollowState> get copyWith => __$ComicFollowStateCopyWithImpl<_ComicFollowState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ComicFollowState&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.items, _items)&&(identical(other.isCheckingUpdates, isCheckingUpdates) || other.isCheckingUpdates == isCheckingUpdates)&&const DeepCollectionEquality().equals(other.checkingKeys, _checkingKeys)&&const DeepCollectionEquality().equals(other.checkErrors, _checkErrors)&&const DeepCollectionEquality().equals(other.lastAttempts, _lastAttempts)&&(identical(other.result, result) || other.result == result)&&(identical(other.revision, revision) || other.revision == revision)&&const DeepCollectionEquality().equals(other.histories, _histories)&&(identical(other.filter, filter) || other.filter == filter)&&(identical(other.sort, sort) || other.sort == sort));
}


@override
int get hashCode {
    return Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_items),isCheckingUpdates,const DeepCollectionEquality().hash(_checkingKeys),const DeepCollectionEquality().hash(_checkErrors),const DeepCollectionEquality().hash(_lastAttempts),result,revision,const DeepCollectionEquality().hash(_histories),filter,sort);
}

@override
String toString() {
    return 'ComicFollowState(status: $status, items: $items, isCheckingUpdates: $isCheckingUpdates, checkingKeys: $checkingKeys, checkErrors: $checkErrors, lastAttempts: $lastAttempts, result: $result, revision: $revision, histories: $histories, filter: $filter, sort: $sort)';
}


}

/// @nodoc
abstract mixin class _$ComicFollowStateCopyWith<$Res> implements $ComicFollowStateCopyWith<$Res> {
  factory _$ComicFollowStateCopyWith(_ComicFollowState value, $Res Function(_ComicFollowState) _then) = __$ComicFollowStateCopyWithImpl;
@override @useResult
$Res call({
 ComicFollowStatus status, List<ComicFollow> items, bool isCheckingUpdates, Set<String> checkingKeys, Map<String, ComicFollowCheckFailure> checkErrors, Map<String, DateTime> lastAttempts, String result, int revision, Map<String, UnifiedComicHistory> histories, ComicFollowFilter filter, ComicFollowSort sort
});




}
/// @nodoc
class __$ComicFollowStateCopyWithImpl<$Res>
    implements _$ComicFollowStateCopyWith<$Res> {
  __$ComicFollowStateCopyWithImpl(this._self, this._then);

  final _ComicFollowState _self;
  final $Res Function(_ComicFollowState) _then;

/// Create a copy of ComicFollowState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? items = null,Object? isCheckingUpdates = null,Object? checkingKeys = null,Object? checkErrors = null,Object? lastAttempts = null,Object? result = null,Object? revision = null,Object? histories = null,Object? filter = null,Object? sort = null,}) {
  return _then(_ComicFollowState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as ComicFollowStatus,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<ComicFollow>,isCheckingUpdates: null == isCheckingUpdates ? _self.isCheckingUpdates : isCheckingUpdates // ignore: cast_nullable_to_non_nullable
as bool,checkingKeys: null == checkingKeys ? _self._checkingKeys : checkingKeys // ignore: cast_nullable_to_non_nullable
as Set<String>,checkErrors: null == checkErrors ? _self._checkErrors : checkErrors // ignore: cast_nullable_to_non_nullable
as Map<String, ComicFollowCheckFailure>,lastAttempts: null == lastAttempts ? _self._lastAttempts : lastAttempts // ignore: cast_nullable_to_non_nullable
as Map<String, DateTime>,result: null == result ? _self.result : result // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,histories: null == histories ? _self._histories : histories // ignore: cast_nullable_to_non_nullable
as Map<String, UnifiedComicHistory>,filter: null == filter ? _self.filter : filter // ignore: cast_nullable_to_non_nullable
as ComicFollowFilter,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as ComicFollowSort,
  ));
}


}

// dart format on
