import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../repositories/provider_reviews_repository.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/common/app_form_fields.dart';
import '../../widgets/common/cotrainr_back_button.dart';
import '../../widgets/home_v3/home_premium_theme.dart';
import '../../widgets/provider/provider_avatar.dart';

/// Shared rating screen for trainers and nutritionists.
class ProviderReviewPage extends StatefulWidget {
  final String providerId;
  final String? titleFallback;
  final String? providerType;
  final String? avatarUrl;

  const ProviderReviewPage({
    super.key,
    required this.providerId,
    this.titleFallback,
    this.providerType,
    this.avatarUrl,
  });

  @override
  State<ProviderReviewPage> createState() => _ProviderReviewPageState();
}

class _ProviderReviewPageState extends State<ProviderReviewPage> {
  final _repo = ProviderReviewsRepository();
  final _notesController = TextEditingController();
  int _rating = 0;
  bool _loading = true;
  bool _submitting = false;
  bool _isUpdate = false;
  String? _error;

  String get _roleLabel =>
      widget.providerType == 'nutritionist' ? 'Nutritionist' : 'Trainer';

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final existing = await _repo.getMyReviewForProvider(widget.providerId);
      if (!mounted) return;
      if (existing != null) {
        setState(() {
          _rating = existing.rating;
          _notesController.text = existing.body ?? '';
          _isUpdate = true;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_rating < 1 || _rating > 5 || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final body = _notesController.text.trim();
      await _repo.submitReview(
        providerId: widget.providerId,
        rating: _rating,
        body: body.isEmpty ? null : body,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isUpdate ? 'Review updated' : 'Thank you for your review'),
        ),
      );
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textPrimary = HomePremiumTheme.primaryText(isLight);
    final textSecondary = HomePremiumTheme.secondaryText(isLight);
    final bg =
        isLight ? HomePremiumTheme.lightWarmBg : DesignTokens.darkBackground;
    final name = widget.titleFallback ?? _roleLabel;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: Text(_isUpdate ? 'Edit review' : 'Review $_roleLabel'),
        leading: CotrainrBackButton(
          onPressed: () => context.pop(false),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: DesignTokens.accentOrange,
              backgroundColor: DesignTokens.surfaceOf(context),
              onRefresh: _loadExisting,
              child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Center(
                  child: ProviderAvatar(
                    imageUrl: widget.avatarUrl,
                    name: name,
                    size: 88,
                    borderRadius: 18,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _roleLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.accentOrange,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final star = i + 1;
                    final filled = star <= _rating;
                    return IconButton(
                      onPressed: _submitting
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              setState(() => _rating = star);
                            },
                      icon: Icon(
                        filled
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 40,
                        color: DesignTokens.accentOrange,
                      ),
                    );
                  }),
                ),
                if (_rating > 0)
                  Text(
                    '$_rating / 5',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: textSecondary,
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  maxLength: 500,
                  maxLines: 4,
                  minLines: 3,
                  enabled: !_submitting,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: AppFormFields.decoration(
                    context,
                    hintText: 'Optional written review',
                    alignLabelWithHint: true,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 48,
                  width: double.infinity,
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: (_rating < 1 || _submitting)
                            ? LinearGradient(
                                colors: [
                                  DesignTokens.accentOrange.withValues(alpha: 0.35),
                                  DesignTokens.accentAmber.withValues(alpha: 0.25),
                                ],
                              )
                            : DesignTokens.primaryGradient,
                      ),
                      child: InkWell(
                        onTap: (_rating < 1 || _submitting) ? null : _submit,
                        child: Center(
                          child: _submitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _isUpdate ? 'Update review' : 'Submit review',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ),
    );
  }
}
