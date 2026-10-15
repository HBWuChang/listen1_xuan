import 'package:supabase_flutter/supabase_flutter.dart';
import 'feedback_models.dart';

class FeedbackApi {
  FeedbackApi(this.client);
  final SupabaseClient client;
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
