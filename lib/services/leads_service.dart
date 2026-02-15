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
            provider:providers!leads_provider_id_fkey(
              user_id,
              provider_type,
              verified,
              rating
            )
          ''')
          .or('client_id.eq.$userId,provider_id.eq.$userId')
          .order('created_at', ascending: false);

      final leads = (response as List).cast<Map<String, dynamic>>();
      if (leads.isEmpty) return leads.map((json) => Lead.fromJson(json)).toList();

      final clientIds = leads
          .map((l) => l['client_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      final profilesMap = <String, Map<String, dynamic>>{};
      if (clientIds.isNotEmpty) {
        try {
          final profilesResponse = await _supabase.rpc(
            'get_public_profiles',
            params: {'p_user_ids': clientIds},
          );
          for (final p in profilesResponse as List) {
            final m = p as Map<String, dynamic>;
            profilesMap[m['id'] as String] = {
              'id': m['id'],
              'full_name': m['full_name'],
              'avatar_url': m['avatar_url'],
            };
          }
        } catch (e) {
          print('LeadsService: Error fetching client profiles: $e');
        }
      }

      return leads.map((json) {
        final enriched = Map<String, dynamic>.from(json);
        final cid = json['client_id'] as String?;
        if (cid != null && profilesMap.containsKey(cid)) {
          enriched['client'] = profilesMap[cid];
        }
        return Lead.fromJson(enriched);
      }).toList();
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
          .select('*')
          .eq('provider_id', userId)
          .eq('status', 'requested')
          .order('created_at', ascending: false);

      final leads = (response as List).cast<Map<String, dynamic>>();
      if (leads.isEmpty) return leads.map((json) => Lead.fromJson(json)).toList();

      final clientIds = leads
          .map((l) => l['client_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      final profilesMap = <String, Map<String, dynamic>>{};
      if (clientIds.isNotEmpty) {
        try {
          final profilesResponse = await _supabase.rpc(
            'get_public_profiles',
            params: {'p_user_ids': clientIds},
          );
          for (final p in profilesResponse as List) {
            final m = p as Map<String, dynamic>;
            profilesMap[m['id'] as String] = {
              'id': m['id'],
              'full_name': m['full_name'],
              'avatar_url': m['avatar_url'],
            };
          }
        } catch (e) {
          print('LeadsService: Error fetching client profiles: $e');
        }
      }

      return leads.map((json) {
        final enriched = Map<String, dynamic>.from(json);
        final cid = json['client_id'] as String?;
        if (cid != null && profilesMap.containsKey(cid)) {
          enriched['client'] = profilesMap[cid];
        }
        return Lead.fromJson(enriched);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch incoming leads: $e');
    }
  }
}

