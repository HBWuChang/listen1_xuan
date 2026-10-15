import '../../controllers/routeController.dart';
import '../../router/base_args.dart';
import '../../services/feedback/feedback_api.dart';
import '../../services/feedback/feedback_models.dart';

enum FeedbackPageKind { issues, messages, profile }

class FeedbackPageArgs extends BaseArgs {
  FeedbackPageArgs.issues({this.api, this.enableRealtime = true, this.proApplication = false})
      : initialText = '', initialMentions = const [], kind = FeedbackPageKind.issues, issue = null, sourceControllerTag = null, userId = null,
        controllerTag = 'feedback_list_${_nextId++}';
  FeedbackPageArgs.messages({required FeedbackIssue this.issue, required FeedbackApi this.api, this.enableRealtime = true, this.initialText = '', this.initialMentions = const []})
      : proApplication = false, kind = FeedbackPageKind.messages, sourceControllerTag = null, userId = null,
        controllerTag = 'feedback_issue_${_nextId++}';
  FeedbackPageArgs.profile({required String this.sourceControllerTag, required String this.userId})
      : proApplication = false, initialText = '', initialMentions = const [], kind = FeedbackPageKind.profile, issue = null, api = null, enableRealtime = false,
        controllerTag = 'feedback_profile_${_nextId++}';

  static int _nextId = 0;
  final bool proApplication;
  final String initialText;
  final List<FeedbackProfile> initialMentions;
  final FeedbackPageKind kind;
  final FeedbackApi? api;
  final bool enableRealtime;
  final FeedbackIssue? issue;
  final String? sourceControllerTag, userId;
  @override
  final String controllerTag;
  @override
  String get path => switch (kind) {
    FeedbackPageKind.issues => RouteName.onlineFeedbackPage,
    FeedbackPageKind.messages => '${RouteName.onlineFeedbackIssuePage}/${issue!.id}/$controllerTag',
    FeedbackPageKind.profile => '${RouteName.onlineFeedbackProfilePage}/$sourceControllerTag/$userId',
  };
}
