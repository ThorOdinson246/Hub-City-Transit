// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bus_location_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BusLocationModel {

 double get lat; double get lng; String get busId; DateTime get lastSeen; double? get heading; double? get speed;
/// Create a copy of BusLocationModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BusLocationModelCopyWith<BusLocationModel> get copyWith => _$BusLocationModelCopyWithImpl<BusLocationModel>(this as BusLocationModel, _$identity);

  /// Serializes this BusLocationModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BusLocationModel&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.busId, busId) || other.busId == busId)&&(identical(other.lastSeen, lastSeen) || other.lastSeen == lastSeen)&&(identical(other.heading, heading) || other.heading == heading)&&(identical(other.speed, speed) || other.speed == speed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lat,lng,busId,lastSeen,heading,speed);

@override
String toString() {
  return 'BusLocationModel(lat: $lat, lng: $lng, busId: $busId, lastSeen: $lastSeen, heading: $heading, speed: $speed)';
}


}

/// @nodoc
abstract mixin class $BusLocationModelCopyWith<$Res>  {
  factory $BusLocationModelCopyWith(BusLocationModel value, $Res Function(BusLocationModel) _then) = _$BusLocationModelCopyWithImpl;
@useResult
$Res call({
 double lat, double lng, String busId, DateTime lastSeen, double? heading, double? speed
});




}
/// @nodoc
class _$BusLocationModelCopyWithImpl<$Res>
    implements $BusLocationModelCopyWith<$Res> {
  _$BusLocationModelCopyWithImpl(this._self, this._then);

  final BusLocationModel _self;
  final $Res Function(BusLocationModel) _then;

/// Create a copy of BusLocationModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? lat = null,Object? lng = null,Object? busId = null,Object? lastSeen = null,Object? heading = freezed,Object? speed = freezed,}) {
  return _then(_self.copyWith(
lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,busId: null == busId ? _self.busId : busId // ignore: cast_nullable_to_non_nullable
as String,lastSeen: null == lastSeen ? _self.lastSeen : lastSeen // ignore: cast_nullable_to_non_nullable
as DateTime,heading: freezed == heading ? _self.heading : heading // ignore: cast_nullable_to_non_nullable
as double?,speed: freezed == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [BusLocationModel].
extension BusLocationModelPatterns on BusLocationModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BusLocationModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BusLocationModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BusLocationModel value)  $default,){
final _that = this;
switch (_that) {
case _BusLocationModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BusLocationModel value)?  $default,){
final _that = this;
switch (_that) {
case _BusLocationModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double lat,  double lng,  String busId,  DateTime lastSeen,  double? heading,  double? speed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BusLocationModel() when $default != null:
return $default(_that.lat,_that.lng,_that.busId,_that.lastSeen,_that.heading,_that.speed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double lat,  double lng,  String busId,  DateTime lastSeen,  double? heading,  double? speed)  $default,) {final _that = this;
switch (_that) {
case _BusLocationModel():
return $default(_that.lat,_that.lng,_that.busId,_that.lastSeen,_that.heading,_that.speed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double lat,  double lng,  String busId,  DateTime lastSeen,  double? heading,  double? speed)?  $default,) {final _that = this;
switch (_that) {
case _BusLocationModel() when $default != null:
return $default(_that.lat,_that.lng,_that.busId,_that.lastSeen,_that.heading,_that.speed);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BusLocationModel implements BusLocationModel {
  const _BusLocationModel({required this.lat, required this.lng, required this.busId, required this.lastSeen, this.heading, this.speed});
  factory _BusLocationModel.fromJson(Map<String, dynamic> json) => _$BusLocationModelFromJson(json);

@override final  double lat;
@override final  double lng;
@override final  String busId;
@override final  DateTime lastSeen;
@override final  double? heading;
@override final  double? speed;

/// Create a copy of BusLocationModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BusLocationModelCopyWith<_BusLocationModel> get copyWith => __$BusLocationModelCopyWithImpl<_BusLocationModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BusLocationModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BusLocationModel&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng)&&(identical(other.busId, busId) || other.busId == busId)&&(identical(other.lastSeen, lastSeen) || other.lastSeen == lastSeen)&&(identical(other.heading, heading) || other.heading == heading)&&(identical(other.speed, speed) || other.speed == speed));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,lat,lng,busId,lastSeen,heading,speed);

@override
String toString() {
  return 'BusLocationModel(lat: $lat, lng: $lng, busId: $busId, lastSeen: $lastSeen, heading: $heading, speed: $speed)';
}


}

/// @nodoc
abstract mixin class _$BusLocationModelCopyWith<$Res> implements $BusLocationModelCopyWith<$Res> {
  factory _$BusLocationModelCopyWith(_BusLocationModel value, $Res Function(_BusLocationModel) _then) = __$BusLocationModelCopyWithImpl;
@override @useResult
$Res call({
 double lat, double lng, String busId, DateTime lastSeen, double? heading, double? speed
});




}
/// @nodoc
class __$BusLocationModelCopyWithImpl<$Res>
    implements _$BusLocationModelCopyWith<$Res> {
  __$BusLocationModelCopyWithImpl(this._self, this._then);

  final _BusLocationModel _self;
  final $Res Function(_BusLocationModel) _then;

/// Create a copy of BusLocationModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? lat = null,Object? lng = null,Object? busId = null,Object? lastSeen = null,Object? heading = freezed,Object? speed = freezed,}) {
  return _then(_BusLocationModel(
lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,busId: null == busId ? _self.busId : busId // ignore: cast_nullable_to_non_nullable
as String,lastSeen: null == lastSeen ? _self.lastSeen : lastSeen // ignore: cast_nullable_to_non_nullable
as DateTime,heading: freezed == heading ? _self.heading : heading // ignore: cast_nullable_to_non_nullable
as double?,speed: freezed == speed ? _self.speed : speed // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

// dart format on
