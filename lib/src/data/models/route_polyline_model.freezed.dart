// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'route_polyline_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RoutePolylineModel {

 String get routeId; List<List<double>> get polyline;
/// Create a copy of RoutePolylineModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RoutePolylineModelCopyWith<RoutePolylineModel> get copyWith => _$RoutePolylineModelCopyWithImpl<RoutePolylineModel>(this as RoutePolylineModel, _$identity);

  /// Serializes this RoutePolylineModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RoutePolylineModel&&(identical(other.routeId, routeId) || other.routeId == routeId)&&const DeepCollectionEquality().equals(other.polyline, polyline));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,routeId,const DeepCollectionEquality().hash(polyline));

@override
String toString() {
  return 'RoutePolylineModel(routeId: $routeId, polyline: $polyline)';
}


}

/// @nodoc
abstract mixin class $RoutePolylineModelCopyWith<$Res>  {
  factory $RoutePolylineModelCopyWith(RoutePolylineModel value, $Res Function(RoutePolylineModel) _then) = _$RoutePolylineModelCopyWithImpl;
@useResult
$Res call({
 String routeId, List<List<double>> polyline
});




}
/// @nodoc
class _$RoutePolylineModelCopyWithImpl<$Res>
    implements $RoutePolylineModelCopyWith<$Res> {
  _$RoutePolylineModelCopyWithImpl(this._self, this._then);

  final RoutePolylineModel _self;
  final $Res Function(RoutePolylineModel) _then;

/// Create a copy of RoutePolylineModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? routeId = null,Object? polyline = null,}) {
  return _then(_self.copyWith(
routeId: null == routeId ? _self.routeId : routeId // ignore: cast_nullable_to_non_nullable
as String,polyline: null == polyline ? _self.polyline : polyline // ignore: cast_nullable_to_non_nullable
as List<List<double>>,
  ));
}

}


/// Adds pattern-matching-related methods to [RoutePolylineModel].
extension RoutePolylineModelPatterns on RoutePolylineModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RoutePolylineModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RoutePolylineModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RoutePolylineModel value)  $default,){
final _that = this;
switch (_that) {
case _RoutePolylineModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RoutePolylineModel value)?  $default,){
final _that = this;
switch (_that) {
case _RoutePolylineModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String routeId,  List<List<double>> polyline)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RoutePolylineModel() when $default != null:
return $default(_that.routeId,_that.polyline);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String routeId,  List<List<double>> polyline)  $default,) {final _that = this;
switch (_that) {
case _RoutePolylineModel():
return $default(_that.routeId,_that.polyline);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String routeId,  List<List<double>> polyline)?  $default,) {final _that = this;
switch (_that) {
case _RoutePolylineModel() when $default != null:
return $default(_that.routeId,_that.polyline);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RoutePolylineModel implements RoutePolylineModel {
  const _RoutePolylineModel({required this.routeId, required final  List<List<double>> polyline}): _polyline = polyline;
  factory _RoutePolylineModel.fromJson(Map<String, dynamic> json) => _$RoutePolylineModelFromJson(json);

@override final  String routeId;
 final  List<List<double>> _polyline;
@override List<List<double>> get polyline {
  if (_polyline is EqualUnmodifiableListView) return _polyline;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_polyline);
}


/// Create a copy of RoutePolylineModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RoutePolylineModelCopyWith<_RoutePolylineModel> get copyWith => __$RoutePolylineModelCopyWithImpl<_RoutePolylineModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RoutePolylineModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RoutePolylineModel&&(identical(other.routeId, routeId) || other.routeId == routeId)&&const DeepCollectionEquality().equals(other._polyline, _polyline));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,routeId,const DeepCollectionEquality().hash(_polyline));

@override
String toString() {
  return 'RoutePolylineModel(routeId: $routeId, polyline: $polyline)';
}


}

/// @nodoc
abstract mixin class _$RoutePolylineModelCopyWith<$Res> implements $RoutePolylineModelCopyWith<$Res> {
  factory _$RoutePolylineModelCopyWith(_RoutePolylineModel value, $Res Function(_RoutePolylineModel) _then) = __$RoutePolylineModelCopyWithImpl;
@override @useResult
$Res call({
 String routeId, List<List<double>> polyline
});




}
/// @nodoc
class __$RoutePolylineModelCopyWithImpl<$Res>
    implements _$RoutePolylineModelCopyWith<$Res> {
  __$RoutePolylineModelCopyWithImpl(this._self, this._then);

  final _RoutePolylineModel _self;
  final $Res Function(_RoutePolylineModel) _then;

/// Create a copy of RoutePolylineModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? routeId = null,Object? polyline = null,}) {
  return _then(_RoutePolylineModel(
routeId: null == routeId ? _self.routeId : routeId // ignore: cast_nullable_to_non_nullable
as String,polyline: null == polyline ? _self._polyline : polyline // ignore: cast_nullable_to_non_nullable
as List<List<double>>,
  ));
}


}

// dart format on
