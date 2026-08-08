import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../repositories/provider_reviews_repository.dart';
import '../../theme/design_tokens.dart';
import '../common/app_form_fields.dart';

/// Compact inline review editor for provider profiles.
class InlineProviderReviewEditor extends StatefulWidget {
  final String providerId;
  final ProviderReview? initialReview;
  final Future<void> Function() onSaved;

  const InlineProviderReviewEditor({
    super.key,
    required this.providerId,
    this.initialReview,
    required this.onSaved,
  });

  @override
  State<InlineProviderReviewEditor> createState() =>
      _InlineProviderReviewEditorState();
}

class _InlineProviderReviewEditorState
    extends State<InlineProviderReviewEditor> {
  static const _maxChars = 500;

  final _repo = ProviderReviewsRepository();
  late final TextEditingController _bodyController;
  late int _rating;
  bool _submitting = false;
  String? _error;

  bool get _isUpdate => widget.initialReview != null;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialReview?.rating ?? 0;
    _bodyController = TextEditingController(
      text: widget.initialReview?.body ?? '',
    );
    _bodyController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant InlineProviderReviewEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialReview?.id != widget.initialReview?.id ||
        oldWidget.initialReview?.rating != widget.initialReview?.rating ||
        oldWidget.initialReview?.body != widget.initialReview?.body) {
      _rating = widget.initialReview?.rating ?? 0;
      _bodyController.text = widget.initialReview?.body ?? '';
    }
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating < 1 || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final body = _bodyController.text.trim();
      await _repo.submitReview(
        providerId: widget.providerId,
        rating: _rating,
        body: body.isEmpty ? null : body,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      await widget.onSaved();
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
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final textPrimary = DesignTokens.textPrimaryOf(context);
    final textSecondary = DesignTokens.textSecondaryOf(context);
    final cardBg = isLight
        ? DesignTokens.lightMutedCardBackground
        : const Color(0xFF121212);
    final canSubmit = _rating >= 1 && !_submitting;
    final count = _bodyController.text.characters.length;

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your review',
              style: GoogleFonts.montserrat(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                final filled = star <= _rating;
                return IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  onPressed: _submitting
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          setState(() => _rating = star);
                        },
                  icon: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 32,
                    color: filled
                        ? DesignTokens.accentOrange
                        : textSecondary.withValues(alpha: 0.55),
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
            const SizedBox(height: 10),
            TextField(
              controller: _bodyController,
              maxLength: _maxChars,
              maxLines: 4,
              minLines: 3,
              enabled: !_submitting,
              textAlignVertical: TextAlignVertical.top,
              decoration: AppFormFields.decoration(
                context,
                hintText: 'Write your review here...',
                alignLabelWithHint: true,
                counterText: '$count / $_maxChars',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                _error!,
                style: TextStyle(
                  color: cs.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canSubmit ? _submit : null,
                style: FilledButton.styleFrom(
                  backgroundColor: DesignTokens.accentOrange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      DesignTokens.accentOrange.withValues(alpha: 0.35),
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isUpdate ? 'Update Review' : 'Submit Review',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
