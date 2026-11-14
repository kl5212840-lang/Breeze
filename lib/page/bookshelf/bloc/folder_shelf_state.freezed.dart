// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'folder_shelf_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FolderShelfState {

 ShelfPageMode get mode; String get currentPath; List<ComicFolder> get folders; Map<String, ComicShelfFolderCount> get folderCounts; List<ComicSimplifyEntryInfo> get comics; Map<String, String> get comicSearchTexts; ShelfFacetSelection get facets; Map<String, String> get comicFolderLabels; SearchStatusState? get search; bool get isLoading; String? get error; String? get actionMessage; int get actionRevision; bool get sortAscending; bool get selectionMode; Set<String> get selectedFolderPaths; Set<String> get selectedComicKeys;
/// Create a copy of FolderShelfState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FolderShelfStateCopyWith<FolderShelfState> get copyWith => _$FolderShelfStateCopyWithImpl<FolderShelfState>(this as FolderShelfState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as FolderShelfState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FolderShelfState&&(identical(other.mode, _this.mode) || other.mode == _this.mode)&&(identical(other.currentPath, _this.currentPath) || other.currentPath == _this.currentPath)&&const DeepCollectionEquality().equals(other.folders, _this.folders)&&const DeepCollectionEquality().equals(other.folderCounts, _this.folderCounts)&&const DeepCollectionEquality().equals(other.comics, _this.comics)&&const DeepCollectionEquality().equals(other.comicSearchTexts, _this.comicSearchTexts)&&(identical(other.facets, _this.facets) || other.facets == _this.facets)&&const DeepCollectionEquality().equals(other.comicFolderLabels, _this.comicFolderLabels)&&(identical(other.search, _this.search) || other.search == _this.search)&&(identical(other.isLoading, _this.isLoading) || other.isLoading == _this.isLoading)&&(identical(other.error, _this.error) || other.error == _this.error)&&(identical(other.actionMessage, _this.actionMessage) || other.actionMessage == _this.actionMessage)&&(identical(other.actionRevision, _this.actionRevision) || other.actionRevision == _this.actionRevision)&&(identical(other.sortAscending, _this.sortAscending) || other.sortAscending == _this.sortAscending)&&(identical(other.selectionMode, _this.selectionMode) || other.selectionMode == _this.selectionMode)&&const DeepCollectionEquality().equals(other.selectedFolderPaths, _this.selectedFolderPaths)&&const DeepCollectionEquality().equals(other.selectedComicKeys, _this.selectedComicKeys));
}


@override
int get hashCode {
  final _this = this as FolderShelfState;
  return Object.hash(runtimeType,_this.mode,_this.currentPath,const DeepCollectionEquality().hash(_this.folders),const DeepCollectionEquality().hash(_this.folderCounts),const DeepCollectionEquality().hash(_this.comics),const DeepCollectionEquality().hash(_this.comicSearchTexts),_this.facets,const DeepCollectionEquality().hash(_this.comicFolderLabels),_this.search,_this.isLoading,_this.error,_this.actionMessage,_this.actionRevision,_this.sortAscending,_this.selectionMode,const DeepCollectionEquality().hash(_this.selectedFolderPaths),const DeepCollectionEquality().hash(_this.selectedComicKeys));
}

@override
String toString() {
  final _this = this as FolderShelfState;
  return 'FolderShelfState(mode: ${_this.mode}, currentPath: ${_this.currentPath}, folders: ${_this.folders}, folderCounts: ${_this.folderCounts}, comics: ${_this.comics}, comicSearchTexts: ${_this.comicSearchTexts}, facets: ${_this.facets}, comicFolderLabels: ${_this.comicFolderLabels}, search: ${_this.search}, isLoading: ${_this.isLoading}, error: ${_this.error}, actionMessage: ${_this.actionMessage}, actionRevision: ${_this.actionRevision}, sortAscending: ${_this.sortAscending}, selectionMode: ${_this.selectionMode}, selectedFolderPaths: ${_this.selectedFolderPaths}, selectedComicKeys: ${_this.selectedComicKeys})';
}


}

/// @nodoc
abstract mixin class $FolderShelfStateCopyWith<$Res>  {
  factory $FolderShelfStateCopyWith(FolderShelfState value, $Res Function(FolderShelfState) _then) = _$FolderShelfStateCopyWithImpl;
@useResult
$Res call({
 ShelfPageMode mode, String currentPath, List<ComicFolder> folders, Map<String, ComicShelfFolderCount> folderCounts, List<ComicSimplifyEntryInfo> comics, Map<String, String> comicSearchTexts, ShelfFacetSelection facets, Map<String, String> comicFolderLabels, SearchStatusState? search, bool isLoading, String? error, String? actionMessage, int actionRevision, bool sortAscending, bool selectionMode, Set<String> selectedFolderPaths, Set<String> selectedComicKeys
});


$ShelfFacetSelectionCopyWith<$Res> get facets;$SearchStatusStateCopyWith<$Res>? get search;

}
/// @nodoc
class _$FolderShelfStateCopyWithImpl<$Res>
    implements $FolderShelfStateCopyWith<$Res> {
  _$FolderShelfStateCopyWithImpl(this._self, this._then);

  final FolderShelfState _self;
  final $Res Function(FolderShelfState) _then;

/// Create a copy of FolderShelfState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mode = null,Object? currentPath = null,Object? folders = null,Object? folderCounts = null,Object? comics = null,Object? comicSearchTexts = null,Object? facets = null,Object? comicFolderLabels = null,Object? search = freezed,Object? isLoading = null,Object? error = freezed,Object? actionMessage = freezed,Object? actionRevision = null,Object? sortAscending = null,Object? selectionMode = null,Object? selectedFolderPaths = null,Object? selectedComicKeys = null,}) {
  return _then(FolderShelfState(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as ShelfPageMode,currentPath: null == currentPath ? _self.currentPath : currentPath // ignore: cast_nullable_to_non_nullable
as String,folders: null == folders ? _self.folders : folders // ignore: cast_nullable_to_non_nullable
as List<ComicFolder>,folderCounts: null == folderCounts ? _self.folderCounts : folderCounts // ignore: cast_nullable_to_non_nullable
as Map<String, ComicShelfFolderCount>,comics: null == comics ? _self.comics : comics // ignore: cast_nullable_to_non_nullable
as List<ComicSimplifyEntryInfo>,comicSearchTexts: null == comicSearchTexts ? _self.comicSearchTexts : comicSearchTexts // ignore: cast_nullable_to_non_nullable
as Map<String, String>,facets: null == facets ? _self.facets : facets // ignore: cast_nullable_to_non_nullable
as ShelfFacetSelection,comicFolderLabels: null == comicFolderLabels ? _self.comicFolderLabels : comicFolderLabels // ignore: cast_nullable_to_non_nullable
as Map<String, String>,search: freezed == search ? _self.search : search // ignore: cast_nullable_to_non_nullable
as SearchStatusState?,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,actionMessage: freezed == actionMessage ? _self.actionMessage : actionMessage // ignore: cast_nullable_to_non_nullable
as String?,actionRevision: null == actionRevision ? _self.actionRevision : actionRevision // ignore: cast_nullable_to_non_nullable
as int,sortAscending: null == sortAscending ? _self.sortAscending : sortAscending // ignore: cast_nullable_to_non_nullable
as bool,selectionMode: null == selectionMode ? _self.selectionMode : selectionMode // ignore: cast_nullable_to_non_nullable
as bool,selectedFolderPaths: null == selectedFolderPaths ? _self.selectedFolderPaths : selectedFolderPaths // ignore: cast_nullable_to_non_nullable
as Set<String>,selectedComicKeys: null == selectedComicKeys ? _self.selectedComicKeys : selectedComicKeys // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}
/// Create a copy of FolderShelfState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ShelfFacetSelectionCopyWith<$Res> get facets {

  return $ShelfFacetSelectionCopyWith<$Res>(_self.facets, (value) {
    return _then(_self.copyWith(facets: value));
  });
}/// Create a copy of FolderShelfState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SearchStatusStateCopyWith<$Res>? get search {
    if (_self.search == null) {
    return null;
  }

  return $SearchStatusStateCopyWith<$Res>(_self.search!, (value) {
    return _then(_self.copyWith(search: value));
  });
}
}


/// Adds pattern-matching-related methods to [FolderShelfState].
extension FolderShelfStatePatterns on FolderShelfState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FolderShelfState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FolderShelfState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FolderShelfState value)  $default,){
final _that = this;
switch (_that) {
case _FolderShelfState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FolderShelfState value)?  $default,){
final _that = this;
switch (_that) {
case _FolderShelfState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ShelfPageMode mode,  String currentPath,  List<ComicFolder> folders,  Map<String, ComicShelfFolderCount> folderCounts,  List<ComicSimplifyEntryInfo> comics,  Map<String, String> comicSearchTexts,  ShelfFacetSelection facets,  Map<String, String> comicFolderLabels,  SearchStatusState? search,  bool isLoading,  String? error,  String? actionMessage,  int actionRevision,  bool sortAscending,  bool selectionMode,  Set<String> selectedFolderPaths,  Set<String> selectedComicKeys)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FolderShelfState() when $default != null:
return $default(_that.mode,_that.currentPath,_that.folders,_that.folderCounts,_that.comics,_that.comicSearchTexts,_that.facets,_that.comicFolderLabels,_that.search,_that.isLoading,_that.error,_that.actionMessage,_that.actionRevision,_that.sortAscending,_that.selectionMode,_that.selectedFolderPaths,_that.selectedComicKeys);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ShelfPageMode mode,  String currentPath,  List<ComicFolder> folders,  Map<String, ComicShelfFolderCount> folderCounts,  List<ComicSimplifyEntryInfo> comics,  Map<String, String> comicSearchTexts,  ShelfFacetSelection facets,  Map<String, String> comicFolderLabels,  SearchStatusState? search,  bool isLoading,  String? error,  String? actionMessage,  int actionRevision,  bool sortAscending,  bool selectionMode,  Set<String> selectedFolderPaths,  Set<String> selectedComicKeys)  $default,) {final _that = this;
switch (_that) {
case _FolderShelfState():
return $default(_that.mode,_that.currentPath,_that.folders,_that.folderCounts,_that.comics,_that.comicSearchTexts,_that.facets,_that.comicFolderLabels,_that.search,_that.isLoading,_that.error,_that.actionMessage,_that.actionRevision,_that.sortAscending,_that.selectionMode,_that.selectedFolderPaths,_that.selectedComicKeys);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ShelfPageMode mode,  String currentPath,  List<ComicFolder> folders,  Map<String, ComicShelfFolderCount> folderCounts,  List<ComicSimplifyEntryInfo> comics,  Map<String, String> comicSearchTexts,  ShelfFacetSelection facets,  Map<String, String> comicFolderLabels,  SearchStatusState? search,  bool isLoading,  String? error,  String? actionMessage,  int actionRevision,  bool sortAscending,  bool selectionMode,  Set<String> selectedFolderPaths,  Set<String> selectedComicKeys)?  $default,) {final _that = this;
switch (_that) {
case _FolderShelfState() when $default != null:
return $default(_that.mode,_that.currentPath,_that.folders,_that.folderCounts,_that.comics,_that.comicSearchTexts,_that.facets,_that.comicFolderLabels,_that.search,_that.isLoading,_that.error,_that.actionMessage,_that.actionRevision,_that.sortAscending,_that.selectionMode,_that.selectedFolderPaths,_that.selectedComicKeys);case _:
  return null;

}
}

}

/// @nodoc


class _FolderShelfState extends FolderShelfState {
  const _FolderShelfState({required this.mode, this.currentPath = kFolderShelfRootPath,  List<ComicFolder> folders = const <ComicFolder>[],  Map<String, ComicShelfFolderCount> folderCounts = const <String, ComicShelfFolderCount>{},  List<ComicSimplifyEntryInfo> comics = const <ComicSimplifyEntryInfo>[],  Map<String, String> comicSearchTexts = const <String, String>{}, this.facets = const ShelfFacetSelection(),  Map<String, String> comicFolderLabels = const <String, String>{}, this.search, this.isLoading = false, this.error, this.actionMessage, this.actionRevision = 0, this.sortAscending = false, this.selectionMode = false,  Set<String> selectedFolderPaths = const <String>{},  Set<String> selectedComicKeys = const <String>{}}): _folders = folders,_folderCounts = folderCounts,_comics = comics,_comicSearchTexts = comicSearchTexts,_comicFolderLabels = comicFolderLabels,_selectedFolderPaths = selectedFolderPaths,_selectedComicKeys = selectedComicKeys,super._();
  

@override final  ShelfPageMode mode;
@override@JsonKey() final  String currentPath;
 final  List<ComicFolder> _folders;
@override@JsonKey() List<ComicFolder> get folders {
  if (_folders is EqualUnmodifiableListView) return _folders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_folders);
}

 final  Map<String, ComicShelfFolderCount> _folderCounts;
@override@JsonKey() Map<String, ComicShelfFolderCount> get folderCounts {
  if (_folderCounts is EqualUnmodifiableMapView) return _folderCounts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_folderCounts);
}

 final  List<ComicSimplifyEntryInfo> _comics;
@override@JsonKey() List<ComicSimplifyEntryInfo> get comics {
  if (_comics is EqualUnmodifiableListView) return _comics;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_comics);
}

 final  Map<String, String> _comicSearchTexts;
@override@JsonKey() Map<String, String> get comicSearchTexts {
  if (_comicSearchTexts is EqualUnmodifiableMapView) return _comicSearchTexts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_comicSearchTexts);
}

@override@JsonKey() final  ShelfFacetSelection facets;
 final  Map<String, String> _comicFolderLabels;
@override@JsonKey() Map<String, String> get comicFolderLabels {
  if (_comicFolderLabels is EqualUnmodifiableMapView) return _comicFolderLabels;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_comicFolderLabels);
}

@override final  SearchStatusState? search;
@override@JsonKey() final  bool isLoading;
@override final  String? error;
@override final  String? actionMessage;
@override@JsonKey() final  int actionRevision;
@override@JsonKey() final  bool sortAscending;
@override@JsonKey() final  bool selectionMode;
 final  Set<String> _selectedFolderPaths;
@override@JsonKey() Set<String> get selectedFolderPaths {
  if (_selectedFolderPaths is EqualUnmodifiableSetView) return _selectedFolderPaths;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_selectedFolderPaths);
}

 final  Set<String> _selectedComicKeys;
@override@JsonKey() Set<String> get selectedComicKeys {
  if (_selectedComicKeys is EqualUnmodifiableSetView) return _selectedComicKeys;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_selectedComicKeys);
}


/// Create a copy of FolderShelfState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FolderShelfStateCopyWith<_FolderShelfState> get copyWith => __$FolderShelfStateCopyWithImpl<_FolderShelfState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FolderShelfState&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.currentPath, currentPath) || other.currentPath == currentPath)&&const DeepCollectionEquality().equals(other.folders, _folders)&&const DeepCollectionEquality().equals(other.folderCounts, _folderCounts)&&const DeepCollectionEquality().equals(other.comics, _comics)&&const DeepCollectionEquality().equals(other.comicSearchTexts, _comicSearchTexts)&&(identical(other.facets, facets) || other.facets == facets)&&const DeepCollectionEquality().equals(other.comicFolderLabels, _comicFolderLabels)&&(identical(other.search, search) || other.search == search)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.error, error) || other.error == error)&&(identical(other.actionMessage, actionMessage) || other.actionMessage == actionMessage)&&(identical(other.actionRevision, actionRevision) || other.actionRevision == actionRevision)&&(identical(other.sortAscending, sortAscending) || other.sortAscending == sortAscending)&&(identical(other.selectionMode, selectionMode) || other.selectionMode == selectionMode)&&const DeepCollectionEquality().equals(other.selectedFolderPaths, _selectedFolderPaths)&&const DeepCollectionEquality().equals(other.selectedComicKeys, _selectedComicKeys));
}


@override
int get hashCode {
    return Object.hash(runtimeType,mode,currentPath,const DeepCollectionEquality().hash(_folders),const DeepCollectionEquality().hash(_folderCounts),const DeepCollectionEquality().hash(_comics),const DeepCollectionEquality().hash(_comicSearchTexts),facets,const DeepCollectionEquality().hash(_comicFolderLabels),search,isLoading,error,actionMessage,actionRevision,sortAscending,selectionMode,const DeepCollectionEquality().hash(_selectedFolderPaths),const DeepCollectionEquality().hash(_selectedComicKeys));
}

@override
String toString() {
    return 'FolderShelfState(mode: $mode, currentPath: $currentPath, folders: $folders, folderCounts: $folderCounts, comics: $comics, comicSearchTexts: $comicSearchTexts, facets: $facets, comicFolderLabels: $comicFolderLabels, search: $search, isLoading: $isLoading, error: $error, actionMessage: $actionMessage, actionRevision: $actionRevision, sortAscending: $sortAscending, selectionMode: $selectionMode, selectedFolderPaths: $selectedFolderPaths, selectedComicKeys: $selectedComicKeys)';
}


}

/// @nodoc
abstract mixin class _$FolderShelfStateCopyWith<$Res> implements $FolderShelfStateCopyWith<$Res> {
  factory _$FolderShelfStateCopyWith(_FolderShelfState value, $Res Function(_FolderShelfState) _then) = __$FolderShelfStateCopyWithImpl;
@override @useResult
$Res call({
 ShelfPageMode mode, String currentPath, List<ComicFolder> folders, Map<String, ComicShelfFolderCount> folderCounts, List<ComicSimplifyEntryInfo> comics, Map<String, String> comicSearchTexts, ShelfFacetSelection facets, Map<String, String> comicFolderLabels, SearchStatusState? search, bool isLoading, String? error, String? actionMessage, int actionRevision, bool sortAscending, bool selectionMode, Set<String> selectedFolderPaths, Set<String> selectedComicKeys
});


@override $ShelfFacetSelectionCopyWith<$Res> get facets;@override $SearchStatusStateCopyWith<$Res>? get search;

}
/// @nodoc
class __$FolderShelfStateCopyWithImpl<$Res>
    implements _$FolderShelfStateCopyWith<$Res> {
  __$FolderShelfStateCopyWithImpl(this._self, this._then);

  final _FolderShelfState _self;
  final $Res Function(_FolderShelfState) _then;

/// Create a copy of FolderShelfState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mode = null,Object? currentPath = null,Object? folders = null,Object? folderCounts = null,Object? comics = null,Object? comicSearchTexts = null,Object? facets = null,Object? comicFolderLabels = null,Object? search = freezed,Object? isLoading = null,Object? error = freezed,Object? actionMessage = freezed,Object? actionRevision = null,Object? sortAscending = null,Object? selectionMode = null,Object? selectedFolderPaths = null,Object? selectedComicKeys = null,}) {
  return _then(_FolderShelfState(
mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as ShelfPageMode,currentPath: null == currentPath ? _self.currentPath : currentPath // ignore: cast_nullable_to_non_nullable
as String,folders: null == folders ? _self._folders : folders // ignore: cast_nullable_to_non_nullable
as List<ComicFolder>,folderCounts: null == folderCounts ? _self._folderCounts : folderCounts // ignore: cast_nullable_to_non_nullable
as Map<String, ComicShelfFolderCount>,comics: null == comics ? _self._comics : comics // ignore: cast_nullable_to_non_nullable
as List<ComicSimplifyEntryInfo>,comicSearchTexts: null == comicSearchTexts ? _self._comicSearchTexts : comicSearchTexts // ignore: cast_nullable_to_non_nullable
as Map<String, String>,facets: null == facets ? _self.facets : facets // ignore: cast_nullable_to_non_nullable
as ShelfFacetSelection,comicFolderLabels: null == comicFolderLabels ? _self._comicFolderLabels : comicFolderLabels // ignore: cast_nullable_to_non_nullable
as Map<String, String>,search: freezed == search ? _self.search : search // ignore: cast_nullable_to_non_nullable
as SearchStatusState?,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,actionMessage: freezed == actionMessage ? _self.actionMessage : actionMessage // ignore: cast_nullable_to_non_nullable
as String?,actionRevision: null == actionRevision ? _self.actionRevision : actionRevision // ignore: cast_nullable_to_non_nullable
as int,sortAscending: null == sortAscending ? _self.sortAscending : sortAscending // ignore: cast_nullable_to_non_nullable
as bool,selectionMode: null == selectionMode ? _self.selectionMode : selectionMode // ignore: cast_nullable_to_non_nullable
as bool,selectedFolderPaths: null == selectedFolderPaths ? _self._selectedFolderPaths : selectedFolderPaths // ignore: cast_nullable_to_non_nullable
as Set<String>,selectedComicKeys: null == selectedComicKeys ? _self._selectedComicKeys : selectedComicKeys // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}

/// Create a copy of FolderShelfState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ShelfFacetSelectionCopyWith<$Res> get facets {

  return $ShelfFacetSelectionCopyWith<$Res>(_self.facets, (value) {
    return _then(_self.copyWith(facets: value));
  });
}/// Create a copy of FolderShelfState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SearchStatusStateCopyWith<$Res>? get search {
    if (_self.search == null) {
    return null;
  }

  return $SearchStatusStateCopyWith<$Res>(_self.search!, (value) {
    return _then(_self.copyWith(search: value));
  });
}
}

// dart format on
