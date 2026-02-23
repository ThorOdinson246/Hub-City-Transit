// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'eta_result_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EtaResultModel {

 int? get etaMinutes; int? get nearestStopId; String? get nearestStopName; String get busId; String get status; String? get message;
/// Create a copy of EtaResultModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EtaResultModelCopyWith<EtaResultModel> get copyWith => _$EtaResultModelCopyWithImpl<EtaResultModel>(this as EtaResultModel, _$identity);

  /// Serializes this EtaResultModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EtaResultModel&&(identical(other.etaMinutes, etaMinutes) || other.etaMinutes == etaMinutes)&&(identical(other.nearestStopId, nearestStopId) || other.nearestStopId == nearestStopId)&&(identical(other.nearestStopName, nearestStopName) || other.nearestStopName == nearestStopName)&&(identical(other.busId, busId) || other.busId == busId)&&(identical(other.status, status) || other.status == status)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,etaMinutes,nearestStopId,nearestStopName,busId,status,message);

@override
String toString() {
  return 'EtaResultModel(etaMinutes: $etaMinutes, nearestStopId: $nearestStopId, nearestStopName: $nearestStopName, busId: $busId, status: $status, message: $message)';
}


}

/// @nodoc
abstract mixin class $EtaResultModelCopyWith<$Res>  {
  factory $EtaResultModelCopyWith(EtaResultModel value, $Res Function(EtaResultModel) _then) = _$EtaResultModelCopyWithImpl;
@useResult
$Res call({
 int? etaMinutes, int? nearestStopId, String? nearestStopName, String busId, String status, String? message
});




}
/// @nodoc
class _$EtaResultModelCopyWithImpl<$Res>
    implements $EtaResultModelCopyWith<$Res> {
  _$EtaResultModelCopyWithImpl(this._self, this._then);

  final EtaResultModel _self;
  final $Res Function(EtaResultModel) _then;

/// Create a copy of EtaResultModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? etaMinutes = freezed,Object? nearestStopId = freezed,Object? nearestStopName = freezed,Object? busId = null,Object? status = null,Object? message = freezed,}) {
  return _then(_self.copyWith(
etaMinutes: freezed == etaMinutes ? _self.etaMinutes : etaMinutes // ignore: cast_nullable_to_non_nullable
as int?,nearestStopId: freezed == nearestStopId ? _self.nearestStopId : nearestStopId // ignore: cast_nullable_to_non_nullable
as int?,nearestStopName: freezed == nearestStopName ? _self.nearestStopName : nearestStopName // ignore: cast_nullable_to_non_nullable
as String?,busId: null == busId ? _self.busId : busId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [EtaResultModel].
extension EtaResultModelPatterns on EtaResultModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EtaResultModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EtaResultModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EtaResultModel value)  $default,){
final _that = this;
switch (_that) {
case _EtaResultModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EtaResultModel value)?  $default,){
final _that = this;
switch (_that) {
case _EtaResultModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? etaMinutes,  int? nearestStopId,  String? nearestStopName,  String busId,  String status,  String? message)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EtaResultModel() when $default != null:
return $default(_that.etaMinutes,_that.nearestStopId,_that.nearestStopName,_that.busId,_that.status,_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? etaMinutes,  int? nearestStopId,  String? nearestStopName,  String busId,  String status,  String? message)  $default,) {final _that = this;
switch (_that) {
case _EtaResultModel():
return $default(_that.etaMinutes,_that.nearestStopId,_that.nearestStopName,_that.busId,_that.status,_that.message);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? etaMinutes,  int? nearestStopId,  String? nearestStopName,  String busId,  String status,  String? message)?  $default,) {final _that = this;
switch (_that) {
case _EtaResultModel() when $default != null:
return $default(_that.etaMinutes,_that.nearestStopId,_that.nearestStopName,_that.busId,_that.status,_that.message);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EtaResultModel implements EtaResultModel {
  const _EtaResultModel({this.etaMinutes, this.nearestStopId, this.nearestStopName, required this.busId, required this.status, this.message});
  factory _EtaResultModel.fromJson(Map<String, dynamic> json) => _$EtaResultModelFromJson(json);

@override final  int? etaMinutes;
@override final  int? nearestStopId;
@override final  String? nearestStopName;
@override final  String busId;
@override final  String status;
@override final  String? message;

/// Create a copy of EtaResultModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EtaResultModelCopyWith<_EtaResultModel> get copyWith => __$EtaResultModelCopyWithImpl<_EtaResultModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EtaResultModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EtaResultModel&&(identical(other.etaMinutes, etaMinutes) || other.etaMinutes == etaMinutes)&&(identical(other.nearestStopId, nearestStopId) || other.nearestStopId == nearestStopId)&&(identical(other.nearestStopName, nearestStopName) || other.nearestStopName == nearestStopName)&&(identical(other.busId, busId) || other.busId == busId)&&(identical(other.status, status) || other.status == status)&&(identical(other.message, message) || other.message == message));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,etaMinutes,nearestStopId,nearestStopName,busId,status,message);

@override
String toString() {
  return 'EtaResultModel(etaMinutes: $etaMinutes, nearestStopId: $nearestStopId, nearestStopName: $nearestStopName, busId: $busId, status: $status, message: $message)';
}


}

/// @nodoc
abstract mixin class _$EtaResultModelCopyWith<$Res> implements $EtaResultModelCopyWith<$Res> {
  factory _$EtaResultModelCopyWith(_EtaResultModel value, $Res Function(_EtaResultModel) _then) = __$EtaResultModelCopyWithImpl;
@override @useResult
$Res call({
 int? etaMinutes, int? nearestStopId, String? nearestStopName, String busId, String status, String? message
});




}
/// @nodoc
class __$EtaResultModelCopyWithImpl<$Res>
    implements _$EtaResultModelCopyWith<$Res> {
  __$EtaResultModelCopyWithImpl(this._self, this._then);

  final _EtaResultModel _self;
  final $Res Function(_EtaResultModel) _then;

/// Create a copy of EtaResultModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? etaMinutes = freezed,Object? nearestStopId = freezed,Object? nearestStopName = freezed,Object? busId = null,Object? status = null,Object? message = freezed,}) {
  return _then(_EtaResultModel(
etaMinutes: freezed == etaMinutes ? _self.etaMinutes : etaMinutes // ignore: cast_nullable_to_non_nullable
as int?,nearestStopId: freezed == nearestStopId ? _self.nearestStopId : nearestStopId // ignore: cast_nullable_to_non_nullable
as int?,nearestStopName: freezed == nearestStopName ? _self.nearestStopName : nearestStopName // ignore: cast_nullable_to_non_nullable
as String?,busId: null == busId ? _self.busId : busId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
