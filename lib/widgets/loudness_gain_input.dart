import 'package:flutter/material.dart';

class LoudnessGainInput extends StatefulWidget {
  const LoudnessGainInput({super.key, required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<LoudnessGainInput> createState() => _LoudnessGainInputState();
}

class _LoudnessGainInputState extends State<LoudnessGainInput> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextFormField(
        initialValue: widget.value.toString(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: '其他平台音量系数',
          helperText: '范围 0～1，0 为静音，1 为原音量；修改立即生效',
          errorText: _error,
        ),
        onChanged: (text) {
          final value = double.tryParse(text.trim());
          final valid = value != null && value.isFinite && value >= 0 && value <= 1;
          setState(() { _error = valid ? null : '请输入 0～1 之间的有效数字'; });
          if (valid) widget.onChanged(value);
        },
      ),
    );
  }
}
