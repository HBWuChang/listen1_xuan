import 'dart:async';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/feedback/feedback_api.dart';
import 'feedback_controller.dart';
import 'feedback_route_args.dart';

class FeedbackBinding extends Bindings {
  FeedbackBinding(this.args);
  final FeedbackPageArgs args;
  @override
  void dependencies() {
    if (args.kind == FeedbackPageKind.profile) {
      Get.put(FeedbackProfileController(args), tag: args.controllerTag);
    } else {
      Get.put(FeedbackController(
        args.api ?? FeedbackApi(Supabase.instance.client),
        enableRealtime: args.enableRealtime, initialIssue: args.issue,
      ), tag: args.controllerTag);
    }
  }
}

/// The profile route borrows its source issue without owning its messages.
class FeedbackProfileController extends GetxController {
  FeedbackProfileController(this.args);
  final FeedbackPageArgs args;
  FeedbackController get source => Get.find<FeedbackController>(tag: args.sourceControllerTag);
  @override
  void onReady() {
    super.onReady();
    if (!isClosed && Get.isRegistered<FeedbackController>(tag: args.sourceControllerTag) && !source.isClosed) {
      unawaited(source.openProfile(args.userId!));
    }
  }
  @override
  void onClose() {
    if (Get.isRegistered<FeedbackController>(tag: args.sourceControllerTag)) {
      final owner = source;
      if (!owner.isClosed && owner.profileId == args.userId) owner.closeProfile();
    }
    super.onClose();
  }
}
