import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/provider_professional_provider.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/home_v3/home_premium_theme.dart';
import '../../widgets/provider/provider_professional_form_fields.dart';
import '../../widgets/provider/provider_professional_form_validation.dart';

class ProviderProfessionalEditPage extends ConsumerStatefulWidget {
  const ProviderProfessionalEditPage({super.key});

  @override
  ConsumerState<ProviderProfessionalEditPage> createState() =>
      _ProviderProfessionalEditPageState();
}

class _ProviderProfessionalEditPageState
    extends ConsumerState<ProviderProfessionalEditPage> {
  final _headlineCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _languageCtrl = TextEditingController();

  String _providerType = 'trainer';
  final Set<String> _specialties = {};
  final Set<String> _sessionModes = {};
  final List<String> _languages = [];
  bool _accepting = true;
  bool _hydrated = false;
  bool _saving = false;

  @override
  void dispose() {
    _headlineCtrl.dispose();
    _bioCtrl.dispose();
    _experienceCtrl.dispose();
    _rateCtrl.dispose();
    _languageCtrl.dispose();
    super.dispose();
  }

  void _hydrateFromProfile() {
    final async = ref.read(myProviderProfessionalProvider);
    final profile = async.valueOrNull;
    if (profile == null || _hydrated) {
      if (!_hydrated && async.hasValue && profile == null) {
        final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
        _providerType =
            meta?['role']?.toString().toLowerCase() == 'nutritionist'
                ? 'nutritionist'
                : 'trainer';
        _hydrated = true;
      }
      return;
    }
    _providerType = profile.providerType;
    _headlineCtrl.text = profile.professionalHeadline ?? '';
    _bioCtrl.text = profile.bio ?? '';
    if (profile.experienceYears != null &&
        (profile.experienceYears! > 0 ||
            (profile.professionalHeadline ?? '').trim().isNotEmpty)) {
      _experienceCtrl.text = '${profile.experienceYears}';
    }
    _rateCtrl.text = profile.hourlyRate != null && profile.hourlyRate! > 0
        ? profile.hourlyRate!.toStringAsFixed(0)
        : '';
    _specialties
      ..clear()
      ..addAll(profile.specializationIds);
    _sessionModes
      ..clear()
      ..addAll(profile.sessionModes);
    _languages
      ..clear()
      ..addAll(profile.languages);
    _accepting = profile.acceptingNewClients;
    _hydrated = true;
  }

  Future<void> _save() async {
    final err = ProviderProfessionalFormValidation.validate(
      headline: _headlineCtrl.text,
      experienceText: _experienceCtrl.text,
      bio: _bioCtrl.text,
      specializationIds: _specialties,
      languages: _languages,
      sessionModes: _sessionModes,
    );
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    final rate = double.tryParse(_rateCtrl.text.trim());
    final expRaw = int.parse(_experienceCtrl.text.trim());

    setState(() => _saving = true);
    try {
      await ref.read(myProviderProfessionalProvider.notifier).save(
            providerType: _providerType,
            professionalHeadline: _headlineCtrl.text,
            bio: _bioCtrl.text,
            experienceYears: expRaw,
            specializationIds: _specialties.toList(),
            sessionModes: _sessionModes.toList(),
            languages: _languages,
            hourlyRate: (rate != null && rate > 0) ? rate : null,
            acceptingNewClients: _accepting,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Professional profile saved')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myProviderProfessionalProvider);
    if (!_hydrated && (async.hasValue || async.hasError)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hydrated) {
          setState(_hydrateFromProfile);
        }
      });
    }

    final isLight = Theme.of(context).brightness == Brightness.light;
    final textPrimary = HomePremiumTheme.primaryText(isLight);
    final textSecondary = HomePremiumTheme.secondaryText(isLight);
    final bg =
        isLight ? HomePremiumTheme.lightWarmBg : DesignTokens.darkBackground;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          'Professional profile',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: textPrimary),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            _providerType == 'nutritionist' ? 'Nutritionist' : 'Trainer',
            style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _field(
            label: 'Professional headline',
            child: TextField(
              controller: _headlineCtrl,
              maxLength: ProviderProfessionalFormValidation.headlineMaxLen,
              decoration: _decoration(
                ProviderProfessionalFormValidation.headlinePlaceholder(
                  _providerType,
                ),
              ),
            ),
          ),
          _field(
            label: 'About',
            child: TextField(
              controller: _bioCtrl,
              maxLines: 5,
              maxLength: ProviderProfessionalFormValidation.bioMaxLen,
              decoration: _decoration('Tell clients how you coach…'),
            ),
          ),
          _field(
            label: 'Years of experience',
            child: TextField(
              controller: _experienceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _decoration('0–60'),
            ),
          ),
          _field(
            label: 'Specialties',
            child: ProviderSpecialtySelector(
              providerType: _providerType,
              selectedIds: _specialties,
              onChanged: (next) => setState(() {
                _specialties
                  ..clear()
                  ..addAll(next);
              }),
            ),
          ),
          _field(
            label: 'Session modes',
            child: ProviderSessionModeSelector(
              providerType: _providerType,
              selectedIds: _sessionModes,
              onChanged: (next) => setState(() {
                _sessionModes
                  ..clear()
                  ..addAll(next);
              }),
            ),
          ),
          _field(
            label: 'Languages',
            child: ProviderLanguageSelector(
              languages: _languages,
              customController: _languageCtrl,
              onChanged: (next) => setState(() {
                _languages
                  ..clear()
                  ..addAll(next);
              }),
            ),
          ),
          _field(
            label: 'Hourly / session rate (optional)',
            child: TextField(
              controller: _rateCtrl,
              keyboardType: TextInputType.number,
              decoration: _decoration('e.g. 50'),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Accepting new clients',
              style: TextStyle(color: textPrimary),
            ),
            value: _accepting,
            activeThumbColor: DesignTokens.accentOrange,
            onChanged: (v) => setState(() => _accepting = v),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.place_outlined),
            title: Text(
              'Service locations',
              style: TextStyle(color: textPrimary),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/profile/service-locations'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.workspace_premium_outlined),
            title: Text(
              'Certifications',
              style: TextStyle(color: textPrimary),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/profile/certifications'),
          ),
        ],
      ),
    );
  }

  Widget _field({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      counterText: '',
    );
  }
}
