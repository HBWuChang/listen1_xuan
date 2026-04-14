import 'package:json_annotation/json_annotation.dart';

import 'a.dart';
import 'r.dart';
import 't.dart';

part 'Equalizer.g.dart';

@JsonSerializable()
/// https://ffmpeg.org/ffmpeg-filters.html#equalizer
class Equalizer {
  ///Set the filter’s central frequency in Hz.
  ///设置滤波器的中心频率（单位：赫兹）。
  int f;

  ///   Set method to specify band-width of filter.
  /// 设置方法以指定滤波器的带宽。
  WidthType t;

  ///Specify the band-width of a filter in width_type units.
  ///指定滤波器的带宽，单位为 width_type。
  double w;

  ///Set the required gain or attenuation in dB. Beware of clipping when using a positive gain.
  ///设置所需的增益或衰减（单位：dB）。使用正增益时，注意削波。
  double g;

  ///How much to use filtered signal in output. Default is 1. Range is between 0 and 1.
  ///输出中使用滤波信号的量。默认值为 1。范围在 0 到 1 之间。
  double? m;

  ///Set transform type of IIR filter.
  ///设置 IIR 滤波器的变换类型。
  Transform? a;

  ///Set precision of filtering.
  ///设置过滤的精度。
  Precision? r;

  Equalizer({
    required this.f,
    this.t = WidthType.q,
    this.w = 1,
    this.g = 0.0,
    this.m,
    this.a,
    this.r,
  });

  /// 从 JSON 创建实例
  factory Equalizer.fromJson(Map<String, dynamic> json) =>
      _$EqualizerFromJson(json);

  /// 转换为 JSON
  Map<String, dynamic> toJson() => _$EqualizerToJson(this);
  // 8.87.1 Examples  8.87.1 示例
  // Attenuate 10 dB at 1000 Hz, with a bandwidth of 200 Hz:
  // 在 1000 Hz 处衰减 10 dB，带宽为 200 Hz：
  // equalizer=f=1000:t=h:width=200:g=-10
  // Apply 2 dB gain at 1000 Hz with Q 1 and attenuate 5 dB at 100 Hz with Q 2:
  // 在 1000 Hz 处应用 2 dB 增益，Q 为 1，并在 100 Hz 处衰减 5 dB，Q 为 2：
  // equalizer=f=1000:t=q:w=1:g=2,equalizer=f=100:t=q:w=2:g=-5

  String toFilterString() {
    final params = [
      'f=$f',
      't=${t.value}',
      'width=$w',
      'g=$g',
      if (m != null) 'm=$m',
      if (a != null) 'a=${a!.value}',
      if (r != null) 'r=${r!.value}',
    ];
    return 'equalizer=${params.join(':')}';
  }

  Equalizer copyWith({
    int? f,
    WidthType? t,
    double? w,
    double? g,
    double? m,
    Transform? a,
    Precision? r,
    DateTime? createdAt,
  }) {
    return Equalizer(
      f: f ?? this.f,
      t: t ?? this.t,
      w: w ?? this.w,
      g: g ?? this.g,
      m: m ?? this.m,
      a: a ?? this.a,
      r: r ?? this.r,
    );
  }
}
