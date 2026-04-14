import 'AEqualizer.dart';
import 'Equalizer.dart';
import 't.dart';

const List<int> _bandFrequencies = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];

AEqualizer _create10BandEq(List<double> gains) {
  if (gains.length != _bandFrequencies.length) {
    throw ArgumentError('gains length must be ${_bandFrequencies.length}, got ${gains.length}');
  }

  return AEqualizer(
    equalizers: List<Equalizer>.generate(
      _bandFrequencies.length,
      (i) => Equalizer(
        f: _bandFrequencies[i],
        t: WidthType.q,
        w: 1,
        g: gains[i],
      ),
    ),
  );
}

Map<String, AEqualizer> createDefEqSet() => {
  'flat': _create10BandEq([0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
  'bass_boost': _create10BandEq([4.5, 3.5, 2.5, 1.5, 0.5, 0, -1, -2, -2.5, -3]),
  'vocal': _create10BandEq([-2, -1.5, -1, 0.5, 2, 3, 3, 2, 0.5, -1]),
  'pop': _create10BandEq([-1, 1.5, 3, 3.5, 2, 0, -1, -0.5, 1.5, 2.5]),
  'rock': _create10BandEq([3, 2, 1, 0, -0.5, 0, 1.5, 2.5, 3, 3]),
  'classical': _create10BandEq([0, 0, -0.5, 0, 1.5, 2.5, 3, 2, 1, 0.5]),
  'electronic': _create10BandEq([3.5, 2.5, 1, 0, -1, 1, 2.5, 3.5, 2.5, 1.5]),
};
