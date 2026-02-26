// This is a generated file - do not edit.
//
// Generated from dm.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use dmSegMobileReplyDescriptor instead')
const DmSegMobileReply$json = {
  '1': 'DmSegMobileReply',
  '2': [
    {
      '1': 'elems',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.bilibili.community.service.dm.v1.DanmuElem',
      '10': 'elems'
    },
  ],
};

/// Descriptor for `DmSegMobileReply`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dmSegMobileReplyDescriptor = $convert.base64Decode(
    'ChBEbVNlZ01vYmlsZVJlcGx5EkEKBWVsZW1zGAEgAygLMisuYmlsaWJpbGkuY29tbXVuaXR5Ln'
    'NlcnZpY2UuZG0udjEuRGFubXVFbGVtUgVlbGVtcw==');

@$core.Deprecated('Use danmuElemDescriptor instead')
const DanmuElem$json = {
  '1': 'DanmuElem',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
    {'1': 'progress', '3': 2, '4': 1, '5': 5, '10': 'progress'},
    {'1': 'mode', '3': 3, '4': 1, '5': 5, '10': 'mode'},
    {'1': 'size', '3': 4, '4': 1, '5': 5, '10': 'size'},
    {'1': 'color', '3': 5, '4': 1, '5': 13, '10': 'color'},
    {'1': 'uhash', '3': 6, '4': 1, '5': 9, '10': 'uhash'},
    {'1': 'text', '3': 7, '4': 1, '5': 9, '10': 'text'},
    {'1': 'date', '3': 8, '4': 1, '5': 3, '10': 'date'},
    {'1': 'weight', '3': 9, '4': 1, '5': 5, '10': 'weight'},
    {'1': 'action', '3': 10, '4': 1, '5': 9, '10': 'action'},
    {'1': 'pool', '3': 11, '4': 1, '5': 5, '10': 'pool'},
    {'1': 'dmid', '3': 12, '4': 1, '5': 9, '10': 'dmid'},
    {'1': 'attr', '3': 13, '4': 1, '5': 5, '10': 'attr'},
    {'1': 'animation', '3': 14, '4': 1, '5': 9, '10': 'animation'},
  ],
};

/// Descriptor for `DanmuElem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List danmuElemDescriptor = $convert.base64Decode(
    'CglEYW5tdUVsZW0SDgoCaWQYASABKANSAmlkEhoKCHByb2dyZXNzGAIgASgFUghwcm9ncmVzcx'
    'ISCgRtb2RlGAMgASgFUgRtb2RlEhIKBHNpemUYBCABKAVSBHNpemUSFAoFY29sb3IYBSABKA1S'
    'BWNvbG9yEhQKBXVoYXNoGAYgASgJUgV1aGFzaBISCgR0ZXh0GAcgASgJUgR0ZXh0EhIKBGRhdG'
    'UYCCABKANSBGRhdGUSFgoGd2VpZ2h0GAkgASgFUgZ3ZWlnaHQSFgoGYWN0aW9uGAogASgJUgZh'
    'Y3Rpb24SEgoEcG9vbBgLIAEoBVIEcG9vbBISCgRkbWlkGAwgASgJUgRkbWlkEhIKBGF0dHIYDS'
    'ABKAVSBGF0dHISHAoJYW5pbWF0aW9uGA4gASgJUglhbmltYXRpb24=');
