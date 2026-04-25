// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_schedule_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RouteScheduleModel {

 List<String> get stops; List<List<String>> get trips;
/// Create a copy of RouteScheduleModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RouteScheduleModelCopyWith<RouteScheduleModel> get copyWith => _$RouteScheduleModelCopyWithImpl<RouteScheduleModel>(this as RouteScheduleModel, _$identity);

  /// Serializes this RouteScheduleModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RouteScheduleModel&&const DeepCollectionEquality().equals(other.stops, stops)&&const DeepCollectionEquality().equals(other.trips, trips));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(stops),const DeepCollectionEquality().hash(trips));

@override
String toString() {
  return 'RouteScheduleModel(stops: $stops, trips: $trips)';
}


}

/// @nodoc
abstract mixin class $RouteScheduleModelCopyWith<$Res>  {
  factory $RouteScheduleModelCopyWith(RouteScheduleModel value, $Res Function(RouteScheduleModel) _then) = _$RouteScheduleModelCopyWithImpl;
@useResult
$Res call({
 List<String> stops, List<List<String>> trips
});




}
/// @nodoc
class _$RouteScheduleModelCopyWithImpl<$Res>
    implements $RouteScheduleModelCopyWith<$Res> {
  _$RouteScheduleModelCopyWithImpl(this._self, this._then);

  final RouteScheduleModel _self;
  final $Res Function(RouteScheduleModel) _then;

/// Create a copy of RouteScheduleModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? stops = null,Object? trips = null,}) {
  return _then(_self.copyWith(
stops: null == stops ? _self.stops : stops // ignore: cast_nullable_to_non_nullable
as List<String>,trips: null == trips ? _self.trips : trips // ignore: cast_nullable_to_non_nullable
as List<List<String>>,
  ));
}

}


/// Adds pattern-matching-related methods to [RouteScheduleModel].
extension RouteScheduleModelPatterns on RouteScheduleModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RouteScheduleModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RouteScheduleModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RouteScheduleModel value)  $default,){
final _that = this;
switch (_that) {
case _RouteScheduleModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RouteScheduleModel value)?  $default,){
final _that = this;
switch (_that) {
case _RouteScheduleModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<String> stops,  List<List<String>> trips)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RouteScheduleModel() when $default != null:
return $default(_that.stops,_that.trips);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<String> stops,  List<List<String>> trips)  $default,) {final _that = this;
switch (_that) {
case _RouteScheduleModel():
return $default(_that.stops,_that.trips);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<String> stops,  List<List<String>> trips)?  $default,) {final _that = this;
switch (_that) {
case _RouteScheduleModel() when $default != null:
return $default(_that.stops,_that.trips);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RouteScheduleModel implements RouteScheduleModel {
  const _RouteScheduleModel({required final  List<String> stops, required final  List<List<String>> trips}): _stops = stops,_trips = trips;
  factory _RouteScheduleModel.fromJson(Map<String, dynamic> json) => _$RouteScheduleModelFromJson(json);

 final  List<String> _stops;
@override List<String> get stops {
  if (_stops is EqualUnmodifiableListView) return _stops;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_stops);
}

 final  List<List<String>> _trips;
@override List<List<String>> get trips {
  if (_trips is EqualUnmodifiableListView) return _trips;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_trips);
}


/// Create a copy of RouteScheduleModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RouteScheduleModelCopyWith<_RouteScheduleModel> get copyWith => __$RouteScheduleModelCopyWithImpl<_RouteScheduleModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RouteScheduleModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RouteScheduleModel&&const DeepCollectionEquality().equals(other._stops, _stops)&&const DeepCollectionEquality().equals(other._trips, _trips));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_stops),const DeepCollectionEquality().hash(_trips));

@override
String toString() {
  return 'RouteScheduleModel(stops: $stops, trips: $trips)';
}


}

/// @nodoc
abstract mixin class _$RouteScheduleModelCopyWith<$Res> implements $RouteScheduleModelCopyWith<$Res> {
  factory _$RouteScheduleModelCopyWith(_RouteScheduleModel value, $Res Function(_RouteScheduleModel) _then) = __$RouteScheduleModelCopyWithImpl;
@override @useResult
$Res call({
 List<String> stops, List<List<String>> trips
});




}
/// @nodoc
class __$RouteScheduleModelCopyWithImpl<$Res>
    implements _$RouteScheduleModelCopyWith<$Res> {
  __$RouteScheduleModelCopyWithImpl(this._self, this._then);

  final _RouteScheduleModel _self;
  final $Res Function(_RouteScheduleModel) _then;

/// Create a copy of RouteScheduleModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? stops = null,Object? trips = null,}) {
  return _then(_RouteScheduleModel(
stops: null == stops ? _self._stops : stops // ignore: cast_nullable_to_non_nullable
as List<String>,trips: null == trips ? _self._trips : trips // ignore: cast_nullable_to_non_nullable
as List<List<String>>,
  ));
}


}

// dart format on
