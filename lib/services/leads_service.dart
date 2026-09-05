import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'leads_models.dart'
    show Lead,
        CreateLeadResult,
        UpdateLeadResult,
        EndConnectionResult,
        AcceptedTrainer,
        AcceptedProvider;

class LeadsService {
  final SupabaseClient _supabase;

  LeadsService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  static Map<String, dynamic> _publicClientProfile(Map<String, dynamic> m) {
    return {
      'id': m['id'],
      'full_name': m['full_name'],
      'username': m['username'],
      'avatar_url': m['avatar_url'],
    };
  }

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

  /// Ends an accepted connection via live RPC `end_connection_tx`.
  /// Allowance restoration is decided server-side only.
  Future<EndConnectionResult> endConnection({
    required String leadId,
    required String reason,
  }) async {
    try {
      final raw = await _supabase.rpc(
        'end_connection_tx',
        params: {
          'p_lead_id': leadId,
          // Live Wave 2A–tested param name (not p_reason).
          'p_end_reason': reason,
        },
      );

      if (raw is! Map) {
        throw Exception('Failed to end connection');
      }

      final data = Map<String, dynamic>.from(raw);
      final error = data['error'] as String?;
      if (error != null) {
        throw Exception(error);
      }
      if (data['ok'] == false) {
        final message = data['message'] as String?;
        final code = data['error_code'] as String?;
        throw Exception(
          (message != null && message.isNotEmpty)
              ? message
              : (code != null && code.isNotEmpty)
                  ? code
                  : 'Failed to end connection',
        );
      }

      return EndConnectionResult.fromJson(data);
    } catch (e) {
      debugPrint('LeadsService.endConnection error: $e');
      // Business errors from RPC JSON (`error` / `ok:false`) are already
      // Exception(message) — rethrow those. Transport/DB errors stay sanitized.
      if (e is Exception &&
          e is! PostgrestException &&
          !e.toString().startsWith('Exception: Failed to end connection')) {
        rethrow;
      }
      throw Exception('Failed to end connection');
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
            profilesMap[m['id'] as String] = _publicClientProfile(m);
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
            profilesMap[m['id'] as String] = _publicClientProfile(m);
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

  /// Accepted trainers for the signed-in client (`leads.status = accepted`).
  /// Fetch lead status map for notification action UI. Keys are lead ids.
  Future<Map<String, String>> getLeadStatusesByIds(List<String> leadIds) async {
    if (leadIds.isEmpty) return {};
    try {
      final unique = leadIds.toSet().toList();
      final response = await _supabase
          .from('leads')
          .select('id, status')
          .inFilter('id', unique);
      final map = <String, String>{};
      for (final row in (response as List).cast<Map<String, dynamic>>()) {
        final id = row['id'] as String?;
        final status = row['status'] as String?;
        if (id != null && status != null) {
          map[id] = status;
        }
      }
      return map;
    } catch (e) {
      debugPrint('LeadsService.getLeadStatusesByIds error: $e');
      return {};
    }
  }

  /// Accepted providers for the signed-in client.
  /// [providerType] when set filters to `trainer` or `nutritionist`.
  Future<List<AcceptedProvider>> getAcceptedProvidersAsClient({
    String? providerType,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Not authenticated');

      var query = _supabase
          .from('leads')
          .select('''
            id,
            client_id,
            provider_id,
            provider_type,
            status,
            created_at,
            provider:providers!leads_provider_id_fkey(
              user_id,
              provider_type,
              verified,
              rating,
              total_reviews,
              specialization,
              experience_years,
              professional_headline
            )
          ''')
          .eq('client_id', userId)
          .eq('status', 'accepted');

      if (providerType != null) {
        query = query.eq('provider_type', providerType);
      }

      final response = await query.order('created_at', ascending: false);

      final rows = (response as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) return const [];

      final providerIds = rows
          .map((r) => r['provider_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      final profilesMap = <String, Map<String, dynamic>>{};
      if (providerIds.isNotEmpty) {
        try {
          final profilesResponse = await _supabase.rpc(
            'get_public_profiles',
            params: {'p_user_ids': providerIds},
          );
          for (final p in profilesResponse as List) {
            final m = p as Map<String, dynamic>;
            profilesMap[m['id'] as String] = m;
          }
        } catch (e) {
          debugPrint('LeadsService: Error fetching provider profiles: $e');
        }
      }

      final locationMap = <String, String>{};
      if (providerIds.isNotEmpty) {
        try {
          final locs = await _supabase
              .from('provider_locations')
              .select('provider_id, display_name, location_type, is_primary')
              .inFilter('provider_id', providerIds)
              .eq('is_active', true);
          for (final raw in locs as List) {
            final loc = Map<String, dynamic>.from(raw as Map);
            final uid = loc['provider_id'] as String?;
            if (uid == null || locationMap.containsKey(uid)) continue;
            final name = (loc['display_name'] as String?)?.trim();
            if (name != null && name.isNotEmpty) {
              locationMap[uid] = name;
            } else if (loc['location_type'] != null) {
              locationMap[uid] = loc['location_type'].toString();
            }
          }
        } catch (e) {
          debugPrint('LeadsService: Error fetching provider locations: $e');
        }
      }

      return rows.map((json) {
        final providerId = json['provider_id'] as String;
        final type = json['provider_type'] as String? ?? 'trainer';
        final providerRaw = json['provider'];
        final provider = providerRaw is Map
            ? Map<String, dynamic>.from(providerRaw)
            : <String, dynamic>{};
        final profile = profilesMap[providerId];
        final specs = provider['specialization'];
        String? specLabel;
        if (specs is List && specs.isNotEmpty) {
          specLabel = specs.map((e) => e.toString()).join(', ');
        }
        final headline =
            (provider['professional_headline'] as String?)?.trim();
        if ((specLabel == null || specLabel.isEmpty) &&
            headline != null &&
            headline.isNotEmpty) {
          specLabel = headline;
        }

        final name = (profile?['full_name'] as String?)?.trim();
        final fallback =
            type == 'nutritionist' ? 'Nutritionist' : 'Trainer';
        return AcceptedProvider(
          leadId: json['id'] as String,
          providerId: providerId,
          providerType: type,
          fullName: (name != null && name.isNotEmpty) ? name : fallback,
          avatarUrl: profile?['avatar_url'] as String?,
          specializationLabel: specLabel,
          experienceYears: (provider['experience_years'] as num?)?.toInt() ?? 0,
          rating: (provider['rating'] as num?)?.toDouble() ?? 0,
          reviewCount: (provider['total_reviews'] as num?)?.toInt() ?? 0,
          verified: provider['verified'] as bool? ?? false,
          relationshipStatus: json['status'] as String? ?? 'accepted',
          locationLabel: locationMap[providerId],
          connectedAt: DateTime.parse(json['created_at'] as String),
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch accepted providers: $e');
    }
  }

  Future<List<AcceptedTrainer>> getAcceptedTrainersAsClient() {
    return getAcceptedProvidersAsClient(providerType: 'trainer');
  }

  Future<List<AcceptedProvider>> getAcceptedNutritionistsAsClient() {
    return getAcceptedProvidersAsClient(providerType: 'nutritionist');
  }

  /// Provider IDs with an accepted lead for the current client.
  Future<Set<String>> getAcceptedProviderIdsAsClient() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return {};
    try {
      final response = await _supabase
          .from('leads')
          .select('provider_id')
          .eq('client_id', userId)
          .eq('status', 'accepted');
      return (response as List)
          .map((r) => (r as Map)['provider_id'] as String?)
          .whereType<String>()
          .toSet();
    } catch (e) {
      debugPrint('LeadsService.getAcceptedProviderIdsAsClient: $e');
      return {};
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
            profilesMap[m['id'] as String] = _publicClientProfile(m);
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
