import 'package:flutter/material.dart';

import '../../models/fitness_goal_taxonomy.dart';
import '../../models/onboarding_specialty_options.dart';
import '../../theme/auth_theme.dart';
import '../../theme/design_tokens.dart';
import 'onboarding_motion.dart';

class OnboardingRoleStep extends StatelessWidget {
  const OnboardingRoleStep({
    super.key,
    required this.role,
    required this.selectedSpecialtyIds,
    required this.customSpecialty,
    required this.onRoleChanged,
    required this.onToggleSpecialty,
  });

  final String role;
  final Set<String> selectedSpecialtyIds;
  final TextEditingController customSpecialty;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<String> onToggleSpecialty;

  bool get _isProvider => role == 'Trainer' || role == 'Nutritionist';

  @override
  Widget build(BuildContext context) {
    final textPrimary = AuthTheme.primaryText(context);
    final textSecondary = AuthTheme.secondaryText(context);
    final options = OnboardingSpecialtyOptions.forRole(role);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose your path',
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _PathRoleTile(
                  icon: Icons.person_outline_rounded,
                  title: 'MEMBER',
                  subtitle: 'Train, track and connect with experts',
                  selected: role == 'Client',
                  onTap: () => onRoleChanged('Client'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PathRoleTile(
                  icon: Icons.sports_outlined,
                  title: 'TRAINER',
                  subtitle: 'Coach members and grow your practice',
                  selected: role == 'Trainer',
                  onTap: () => onRoleChanged('Trainer'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PathRoleTile(
                  icon: Icons.restaurant_outlined,
                  title: 'NUTRITIONIST',
                  subtitle: 'Guide members with nutrition',
                  selected: role == 'Nutritionist',
                  onTap: () => onRoleChanged('Nutritionist'),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: _isProvider
                ? Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          role == 'Trainer'
                              ? 'Your specialties'
                              : 'Your focus areas',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pick at least one. You can refine this later.',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final option in options)
                              _SpecialtyChip(
                                label: option.label,
                                selected:
                                    selectedSpecialtyIds.contains(option.id),
                                onTap: () => onToggleSpecialty(option.id),
                              ),
                          ],
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          child: OnboardingSpecialtyOptions.otherSelected(
                                  selectedSpecialtyIds)
                              ? _OtherSpecialtyField(
                                  controller: customSpecialty,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _OtherSpecialtyField extends StatefulWidget {
  const _OtherSpecialtyField({
    required this.controller,
    required this.textPrimary,
    required this.textSecondary,
  });

  final TextEditingController controller;
  final Color textPrimary;
  final Color textSecondary;

  @override
  State<_OtherSpecialtyField> createState() => _OtherSpecialtyFieldState();
}

class _OtherSpecialtyFieldState extends State<_OtherSpecialtyField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    )..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(_fade);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: TextField(
            controller: widget.controller,
            maxLength: 40,
            style: TextStyle(
              color: widget.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              counterText: '',
              labelText: 'Other specialty',
              hintText: 'Enter your specialty',
              labelStyle: TextStyle(
                color: widget.textSecondary,
                fontSize: 13,
              ),
              filled: true,
              fillColor: widget.textPrimary.withValues(alpha: 0.04),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: widget.textPrimary.withValues(alpha: 0.12),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: CotrainrGradients.focus),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PathRoleTile extends StatelessWidget {
  const _PathRoleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SelectionSpring(
      selected: selected,
      onTap: onTap,
      semanticLabel: title,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        constraints: const BoxConstraints(minHeight: 132),
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
        decoration: BoxDecoration(
          color: selected
              ? AuthTheme.selectionSurface(context)
              : AuthTheme.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AuthTheme.selectionBorder(context)
                : AuthTheme.fieldBorder(context),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 26,
                  color: selected
                      ? AuthTheme.accent
                      : AuthTheme.secondaryText(context),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AuthTheme.primaryText(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AuthTheme.secondaryText(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selected ? CotrainrGradients.primary : null,
                  color: selected ? null : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? Colors.transparent
                        : AuthTheme.fieldBorder(context),
                    width: 1.4,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 11,
                        color: Colors.black,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  const _SpecialtyChip({
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
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AuthTheme.selectionSurface(context)
              : AuthTheme.surface(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? AuthTheme.selectionBorder(context)
                : AuthTheme.fieldBorder(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check_rounded,
                  size: 14, color: AuthTheme.accent),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? AuthTheme.selectionText(context)
                    : AuthTheme.primaryText(context),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingGoalsStep extends StatelessWidget {
  const OnboardingGoalsStep({
    super.key,
    required this.selectedGoalIds,
    required this.agreedLegal,
    required this.onToggleGoal,
    required this.onAgreedLegalChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final Set<String> selectedGoalIds;
  final bool agreedLegal;
  final ValueChanged<String> onToggleGoal;
  final ValueChanged<bool> onAgreedLegalChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    final textPrimary = AuthTheme.primaryText(context);
    final textSecondary = AuthTheme.secondaryText(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose everything that matters.',
            style: TextStyle(
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'You can change this later.',
            style: TextStyle(color: textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Selected ',
                style: TextStyle(color: textSecondary, fontSize: 14),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: child,
                ),
                child: Text(
                  '${selectedGoalIds.length}',
                  key: ValueKey(selectedGoalIds.length),
                  style: const TextStyle(
                    color: CotrainrGradients.focus,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final goal in FitnessGoalTaxonomy.primary) ...[
            _GoalCard(
              goal: goal,
              selected: selectedGoalIds.contains(goal.id),
              onTap: () => onToggleGoal(goal.id),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final goal in FitnessGoalTaxonomy.secondary)
                _GoalChip(
                  goal: goal,
                  selected: selectedGoalIds.contains(goal.id),
                  onTap: () => onToggleGoal(goal.id),
                ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: 'Agree to Terms of Service and Privacy Policy',
                child: Checkbox(
                  value: agreedLegal,
                  activeColor: CotrainrGradients.focus,
                  onChanged: (v) => onAgreedLegalChanged(v ?? false),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'I agree to the ',
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                      GestureDetector(
                        onTap: onOpenTerms,
                        child: const Text(
                          'Terms of Service',
                          style: TextStyle(
                            color: CotrainrGradients.focus,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      Text(
                        ' and ',
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                      GestureDetector(
                        onTap: onOpenPrivacy,
                        child: const Text(
                          'Privacy Policy',
                          style: TextStyle(
                            color: CotrainrGradients.focus,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.selected,
    required this.onTap,
  });

  final FitnessGoal goal;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (goal.iconName) {
        'monitor_weight' => Icons.monitor_weight_outlined,
        'fitness_center' => Icons.fitness_center_outlined,
        'bolt' => Icons.bolt_rounded,
        _ => Icons.directions_run_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final textPrimary = AuthTheme.primaryText(context);
    final textSecondary = AuthTheme.secondaryText(context);

    return SelectionSpring(
      selected: selected,
      onTap: onTap,
      semanticLabel: goal.label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: selected
              ? AuthTheme.selectionSurface(context)
              : AuthTheme.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AuthTheme.selectionBorder(context)
                : AuthTheme.fieldBorder(context),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AuthTheme.accent.withValues(alpha: 0.16),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              _icon,
              color: selected ? AuthTheme.accent : textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.label.toUpperCase(),
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    goal.subtitle,
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_rounded : Icons.add_rounded,
              color: selected ? AuthTheme.accent : textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalChip extends StatelessWidget {
  const _GoalChip({
    required this.goal,
    required this.selected,
    required this.onTap,
  });

  final FitnessGoal goal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SelectionSpring(
      selected: selected,
      onTap: onTap,
      semanticLabel: goal.label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minHeight: 44, minWidth: 72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AuthTheme.selectionSurface(context)
              : AuthTheme.surface(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? AuthTheme.selectionBorder(context)
                : AuthTheme.fieldBorder(context),
          ),
        ),
        child: Text(
          goal.label,
          style: TextStyle(
            color: selected
                ? AuthTheme.selectionText(context)
                : AuthTheme.primaryText(context),
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
