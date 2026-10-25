// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'video_search_filters.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VideoSearchFilters {

 String get query; String get genre; String get sort; String get date; String get duration; List<String> get tags; bool get anyTag; bool get author; int get page;
/// Create a copy of VideoSearchFilters
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoSearchFiltersCopyWith<VideoSearchFilters> get copyWith => _$VideoSearchFiltersCopyWithImpl<VideoSearchFilters>(this as VideoSearchFilters, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as VideoSearchFilters;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoSearchFilters&&(identical(other.query, _this.query) || other.query == _this.query)&&(identical(other.genre, _this.genre) || other.genre == _this.genre)&&(identical(other.sort, _this.sort) || other.sort == _this.sort)&&(identical(other.date, _this.date) || other.date == _this.date)&&(identical(other.duration, _this.duration) || other.duration == _this.duration)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&(identical(other.anyTag, _this.anyTag) || other.anyTag == _this.anyTag)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.page, _this.page) || other.page == _this.page));
}


@override
int get hashCode {
  final _this = this as VideoSearchFilters;
  return Object.hash(runtimeType,_this.query,_this.genre,_this.sort,_this.date,_this.duration,const DeepCollectionEquality().hash(_this.tags),_this.anyTag,_this.author,_this.page);
}

@override
String toString() {
  final _this = this as VideoSearchFilters;
  return 'VideoSearchFilters(query: ${_this.query}, genre: ${_this.genre}, sort: ${_this.sort}, date: ${_this.date}, duration: ${_this.duration}, tags: ${_this.tags}, anyTag: ${_this.anyTag}, author: ${_this.author}, page: ${_this.page})';
}


}

/// @nodoc
abstract mixin class $VideoSearchFiltersCopyWith<$Res>  {
  factory $VideoSearchFiltersCopyWith(VideoSearchFilters value, $Res Function(VideoSearchFilters) _then) = _$VideoSearchFiltersCopyWithImpl;
@useResult
$Res call({
 String query, String genre, String sort, String date, String duration, List<String> tags, bool anyTag, bool author, int page
});




}
/// @nodoc
class _$VideoSearchFiltersCopyWithImpl<$Res>
    implements $VideoSearchFiltersCopyWith<$Res> {
  _$VideoSearchFiltersCopyWithImpl(this._self, this._then);

  final VideoSearchFilters _self;
  final $Res Function(VideoSearchFilters) _then;

/// Create a copy of VideoSearchFilters
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? query = null,Object? genre = null,Object? sort = null,Object? date = null,Object? duration = null,Object? tags = null,Object? anyTag = null,Object? author = null,Object? page = null,}) {
  return _then(VideoSearchFilters(
query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,genre: null == genre ? _self.genre : genre // ignore: cast_nullable_to_non_nullable
as String,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,anyTag: null == anyTag ? _self.anyTag : anyTag // ignore: cast_nullable_to_non_nullable
as bool,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as bool,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [VideoSearchFilters].
extension VideoSearchFiltersPatterns on VideoSearchFilters {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VideoSearchFilters value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VideoSearchFilters() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VideoSearchFilters value)  $default,){
final _that = this;
switch (_that) {
case _VideoSearchFilters():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VideoSearchFilters value)?  $default,){
final _that = this;
switch (_that) {
case _VideoSearchFilters() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String query,  String genre,  String sort,  String date,  String duration,  List<String> tags,  bool anyTag,  bool author,  int page)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VideoSearchFilters() when $default != null:
return $default(_that.query,_that.genre,_that.sort,_that.date,_that.duration,_that.tags,_that.anyTag,_that.author,_that.page);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String query,  String genre,  String sort,  String date,  String duration,  List<String> tags,  bool anyTag,  bool author,  int page)  $default,) {final _that = this;
switch (_that) {
case _VideoSearchFilters():
return $default(_that.query,_that.genre,_that.sort,_that.date,_that.duration,_that.tags,_that.anyTag,_that.author,_that.page);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String query,  String genre,  String sort,  String date,  String duration,  List<String> tags,  bool anyTag,  bool author,  int page)?  $default,) {final _that = this;
switch (_that) {
case _VideoSearchFilters() when $default != null:
return $default(_that.query,_that.genre,_that.sort,_that.date,_that.duration,_that.tags,_that.anyTag,_that.author,_that.page);case _:
  return null;

}
}

}

/// @nodoc


class _VideoSearchFilters extends VideoSearchFilters {
  const _VideoSearchFilters({this.query = '', this.genre = '', this.sort = '', this.date = '', this.duration = '',  List<String> tags = const [], this.anyTag = false, this.author = false, this.page = 1}): _tags = tags,super._();
  

@override@JsonKey() final  String query;
@override@JsonKey() final  String genre;
@override@JsonKey() final  String sort;
@override@JsonKey() final  String date;
@override@JsonKey() final  String duration;
 final  List<String> _tags;
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

@override@JsonKey() final  bool anyTag;
@override@JsonKey() final  bool author;
@override@JsonKey() final  int page;

/// Create a copy of VideoSearchFilters
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoSearchFiltersCopyWith<_VideoSearchFilters> get copyWith => __$VideoSearchFiltersCopyWithImpl<_VideoSearchFilters>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoSearchFilters&&(identical(other.query, query) || other.query == query)&&(identical(other.genre, genre) || other.genre == genre)&&(identical(other.sort, sort) || other.sort == sort)&&(identical(other.date, date) || other.date == date)&&(identical(other.duration, duration) || other.duration == duration)&&const DeepCollectionEquality().equals(other.tags, _tags)&&(identical(other.anyTag, anyTag) || other.anyTag == anyTag)&&(identical(other.author, author) || other.author == author)&&(identical(other.page, page) || other.page == page));
}


@override
int get hashCode {
    return Object.hash(runtimeType,query,genre,sort,date,duration,const DeepCollectionEquality().hash(_tags),anyTag,author,page);
}

@override
String toString() {
    return 'VideoSearchFilters(query: $query, genre: $genre, sort: $sort, date: $date, duration: $duration, tags: $tags, anyTag: $anyTag, author: $author, page: $page)';
}


}

/// @nodoc
abstract mixin class _$VideoSearchFiltersCopyWith<$Res> implements $VideoSearchFiltersCopyWith<$Res> {
  factory _$VideoSearchFiltersCopyWith(_VideoSearchFilters value, $Res Function(_VideoSearchFilters) _then) = __$VideoSearchFiltersCopyWithImpl;
@override @useResult
$Res call({
 String query, String genre, String sort, String date, String duration, List<String> tags, bool anyTag, bool author, int page
});




}
/// @nodoc
class __$VideoSearchFiltersCopyWithImpl<$Res>
    implements _$VideoSearchFiltersCopyWith<$Res> {
  __$VideoSearchFiltersCopyWithImpl(this._self, this._then);

  final _VideoSearchFilters _self;
  final $Res Function(_VideoSearchFilters) _then;

/// Create a copy of VideoSearchFilters
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? query = null,Object? genre = null,Object? sort = null,Object? date = null,Object? duration = null,Object? tags = null,Object? anyTag = null,Object? author = null,Object? page = null,}) {
  return _then(_VideoSearchFilters(
query: null == query ? _self.query : query // ignore: cast_nullable_to_non_nullable
as String,genre: null == genre ? _self.genre : genre // ignore: cast_nullable_to_non_nullable
as String,sort: null == sort ? _self.sort : sort // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,anyTag: null == anyTag ? _self.anyTag : anyTag // ignore: cast_nullable_to_non_nullable
as bool,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as bool,page: null == page ? _self.page : page // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$VideoFilterChoice {

 String get value; String get label;
/// Create a copy of VideoFilterChoice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoFilterChoiceCopyWith<VideoFilterChoice> get copyWith => _$VideoFilterChoiceCopyWithImpl<VideoFilterChoice>(this as VideoFilterChoice, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as VideoFilterChoice;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoFilterChoice&&(identical(other.value, _this.value) || other.value == _this.value)&&(identical(other.label, _this.label) || other.label == _this.label));
}


@override
int get hashCode {
  final _this = this as VideoFilterChoice;
  return Object.hash(runtimeType,_this.value,_this.label);
}

@override
String toString() {
  final _this = this as VideoFilterChoice;
  return 'VideoFilterChoice(value: ${_this.value}, label: ${_this.label})';
}


}

/// @nodoc
abstract mixin class $VideoFilterChoiceCopyWith<$Res>  {
  factory $VideoFilterChoiceCopyWith(VideoFilterChoice value, $Res Function(VideoFilterChoice) _then) = _$VideoFilterChoiceCopyWithImpl;
@useResult
$Res call({
 String value, String label
});




}
/// @nodoc
class _$VideoFilterChoiceCopyWithImpl<$Res>
    implements $VideoFilterChoiceCopyWith<$Res> {
  _$VideoFilterChoiceCopyWithImpl(this._self, this._then);

  final VideoFilterChoice _self;
  final $Res Function(VideoFilterChoice) _then;

/// Create a copy of VideoFilterChoice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? value = null,Object? label = null,}) {
  return _then(VideoFilterChoice(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [VideoFilterChoice].
extension VideoFilterChoicePatterns on VideoFilterChoice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VideoFilterChoice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VideoFilterChoice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VideoFilterChoice value)  $default,){
final _that = this;
switch (_that) {
case _VideoFilterChoice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VideoFilterChoice value)?  $default,){
final _that = this;
switch (_that) {
case _VideoFilterChoice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String value,  String label)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VideoFilterChoice() when $default != null:
return $default(_that.value,_that.label);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String value,  String label)  $default,) {final _that = this;
switch (_that) {
case _VideoFilterChoice():
return $default(_that.value,_that.label);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String value,  String label)?  $default,) {final _that = this;
switch (_that) {
case _VideoFilterChoice() when $default != null:
return $default(_that.value,_that.label);case _:
  return null;

}
}

}

/// @nodoc


class _VideoFilterChoice implements VideoFilterChoice {
  const _VideoFilterChoice({required this.value, required this.label});
  

@override final  String value;
@override final  String label;

/// Create a copy of VideoFilterChoice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoFilterChoiceCopyWith<_VideoFilterChoice> get copyWith => __$VideoFilterChoiceCopyWithImpl<_VideoFilterChoice>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoFilterChoice&&(identical(other.value, value) || other.value == value)&&(identical(other.label, label) || other.label == label));
}


@override
int get hashCode {
    return Object.hash(runtimeType,value,label);
}

@override
String toString() {
    return 'VideoFilterChoice(value: $value, label: $label)';
}


}

/// @nodoc
abstract mixin class _$VideoFilterChoiceCopyWith<$Res> implements $VideoFilterChoiceCopyWith<$Res> {
  factory _$VideoFilterChoiceCopyWith(_VideoFilterChoice value, $Res Function(_VideoFilterChoice) _then) = __$VideoFilterChoiceCopyWithImpl;
@override @useResult
$Res call({
 String value, String label
});




}
/// @nodoc
class __$VideoFilterChoiceCopyWithImpl<$Res>
    implements _$VideoFilterChoiceCopyWith<$Res> {
  __$VideoFilterChoiceCopyWithImpl(this._self, this._then);

  final _VideoFilterChoice _self;
  final $Res Function(_VideoFilterChoice) _then;

/// Create a copy of VideoFilterChoice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? value = null,Object? label = null,}) {
  return _then(_VideoFilterChoice(
value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$VideoFilterSchema {

 Map<String, List<VideoFilterChoice>> get options; Map<String, List<VideoFilterChoice>> get tagGroups; List<String> get years; bool get customDate;
/// Create a copy of VideoFilterSchema
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoFilterSchemaCopyWith<VideoFilterSchema> get copyWith => _$VideoFilterSchemaCopyWithImpl<VideoFilterSchema>(this as VideoFilterSchema, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as VideoFilterSchema;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoFilterSchema&&const DeepCollectionEquality().equals(other.options, _this.options)&&const DeepCollectionEquality().equals(other.tagGroups, _this.tagGroups)&&const DeepCollectionEquality().equals(other.years, _this.years)&&(identical(other.customDate, _this.customDate) || other.customDate == _this.customDate));
}


@override
int get hashCode {
  final _this = this as VideoFilterSchema;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.options),const DeepCollectionEquality().hash(_this.tagGroups),const DeepCollectionEquality().hash(_this.years),_this.customDate);
}

@override
String toString() {
  final _this = this as VideoFilterSchema;
  return 'VideoFilterSchema(options: ${_this.options}, tagGroups: ${_this.tagGroups}, years: ${_this.years}, customDate: ${_this.customDate})';
}


}

/// @nodoc
abstract mixin class $VideoFilterSchemaCopyWith<$Res>  {
  factory $VideoFilterSchemaCopyWith(VideoFilterSchema value, $Res Function(VideoFilterSchema) _then) = _$VideoFilterSchemaCopyWithImpl;
@useResult
$Res call({
 Map<String, List<VideoFilterChoice>> options, Map<String, List<VideoFilterChoice>> tagGroups, List<String> years, bool customDate
});




}
/// @nodoc
class _$VideoFilterSchemaCopyWithImpl<$Res>
    implements $VideoFilterSchemaCopyWith<$Res> {
  _$VideoFilterSchemaCopyWithImpl(this._self, this._then);

  final VideoFilterSchema _self;
  final $Res Function(VideoFilterSchema) _then;

/// Create a copy of VideoFilterSchema
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? options = null,Object? tagGroups = null,Object? years = null,Object? customDate = null,}) {
  return _then(VideoFilterSchema(
options: null == options ? _self.options : options // ignore: cast_nullable_to_non_nullable
as Map<String, List<VideoFilterChoice>>,tagGroups: null == tagGroups ? _self.tagGroups : tagGroups // ignore: cast_nullable_to_non_nullable
as Map<String, List<VideoFilterChoice>>,years: null == years ? _self.years : years // ignore: cast_nullable_to_non_nullable
as List<String>,customDate: null == customDate ? _self.customDate : customDate // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [VideoFilterSchema].
extension VideoFilterSchemaPatterns on VideoFilterSchema {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VideoFilterSchema value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VideoFilterSchema() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VideoFilterSchema value)  $default,){
final _that = this;
switch (_that) {
case _VideoFilterSchema():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VideoFilterSchema value)?  $default,){
final _that = this;
switch (_that) {
case _VideoFilterSchema() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, List<VideoFilterChoice>> options,  Map<String, List<VideoFilterChoice>> tagGroups,  List<String> years,  bool customDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VideoFilterSchema() when $default != null:
return $default(_that.options,_that.tagGroups,_that.years,_that.customDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, List<VideoFilterChoice>> options,  Map<String, List<VideoFilterChoice>> tagGroups,  List<String> years,  bool customDate)  $default,) {final _that = this;
switch (_that) {
case _VideoFilterSchema():
return $default(_that.options,_that.tagGroups,_that.years,_that.customDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, List<VideoFilterChoice>> options,  Map<String, List<VideoFilterChoice>> tagGroups,  List<String> years,  bool customDate)?  $default,) {final _that = this;
switch (_that) {
case _VideoFilterSchema() when $default != null:
return $default(_that.options,_that.tagGroups,_that.years,_that.customDate);case _:
  return null;

}
}

}

/// @nodoc


class _VideoFilterSchema extends VideoFilterSchema {
  const _VideoFilterSchema({ Map<String, List<VideoFilterChoice>> options = const {},  Map<String, List<VideoFilterChoice>> tagGroups = const {},  List<String> years = const [], this.customDate = false}): _options = options,_tagGroups = tagGroups,_years = years,super._();
  

 final  Map<String, List<VideoFilterChoice>> _options;
@override@JsonKey() Map<String, List<VideoFilterChoice>> get options {
  if (_options is EqualUnmodifiableMapView) return _options;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_options);
}

 final  Map<String, List<VideoFilterChoice>> _tagGroups;
@override@JsonKey() Map<String, List<VideoFilterChoice>> get tagGroups {
  if (_tagGroups is EqualUnmodifiableMapView) return _tagGroups;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_tagGroups);
}

 final  List<String> _years;
@override@JsonKey() List<String> get years {
  if (_years is EqualUnmodifiableListView) return _years;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_years);
}

@override@JsonKey() final  bool customDate;

/// Create a copy of VideoFilterSchema
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoFilterSchemaCopyWith<_VideoFilterSchema> get copyWith => __$VideoFilterSchemaCopyWithImpl<_VideoFilterSchema>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoFilterSchema&&const DeepCollectionEquality().equals(other.options, _options)&&const DeepCollectionEquality().equals(other.tagGroups, _tagGroups)&&const DeepCollectionEquality().equals(other.years, _years)&&(identical(other.customDate, customDate) || other.customDate == customDate));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_options),const DeepCollectionEquality().hash(_tagGroups),const DeepCollectionEquality().hash(_years),customDate);
}

@override
String toString() {
    return 'VideoFilterSchema(options: $options, tagGroups: $tagGroups, years: $years, customDate: $customDate)';
}


}

/// @nodoc
abstract mixin class _$VideoFilterSchemaCopyWith<$Res> implements $VideoFilterSchemaCopyWith<$Res> {
  factory _$VideoFilterSchemaCopyWith(_VideoFilterSchema value, $Res Function(_VideoFilterSchema) _then) = __$VideoFilterSchemaCopyWithImpl;
@override @useResult
$Res call({
 Map<String, List<VideoFilterChoice>> options, Map<String, List<VideoFilterChoice>> tagGroups, List<String> years, bool customDate
});




}
/// @nodoc
class __$VideoFilterSchemaCopyWithImpl<$Res>
    implements _$VideoFilterSchemaCopyWith<$Res> {
  __$VideoFilterSchemaCopyWithImpl(this._self, this._then);

  final _VideoFilterSchema _self;
  final $Res Function(_VideoFilterSchema) _then;

/// Create a copy of VideoFilterSchema
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? options = null,Object? tagGroups = null,Object? years = null,Object? customDate = null,}) {
  return _then(_VideoFilterSchema(
options: null == options ? _self._options : options // ignore: cast_nullable_to_non_nullable
as Map<String, List<VideoFilterChoice>>,tagGroups: null == tagGroups ? _self._tagGroups : tagGroups // ignore: cast_nullable_to_non_nullable
as Map<String, List<VideoFilterChoice>>,years: null == years ? _self._years : years // ignore: cast_nullable_to_non_nullable
as List<String>,customDate: null == customDate ? _self.customDate : customDate // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
