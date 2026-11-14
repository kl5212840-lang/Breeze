// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shelf_facets.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ShelfFacetEntry {

 String get key; String get source; String get searchText; Set<String> get folders; Map<String, Set<String>> get fields;
/// Create a copy of ShelfFacetEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShelfFacetEntryCopyWith<ShelfFacetEntry> get copyWith => _$ShelfFacetEntryCopyWithImpl<ShelfFacetEntry>(this as ShelfFacetEntry, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ShelfFacetEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShelfFacetEntry&&(identical(other.key, _this.key) || other.key == _this.key)&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.searchText, _this.searchText) || other.searchText == _this.searchText)&&const DeepCollectionEquality().equals(other.folders, _this.folders)&&const DeepCollectionEquality().equals(other.fields, _this.fields));
}


@override
int get hashCode {
  final _this = this as ShelfFacetEntry;
  return Object.hash(runtimeType,_this.key,_this.source,_this.searchText,const DeepCollectionEquality().hash(_this.folders),const DeepCollectionEquality().hash(_this.fields));
}

@override
String toString() {
  final _this = this as ShelfFacetEntry;
  return 'ShelfFacetEntry(key: ${_this.key}, source: ${_this.source}, searchText: ${_this.searchText}, folders: ${_this.folders}, fields: ${_this.fields})';
}


}

/// @nodoc
abstract mixin class $ShelfFacetEntryCopyWith<$Res>  {
  factory $ShelfFacetEntryCopyWith(ShelfFacetEntry value, $Res Function(ShelfFacetEntry) _then) = _$ShelfFacetEntryCopyWithImpl;
@useResult
$Res call({
 String key, String source, String searchText, Set<String> folders, Map<String, Set<String>> fields
});




}
/// @nodoc
class _$ShelfFacetEntryCopyWithImpl<$Res>
    implements $ShelfFacetEntryCopyWith<$Res> {
  _$ShelfFacetEntryCopyWithImpl(this._self, this._then);

  final ShelfFacetEntry _self;
  final $Res Function(ShelfFacetEntry) _then;

/// Create a copy of ShelfFacetEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? source = null,Object? searchText = null,Object? folders = null,Object? fields = null,}) {
  return _then(ShelfFacetEntry(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,searchText: null == searchText ? _self.searchText : searchText // ignore: cast_nullable_to_non_nullable
as String,folders: null == folders ? _self.folders : folders // ignore: cast_nullable_to_non_nullable
as Set<String>,fields: null == fields ? _self.fields : fields // ignore: cast_nullable_to_non_nullable
as Map<String, Set<String>>,
  ));
}

}


/// Adds pattern-matching-related methods to [ShelfFacetEntry].
extension ShelfFacetEntryPatterns on ShelfFacetEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ShelfFacetEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ShelfFacetEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ShelfFacetEntry value)  $default,){
final _that = this;
switch (_that) {
case _ShelfFacetEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ShelfFacetEntry value)?  $default,){
final _that = this;
switch (_that) {
case _ShelfFacetEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  String source,  String searchText,  Set<String> folders,  Map<String, Set<String>> fields)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ShelfFacetEntry() when $default != null:
return $default(_that.key,_that.source,_that.searchText,_that.folders,_that.fields);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  String source,  String searchText,  Set<String> folders,  Map<String, Set<String>> fields)  $default,) {final _that = this;
switch (_that) {
case _ShelfFacetEntry():
return $default(_that.key,_that.source,_that.searchText,_that.folders,_that.fields);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  String source,  String searchText,  Set<String> folders,  Map<String, Set<String>> fields)?  $default,) {final _that = this;
switch (_that) {
case _ShelfFacetEntry() when $default != null:
return $default(_that.key,_that.source,_that.searchText,_that.folders,_that.fields);case _:
  return null;

}
}

}

/// @nodoc


class _ShelfFacetEntry implements ShelfFacetEntry {
  const _ShelfFacetEntry({required this.key, required this.source, required this.searchText,  Set<String> folders = const {''},  Map<String, Set<String>> fields = const {}}): _folders = folders,_fields = fields;


@override final  String key;
@override final  String source;
@override final  String searchText;
 final  Set<String> _folders;
@override@JsonKey() Set<String> get folders {
  if (_folders is EqualUnmodifiableSetView) return _folders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_folders);
}

 final  Map<String, Set<String>> _fields;
@override@JsonKey() Map<String, Set<String>> get fields {
  if (_fields is EqualUnmodifiableMapView) return _fields;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_fields);
}


/// Create a copy of ShelfFacetEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShelfFacetEntryCopyWith<_ShelfFacetEntry> get copyWith => __$ShelfFacetEntryCopyWithImpl<_ShelfFacetEntry>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShelfFacetEntry&&(identical(other.key, key) || other.key == key)&&(identical(other.source, source) || other.source == source)&&(identical(other.searchText, searchText) || other.searchText == searchText)&&const DeepCollectionEquality().equals(other.folders, _folders)&&const DeepCollectionEquality().equals(other.fields, _fields));
}


@override
int get hashCode {
    return Object.hash(runtimeType,key,source,searchText,const DeepCollectionEquality().hash(_folders),const DeepCollectionEquality().hash(_fields));
}

@override
String toString() {
    return 'ShelfFacetEntry(key: $key, source: $source, searchText: $searchText, folders: $folders, fields: $fields)';
}


}

/// @nodoc
abstract mixin class _$ShelfFacetEntryCopyWith<$Res> implements $ShelfFacetEntryCopyWith<$Res> {
  factory _$ShelfFacetEntryCopyWith(_ShelfFacetEntry value, $Res Function(_ShelfFacetEntry) _then) = __$ShelfFacetEntryCopyWithImpl;
@override @useResult
$Res call({
 String key, String source, String searchText, Set<String> folders, Map<String, Set<String>> fields
});




}
/// @nodoc
class __$ShelfFacetEntryCopyWithImpl<$Res>
    implements _$ShelfFacetEntryCopyWith<$Res> {
  __$ShelfFacetEntryCopyWithImpl(this._self, this._then);

  final _ShelfFacetEntry _self;
  final $Res Function(_ShelfFacetEntry) _then;

/// Create a copy of ShelfFacetEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? source = null,Object? searchText = null,Object? folders = null,Object? fields = null,}) {
  return _then(_ShelfFacetEntry(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,searchText: null == searchText ? _self.searchText : searchText // ignore: cast_nullable_to_non_nullable
as String,folders: null == folders ? _self._folders : folders // ignore: cast_nullable_to_non_nullable
as Set<String>,fields: null == fields ? _self._fields : fields // ignore: cast_nullable_to_non_nullable
as Map<String, Set<String>>,
  ));
}


}

/// @nodoc
mixin _$ShelfFacetSelection {

 ShelfFacetScope get scope; Map<String, Set<String>> get values; bool get applied;
/// Create a copy of ShelfFacetSelection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShelfFacetSelectionCopyWith<ShelfFacetSelection> get copyWith => _$ShelfFacetSelectionCopyWithImpl<ShelfFacetSelection>(this as ShelfFacetSelection, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ShelfFacetSelection;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShelfFacetSelection&&(identical(other.scope, _this.scope) || other.scope == _this.scope)&&const DeepCollectionEquality().equals(other.values, _this.values)&&(identical(other.applied, _this.applied) || other.applied == _this.applied));
}


@override
int get hashCode {
  final _this = this as ShelfFacetSelection;
  return Object.hash(runtimeType,_this.scope,const DeepCollectionEquality().hash(_this.values),_this.applied);
}

@override
String toString() {
  final _this = this as ShelfFacetSelection;
  return 'ShelfFacetSelection(scope: ${_this.scope}, values: ${_this.values}, applied: ${_this.applied})';
}


}

/// @nodoc
abstract mixin class $ShelfFacetSelectionCopyWith<$Res>  {
  factory $ShelfFacetSelectionCopyWith(ShelfFacetSelection value, $Res Function(ShelfFacetSelection) _then) = _$ShelfFacetSelectionCopyWithImpl;
@useResult
$Res call({
 ShelfFacetScope scope, Map<String, Set<String>> values, bool applied
});




}
/// @nodoc
class _$ShelfFacetSelectionCopyWithImpl<$Res>
    implements $ShelfFacetSelectionCopyWith<$Res> {
  _$ShelfFacetSelectionCopyWithImpl(this._self, this._then);

  final ShelfFacetSelection _self;
  final $Res Function(ShelfFacetSelection) _then;

/// Create a copy of ShelfFacetSelection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? scope = null,Object? values = null,Object? applied = null,}) {
  return _then(ShelfFacetSelection(
scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as ShelfFacetScope,values: null == values ? _self.values : values // ignore: cast_nullable_to_non_nullable
as Map<String, Set<String>>,applied: null == applied ? _self.applied : applied // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ShelfFacetSelection].
extension ShelfFacetSelectionPatterns on ShelfFacetSelection {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ShelfFacetSelection value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ShelfFacetSelection() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ShelfFacetSelection value)  $default,){
final _that = this;
switch (_that) {
case _ShelfFacetSelection():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ShelfFacetSelection value)?  $default,){
final _that = this;
switch (_that) {
case _ShelfFacetSelection() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ShelfFacetScope scope,  Map<String, Set<String>> values,  bool applied)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ShelfFacetSelection() when $default != null:
return $default(_that.scope,_that.values,_that.applied);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ShelfFacetScope scope,  Map<String, Set<String>> values,  bool applied)  $default,) {final _that = this;
switch (_that) {
case _ShelfFacetSelection():
return $default(_that.scope,_that.values,_that.applied);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ShelfFacetScope scope,  Map<String, Set<String>> values,  bool applied)?  $default,) {final _that = this;
switch (_that) {
case _ShelfFacetSelection() when $default != null:
return $default(_that.scope,_that.values,_that.applied);case _:
  return null;

}
}

}

/// @nodoc


class _ShelfFacetSelection extends ShelfFacetSelection {
  const _ShelfFacetSelection({this.scope = ShelfFacetScope.current,  Map<String, Set<String>> values = const {}, this.applied = false}): _values = values,super._();


@override@JsonKey() final  ShelfFacetScope scope;
 final  Map<String, Set<String>> _values;
@override@JsonKey() Map<String, Set<String>> get values {
  if (_values is EqualUnmodifiableMapView) return _values;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_values);
}

@override@JsonKey() final  bool applied;

/// Create a copy of ShelfFacetSelection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ShelfFacetSelectionCopyWith<_ShelfFacetSelection> get copyWith => __$ShelfFacetSelectionCopyWithImpl<_ShelfFacetSelection>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ShelfFacetSelection&&(identical(other.scope, scope) || other.scope == scope)&&const DeepCollectionEquality().equals(other.values, _values)&&(identical(other.applied, applied) || other.applied == applied));
}


@override
int get hashCode {
    return Object.hash(runtimeType,scope,const DeepCollectionEquality().hash(_values),applied);
}

@override
String toString() {
    return 'ShelfFacetSelection(scope: $scope, values: $values, applied: $applied)';
}


}

/// @nodoc
abstract mixin class _$ShelfFacetSelectionCopyWith<$Res> implements $ShelfFacetSelectionCopyWith<$Res> {
  factory _$ShelfFacetSelectionCopyWith(_ShelfFacetSelection value, $Res Function(_ShelfFacetSelection) _then) = __$ShelfFacetSelectionCopyWithImpl;
@override @useResult
$Res call({
 ShelfFacetScope scope, Map<String, Set<String>> values, bool applied
});




}
/// @nodoc
class __$ShelfFacetSelectionCopyWithImpl<$Res>
    implements _$ShelfFacetSelectionCopyWith<$Res> {
  __$ShelfFacetSelectionCopyWithImpl(this._self, this._then);

  final _ShelfFacetSelection _self;
  final $Res Function(_ShelfFacetSelection) _then;

/// Create a copy of ShelfFacetSelection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? scope = null,Object? values = null,Object? applied = null,}) {
  return _then(_ShelfFacetSelection(
scope: null == scope ? _self.scope : scope // ignore: cast_nullable_to_non_nullable
as ShelfFacetScope,values: null == values ? _self._values : values // ignore: cast_nullable_to_non_nullable
as Map<String, Set<String>>,applied: null == applied ? _self.applied : applied // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
