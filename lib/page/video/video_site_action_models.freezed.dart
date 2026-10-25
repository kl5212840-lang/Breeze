// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'video_site_action_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VideoInteractionState {

 VideoSiteActor get actor; Map<VideoSiteAction, VideoActionCapability> get capabilities; bool? get liked; bool? get disliked; int? get positiveVotes; int? get negativeVotes; int? get totalVotes; bool? get following; bool? get watchLater;
/// Create a copy of VideoInteractionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoInteractionStateCopyWith<VideoInteractionState> get copyWith => _$VideoInteractionStateCopyWithImpl<VideoInteractionState>(this as VideoInteractionState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as VideoInteractionState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoInteractionState&&(identical(other.actor, _this.actor) || other.actor == _this.actor)&&const DeepCollectionEquality().equals(other.capabilities, _this.capabilities)&&(identical(other.liked, _this.liked) || other.liked == _this.liked)&&(identical(other.disliked, _this.disliked) || other.disliked == _this.disliked)&&(identical(other.positiveVotes, _this.positiveVotes) || other.positiveVotes == _this.positiveVotes)&&(identical(other.negativeVotes, _this.negativeVotes) || other.negativeVotes == _this.negativeVotes)&&(identical(other.totalVotes, _this.totalVotes) || other.totalVotes == _this.totalVotes)&&(identical(other.following, _this.following) || other.following == _this.following)&&(identical(other.watchLater, _this.watchLater) || other.watchLater == _this.watchLater));
}


@override
int get hashCode {
  final _this = this as VideoInteractionState;
  return Object.hash(runtimeType,_this.actor,const DeepCollectionEquality().hash(_this.capabilities),_this.liked,_this.disliked,_this.positiveVotes,_this.negativeVotes,_this.totalVotes,_this.following,_this.watchLater);
}

@override
String toString() {
  final _this = this as VideoInteractionState;
  return 'VideoInteractionState(actor: ${_this.actor}, capabilities: ${_this.capabilities}, liked: ${_this.liked}, disliked: ${_this.disliked}, positiveVotes: ${_this.positiveVotes}, negativeVotes: ${_this.negativeVotes}, totalVotes: ${_this.totalVotes}, following: ${_this.following}, watchLater: ${_this.watchLater})';
}


}

/// @nodoc
abstract mixin class $VideoInteractionStateCopyWith<$Res>  {
  factory $VideoInteractionStateCopyWith(VideoInteractionState value, $Res Function(VideoInteractionState) _then) = _$VideoInteractionStateCopyWithImpl;
@useResult
$Res call({
 VideoSiteActor actor, Map<VideoSiteAction, VideoActionCapability> capabilities, bool? liked, bool? disliked, int? positiveVotes, int? negativeVotes, int? totalVotes, bool? following, bool? watchLater
});




}
/// @nodoc
class _$VideoInteractionStateCopyWithImpl<$Res>
    implements $VideoInteractionStateCopyWith<$Res> {
  _$VideoInteractionStateCopyWithImpl(this._self, this._then);

  final VideoInteractionState _self;
  final $Res Function(VideoInteractionState) _then;

/// Create a copy of VideoInteractionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? actor = null,Object? capabilities = null,Object? liked = freezed,Object? disliked = freezed,Object? positiveVotes = freezed,Object? negativeVotes = freezed,Object? totalVotes = freezed,Object? following = freezed,Object? watchLater = freezed,}) {
  return _then(VideoInteractionState(
actor: null == actor ? _self.actor : actor // ignore: cast_nullable_to_non_nullable
as VideoSiteActor,capabilities: null == capabilities ? _self.capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as Map<VideoSiteAction, VideoActionCapability>,liked: freezed == liked ? _self.liked : liked // ignore: cast_nullable_to_non_nullable
as bool?,disliked: freezed == disliked ? _self.disliked : disliked // ignore: cast_nullable_to_non_nullable
as bool?,positiveVotes: freezed == positiveVotes ? _self.positiveVotes : positiveVotes // ignore: cast_nullable_to_non_nullable
as int?,negativeVotes: freezed == negativeVotes ? _self.negativeVotes : negativeVotes // ignore: cast_nullable_to_non_nullable
as int?,totalVotes: freezed == totalVotes ? _self.totalVotes : totalVotes // ignore: cast_nullable_to_non_nullable
as int?,following: freezed == following ? _self.following : following // ignore: cast_nullable_to_non_nullable
as bool?,watchLater: freezed == watchLater ? _self.watchLater : watchLater // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [VideoInteractionState].
extension VideoInteractionStatePatterns on VideoInteractionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VideoInteractionState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VideoInteractionState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VideoInteractionState value)  $default,){
final _that = this;
switch (_that) {
case _VideoInteractionState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VideoInteractionState value)?  $default,){
final _that = this;
switch (_that) {
case _VideoInteractionState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( VideoSiteActor actor,  Map<VideoSiteAction, VideoActionCapability> capabilities,  bool? liked,  bool? disliked,  int? positiveVotes,  int? negativeVotes,  int? totalVotes,  bool? following,  bool? watchLater)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VideoInteractionState() when $default != null:
return $default(_that.actor,_that.capabilities,_that.liked,_that.disliked,_that.positiveVotes,_that.negativeVotes,_that.totalVotes,_that.following,_that.watchLater);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( VideoSiteActor actor,  Map<VideoSiteAction, VideoActionCapability> capabilities,  bool? liked,  bool? disliked,  int? positiveVotes,  int? negativeVotes,  int? totalVotes,  bool? following,  bool? watchLater)  $default,) {final _that = this;
switch (_that) {
case _VideoInteractionState():
return $default(_that.actor,_that.capabilities,_that.liked,_that.disliked,_that.positiveVotes,_that.negativeVotes,_that.totalVotes,_that.following,_that.watchLater);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( VideoSiteActor actor,  Map<VideoSiteAction, VideoActionCapability> capabilities,  bool? liked,  bool? disliked,  int? positiveVotes,  int? negativeVotes,  int? totalVotes,  bool? following,  bool? watchLater)?  $default,) {final _that = this;
switch (_that) {
case _VideoInteractionState() when $default != null:
return $default(_that.actor,_that.capabilities,_that.liked,_that.disliked,_that.positiveVotes,_that.negativeVotes,_that.totalVotes,_that.following,_that.watchLater);case _:
  return null;

}
}

}

/// @nodoc


class _VideoInteractionState extends VideoInteractionState {
  const _VideoInteractionState({this.actor = VideoSiteActor.unknown,  Map<VideoSiteAction, VideoActionCapability> capabilities = const {}, this.liked, this.disliked, this.positiveVotes, this.negativeVotes, this.totalVotes, this.following, this.watchLater}): _capabilities = capabilities,super._();
  

@override@JsonKey() final  VideoSiteActor actor;
 final  Map<VideoSiteAction, VideoActionCapability> _capabilities;
@override@JsonKey() Map<VideoSiteAction, VideoActionCapability> get capabilities {
  if (_capabilities is EqualUnmodifiableMapView) return _capabilities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_capabilities);
}

@override final  bool? liked;
@override final  bool? disliked;
@override final  int? positiveVotes;
@override final  int? negativeVotes;
@override final  int? totalVotes;
@override final  bool? following;
@override final  bool? watchLater;

/// Create a copy of VideoInteractionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoInteractionStateCopyWith<_VideoInteractionState> get copyWith => __$VideoInteractionStateCopyWithImpl<_VideoInteractionState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoInteractionState&&(identical(other.actor, actor) || other.actor == actor)&&const DeepCollectionEquality().equals(other.capabilities, _capabilities)&&(identical(other.liked, liked) || other.liked == liked)&&(identical(other.disliked, disliked) || other.disliked == disliked)&&(identical(other.positiveVotes, positiveVotes) || other.positiveVotes == positiveVotes)&&(identical(other.negativeVotes, negativeVotes) || other.negativeVotes == negativeVotes)&&(identical(other.totalVotes, totalVotes) || other.totalVotes == totalVotes)&&(identical(other.following, following) || other.following == following)&&(identical(other.watchLater, watchLater) || other.watchLater == watchLater));
}


@override
int get hashCode {
    return Object.hash(runtimeType,actor,const DeepCollectionEquality().hash(_capabilities),liked,disliked,positiveVotes,negativeVotes,totalVotes,following,watchLater);
}

@override
String toString() {
    return 'VideoInteractionState(actor: $actor, capabilities: $capabilities, liked: $liked, disliked: $disliked, positiveVotes: $positiveVotes, negativeVotes: $negativeVotes, totalVotes: $totalVotes, following: $following, watchLater: $watchLater)';
}


}

/// @nodoc
abstract mixin class _$VideoInteractionStateCopyWith<$Res> implements $VideoInteractionStateCopyWith<$Res> {
  factory _$VideoInteractionStateCopyWith(_VideoInteractionState value, $Res Function(_VideoInteractionState) _then) = __$VideoInteractionStateCopyWithImpl;
@override @useResult
$Res call({
 VideoSiteActor actor, Map<VideoSiteAction, VideoActionCapability> capabilities, bool? liked, bool? disliked, int? positiveVotes, int? negativeVotes, int? totalVotes, bool? following, bool? watchLater
});




}
/// @nodoc
class __$VideoInteractionStateCopyWithImpl<$Res>
    implements _$VideoInteractionStateCopyWith<$Res> {
  __$VideoInteractionStateCopyWithImpl(this._self, this._then);

  final _VideoInteractionState _self;
  final $Res Function(_VideoInteractionState) _then;

/// Create a copy of VideoInteractionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? actor = null,Object? capabilities = null,Object? liked = freezed,Object? disliked = freezed,Object? positiveVotes = freezed,Object? negativeVotes = freezed,Object? totalVotes = freezed,Object? following = freezed,Object? watchLater = freezed,}) {
  return _then(_VideoInteractionState(
actor: null == actor ? _self.actor : actor // ignore: cast_nullable_to_non_nullable
as VideoSiteActor,capabilities: null == capabilities ? _self._capabilities : capabilities // ignore: cast_nullable_to_non_nullable
as Map<VideoSiteAction, VideoActionCapability>,liked: freezed == liked ? _self.liked : liked // ignore: cast_nullable_to_non_nullable
as bool?,disliked: freezed == disliked ? _self.disliked : disliked // ignore: cast_nullable_to_non_nullable
as bool?,positiveVotes: freezed == positiveVotes ? _self.positiveVotes : positiveVotes // ignore: cast_nullable_to_non_nullable
as int?,negativeVotes: freezed == negativeVotes ? _self.negativeVotes : negativeVotes // ignore: cast_nullable_to_non_nullable
as int?,totalVotes: freezed == totalVotes ? _self.totalVotes : totalVotes // ignore: cast_nullable_to_non_nullable
as int?,following: freezed == following ? _self.following : following // ignore: cast_nullable_to_non_nullable
as bool?,watchLater: freezed == watchLater ? _self.watchLater : watchLater // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

/// @nodoc
mixin _$VideoPlaylistChoice {

 String get id; String get title; bool? get containsVideo;
/// Create a copy of VideoPlaylistChoice
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoPlaylistChoiceCopyWith<VideoPlaylistChoice> get copyWith => _$VideoPlaylistChoiceCopyWithImpl<VideoPlaylistChoice>(this as VideoPlaylistChoice, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as VideoPlaylistChoice;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoPlaylistChoice&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.containsVideo, _this.containsVideo) || other.containsVideo == _this.containsVideo));
}


@override
int get hashCode {
  final _this = this as VideoPlaylistChoice;
  return Object.hash(runtimeType,_this.id,_this.title,_this.containsVideo);
}

@override
String toString() {
  final _this = this as VideoPlaylistChoice;
  return 'VideoPlaylistChoice(id: ${_this.id}, title: ${_this.title}, containsVideo: ${_this.containsVideo})';
}


}

/// @nodoc
abstract mixin class $VideoPlaylistChoiceCopyWith<$Res>  {
  factory $VideoPlaylistChoiceCopyWith(VideoPlaylistChoice value, $Res Function(VideoPlaylistChoice) _then) = _$VideoPlaylistChoiceCopyWithImpl;
@useResult
$Res call({
 String id, String title, bool? containsVideo
});




}
/// @nodoc
class _$VideoPlaylistChoiceCopyWithImpl<$Res>
    implements $VideoPlaylistChoiceCopyWith<$Res> {
  _$VideoPlaylistChoiceCopyWithImpl(this._self, this._then);

  final VideoPlaylistChoice _self;
  final $Res Function(VideoPlaylistChoice) _then;

/// Create a copy of VideoPlaylistChoice
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? containsVideo = freezed,}) {
  return _then(VideoPlaylistChoice(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,containsVideo: freezed == containsVideo ? _self.containsVideo : containsVideo // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [VideoPlaylistChoice].
extension VideoPlaylistChoicePatterns on VideoPlaylistChoice {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VideoPlaylistChoice value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VideoPlaylistChoice() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VideoPlaylistChoice value)  $default,){
final _that = this;
switch (_that) {
case _VideoPlaylistChoice():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VideoPlaylistChoice value)?  $default,){
final _that = this;
switch (_that) {
case _VideoPlaylistChoice() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  bool? containsVideo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VideoPlaylistChoice() when $default != null:
return $default(_that.id,_that.title,_that.containsVideo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  bool? containsVideo)  $default,) {final _that = this;
switch (_that) {
case _VideoPlaylistChoice():
return $default(_that.id,_that.title,_that.containsVideo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  bool? containsVideo)?  $default,) {final _that = this;
switch (_that) {
case _VideoPlaylistChoice() when $default != null:
return $default(_that.id,_that.title,_that.containsVideo);case _:
  return null;

}
}

}

/// @nodoc


class _VideoPlaylistChoice implements VideoPlaylistChoice {
  const _VideoPlaylistChoice({required this.id, required this.title, this.containsVideo});
  

@override final  String id;
@override final  String title;
@override final  bool? containsVideo;

/// Create a copy of VideoPlaylistChoice
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoPlaylistChoiceCopyWith<_VideoPlaylistChoice> get copyWith => __$VideoPlaylistChoiceCopyWithImpl<_VideoPlaylistChoice>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoPlaylistChoice&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.containsVideo, containsVideo) || other.containsVideo == containsVideo));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,title,containsVideo);
}

@override
String toString() {
    return 'VideoPlaylistChoice(id: $id, title: $title, containsVideo: $containsVideo)';
}


}

/// @nodoc
abstract mixin class _$VideoPlaylistChoiceCopyWith<$Res> implements $VideoPlaylistChoiceCopyWith<$Res> {
  factory _$VideoPlaylistChoiceCopyWith(_VideoPlaylistChoice value, $Res Function(_VideoPlaylistChoice) _then) = __$VideoPlaylistChoiceCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, bool? containsVideo
});




}
/// @nodoc
class __$VideoPlaylistChoiceCopyWithImpl<$Res>
    implements _$VideoPlaylistChoiceCopyWith<$Res> {
  __$VideoPlaylistChoiceCopyWithImpl(this._self, this._then);

  final _VideoPlaylistChoice _self;
  final $Res Function(_VideoPlaylistChoice) _then;

/// Create a copy of VideoPlaylistChoice
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? containsVideo = freezed,}) {
  return _then(_VideoPlaylistChoice(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,containsVideo: freezed == containsVideo ? _self.containsVideo : containsVideo // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

/// @nodoc
mixin _$VideoPlaylistSelection {

 List<VideoPlaylistChoice> get lists; bool get canCreate; int? get nextPage;
/// Create a copy of VideoPlaylistSelection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoPlaylistSelectionCopyWith<VideoPlaylistSelection> get copyWith => _$VideoPlaylistSelectionCopyWithImpl<VideoPlaylistSelection>(this as VideoPlaylistSelection, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as VideoPlaylistSelection;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoPlaylistSelection&&const DeepCollectionEquality().equals(other.lists, _this.lists)&&(identical(other.canCreate, _this.canCreate) || other.canCreate == _this.canCreate)&&(identical(other.nextPage, _this.nextPage) || other.nextPage == _this.nextPage));
}


@override
int get hashCode {
  final _this = this as VideoPlaylistSelection;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.lists),_this.canCreate,_this.nextPage);
}

@override
String toString() {
  final _this = this as VideoPlaylistSelection;
  return 'VideoPlaylistSelection(lists: ${_this.lists}, canCreate: ${_this.canCreate}, nextPage: ${_this.nextPage})';
}


}

/// @nodoc
abstract mixin class $VideoPlaylistSelectionCopyWith<$Res>  {
  factory $VideoPlaylistSelectionCopyWith(VideoPlaylistSelection value, $Res Function(VideoPlaylistSelection) _then) = _$VideoPlaylistSelectionCopyWithImpl;
@useResult
$Res call({
 List<VideoPlaylistChoice> lists, bool canCreate, int? nextPage
});




}
/// @nodoc
class _$VideoPlaylistSelectionCopyWithImpl<$Res>
    implements $VideoPlaylistSelectionCopyWith<$Res> {
  _$VideoPlaylistSelectionCopyWithImpl(this._self, this._then);

  final VideoPlaylistSelection _self;
  final $Res Function(VideoPlaylistSelection) _then;

/// Create a copy of VideoPlaylistSelection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lists = null,Object? canCreate = null,Object? nextPage = freezed,}) {
  return _then(VideoPlaylistSelection(
lists: null == lists ? _self.lists : lists // ignore: cast_nullable_to_non_nullable
as List<VideoPlaylistChoice>,canCreate: null == canCreate ? _self.canCreate : canCreate // ignore: cast_nullable_to_non_nullable
as bool,nextPage: freezed == nextPage ? _self.nextPage : nextPage // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [VideoPlaylistSelection].
extension VideoPlaylistSelectionPatterns on VideoPlaylistSelection {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VideoPlaylistSelection value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VideoPlaylistSelection() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VideoPlaylistSelection value)  $default,){
final _that = this;
switch (_that) {
case _VideoPlaylistSelection():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VideoPlaylistSelection value)?  $default,){
final _that = this;
switch (_that) {
case _VideoPlaylistSelection() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<VideoPlaylistChoice> lists,  bool canCreate,  int? nextPage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VideoPlaylistSelection() when $default != null:
return $default(_that.lists,_that.canCreate,_that.nextPage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<VideoPlaylistChoice> lists,  bool canCreate,  int? nextPage)  $default,) {final _that = this;
switch (_that) {
case _VideoPlaylistSelection():
return $default(_that.lists,_that.canCreate,_that.nextPage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<VideoPlaylistChoice> lists,  bool canCreate,  int? nextPage)?  $default,) {final _that = this;
switch (_that) {
case _VideoPlaylistSelection() when $default != null:
return $default(_that.lists,_that.canCreate,_that.nextPage);case _:
  return null;

}
}

}

/// @nodoc


class _VideoPlaylistSelection implements VideoPlaylistSelection {
  const _VideoPlaylistSelection({ List<VideoPlaylistChoice> lists = const [], this.canCreate = false, this.nextPage}): _lists = lists;
  

 final  List<VideoPlaylistChoice> _lists;
@override@JsonKey() List<VideoPlaylistChoice> get lists {
  if (_lists is EqualUnmodifiableListView) return _lists;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_lists);
}

@override@JsonKey() final  bool canCreate;
@override final  int? nextPage;

/// Create a copy of VideoPlaylistSelection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoPlaylistSelectionCopyWith<_VideoPlaylistSelection> get copyWith => __$VideoPlaylistSelectionCopyWithImpl<_VideoPlaylistSelection>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoPlaylistSelection&&const DeepCollectionEquality().equals(other.lists, _lists)&&(identical(other.canCreate, canCreate) || other.canCreate == canCreate)&&(identical(other.nextPage, nextPage) || other.nextPage == nextPage));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_lists),canCreate,nextPage);
}

@override
String toString() {
    return 'VideoPlaylistSelection(lists: $lists, canCreate: $canCreate, nextPage: $nextPage)';
}


}

/// @nodoc
abstract mixin class _$VideoPlaylistSelectionCopyWith<$Res> implements $VideoPlaylistSelectionCopyWith<$Res> {
  factory _$VideoPlaylistSelectionCopyWith(_VideoPlaylistSelection value, $Res Function(_VideoPlaylistSelection) _then) = __$VideoPlaylistSelectionCopyWithImpl;
@override @useResult
$Res call({
 List<VideoPlaylistChoice> lists, bool canCreate, int? nextPage
});




}
/// @nodoc
class __$VideoPlaylistSelectionCopyWithImpl<$Res>
    implements _$VideoPlaylistSelectionCopyWith<$Res> {
  __$VideoPlaylistSelectionCopyWithImpl(this._self, this._then);

  final _VideoPlaylistSelection _self;
  final $Res Function(_VideoPlaylistSelection) _then;

/// Create a copy of VideoPlaylistSelection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lists = null,Object? canCreate = null,Object? nextPage = freezed,}) {
  return _then(_VideoPlaylistSelection(
lists: null == lists ? _self._lists : lists // ignore: cast_nullable_to_non_nullable
as List<VideoPlaylistChoice>,canCreate: null == canCreate ? _self.canCreate : canCreate // ignore: cast_nullable_to_non_nullable
as bool,nextPage: freezed == nextPage ? _self.nextPage : nextPage // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$VideoSiteComment {

 String get id; String get author; String get text; String get time; String get avatar; bool get hasReplies;
/// Create a copy of VideoSiteComment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoSiteCommentCopyWith<VideoSiteComment> get copyWith => _$VideoSiteCommentCopyWithImpl<VideoSiteComment>(this as VideoSiteComment, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as VideoSiteComment;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoSiteComment&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.text, _this.text) || other.text == _this.text)&&(identical(other.time, _this.time) || other.time == _this.time)&&(identical(other.avatar, _this.avatar) || other.avatar == _this.avatar)&&(identical(other.hasReplies, _this.hasReplies) || other.hasReplies == _this.hasReplies));
}


@override
int get hashCode {
  final _this = this as VideoSiteComment;
  return Object.hash(runtimeType,_this.id,_this.author,_this.text,_this.time,_this.avatar,_this.hasReplies);
}

@override
String toString() {
  final _this = this as VideoSiteComment;
  return 'VideoSiteComment(id: ${_this.id}, author: ${_this.author}, text: ${_this.text}, time: ${_this.time}, avatar: ${_this.avatar}, hasReplies: ${_this.hasReplies})';
}


}

/// @nodoc
abstract mixin class $VideoSiteCommentCopyWith<$Res>  {
  factory $VideoSiteCommentCopyWith(VideoSiteComment value, $Res Function(VideoSiteComment) _then) = _$VideoSiteCommentCopyWithImpl;
@useResult
$Res call({
 String id, String author, String text, String time, String avatar, bool hasReplies
});




}
/// @nodoc
class _$VideoSiteCommentCopyWithImpl<$Res>
    implements $VideoSiteCommentCopyWith<$Res> {
  _$VideoSiteCommentCopyWithImpl(this._self, this._then);

  final VideoSiteComment _self;
  final $Res Function(VideoSiteComment) _then;

/// Create a copy of VideoSiteComment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? author = null,Object? text = null,Object? time = null,Object? avatar = null,Object? hasReplies = null,}) {
  return _then(VideoSiteComment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as String,avatar: null == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as String,hasReplies: null == hasReplies ? _self.hasReplies : hasReplies // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [VideoSiteComment].
extension VideoSiteCommentPatterns on VideoSiteComment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VideoSiteComment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VideoSiteComment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VideoSiteComment value)  $default,){
final _that = this;
switch (_that) {
case _VideoSiteComment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VideoSiteComment value)?  $default,){
final _that = this;
switch (_that) {
case _VideoSiteComment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String author,  String text,  String time,  String avatar,  bool hasReplies)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VideoSiteComment() when $default != null:
return $default(_that.id,_that.author,_that.text,_that.time,_that.avatar,_that.hasReplies);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String author,  String text,  String time,  String avatar,  bool hasReplies)  $default,) {final _that = this;
switch (_that) {
case _VideoSiteComment():
return $default(_that.id,_that.author,_that.text,_that.time,_that.avatar,_that.hasReplies);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String author,  String text,  String time,  String avatar,  bool hasReplies)?  $default,) {final _that = this;
switch (_that) {
case _VideoSiteComment() when $default != null:
return $default(_that.id,_that.author,_that.text,_that.time,_that.avatar,_that.hasReplies);case _:
  return null;

}
}

}

/// @nodoc


class _VideoSiteComment implements VideoSiteComment {
  const _VideoSiteComment({this.id = '', required this.author, required this.text, this.time = '', this.avatar = '', this.hasReplies = false});
  

@override@JsonKey() final  String id;
@override final  String author;
@override final  String text;
@override@JsonKey() final  String time;
@override@JsonKey() final  String avatar;
@override@JsonKey() final  bool hasReplies;

/// Create a copy of VideoSiteComment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoSiteCommentCopyWith<_VideoSiteComment> get copyWith => __$VideoSiteCommentCopyWithImpl<_VideoSiteComment>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoSiteComment&&(identical(other.id, id) || other.id == id)&&(identical(other.author, author) || other.author == author)&&(identical(other.text, text) || other.text == text)&&(identical(other.time, time) || other.time == time)&&(identical(other.avatar, avatar) || other.avatar == avatar)&&(identical(other.hasReplies, hasReplies) || other.hasReplies == hasReplies));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,author,text,time,avatar,hasReplies);
}

@override
String toString() {
    return 'VideoSiteComment(id: $id, author: $author, text: $text, time: $time, avatar: $avatar, hasReplies: $hasReplies)';
}


}

/// @nodoc
abstract mixin class _$VideoSiteCommentCopyWith<$Res> implements $VideoSiteCommentCopyWith<$Res> {
  factory _$VideoSiteCommentCopyWith(_VideoSiteComment value, $Res Function(_VideoSiteComment) _then) = __$VideoSiteCommentCopyWithImpl;
@override @useResult
$Res call({
 String id, String author, String text, String time, String avatar, bool hasReplies
});




}
/// @nodoc
class __$VideoSiteCommentCopyWithImpl<$Res>
    implements _$VideoSiteCommentCopyWith<$Res> {
  __$VideoSiteCommentCopyWithImpl(this._self, this._then);

  final _VideoSiteComment _self;
  final $Res Function(_VideoSiteComment) _then;

/// Create a copy of VideoSiteComment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? author = null,Object? text = null,Object? time = null,Object? avatar = null,Object? hasReplies = null,}) {
  return _then(_VideoSiteComment(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,author: null == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String,text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,time: null == time ? _self.time : time // ignore: cast_nullable_to_non_nullable
as String,avatar: null == avatar ? _self.avatar : avatar // ignore: cast_nullable_to_non_nullable
as String,hasReplies: null == hasReplies ? _self.hasReplies : hasReplies // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$VideoCommentThread {

 List<VideoSiteComment> get items; bool get canPost; bool? get signedIn; String? get postGate; int? get nextOffset; String? get revision;
/// Create a copy of VideoCommentThread
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoCommentThreadCopyWith<VideoCommentThread> get copyWith => _$VideoCommentThreadCopyWithImpl<VideoCommentThread>(this as VideoCommentThread, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as VideoCommentThread;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoCommentThread&&const DeepCollectionEquality().equals(other.items, _this.items)&&(identical(other.canPost, _this.canPost) || other.canPost == _this.canPost)&&(identical(other.signedIn, _this.signedIn) || other.signedIn == _this.signedIn)&&(identical(other.postGate, _this.postGate) || other.postGate == _this.postGate)&&(identical(other.nextOffset, _this.nextOffset) || other.nextOffset == _this.nextOffset)&&(identical(other.revision, _this.revision) || other.revision == _this.revision));
}


@override
int get hashCode {
  final _this = this as VideoCommentThread;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.items),_this.canPost,_this.signedIn,_this.postGate,_this.nextOffset,_this.revision);
}

@override
String toString() {
  final _this = this as VideoCommentThread;
  return 'VideoCommentThread(items: ${_this.items}, canPost: ${_this.canPost}, signedIn: ${_this.signedIn}, postGate: ${_this.postGate}, nextOffset: ${_this.nextOffset}, revision: ${_this.revision})';
}


}

/// @nodoc
abstract mixin class $VideoCommentThreadCopyWith<$Res>  {
  factory $VideoCommentThreadCopyWith(VideoCommentThread value, $Res Function(VideoCommentThread) _then) = _$VideoCommentThreadCopyWithImpl;
@useResult
$Res call({
 List<VideoSiteComment> items, bool canPost, bool? signedIn, String? postGate, int? nextOffset, String? revision
});




}
/// @nodoc
class _$VideoCommentThreadCopyWithImpl<$Res>
    implements $VideoCommentThreadCopyWith<$Res> {
  _$VideoCommentThreadCopyWithImpl(this._self, this._then);

  final VideoCommentThread _self;
  final $Res Function(VideoCommentThread) _then;

/// Create a copy of VideoCommentThread
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? canPost = null,Object? signedIn = freezed,Object? postGate = freezed,Object? nextOffset = freezed,Object? revision = freezed,}) {
  return _then(VideoCommentThread(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<VideoSiteComment>,canPost: null == canPost ? _self.canPost : canPost // ignore: cast_nullable_to_non_nullable
as bool,signedIn: freezed == signedIn ? _self.signedIn : signedIn // ignore: cast_nullable_to_non_nullable
as bool?,postGate: freezed == postGate ? _self.postGate : postGate // ignore: cast_nullable_to_non_nullable
as String?,nextOffset: freezed == nextOffset ? _self.nextOffset : nextOffset // ignore: cast_nullable_to_non_nullable
as int?,revision: freezed == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VideoCommentThread].
extension VideoCommentThreadPatterns on VideoCommentThread {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VideoCommentThread value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VideoCommentThread() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VideoCommentThread value)  $default,){
final _that = this;
switch (_that) {
case _VideoCommentThread():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VideoCommentThread value)?  $default,){
final _that = this;
switch (_that) {
case _VideoCommentThread() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<VideoSiteComment> items,  bool canPost,  bool? signedIn,  String? postGate,  int? nextOffset,  String? revision)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VideoCommentThread() when $default != null:
return $default(_that.items,_that.canPost,_that.signedIn,_that.postGate,_that.nextOffset,_that.revision);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<VideoSiteComment> items,  bool canPost,  bool? signedIn,  String? postGate,  int? nextOffset,  String? revision)  $default,) {final _that = this;
switch (_that) {
case _VideoCommentThread():
return $default(_that.items,_that.canPost,_that.signedIn,_that.postGate,_that.nextOffset,_that.revision);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<VideoSiteComment> items,  bool canPost,  bool? signedIn,  String? postGate,  int? nextOffset,  String? revision)?  $default,) {final _that = this;
switch (_that) {
case _VideoCommentThread() when $default != null:
return $default(_that.items,_that.canPost,_that.signedIn,_that.postGate,_that.nextOffset,_that.revision);case _:
  return null;

}
}

}

/// @nodoc


class _VideoCommentThread implements VideoCommentThread {
  const _VideoCommentThread({ List<VideoSiteComment> items = const [], this.canPost = false, this.signedIn, this.postGate, this.nextOffset, this.revision}): _items = items;
  

 final  List<VideoSiteComment> _items;
@override@JsonKey() List<VideoSiteComment> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override@JsonKey() final  bool canPost;
@override final  bool? signedIn;
@override final  String? postGate;
@override final  int? nextOffset;
@override final  String? revision;

/// Create a copy of VideoCommentThread
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoCommentThreadCopyWith<_VideoCommentThread> get copyWith => __$VideoCommentThreadCopyWithImpl<_VideoCommentThread>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoCommentThread&&const DeepCollectionEquality().equals(other.items, _items)&&(identical(other.canPost, canPost) || other.canPost == canPost)&&(identical(other.signedIn, signedIn) || other.signedIn == signedIn)&&(identical(other.postGate, postGate) || other.postGate == postGate)&&(identical(other.nextOffset, nextOffset) || other.nextOffset == nextOffset)&&(identical(other.revision, revision) || other.revision == revision));
}


@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),canPost,signedIn,postGate,nextOffset,revision);
}

@override
String toString() {
    return 'VideoCommentThread(items: $items, canPost: $canPost, signedIn: $signedIn, postGate: $postGate, nextOffset: $nextOffset, revision: $revision)';
}


}

/// @nodoc
abstract mixin class _$VideoCommentThreadCopyWith<$Res> implements $VideoCommentThreadCopyWith<$Res> {
  factory _$VideoCommentThreadCopyWith(_VideoCommentThread value, $Res Function(_VideoCommentThread) _then) = __$VideoCommentThreadCopyWithImpl;
@override @useResult
$Res call({
 List<VideoSiteComment> items, bool canPost, bool? signedIn, String? postGate, int? nextOffset, String? revision
});




}
/// @nodoc
class __$VideoCommentThreadCopyWithImpl<$Res>
    implements _$VideoCommentThreadCopyWith<$Res> {
  __$VideoCommentThreadCopyWithImpl(this._self, this._then);

  final _VideoCommentThread _self;
  final $Res Function(_VideoCommentThread) _then;

/// Create a copy of VideoCommentThread
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? canPost = null,Object? signedIn = freezed,Object? postGate = freezed,Object? nextOffset = freezed,Object? revision = freezed,}) {
  return _then(_VideoCommentThread(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<VideoSiteComment>,canPost: null == canPost ? _self.canPost : canPost // ignore: cast_nullable_to_non_nullable
as bool,signedIn: freezed == signedIn ? _self.signedIn : signedIn // ignore: cast_nullable_to_non_nullable
as bool?,postGate: freezed == postGate ? _self.postGate : postGate // ignore: cast_nullable_to_non_nullable
as String?,nextOffset: freezed == nextOffset ? _self.nextOffset : nextOffset // ignore: cast_nullable_to_non_nullable
as int?,revision: freezed == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
