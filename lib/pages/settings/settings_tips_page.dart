import 'package:super_sliver_list/super_sliver_list.dart';
import 'package:listen1_xuan/widgets/page_scroll_to_top.dart';
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
          return PageScrollToTop(superList: true, topInset: 16, builder: (context, pageScrollController, pageListController) => SuperListView.separated(
          controller: pageScrollController,
          listController: pageListController,
            padding: const EdgeInsets.all(16),
            itemCount: tips.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) => ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: Text(tips[index]),
            ),
          ));
        },
      ),
    );
  }
}
