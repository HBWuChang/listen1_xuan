class FeedbackPushTarget {
  const FeedbackPushTarget({required this.issueId, required this.userId, required this.messageId});
  final String issueId, userId;
  final int messageId;
  String get key => '$userId:$issueId:$messageId';
  static final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

  static FeedbackPushTarget? parse(Map<dynamic, dynamic> data) {
    final issue = data['issue_id'], user = data['user_id'];
    final message = int.tryParse('${data['message_id']}');
    if (data['kind'] != 'feedback_message' || issue is! String || user is! String ||
        !_uuid.hasMatch(issue) || !_uuid.hasMatch(user) || message == null || message <= 0) {
      return null;
    }
    return FeedbackPushTarget(issueId: issue, userId: user, messageId: message);
  }
}
