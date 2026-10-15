import 'package:flutter/foundation.dart';

DateTime feedbackDate(dynamic value) => DateTime.parse(value as String).toLocal();

class FeedbackProfile {
  FeedbackProfile.fromJson(Map<String, dynamic> json)
      : id = json['user_id'] as String,
        nickname = json['nickname'] as String?,
        isPro = json['is_pro'] == true,
        lastLogin = json['last_login_at'] == null ? null : feedbackDate(json['last_login_at']);
  final String id;
  final String? nickname;
  final bool isPro;
  final DateTime? lastLogin;
  String get name => nickname?.trim().isNotEmpty == true ? nickname! : '用户 ${id.substring(0, 8)}';
}

class FeedbackIssue {
  FeedbackIssue.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        creatorId = json['creator_id'] as String,
        title = json['title'] as String,
        description = json['description'] as String,
        status = json['status'] as String,
        locked = json['locked'] == true,
        createdAt = feedbackDate(json['created_at']),
        lastMessageAt = feedbackDate(json['last_message_at']);
  final String id, creatorId, title, description, status;
  final bool locked;
  final DateTime createdAt, lastMessageAt;
  String get statusLabel => const {'open': '开启', 'declined': '不予处理', 'completed': '已完成'}[status] ?? status;
}

class FeedbackMessage {
  FeedbackMessage.fromJson(Map<String, dynamic> json)
      : id = (json['id'] as num).toInt(),
        issueId = json['issue_id'] as String,
        senderId = json['sender_id'] as String,
        body = json['body'] as String?,
        mentions = List<String>.from(json['mentions'] as List? ?? const []),
        mentionAll = json['mention_all'] == true,
        replyTo = (json['reply_to'] as num?)?.toInt(),
        createdAt = feedbackDate(json['created_at']),
        withdrawnAt = json['withdrawn_at'] == null ? null : feedbackDate(json['withdrawn_at']);
  final int id;
  final String issueId, senderId;
  final String? body;
  final List<String> mentions;
  final bool mentionAll;
  final int? replyTo;
  final DateTime createdAt;
  final DateTime? withdrawnAt;
  bool get withdrawn => withdrawnAt != null;
  String get text => withdrawn ? '该消息已被撤回' : body ?? '';
}

@immutable
class FeedbackPermissions {
  const FeedbackPermissions({this.userId, this.isAdmin = false, this.isCreator = false,
    this.globalBanned = false, this.issueBanned = false, this.targetProtected = false,
    this.targetIssueBanned = false, this.targetGlobalBanned = false, this.canGlobalBan = false});
  factory FeedbackPermissions.fromJson(Map<String, dynamic> json) => FeedbackPermissions(
    userId: json['user_id'] as String?, isAdmin: json['is_admin'] == true,
    isCreator: json['is_creator'] == true, globalBanned: json['global_banned'] == true,
    issueBanned: json['issue_banned'] == true, targetProtected: json['target_protected'] == true,
    targetIssueBanned: json['target_issue_banned'] == true, targetGlobalBanned: json['target_global_banned'] == true,
    canGlobalBan: json['can_global_ban'] == true);
  final String? userId;
  final bool isAdmin, isCreator, globalBanned, issueBanned, targetProtected, targetIssueBanned, targetGlobalBanned, canGlobalBan;
  bool get canManage => isAdmin || isCreator;
  bool canSend(FeedbackIssue issue) => userId != null &&
      (isAdmin || (!globalBanned && !issueBanned && (!issue.locked || isCreator)));
}

/// Prefer a tombstone over an older HTTP snapshot racing with Realtime.
List<FeedbackMessage> mergeFeedbackMessages(Iterable<FeedbackMessage> current, Iterable<FeedbackMessage> incoming) {
  final byId = {for (final message in current) message.id: message};
  for (final message in incoming) {
    if (byId[message.id]?.withdrawn == true && !message.withdrawn) continue;
    byId[message.id] = message;
  }
  return byId.values.toList()..sort((a, b) => b.id.compareTo(a.id));
}
