// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'collection_cover_privacy.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CollectionCoverPrivacySettings implements DiagnosticableTreeMixin {

 bool get enabled; CollectionCoverStyle get style; bool get ready;
/// Create a copy of CollectionCoverPrivacySettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CollectionCoverPrivacySettingsCopyWith<CollectionCoverPrivacySettings> get copyWith => _$CollectionCoverPrivacySettingsCopyWithImpl<CollectionCoverPrivacySettings>(this as CollectionCoverPrivacySettings, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  final _this = this as CollectionCoverPrivacySettings;
  properties
    ..add(DiagnosticsProperty('type', 'CollectionCoverPrivacySettings'))
    ..add(DiagnosticsProperty('enabled', _this.enabled))..add(DiagnosticsProperty('style', _this.style))..add(DiagnosticsProperty('ready', _this.ready));
}

@override
bool operator ==(Object other) {
  final _this = this as CollectionCoverPrivacySettings;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CollectionCoverPrivacySettings&&(identical(other.enabled, _this.enabled) || other.enabled == _this.enabled)&&(identical(other.style, _this.style) || other.style == _this.style)&&(identical(other.ready, _this.ready) || other.ready == _this.ready));
}


@override
int get hashCode {
  final _this = this as CollectionCoverPrivacySettings;
  return Object.hash(runtimeType,_this.enabled,_this.style,_this.ready);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  final _this = this as CollectionCoverPrivacySettings;
  return 'CollectionCoverPrivacySettings(enabled: ${_this.enabled}, style: ${_this.style}, ready: ${_this.ready})';
}


}

/// @nodoc
abstract mixin class $CollectionCoverPrivacySettingsCopyWith<$Res>  {
  factory $CollectionCoverPrivacySettingsCopyWith(CollectionCoverPrivacySettings value, $Res Function(CollectionCoverPrivacySettings) _then) = _$CollectionCoverPrivacySettingsCopyWithImpl;
@useResult
$Res call({
 bool enabled, CollectionCoverStyle style, bool ready
});




}
/// @nodoc
class _$CollectionCoverPrivacySettingsCopyWithImpl<$Res>
    implements $CollectionCoverPrivacySettingsCopyWith<$Res> {
  _$CollectionCoverPrivacySettingsCopyWithImpl(this._self, this._then);

  final CollectionCoverPrivacySettings _self;
  final $Res Function(CollectionCoverPrivacySettings) _then;

/// Create a copy of CollectionCoverPrivacySettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? enabled = null,Object? style = null,Object? ready = null,}) {
  return _then(CollectionCoverPrivacySettings(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,style: null == style ? _self.style : style // ignore: cast_nullable_to_non_nullable
as CollectionCoverStyle,ready: null == ready ? _self.ready : ready // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [CollectionCoverPrivacySettings].
extension CollectionCoverPrivacySettingsPatterns on CollectionCoverPrivacySettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CollectionCoverPrivacySettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CollectionCoverPrivacySettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CollectionCoverPrivacySettings value)  $default,){
final _that = this;
switch (_that) {
case _CollectionCoverPrivacySettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CollectionCoverPrivacySettings value)?  $default,){
final _that = this;
switch (_that) {
case _CollectionCoverPrivacySettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool enabled,  CollectionCoverStyle style,  bool ready)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CollectionCoverPrivacySettings() when $default != null:
return $default(_that.enabled,_that.style,_that.ready);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool enabled,  CollectionCoverStyle style,  bool ready)  $default,) {final _that = this;
switch (_that) {
case _CollectionCoverPrivacySettings():
return $default(_that.enabled,_that.style,_that.ready);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool enabled,  CollectionCoverStyle style,  bool ready)?  $default,) {final _that = this;
switch (_that) {
case _CollectionCoverPrivacySettings() when $default != null:
return $default(_that.enabled,_that.style,_that.ready);case _:
  return null;

}
}

}

/// @nodoc


class _CollectionCoverPrivacySettings with DiagnosticableTreeMixin implements CollectionCoverPrivacySettings {
  const _CollectionCoverPrivacySettings({this.enabled = false, this.style = CollectionCoverStyle.blur, this.ready = false});


@override@JsonKey() final  bool enabled;
@override@JsonKey() final  CollectionCoverStyle style;
@override@JsonKey() final  bool ready;

/// Create a copy of CollectionCoverPrivacySettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CollectionCoverPrivacySettingsCopyWith<_CollectionCoverPrivacySettings> get copyWith => __$CollectionCoverPrivacySettingsCopyWithImpl<_CollectionCoverPrivacySettings>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties
    ..add(DiagnosticsProperty('type', 'CollectionCoverPrivacySettings'))
    ..add(DiagnosticsProperty('enabled', enabled))..add(DiagnosticsProperty('style', style))..add(DiagnosticsProperty('ready', ready));
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CollectionCoverPrivacySettings&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.style, style) || other.style == style)&&(identical(other.ready, ready) || other.ready == ready));
}


@override
int get hashCode {
    return Object.hash(runtimeType,enabled,style,ready);
}

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
    return 'CollectionCoverPrivacySettings(enabled: $enabled, style: $style, ready: $ready)';
}


}

/// @nodoc
abstract mixin class _$CollectionCoverPrivacySettingsCopyWith<$Res> implements $CollectionCoverPrivacySettingsCopyWith<$Res> {
  factory _$CollectionCoverPrivacySettingsCopyWith(_CollectionCoverPrivacySettings value, $Res Function(_CollectionCoverPrivacySettings) _then) = __$CollectionCoverPrivacySettingsCopyWithImpl;
@override @useResult
$Res call({
 bool enabled, CollectionCoverStyle style, bool ready
});




}
/// @nodoc
class __$CollectionCoverPrivacySettingsCopyWithImpl<$Res>
    implements _$CollectionCoverPrivacySettingsCopyWith<$Res> {
  __$CollectionCoverPrivacySettingsCopyWithImpl(this._self, this._then);

  final _CollectionCoverPrivacySettings _self;
  final $Res Function(_CollectionCoverPrivacySettings) _then;

/// Create a copy of CollectionCoverPrivacySettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? enabled = null,Object? style = null,Object? ready = null,}) {
  return _then(_CollectionCoverPrivacySettings(
enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,style: null == style ? _self.style : style // ignore: cast_nullable_to_non_nullable
as CollectionCoverStyle,ready: null == ready ? _self.ready : ready // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
