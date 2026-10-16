import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/routeController.dart';
import '../../router/image_toolbox_predictive_transitions.dart';
import 'feedback_binding.dart';
import 'feedback_page.dart';
import 'feedback_route_args.dart';

/// Shares the application's navigator, themed transitions and route bookkeeping.
Route<dynamic>? buildFeedbackRoute(RouteSettings settings, {List<GetMiddleware>? middlewares}) {
  final provided = settings.arguments;
  final args = provided is FeedbackPageArgs ? provided :
      settings.name == RouteName.onlineFeedbackPage ? FeedbackPageArgs.issues() : null;
  if (args == null || settings.name != args.path) return null;
  final route = ThemedGetPageRoute(
    settings: settings,
    binding: FeedbackBinding(args),
    transition: Transition.rightToLeft,
    middlewares: middlewares ?? [ListenPopMiddleware()],
    page: () => switch (args.kind) {
      FeedbackPageKind.issues => FeedbackPage(args: args),
      FeedbackPageKind.messages => FeedbackIssuePage(args: args),
      FeedbackPageKind.profile => FeedbackProfilePage(args: args),
    },
  );
  addAndCleanReapeatRoute(route, args.path);
  return route;
}
