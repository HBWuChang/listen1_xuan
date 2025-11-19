// import 'package:just_audio/just_audio.dart';

// class AndroidEQBand {
//   int index;
//   double gain;
//   double? upperFrequency;
//   double? lowerFrequency;
//   double? centerFrequency;

//   AndroidEQBand({
//     required this.index,
//     required this.gain,
//     this.upperFrequency,
//     this.lowerFrequency,
//     this.centerFrequency,
//   });
//   AndroidEQBand.fromAndroidEqualizerBand(AndroidEqualizerBand androidEQBand)
//     : index = androidEQBand.index,
//       gain = androidEQBand.gain,
//       upperFrequency = androidEQBand.upperFrequency,
//       lowerFrequency = androidEQBand.lowerFrequency,
//       centerFrequency = androidEQBand.centerFrequency;
//   factory AndroidEQBand.fromJson(Map<String, dynamic> json) {
//     return AndroidEQBand(index: json['index'], gain: json['gain']);
//   }
//   Map<String, dynamic> toJson() {
//     return {'index': index, 'gain': gain};
//   }
// }