import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/feedback_unread_controller.dart';

class FeedbackUnreadBadge extends StatelessWidget {
  const FeedbackUnreadBadge({super.key, required this.child, this.issueId});
  final Widget child;
  final String? issueId;

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<FeedbackUnreadController>()) return child;
    return GetBuilder<FeedbackUnreadController>(
      autoRemove: false,
      builder: (controller) {
        final unread = issueId == null ? controller.hasUnread : controller.unread(issueId!);
        return Semantics(
          label: unread ? '有未读反馈' : null,
          child: Badge(isLabelVisible: unread, child: child),
        );
      },
    );
  }
}
