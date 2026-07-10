import 'package:flutter/foundation.dart';
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
      final raw = await _supabase.rpc(
        'create_lead_tx',
        params: {
          'p_provider_id': providerId,
          'p_message': message,
        },
      );

      final data = Map<String, dynamic>.from(raw as Map);
      final error = data['error'] as String?;
      if (error != null) {
        throw Exception(error);
      }

      return CreateLeadResult.fromJson(data);
    } catch (e) {
      debugPrint('LeadsService.createLead error: $e');
      if (e is Exception && !e.toString().startsWith('Exception: Failed to create lead')) {
        rethrow;
      }
      throw Exception('Failed to create lead: $e');
    }
  }

  Future<UpdateLeadResult> updateLeadStatus({
    required String leadId,
    required String status,
  }) async {
    try {
      final raw = await _supabase.rpc(
        'update_lead_status_tx',
        params: {
          'p_lead_id': leadId,
          'p_status': status,
        },
      );

      final data = Map<String, dynamic>.from(raw as Map);
      final error = data['error'] as String?;
      if (error != null) {
        throw Exception(error);
      }

      return UpdateLeadResult.fromJson(data);
    } catch (e) {
      debugPrint('LeadsService.updateLeadStatus error: $e');
      if (e is Exception && !e.toString().startsWith('Exception: Failed to update lead')) {
        rethrow;
      }
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
          debugPrint('LeadsService: Error fetching client profiles: $e');
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

  /// Accepted leads where current user is provider (for inviting to video sessions).
  Future<List<Lead>> getAcceptedLeadsAsProvider() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      final response = await _supabase
          .from('leads')
          .select('*')
          .eq('provider_id', userId)
          .eq('status', 'accepted')
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
          debugPrint('LeadsService: Error fetching client profiles: $e');
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
      throw Exception('Failed to fetch accepted leads: $e');
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
          debugPrint('LeadsService: Error fetching client profiles: $e');
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
