import 'package:flutter/material.dart';

import '../../controllers/routeController.dart';
import '../../services/startup_tips_service.dart';

class SettingsTipsPage extends StatelessWidget {
  const SettingsTipsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tip'),
        leading: BackButton(onPressed: routerPop),
      ),
      body: ValueListenableBuilder<List<String>>(
        valueListenable: startupTipsService.tips,
        builder: (context, tips, _) {
          if (tips.isEmpty) {
            return const Center(child: Text('暂无Tip'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: tips.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) => ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: Text(tips[index]),
            ),
          );
        },
      ),
    );
  }
}
