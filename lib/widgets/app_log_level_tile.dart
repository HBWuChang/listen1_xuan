import 'package:flutter/material.dart';

import '../services/app_logger.dart';

class AppLogLevelTile extends StatelessWidget {
  const AppLogLevelTile({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final AppLogLevel value;
  final ValueChanged<AppLogLevel> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.bug_report_outlined),
    title: const Text('日志级别'),
    subtitle: Text('${value.label}\n立即生效并保存，可通过 flutter logs 查看'),
    trailing: const Icon(Icons.chevron_right),
    onTap: () async {
      final selected = await showDialog<AppLogLevel>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('日志级别'),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text('输出所选级别及以上的日志；关闭时不输出应用 Logger 日志。'),
            ),
            for (final level in AppLogLevel.values)
              SimpleDialogOption(
                onPressed: () => Navigator.of(context).pop(level),
                child: Row(
                  children: [
                    Expanded(child: Text(level.label)),
                    if (level == value) const Icon(Icons.check),
                  ],
                ),
              ),
          ],
        ),
      );
      if (selected != null) onChanged(selected);
    },
  );
}
