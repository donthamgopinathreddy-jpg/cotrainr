import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_colors.dart';

/// Read-only public profile (no CoCircle posts, follow, or DM).
class PublicProfileReadonlyPage extends StatefulWidget {
  final String userId;
  final String? titleFallback;

  const PublicProfileReadonlyPage({
    super.key,
    required this.userId,
    this.titleFallback,
  });

  @override
  State<PublicProfileReadonlyPage> createState() => _PublicProfileReadonlyPageState();
}

class _PublicProfileReadonlyPageState extends State<PublicProfileReadonlyPage> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  String? _fullName;
  String? _username;
  String? _bio;
  String? _avatarUrl;
  String? _role;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list =
          (await _supabase.rpc('get_public_profile', params: {'p_user_id': widget.userId}) as List)
              .cast<Map<String, dynamic>>();
      final p = list.isNotEmpty ? list.first : null;
      if (mounted) {
        setState(() {
          _fullName = p?['full_name'] as String?;
          _username = p?['username'] as String?;
          _bio = p?['bio'] as String?;
          _avatarUrl = p?['avatar_url'] as String?;
          _role = p?['role'] as String?;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = _fullName ?? _username ?? widget.titleFallback ?? 'Profile';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.blue.withValues(alpha: 0.2),
                    backgroundImage:
                        _avatarUrl != null && _avatarUrl!.isNotEmpty ? CachedNetworkImageProvider(_avatarUrl!) : null,
                    child: _avatarUrl == null || _avatarUrl!.isEmpty
                        ? Text(
                            title.isNotEmpty ? title[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                if (_username != null && _username!.isNotEmpty)
                  Text(
                    '@$_username',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                  ),
                if (_role != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _role!.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.blue,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  _bio?.trim().isNotEmpty == true ? _bio! : 'No bio yet.',
                  style: TextStyle(color: cs.onSurface, fontSize: 15, height: 1.4),
                ),
              ],
            ),
    );
  }
}
