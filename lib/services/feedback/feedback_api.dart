import 'package:supabase_flutter/supabase_flutter.dart';
import 'feedback_models.dart';

class FeedbackApi {
  FeedbackApi(this.client);
  final SupabaseClient client;
  String? get currentUserId => client.auth.currentUser?.id;

  Future<void> registerPushDevice(String installation, String secret, String token, String project) async {
    await client.rpc('feedback_register_push_device', params: {
      'p_installation': installation, 'p_secret': secret, 'p_token': token, 'p_project': project,
    });
  }

  Future<void> unregisterPushDevice(String installation, String secret) async {
    await client.rpc('feedback_unregister_push_device', params: {'p_installation': installation, 'p_secret': secret});
  }

  Future<List<FeedbackIssueState>> issueStates(String userId, {String? after}) async {
    var query = client.from('feedback_issue_states').select().eq('user_id', userId);
    if (after != null) query = query.gt('issue_id', after);
    return (await query.order('issue_id').limit(500)).map(FeedbackIssueState.fromJson).toList();
  }

  Future<FeedbackIssueState> markRead(String issueId, int through) async =>
      FeedbackIssueState.fromJson(Map<String, dynamic>.from(await client.rpc(
        'feedback_mark_read', params: {'p_issue': issueId, 'p_through': through},
      ) as Map));

  Future<FeedbackIssueState> setUnreadPreference(String issueId, String preference) async =>
      FeedbackIssueState.fromJson(Map<String, dynamic>.from(await client.rpc(
        'feedback_set_unread_preference', params: {'p_issue': issueId, 'p_preference': preference},
      ) as Map));

  Future<List<Map<String, dynamic>>> rows(String rpc, Map<String, dynamic> params) async =>
      List<Map<String, dynamic>>.from(await client.rpc(rpc, params: params) as List);

  Future<FeedbackPermissions> context({String? issueId, String? target}) async =>
      FeedbackPermissions.fromJson(Map<String, dynamic>.from(await client.rpc('feedback_context', params: {'p_issue': issueId, 'p_target': target}) as Map));

  Future<List<FeedbackIssue>> issues({required String search, required bool mine, required String sort,
    required bool ascending, FeedbackIssue? cursor}) async => (await rows('feedback_issue_page', {
      'p_search': search, 'p_mine': mine, 'p_sort': sort, 'p_ascending': ascending,
      'p_cursor_time': cursor == null ? null : (sort == 'created' ? cursor.createdAt : cursor.lastMessageAt).toUtc().toIso8601String(),
      'p_cursor_id': cursor?.id,
    })).map(FeedbackIssue.fromJson).toList();

  Future<FeedbackIssue> issue(String id) async => FeedbackIssue.fromJson(
      await client.from('feedback_issues').select().eq('id', id).single());

  Future<List<FeedbackMessage>> messages(String issueId, {int? before, int? after, int limit = 30}) async =>
      (await rows('feedback_message_page', {'p_issue': issueId, 'p_before': before, 'p_after': after, 'p_limit': limit}))
          .map(FeedbackMessage.fromJson).toList();

  Future<FeedbackMessage?> message(String issueId, int id) async {
    final json = await client.from('feedback_messages').select().eq('issue_id', issueId).eq('id', id).maybeSingle();
    return json == null ? null : FeedbackMessage.fromJson(json);
  }

  Future<List<FeedbackProfile>> profiles(Iterable<String> ids) async {
    final unique = ids.toSet().toList();
    final result = <FeedbackProfile>[];
    for (var offset = 0; offset < unique.length; offset += 500) {
      final end = (offset + 500).clamp(0, unique.length);
      result.addAll((await rows('feedback_profiles', {'p_ids': unique.sublist(offset, end)})).map(FeedbackProfile.fromJson));
    }
    return result;
  }

  Future<List<FeedbackProfile>> participants(String issueId, {String search = '', String? after}) async =>
      (await rows('feedback_participants', {'p_issue': issueId, 'p_search': search, 'p_after': after, 'p_limit': 30}))
          .map(FeedbackProfile.fromJson).toList();

  Future<bool> canWithdraw(int messageId) async =>
      await client.rpc('feedback_can_withdraw', params: {'p_message': messageId}) == true;

  Future<List<Map<String, dynamic>>> withdrawalAudit(int messageId) =>
      rows('feedback_withdrawal_audit', {'p_message': messageId});

  Future<Map<String, dynamic>> action(String action, Map<String, dynamic> data) async =>
      Map<String, dynamic>.from(await client.rpc('feedback_action', params: {'p_action': action, 'p_data': data}) as Map);
}
