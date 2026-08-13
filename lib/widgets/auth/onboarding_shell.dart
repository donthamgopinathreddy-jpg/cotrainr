import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/auth_theme.dart';
import '../../theme/design_tokens.dart';
import 'auth_ui.dart';
import 'onboarding_motion.dart';

/// Progress → Height/Weight value control gap. Never below 16dp.
double onboardingMeasureControlGap(BuildContext context) {
  final h = MediaQuery.sizeOf(context).height;
  if (h < 640) return 32;
  if (h < 740) return 44;
  return 48;
}

/// Compact onboarding header: title, subtitle, quiet progress. No back. No 1/7.
class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.step,
    required this.totalSteps,
    this.centerAlign = false,
    this.afterProgress,
  });

  final String title;
  final String subtitle;
  final int step;
  final int totalSteps;
  final bool centerAlign;

  /// Space below the progress bar before step content. Height/Weight uses ~24.
  final double? afterProgress;

  @override
  Widget build(BuildContext context) {
    final align = centerAlign ? TextAlign.center : TextAlign.start;
    final cross =
        centerAlign ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final short = MediaQuery.sizeOf(context).height < 700;
    final belowProgress = afterProgress ?? 8;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: cross,
        children: [
          Text(
            title,
            textAlign: align,
            style: AuthUi.pageTitle(context).copyWith(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.12,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: align,
            style: AuthUi.pageSubtitle(context).copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.35,
            ),
          ),
          SizedBox(height: short ? 20 : 26),
          OnboardingProgress(step: step, totalSteps: totalSteps),
          SizedBox(height: belowProgress),
        ],
      ),
    );
  }
}

/// Thin segmented progress. Not the visual focus of the page.
class OnboardingProgress extends StatelessWidget {
  const OnboardingProgress({
    super.key,
    required this.step,
    required this.totalSteps,
  });

  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final inactive = AuthTheme.progressInactive(context);

    return Semantics(
      label: 'Onboarding progress, step ${step + 1} of $totalSteps',
      child: Row(
        children: List.generate(totalSteps, (index) {
          final isActive = index <= step;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              height: 3,
              margin: EdgeInsets.only(right: index < totalSteps - 1 ? 5 : 0),
              decoration: BoxDecoration(
                gradient: isActive ? CotrainrGradients.primary : null,
                color: isActive ? null : inactive,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Bottom nav: first step is Next only; later steps Back (secondary) + Next.
class OnboardingBottomActions extends StatelessWidget {
  const OnboardingBottomActions({
    super.key,
    required this.step,
    required this.isLast,
    required this.onNext,
    this.onBack,
    this.isLoading = false,
    this.slowHint = false,
    this.nextLabel,
    this.finishLabel = 'Finish',
  });

  final int step;
  final bool isLast;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final bool isLoading;
  final bool slowHint;
  final String? nextLabel;
  final String finishLabel;

  bool get _showBack => step > 0 && onBack != null;

  @override
  Widget build(BuildContext context) {
    final label = isLast ? finishLabel : (nextLabel ?? 'Next');
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 6, 16, 10 + bottomInset.clamp(0, 12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (slowHint) ...[
            Text(
              'Taking a little longer…',
              style: TextStyle(
                color: AuthTheme.secondaryText(context),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              if (_showBack) ...[
                Expanded(
                  child: _BackButton(onPressed: isLoading ? null : onBack),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: AuthPrimaryButton(
                  label: label,
                  isLoading: isLoading,
                  trailingIcon:
                      isLoading ? null : Icons.arrow_forward_rounded,
                  onPressed: isLoading ? null : onNext,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: SizedBox(
        height: 56,
        child: OutlinedButton(
          onPressed: onPressed == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                },
          style: OutlinedButton.styleFrom(
            foregroundColor: AuthTheme.primaryText(context),
            side: BorderSide(color: AuthTheme.backBorder(context)),
            backgroundColor: AuthTheme.backSurface(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_back_rounded, size: 18),
              SizedBox(width: 6),
              Text(
                'Back',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Equal-width Male / Female / Other selector.
class AuthGenderSelector extends StatelessWidget {
  const AuthGenderSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.options = const ['Male', 'Female', 'Other'],
  });

  final String value;
  final ValueChanged<String> onChanged;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Gender',
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _GenderOption(
                label: options[i],
                selected: value == options[i],
                onTap: () => onChanged(options[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GenderOption extends StatelessWidget {
  const _GenderOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SelectionSpring(
      selected: selected,
      onTap: onTap,
      semanticLabel: label,
      child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? AuthTheme.selectionSurface(context)
                  : AuthTheme.surface(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AuthTheme.selectionBorder(context)
                    : AuthTheme.fieldBorder(context),
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? AuthTheme.selectionText(context)
                    : AuthTheme.primaryText(context),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
    );
  }
}
