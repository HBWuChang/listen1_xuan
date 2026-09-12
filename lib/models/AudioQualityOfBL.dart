enum AudioQualityOfBL { k64, k132, k192, dolby, hiRes }

extension AudioQualityCode on AudioQualityOfBL {
  static final List<int> _codeList = [30216, 30232, 30280, 30250, 30251];
  int get code => _codeList[index];

  static AudioQualityOfBL? fromCode(int code) {
    final index = _codeList.indexOf(code);
    if (index != -1) {
      return AudioQualityOfBL.values[index];
    }
    return null;
  }
}

extension AudioQualityDesc on AudioQualityOfBL {
  static final List<String> _descList = [
    '64K',
    '132K',
    '192K',
    '杜比全景声',
    'Hi-Res无损',
  ];
  String get description => _descList[index];
}
