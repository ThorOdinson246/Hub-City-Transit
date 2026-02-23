// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'stop_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$StopModel {

 int get stopId; String get location; double get lat; double get lng; String get direction;
/// Create a copy of StopModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StopModelCopyWith<StopModel> get copyWith => _$StopModelCopyWithImpl<StopModel>(this as StopModel, _$identity);

  /// Serializes this StopModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StopModel&&(identical(other.stopId, stopId) || other.stopId == stopId)&&(identical(other.location, location) || other.location == location)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.direction, direction) || other.direction == direction));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,stopId,location,lat,lng,direction);

@override
String toString() {
  return 'StopModel(stopId: $stopId, location: $location, lat: $lat, lng: $lng, direction: $direction)';
}


}

/// @nodoc
abstract mixin class $StopModelCopyWith<$Res>  {
  factory $StopModelCopyWith(StopModel value, $Res Function(StopModel) _then) = _$StopModelCopyWithImpl;
@useResult
$Res call({
 int stopId, String location, double lat, double lng, String direction
});




}
/// @nodoc
class _$StopModelCopyWithImpl<$Res>
    implements $StopModelCopyWith<$Res> {
  _$StopModelCopyWithImpl(this._self, this._then);

  final StopModel _self;
  final $Res Function(StopModel) _then;

/// Create a copy of StopModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? stopId = null,Object? location = null,Object? lat = null,Object? lng = null,Object? direction = null,}) {
  return _then(_self.copyWith(
stopId: null == stopId ? _self.stopId : stopId // ignore: cast_nullable_to_non_nullable
as int,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [StopModel].
extension StopModelPatterns on StopModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StopModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StopModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StopModel value)  $default,){
final _that = this;
switch (_that) {
case _StopModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StopModel value)?  $default,){
final _that = this;
switch (_that) {
case _StopModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int stopId,  String location,  double lat,  double lng,  String direction)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StopModel() when $default != null:
return $default(_that.stopId,_that.location,_that.lat,_that.lng,_that.direction);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int stopId,  String location,  double lat,  double lng,  String direction)  $default,) {final _that = this;
switch (_that) {
case _StopModel():
return $default(_that.stopId,_that.location,_that.lat,_that.lng,_that.direction);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int stopId,  String location,  double lat,  double lng,  String direction)?  $default,) {final _that = this;
switch (_that) {
case _StopModel() when $default != null:
return $default(_that.stopId,_that.location,_that.lat,_that.lng,_that.direction);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StopModel implements StopModel {
  const _StopModel({required this.stopId, required this.location, required this.lat, required this.lng, required this.direction});
  factory _StopModel.fromJson(Map<String, dynamic> json) => _$StopModelFromJson(json);

@override final  int stopId;
@override final  String location;
@override final  double lat;
@override final  double lng;
@override final  String direction;

/// Create a copy of StopModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StopModelCopyWith<_StopModel> get copyWith => __$StopModelCopyWithImpl<_StopModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StopModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StopModel&&(identical(other.stopId, stopId) || other.stopId == stopId)&&(identical(other.location, location) || other.location == location)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.direction, direction) || other.direction == direction));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,stopId,location,lat,lng,direction);

@override
String toString() {
  return 'StopModel(stopId: $stopId, location: $location, lat: $lat, lng: $lng, direction: $direction)';
}


}

/// @nodoc
abstract mixin class _$StopModelCopyWith<$Res> implements $StopModelCopyWith<$Res> {
  factory _$StopModelCopyWith(_StopModel value, $Res Function(_StopModel) _then) = __$StopModelCopyWithImpl;
@override @useResult
$Res call({
 int stopId, String location, double lat, double lng, String direction
});




}
/// @nodoc
class __$StopModelCopyWithImpl<$Res>
    implements _$StopModelCopyWith<$Res> {
  __$StopModelCopyWithImpl(this._self, this._then);

  final _StopModel _self;
  final $Res Function(_StopModel) _then;

/// Create a copy of StopModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? stopId = null,Object? location = null,Object? lat = null,Object? lng = null,Object? direction = null,}) {
  return _then(_StopModel(
stopId: null == stopId ? _self.stopId : stopId // ignore: cast_nullable_to_non_nullable
as int,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,direction: null == direction ? _self.direction : direction // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
