// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'source_checkin_status.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SourceCheckinStatus {

 String get accountId; String get date; bool? get checkedIn;
/// Create a copy of SourceCheckinStatus
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SourceCheckinStatusCopyWith<SourceCheckinStatus> get copyWith => _$SourceCheckinStatusCopyWithImpl<SourceCheckinStatus>(this as SourceCheckinStatus, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SourceCheckinStatus;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SourceCheckinStatus&&(identical(other.accountId, _this.accountId) || other.accountId == _this.accountId)&&(identical(other.date, _this.date) || other.date == _this.date)&&(identical(other.checkedIn, _this.checkedIn) || other.checkedIn == _this.checkedIn));
}


@override
int get hashCode {
  final _this = this as SourceCheckinStatus;
  return Object.hash(runtimeType,_this.accountId,_this.date,_this.checkedIn);
}

@override
String toString() {
  final _this = this as SourceCheckinStatus;
  return 'SourceCheckinStatus(accountId: ${_this.accountId}, date: ${_this.date}, checkedIn: ${_this.checkedIn})';
}


}

/// @nodoc
abstract mixin class $SourceCheckinStatusCopyWith<$Res>  {
  factory $SourceCheckinStatusCopyWith(SourceCheckinStatus value, $Res Function(SourceCheckinStatus) _then) = _$SourceCheckinStatusCopyWithImpl;
@useResult
$Res call({
 String accountId, String date, bool? checkedIn
});




}
/// @nodoc
class _$SourceCheckinStatusCopyWithImpl<$Res>
    implements $SourceCheckinStatusCopyWith<$Res> {
  _$SourceCheckinStatusCopyWithImpl(this._self, this._then);

  final SourceCheckinStatus _self;
  final $Res Function(SourceCheckinStatus) _then;

/// Create a copy of SourceCheckinStatus
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? accountId = null,Object? date = null,Object? checkedIn = freezed,}) {
  return _then(SourceCheckinStatus(
accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,checkedIn: freezed == checkedIn ? _self.checkedIn : checkedIn // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [SourceCheckinStatus].
extension SourceCheckinStatusPatterns on SourceCheckinStatus {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SourceCheckinStatus value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SourceCheckinStatus() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SourceCheckinStatus value)  $default,){
final _that = this;
switch (_that) {
case _SourceCheckinStatus():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SourceCheckinStatus value)?  $default,){
final _that = this;
switch (_that) {
case _SourceCheckinStatus() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String accountId,  String date,  bool? checkedIn)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SourceCheckinStatus() when $default != null:
return $default(_that.accountId,_that.date,_that.checkedIn);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String accountId,  String date,  bool? checkedIn)  $default,) {final _that = this;
switch (_that) {
case _SourceCheckinStatus():
return $default(_that.accountId,_that.date,_that.checkedIn);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String accountId,  String date,  bool? checkedIn)?  $default,) {final _that = this;
switch (_that) {
case _SourceCheckinStatus() when $default != null:
return $default(_that.accountId,_that.date,_that.checkedIn);case _:
  return null;

}
}

}

/// @nodoc


class _SourceCheckinStatus extends SourceCheckinStatus {
  const _SourceCheckinStatus({required this.accountId, required this.date, this.checkedIn}): super._();


@override final  String accountId;
@override final  String date;
@override final  bool? checkedIn;

/// Create a copy of SourceCheckinStatus
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SourceCheckinStatusCopyWith<_SourceCheckinStatus> get copyWith => __$SourceCheckinStatusCopyWithImpl<_SourceCheckinStatus>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SourceCheckinStatus&&(identical(other.accountId, accountId) || other.accountId == accountId)&&(identical(other.date, date) || other.date == date)&&(identical(other.checkedIn, checkedIn) || other.checkedIn == checkedIn));
}


@override
int get hashCode {
    return Object.hash(runtimeType,accountId,date,checkedIn);
}

@override
String toString() {
    return 'SourceCheckinStatus(accountId: $accountId, date: $date, checkedIn: $checkedIn)';
}


}

/// @nodoc
abstract mixin class _$SourceCheckinStatusCopyWith<$Res> implements $SourceCheckinStatusCopyWith<$Res> {
  factory _$SourceCheckinStatusCopyWith(_SourceCheckinStatus value, $Res Function(_SourceCheckinStatus) _then) = __$SourceCheckinStatusCopyWithImpl;
@override @useResult
$Res call({
 String accountId, String date, bool? checkedIn
});




}
/// @nodoc
class __$SourceCheckinStatusCopyWithImpl<$Res>
    implements _$SourceCheckinStatusCopyWith<$Res> {
  __$SourceCheckinStatusCopyWithImpl(this._self, this._then);

  final _SourceCheckinStatus _self;
  final $Res Function(_SourceCheckinStatus) _then;

/// Create a copy of SourceCheckinStatus
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? accountId = null,Object? date = null,Object? checkedIn = freezed,}) {
  return _then(_SourceCheckinStatus(
accountId: null == accountId ? _self.accountId : accountId // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,checkedIn: freezed == checkedIn ? _self.checkedIn : checkedIn // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

// dart format on
