// This is a generated file - do not edit.
//
// Generated from dm.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// 弹幕分段拉取返回结果
class DmSegMobileReply extends $pb.GeneratedMessage {
  factory DmSegMobileReply({
    $core.Iterable<DanmuElem>? elems,
  }) {
    final result = create();
    if (elems != null) result.elems.addAll(elems);
    return result;
  }

  DmSegMobileReply._();

  factory DmSegMobileReply.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DmSegMobileReply.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DmSegMobileReply',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.community.service.dm.v1'),
      createEmptyInstance: create)
    ..pPM<DanmuElem>(1, _omitFieldNames ? '' : 'elems',
        subBuilder: DanmuElem.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DmSegMobileReply clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DmSegMobileReply copyWith(void Function(DmSegMobileReply) updates) =>
      super.copyWith((message) => updates(message as DmSegMobileReply))
          as DmSegMobileReply;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DmSegMobileReply create() => DmSegMobileReply._();
  @$core.override
  DmSegMobileReply createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DmSegMobileReply getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DmSegMobileReply>(create);
  static DmSegMobileReply? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<DanmuElem> get elems => $_getList(0);
}

/// 单条弹幕详情
class DanmuElem extends $pb.GeneratedMessage {
  factory DanmuElem({
    $fixnum.Int64? id,
    $core.int? progress,
    $core.int? mode,
    $core.int? size,
    $core.int? color,
    $core.String? uhash,
    $core.String? text,
    $fixnum.Int64? date,
    $core.int? weight,
    $core.String? action,
    $core.int? pool,
    $core.String? dmid,
    $core.int? attr,
    $core.String? animation,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (progress != null) result.progress = progress;
    if (mode != null) result.mode = mode;
    if (size != null) result.size = size;
    if (color != null) result.color = color;
    if (uhash != null) result.uhash = uhash;
    if (text != null) result.text = text;
    if (date != null) result.date = date;
    if (weight != null) result.weight = weight;
    if (action != null) result.action = action;
    if (pool != null) result.pool = pool;
    if (dmid != null) result.dmid = dmid;
    if (attr != null) result.attr = attr;
    if (animation != null) result.animation = animation;
    return result;
  }

  DanmuElem._();

  factory DanmuElem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DanmuElem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DanmuElem',
      package: const $pb.PackageName(
          _omitMessageNames ? '' : 'bilibili.community.service.dm.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..aI(2, _omitFieldNames ? '' : 'progress')
    ..aI(3, _omitFieldNames ? '' : 'mode')
    ..aI(4, _omitFieldNames ? '' : 'size')
    ..aI(5, _omitFieldNames ? '' : 'color', fieldType: $pb.PbFieldType.OU3)
    ..aOS(6, _omitFieldNames ? '' : 'uhash')
    ..aOS(7, _omitFieldNames ? '' : 'text')
    ..aInt64(8, _omitFieldNames ? '' : 'date')
    ..aI(9, _omitFieldNames ? '' : 'weight')
    ..aOS(10, _omitFieldNames ? '' : 'action')
    ..aI(11, _omitFieldNames ? '' : 'pool')
    ..aOS(12, _omitFieldNames ? '' : 'dmid')
    ..aI(13, _omitFieldNames ? '' : 'attr')
    ..aOS(14, _omitFieldNames ? '' : 'animation')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DanmuElem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DanmuElem copyWith(void Function(DanmuElem) updates) =>
      super.copyWith((message) => updates(message as DanmuElem)) as DanmuElem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DanmuElem create() => DanmuElem._();
  @$core.override
  DanmuElem createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DanmuElem getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DanmuElem>(create);
  static DanmuElem? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get progress => $_getIZ(1);
  @$pb.TagNumber(2)
  set progress($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProgress() => $_has(1);
  @$pb.TagNumber(2)
  void clearProgress() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get mode => $_getIZ(2);
  @$pb.TagNumber(3)
  set mode($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMode() => $_has(2);
  @$pb.TagNumber(3)
  void clearMode() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get size => $_getIZ(3);
  @$pb.TagNumber(4)
  set size($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSize() => $_has(3);
  @$pb.TagNumber(4)
  void clearSize() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get color => $_getIZ(4);
  @$pb.TagNumber(5)
  set color($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasColor() => $_has(4);
  @$pb.TagNumber(5)
  void clearColor() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get uhash => $_getSZ(5);
  @$pb.TagNumber(6)
  set uhash($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasUhash() => $_has(5);
  @$pb.TagNumber(6)
  void clearUhash() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get text => $_getSZ(6);
  @$pb.TagNumber(7)
  set text($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasText() => $_has(6);
  @$pb.TagNumber(7)
  void clearText() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get date => $_getI64(7);
  @$pb.TagNumber(8)
  set date($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasDate() => $_has(7);
  @$pb.TagNumber(8)
  void clearDate() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get weight => $_getIZ(8);
  @$pb.TagNumber(9)
  set weight($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasWeight() => $_has(8);
  @$pb.TagNumber(9)
  void clearWeight() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get action => $_getSZ(9);
  @$pb.TagNumber(10)
  set action($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasAction() => $_has(9);
  @$pb.TagNumber(10)
  void clearAction() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get pool => $_getIZ(10);
  @$pb.TagNumber(11)
  set pool($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasPool() => $_has(10);
  @$pb.TagNumber(11)
  void clearPool() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get dmid => $_getSZ(11);
  @$pb.TagNumber(12)
  set dmid($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasDmid() => $_has(11);
  @$pb.TagNumber(12)
  void clearDmid() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.int get attr => $_getIZ(12);
  @$pb.TagNumber(13)
  set attr($core.int value) => $_setSignedInt32(12, value);
  @$pb.TagNumber(13)
  $core.bool hasAttr() => $_has(12);
  @$pb.TagNumber(13)
  void clearAttr() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.String get animation => $_getSZ(13);
  @$pb.TagNumber(14)
  set animation($core.String value) => $_setString(13, value);
  @$pb.TagNumber(14)
  $core.bool hasAnimation() => $_has(13);
  @$pb.TagNumber(14)
  void clearAnimation() => $_clearField(14);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
