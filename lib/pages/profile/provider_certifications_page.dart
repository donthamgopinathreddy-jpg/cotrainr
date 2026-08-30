import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth/verification_error_messages.dart';
import '../../models/provider_professional_profile.dart';
import '../../providers/provider_professional_provider.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/common/cotrainr_back_button.dart';
import '../../widgets/home_v3/home_premium_theme.dart';

class ProviderCertificationsPage extends ConsumerStatefulWidget {
  const ProviderCertificationsPage({super.key});

  @override
  ConsumerState<ProviderCertificationsPage> createState() =>
      _ProviderCertificationsPageState();
}

class _ProviderCertificationsPageState
    extends ConsumerState<ProviderCertificationsPage> {
  @override
  Widget build(BuildContext context) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textPrimary = HomePremiumTheme.primaryText(isLight);
    final bg =
        isLight ? HomePremiumTheme.lightWarmBg : DesignTokens.darkBackground;

    if (uid == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: CotrainrAppBar(title: 'Certifications', backgroundColor: bg),
        body: const Center(child: Text('Sign in required')),
      );
    }

    final certsAsync = ref.watch(
      providerCertificationsProvider((providerId: uid, publicOnly: false)),
    );

    return Scaffold(
      backgroundColor: bg,
      appBar: CotrainrAppBar(
        title: 'Certifications',
        backgroundColor: bg,
        foregroundColor: textPrimary,
        actions: [
          IconButton(
            onPressed: () => _showEditor(context, uid),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: certsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) {
          VerificationErrorMessages.log('loadCertifications', e, s);
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                VerificationErrorMessages.forLoadStatus(e) ==
                        VerificationErrorMessages.network
                    ? VerificationErrorMessages.network
                    : VerificationErrorMessages.loadCertifications,
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
        data: (certs) {
          if (certs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No certifications yet',
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add public credentials such as ACE, NASM, RYT, or Precision Nutrition.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => _showEditor(context, uid),
                      child: const Text('Add certification'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: certs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final c = certs[i];
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tileColor: isLight
                    ? HomePremiumTheme.lightCreamCard
                    : HomePremiumTheme.darkCard,
                title: Text(c.name, style: TextStyle(color: textPrimary)),
                subtitle: Text(
                  [
                    if (c.issuingOrganization != null) c.issuingOrganization!,
                    if (c.issueYear != null) '${c.issueYear}',
                    c.verificationStatus,
                  ].join(' · '),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await ref
                        .read(providerProfessionalRepositoryProvider)
                        .deleteCertification(c.id);
                    ref.invalidate(
                      providerCertificationsProvider(
                        (providerId: uid, publicOnly: false),
                      ),
                    );
                  },
                ),
                onTap: () => _showEditor(context, uid, existing: c),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showEditor(
    BuildContext context,
    String uid, {
    ProviderCertification? existing,
  }) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final orgCtrl =
        TextEditingController(text: existing?.issuingOrganization ?? '');
    final issueCtrl = TextEditingController(
      text: existing?.issueYear?.toString() ?? '',
    );
    final expiryCtrl = TextEditingController(
      text: existing?.expiryYear?.toString() ?? '',
    );
    var isPublic = existing?.isPublic ?? true;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null ? 'Add certification' : 'Edit certification',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g. ACE Certified Personal Trainer',
                    ),
                  ),
                  TextField(
                    controller: orgCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Issuing organization',
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: issueCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration:
                              const InputDecoration(labelText: 'Issue year'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: expiryCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration:
                              const InputDecoration(labelText: 'Expiry year'),
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show on public profile'),
                    value: isPublic,
                    onChanged: (v) => setModal(() => isPublic = v),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      final repo =
                          ref.read(providerProfessionalRepositoryProvider);
                      if (existing == null) {
                        await repo.addCertification(
                          name: name,
                          issuingOrganization: orgCtrl.text.trim().isEmpty
                              ? null
                              : orgCtrl.text.trim(),
                          issueYear: int.tryParse(issueCtrl.text),
                          expiryYear: int.tryParse(expiryCtrl.text),
                          isPublic: isPublic,
                        );
                      } else {
                        await repo.updateCertification(
                          ProviderCertification(
                            id: existing.id,
                            providerId: uid,
                            name: name,
                            issuingOrganization: orgCtrl.text.trim().isEmpty
                                ? null
                                : orgCtrl.text.trim(),
                            issueYear: int.tryParse(issueCtrl.text),
                            expiryYear: int.tryParse(expiryCtrl.text),
                            verificationStatus: existing.verificationStatus,
                            isPublic: isPublic,
                          ),
                        );
                      }
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (saved == true && mounted) {
      ref.invalidate(
        providerCertificationsProvider((providerId: uid, publicOnly: false)),
      );
    }
  }
}
