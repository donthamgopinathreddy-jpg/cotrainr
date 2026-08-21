import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../repositories/partner_centers_repository.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/common/app_form_fields.dart';
import '../../widgets/common/cotrainr_back_button.dart';

class PartnerCenterApplicationPage extends StatefulWidget {
  const PartnerCenterApplicationPage({super.key});

  @override
  State<PartnerCenterApplicationPage> createState() =>
      _PartnerCenterApplicationPageState();
}

class _PartnerCenterApplicationPageState
    extends State<PartnerCenterApplicationPage> {
  final _repo = PartnerCentersRepository();
  final _formKey = GlobalKey<FormState>();

  final _businessName = TextEditingController();
  final _contactName = TextEditingController();
  final _contactRole = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _website = TextEditingController();
  final _address1 = TextEditingController();
  final _address2 = TextEditingController();
  final _city = TextEditingController();
  final _postal = TextEditingController();
  final _country = TextEditingController();
  final _description = TextEditingController();
  final _offerTitle = TextEditingController();
  final _offerDescription = TextEditingController();

  String _businessType = 'Gym';
  String? _memberCount;
  final Set<String> _facilities = {};
  final Set<String> _interests = {};
  bool _offerYes = false;
  bool _authorized = false;
  bool _agreeTerms = false;
  bool _submitting = false;
  String? _successCode;

  static const _businessTypes = [
    'Gym',
    'Fitness Studio',
    'Yoga Studio',
    'Pilates Studio',
    'Boxing / Martial Arts',
    'CrossFit / Functional Fitness',
    'Sports Centre',
    'Wellness Centre',
    'Other',
  ];

  static const _memberCounts = [
    'Under 100',
    '100–250',
    '251–500',
    '501–1,000',
    '1,000+',
    'Prefer not to say',
  ];

  static const _facilityOptions = [
    'Strength Training',
    'Cardio',
    'Personal Training',
    'Group Classes',
    'Yoga',
    'Pilates',
    'Boxing',
    'Swimming',
    'Functional Training',
    'Nutrition',
    'Other',
  ];

  static const _interestOptions = [
    'List my centre on Cotrainr',
    'Offer Cotrainr member benefits',
    'Accept Cotrainr Pass verification',
    'Promote memberships/classes',
    'Work with Cotrainr trainers',
    'Other',
  ];

  @override
  void dispose() {
    _businessName.dispose();
    _contactName.dispose();
    _contactRole.dispose();
    _email.dispose();
    _phone.dispose();
    _website.dispose();
    _address1.dispose();
    _address2.dispose();
    _city.dispose();
    _postal.dispose();
    _country.dispose();
    _description.dispose();
    _offerTitle.dispose();
    _offerDescription.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (!_authorized || !_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please confirm authorization and agree to Partner Terms'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_offerYes && _offerTitle.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter an offer title or choose Not yet'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    final payload = <String, dynamic>{
      'business_name': _businessName.text.trim(),
      'business_type': _businessType,
      'contact_name': _contactName.text.trim(),
      'contact_role': _contactRole.text.trim(),
      'business_email': _email.text.trim(),
      'business_phone': _phone.text.trim(),
      'website': _website.text.trim(),
      'address_line_1': _address1.text.trim(),
      'address_line_2': _address2.text.trim(),
      'city': _city.text.trim(),
      'postal_code': _postal.text.trim(),
      'country': _country.text.trim(),
      'approx_member_count': _memberCount,
      'facilities': _facilities.toList(),
      'description': _description.text.trim(),
      'partnership_interests': _interests.toList(),
      if (_offerYes) ...{
        'proposed_offer_title': _offerTitle.text.trim(),
        'proposed_offer_description': _offerDescription.text.trim(),
      },
    };

    final result = await _repo.submitApplication(payload);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.ok) {
      final msg = switch (result.error) {
        'duplicate_open_application' =>
          result.detail ?? 'You already have an application in review.',
        'invalid_email' => 'Enter a valid business email.',
        'validation_failed' => 'Please complete all required fields.',
        _ => result.detail ?? 'Could not submit application.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _successCode = result.applicationCode);
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bg = isLight
        ? const Color(0xFFF7F4F0)
        : DesignTokens.backgroundOf(context);
    final onSurface = isLight ? const Color(0xFF141414) : Colors.white;
    final muted = isLight
        ? const Color(0xFF6B6560)
        : Colors.white.withValues(alpha: 0.62);

    if (_successCode != null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: CotrainrAppBar(
          title: 'Application received',
          backgroundColor: bg,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 48, color: DesignTokens.accentOrange),
                const SizedBox(height: 16),
                Text(
                  'Application received',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Thank you for applying to become a Cotrainr Partner.\n\n'
                  "We'll review your centre information before enabling Partner features.",
                  style: TextStyle(fontSize: 15, height: 1.45, color: muted),
                ),
                const SizedBox(height: 20),
                Text(
                  'Application ID',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _successCode!,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: onSurface,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => context.pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: DesignTokens.accentOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: CotrainrAppBar(
        title: 'Become a Cotrainr Partner',
        backgroundColor: bg,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Text(
              'Partner with Cotrainr to reach members, publish exclusive offers and '
              'verify eligible Cotrainr members at your centre.',
              style: TextStyle(fontSize: 14, height: 1.45, color: muted),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Business Details', onSurface),
            const SizedBox(height: 12),
            TextFormField(
              controller: _businessName,
              textCapitalization: TextCapitalization.words,
              decoration: AppFormFields.decoration(
                context,
                labelText: 'Business / Centre Name *',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _businessType,
              decoration: AppFormFields.decoration(
                context,
                labelText: 'Business Type *',
              ),
              items: _businessTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _businessType = v);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactName,
              textCapitalization: TextCapitalization.words,
              decoration: AppFormFields.decoration(
                context,
                labelText: 'Contact Person *',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactRole,
              textCapitalization: TextCapitalization.words,
              decoration: AppFormFields.decoration(
                context,
                labelText: 'Role / Position *',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: AppFormFields.decoration(
                context,
                labelText: 'Business Email *',
              ),
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return 'Required';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: AppFormFields.decoration(
                context,
                labelText: 'Business Phone *',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _website,
              keyboardType: TextInputType.url,
              decoration: AppFormFields.decoration(
                context,
                labelText: 'Website',
              ),
            ),
            const SizedBox(height: 28),
            _sectionTitle('Centre Location', onSurface),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address1,
              textCapitalization: TextCapitalization.words,
              decoration: AppFormFields.decoration(
                context,
                labelText: 'Address Line 1 *',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address2,
              textCapitalization: TextCapitalization.words,
              decoration: AppFormFields.decoration(
                context,
                labelText: 'Address Line 2',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _city,
              textCapitalization: TextCapitalization.words,
              decoration: AppFormFields.decoration(
                context,
                labelText: 'City *',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _postal,
              decoration: AppFormFields.decoration(
                context,
                labelText: 'Postcode / PIN Code *',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _country,
              textCapitalization: TextCapitalization.words,
              decoration: AppFormFields.decoration(
                context,
                labelText: 'Country *',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 28),
            _sectionTitle('About Your Centre', onSurface),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _memberCount ?? '',
              decoration: AppFormFields.decoration(
                context,
                labelText: 'Approximate Member Count',
              ),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Select'),
                ),
                ..._memberCounts.map(
                  (t) => DropdownMenuItem(value: t, child: Text(t)),
                ),
              ],
              onChanged: (v) => setState(
                () => _memberCount = (v == null || v.isEmpty) ? null : v,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Facilities / Services',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: muted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _facilityOptions.map((f) {
                final selected = _facilities.contains(f);
                return FilterChip(
                  label: Text(f),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _facilities.add(f);
                      } else {
                        _facilities.remove(f);
                      }
                    });
                  },
                  selectedColor:
                      DesignTokens.accentOrange.withValues(alpha: 0.18),
                  checkmarkColor: DesignTokens.accentOrange,
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 4,
              maxLength: 500,
              decoration: AppFormFields.decoration(
                context,
                labelText: 'Short Description',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 28),
            _sectionTitle('How would you like to partner?', onSurface),
            const SizedBox(height: 8),
            ..._interestOptions.map((interest) {
              final selected = _interests.contains(interest);
              return CheckboxListTile(
                value: selected,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _interests.add(interest);
                    } else {
                      _interests.remove(interest);
                    }
                  });
                },
                title: Text(interest, style: TextStyle(color: onSurface)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                activeColor: DesignTokens.accentOrange,
              );
            }),
            const SizedBox(height: 20),
            _sectionTitle('Member Benefit', onSurface),
            const SizedBox(height: 8),
            Text(
              'Would you like to offer a benefit to Cotrainr members?',
              style: TextStyle(fontSize: 13, color: muted),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Not yet'),
                  selected: !_offerYes,
                  onSelected: (_) => setState(() => _offerYes = false),
                  selectedColor:
                      DesignTokens.accentOrange.withValues(alpha: 0.18),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Yes'),
                  selected: _offerYes,
                  onSelected: (_) => setState(() => _offerYes = true),
                  selectedColor:
                      DesignTokens.accentOrange.withValues(alpha: 0.18),
                ),
              ],
            ),
            if (_offerYes) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _offerTitle,
                decoration: AppFormFields.decoration(
                  context,
                  labelText: 'Offer Title',
                  hintText: '10% off monthly membership',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _offerDescription,
                maxLines: 3,
                decoration: AppFormFields.decoration(
                  context,
                  labelText: 'Offer Description',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Offers are proposed only and stay pending until Cotrainr Admin reviews them.',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ],
            const SizedBox(height: 24),
            CheckboxListTile(
              value: _authorized,
              onChanged: (v) => setState(() => _authorized = v ?? false),
              title: Text(
                'I confirm that I am authorized to submit this application on behalf of this business.',
                style: TextStyle(fontSize: 13, color: onSurface),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: DesignTokens.accentOrange,
            ),
            CheckboxListTile(
              value: _agreeTerms,
              onChanged: (v) => setState(() => _agreeTerms = v ?? false),
              title: Text(
                'I agree to the Cotrainr Partner Terms and Privacy Policy.',
                style: TextStyle(fontSize: 13, color: onSurface),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: DesignTokens.accentOrange,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: DesignTokens.accentOrange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      DesignTokens.accentOrange.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit Partner Application'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, Color color) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w900,
        color: color,
      ),
    );
  }
}
