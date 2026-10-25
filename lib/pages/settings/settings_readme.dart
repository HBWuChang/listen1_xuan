import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:get/get.dart';
import 'package:listen1_xuan/controllers/routeController.dart';
import 'package:listen1_xuan/controllers/settings_controller.dart';
import 'package:listen1_xuan/services/repository_document.dart';
import 'package:listen1_xuan/settings.dart' show g_launchURL;
import 'package:listen1_xuan/widgets/page_scroll_to_top.dart';

class SettingsReadmePage extends StatelessWidget {
  const SettingsReadmePage({super.key});

  @override
  Widget build(BuildContext context) => RepositoryDocumentPage(
    title: 'README',
    document: Get.find<SettingsController>().readmeDocument,
  );
}

class SettingsChangelogPage extends StatelessWidget {
  const SettingsChangelogPage({super.key});

  @override
  Widget build(BuildContext context) => RepositoryDocumentPage(
    title: 'Changelog',
    document: Get.find<SettingsController>().changelogDocument,
  );
}

class RepositoryDocumentPage extends StatefulWidget {
  const RepositoryDocumentPage({
    super.key,
    required this.title,
    required this.document,
  });

  final String title;
  final RepositoryDocument document;

  @override
  State<RepositoryDocumentPage> createState() => _RepositoryDocumentPageState();
}

class _RepositoryDocumentPageState extends State<RepositoryDocumentPage> {
  @override
  void initState() {
    super.initState();
    widget.document.load();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.document,
    builder: (context, _) {
      final document = widget.document;
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          leading: BackButton(onPressed: routerPop),
          actions: [
            IconButton(
              tooltip: '在浏览器中打开',
              icon: const Icon(Icons.open_in_browser),
              onPressed: () => g_launchURL(document.sourceUri),
            ),
            IconButton(
              tooltip: '刷新',
              icon: const Icon(Icons.refresh),
              onPressed: document.loading
                  ? null
                  : () => document.load(force: true),
            ),
          ],
        ),
        body: Column(
          children: [
            if (document.loading && document.content != null)
              const LinearProgressIndicator(),
            if (document.error != null && document.content != null)
              MaterialBanner(
                content: Text(document.error!),
                actions: [
                  TextButton(
                    onPressed: () => document.load(force: true),
                    child: const Text('重试'),
                  ),
                ],
              ),
            Expanded(child: _buildContent(document)),
          ],
        ),
      );
    },
  );

  Widget _buildContent(RepositoryDocument document) {
    if (document.content == null) {
      if (document.loading) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(document.error ?? '暂无内容'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => document.load(force: true),
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    return PageScrollToTop(
      builder: (context, pageScrollController, pageListController) => Markdown(
        controller: pageScrollController,
        imageDirectory: document.imageDirectory,
        onTapLink: (text, href, title) {
          if (href != null) {
            g_launchURL(document.sourceUri.resolve(href));
          }
        },
        selectable: true,
        data: document.content!,
      ),
    );
  }
}
