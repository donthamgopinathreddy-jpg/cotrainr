import 'package:supabase_flutter/supabase_flutter.dart';
import 'leads_models.dart' show Lead, CreateLeadResult, UpdateLeadResult;

class LeadsService {
  final SupabaseClient _supabase;

  LeadsService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  Future<CreateLeadResult> createLead({
    required String providerId,
    String? message,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'create-lead',
        body: {
          'provider_id': providerId,
          if (message != null) 'message': message,
        },
      );

      if (response.status != 200) {
        final error = response.data?['error'] as String? ?? 'Failed to create lead';
        throw Exception(error);
      }

      final data = response.data as Map<String, dynamic>;
      return CreateLeadResult.fromJson(data);
    } catch (e) {
      throw Exception('Failed to create lead: $e');
    }
  }

  Future<UpdateLeadResult> updateLeadStatus({
    required String leadId,
    required String status,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'update-lead-status',
        body: {
          'lead_id': leadId,
          'status': status,
        },
      );

      if (response.status != 200) {
        final error = response.data?['error'] as String? ?? 'Failed to update lead';
        throw Exception(error);
      }

      final data = response.data as Map<String, dynamic>;
      return UpdateLeadResult.fromJson(data);
    } catch (e) {
      throw Exception('Failed to update lead: $e');
    }
  }

  Future<List<Lead>> getMyLeads() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      final response = await _supabase
          .from('leads')
          .select('''
            *,
            client:profiles!leads_client_id_fkey(id, full_name, avatar_url),
            provider:providers!leads_provider_id_fkey(
              user_id,
              provider_type,
              verified,
              rating
            )
          ''')
          .or('client_id.eq.$userId,provider_id.eq.$userId')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Lead.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch leads: $e');
    }
  }

  Future<List<Lead>> getIncomingLeads() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      final response = await _supabase
          .from('leads')
          .select('''
            *,
            client:profiles!leads_client_id_fkey(id, full_name, avatar_url)
          ''')
          .eq('provider_id', userId)
          .eq('status', 'requested')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Lead.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch incoming leads: $e');
    }
  }
}

