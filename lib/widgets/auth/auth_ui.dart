import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/account_hub_theme.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/branding/cotrainr_logo.dart';
import '../../widgets/home_v3/home_premium_theme.dart';

/// Shared auth flow styling aligned with account hub pages.
abstract final class AuthUi {
  static const accent = DesignTokens.accentOrange;

  static Color pageBg(BuildContext context) => AccountHubTheme.pageBg(context);

  static TextStyle pageTitle(BuildContext context) =>
      AccountHubTheme.rowTitle(context).copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      );

  static TextStyle pageSubtitle(BuildContext context) =>
      AccountHubTheme.rowSubtitle(context).copyWith(
        fontSize: 16,
        height: 1.4,
        color: Theme.of(context)
            .colorScheme
            .onSurface
            .withValues(alpha: 0.65),
      );

  static TextStyle heroTitle(BuildContext context) =>
      pageTitle(context).copyWith(fontSize: 32);

  static TextStyle heroSubtitle(BuildContext context) =>
      pageSubtitle(context).copyWith(fontSize: 17);

  static TextStyle fieldTextStyle(BuildContext context, {bool large = false}) =>
      AccountHubTheme.rowTitle(context).copyWith(
        fontSize: large ? 18 : 16,
        fontWeight: FontWeight.w500,
      );

  static InputDecoration fieldDecoration(
    BuildContext context, {
    required String label,
    String? hint,
    Widget? prefixIcon,
    Widget? prefix,
    Widget? suffixIcon,
    bool compact = false,
    bool large = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    final border = cs.onSurface.withValues(alpha: 0.1);
    final labelStyle = AccountHubTheme.rowSubtitle(context).copyWith(
      fontSize: large ? 15 : (compact ? 13 : 14),
      fontWeight: large ? FontWeight.w600 : FontWeight.w500,
    );
    final radius = large ? 18.0 : (compact ? 14.0 : 16.0);
    final verticalPadding = large ? 18.0 : (compact ? 11.0 : 14.0);

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: labelStyle,
      hintStyle: labelStyle,
      prefixIcon: prefix == null ? prefixIcon : null,
      prefix: prefix,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: cs.onSurface.withValues(alpha: 0.04),
      isDense: !large,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: const BorderSide(color: DesignTokens.accentRed),
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: large ? 16 : 14,
        vertical: verticalPadding,
      ),
    );
  }
}

/// Official Cotrainr mark for auth screens — always from master SVG.
class AuthBrandLogo extends StatelessWidget {
  final double width;
  final bool useHero;

  const AuthBrandLogo({
    super.key,
    this.width = 200,
    this.useHero = true,
  });

  @override
  Widget build(BuildContext context) {
    final logo = CotrainrBrandLockup(
      logoWidth: width * 0.42,
      showTagline: false,
      variant: CotrainrLogoVariant.color,
    );
    if (!useHero) return logo;
    return Hero(
      tag: 'auth-cotrainr-logo',
      flightShuttleBuilder: (
        flightContext,
        animation,
        direction,
        fromContext,
        toContext,
      ) {
        return FadeTransition(opacity: animation, child: logo);
      },
      child: Material(type: MaterialType.transparency, child: logo),
    );
  }
}

/// Fade + slight slide-up entrance for titles / cards.
class AuthFadeSlide extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final Offset begin;
  final double beginScale;

  const AuthFadeSlide({
    super.key,
    required this.child,
    required this.animation,
    this.begin = const Offset(0, 0.04),
    this.beginScale = 0.985,
  });

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: begin, end: Offset.zero).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: beginScale, end: 1).animate(curved),
          child: child,
        ),
      ),
    );
  }
}

class AuthTextLink extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final double fontSize;

  const AuthTextLink({
    super.key,
    required this.label,
    this.onTap,
    this.color,
    this.fontSize = 14,
  });

  @override
  State<AuthTextLink> createState() => _AuthTextLinkState();
}

class _AuthTextLinkState extends State<AuthTextLink> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AuthUi.accent;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: _pressed ? 0.55 : 1,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 120),
          scale: _pressed ? 0.98 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Text(
              widget.label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: widget.fontSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthHeroCard extends StatelessWidget {
  final bool isLight;
  final IconData? icon;
  final String title;
  final String subtitle;
  final Color accent;
  final bool compact;
  final bool showLogo;

  const AuthHeroCard({
    super.key,
    required this.isLight,
    this.icon,
    required this.title,
    required this.subtitle,
    this.accent = AuthUi.accent,
    this.compact = false,
    this.showLogo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: compact
          ? const EdgeInsets.fromLTRB(16, 18, 16, 16)
          : const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: AccountHubTheme.cardBg(context),
        borderRadius: BorderRadius.circular(AccountHubTheme.sectionRadius),
        boxShadow: AccountHubTheme.cardShadow(context),
        gradient: HomePremiumTheme.bmiTileGradient(isLight, accent).scale(0.45),
      ),
      child: Column(
        crossAxisAlignment: showLogo
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          if (showLogo) ...[
            AuthBrandLogo(width: compact ? 168 : 200),
            SizedBox(height: compact ? 16 : 20),
          ] else if (icon != null) ...[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            title,
            style: compact
                ? AuthUi.pageTitle(context).copyWith(fontSize: 22)
                : AuthUi.heroTitle(context),
            textAlign: showLogo ? TextAlign.center : TextAlign.start,
          ),
          SizedBox(height: compact ? 4 : 8),
          Text(
            subtitle,
            style: compact
                ? AuthUi.pageSubtitle(context).copyWith(fontSize: 14)
                : AuthUi.heroSubtitle(context),
            textAlign: showLogo ? TextAlign.center : TextAlign.start,
          ),
        ],
      ),
    );
  }
}

class AuthProgressBar extends StatelessWidget {
  final int step;
  final int totalSteps;

  const AuthProgressBar({
    super.key,
    required this.step,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = Theme.of(context)
        .colorScheme
        .onSurface
        .withValues(alpha: 0.1);

    return Row(
      children: List.generate(totalSteps, (index) {
        final isActive = index <= step;
        final isCurrent = index == step;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            height: isCurrent ? 4 : 3,
            margin: EdgeInsets.only(right: index < totalSteps - 1 ? 6 : 0),
            decoration: BoxDecoration(
              gradient: isActive ? DesignTokens.primaryGradient : null,
              color: isActive ? null : inactive,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}

class AuthPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool showSuccess;
  final IconData? trailingIcon;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.showSuccess = false,
    this.trailingIcon,
  });

  @override
  State<AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<AuthPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.isLoading ||
        widget.showSuccess ||
        widget.onPressed == null;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        scale: _pressed ? 0.98 : 1,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: disabled ? null : widget.onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: AuthUi.accent,
              disabledBackgroundColor: AuthUi.accent.withValues(alpha: 0.45),
              foregroundColor: DesignTokens.darkTextPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: widget.showSuccess
                  ? const Icon(
                      Icons.check_rounded,
                      key: ValueKey('ok'),
                      size: 26,
                      color: DesignTokens.darkTextPrimary,
                    )
                  : widget.isLoading
                      ? const SizedBox(
                          key: ValueKey('load'),
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: DesignTokens.darkTextPrimary,
                          ),
                        )
                      : Row(
                          key: ValueKey(widget.label),
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.label,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.1,
                              ),
                            ),
                            if (widget.trailingIcon != null) ...[
                              const SizedBox(width: 8),
                              Icon(widget.trailingIcon, size: 18),
                            ],
                          ],
                        ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthOutlinedButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const AuthOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  State<AuthOutlinedButton> createState() => _AuthOutlinedButtonState();
}

class _AuthOutlinedButtonState extends State<AuthOutlinedButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = cs.onSurface.withValues(alpha: 0.12);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 130),
        scale: _pressed ? 0.98 : 1,
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              widget.onPressed();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.onSurface,
              side: BorderSide(color: border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              widget.label,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthSocialButton extends StatefulWidget {
  final Widget icon;
  final VoidCallback? onTap;
  final bool isLoading;

  const AuthSocialButton({
    super.key,
    required this.icon,
    this.onTap,
    this.isLoading = false,
  });

  @override
  State<AuthSocialButton> createState() => _AuthSocialButtonState();
}

class _AuthSocialButtonState extends State<AuthSocialButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: _pressed ? 0.96 : 1,
      child: Material(
        color: AccountHubTheme.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTapDown: widget.isLoading
              ? null
              : (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.isLoading
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  widget.onTap?.call();
                },
          borderRadius: BorderRadius.circular(16),
          splashColor: AuthUi.accent.withValues(alpha: 0.12),
          highlightColor: AuthUi.accent.withValues(alpha: 0.06),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: widget.isLoading ? 0.45 : 1,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.onSurface.withValues(alpha: 0.1),
                ),
                boxShadow: AccountHubTheme.cardShadow(context),
              ),
              child: Center(child: widget.icon),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthSectionCard extends StatelessWidget {
  final String? title;
  final Widget child;
  final bool compact;

  const AuthSectionCard({
    super.key,
    this.title,
    required this.child,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: isLight
            ? DesignTokens.lightCardBackground
            : DesignTokens.darkSurfaceElevated.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AccountHubTheme.sectionRadius),
        border: Border.all(
          color: cs.onSurface.withValues(alpha: isLight ? 0.06 : 0.08),
        ),
        boxShadow: AccountHubTheme.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: AccountHubTheme.sectionTitle(context).copyWith(
                fontSize: compact ? 15 : null,
              ),
            ),
            SizedBox(height: compact ? 10 : 12),
          ],
          child,
        ],
      ),
    );
  }
}

extension on LinearGradient {
  LinearGradient scale(double factor) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: colors
          .map((c) => Color.lerp(c, Colors.transparent, 1 - factor) ?? c)
          .toList(),
    );
  }
}

class AuthRotatorItem {
  final String label;
  final String subtitle;
  final IconData icon;

  const AuthRotatorItem({
    required this.label,
    required this.subtitle,
    required this.icon,
  });
}

/// Sideways carousel picker for gender, role, etc.
class AuthHorizontalRotator extends StatefulWidget {
  final List<AuthRotatorItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const AuthHorizontalRotator({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  State<AuthHorizontalRotator> createState() => _AuthHorizontalRotatorState();
}

class _AuthHorizontalRotatorState extends State<AuthHorizontalRotator> {
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      viewportFraction: 0.42,
      initialPage: widget.selectedIndex,
    );
  }

  @override
  void didUpdateWidget(covariant AuthHorizontalRotator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex &&
        _controller.hasClients) {
      _controller.animateToPage(
        widget.selectedIndex,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        SizedBox(
          height: 168,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 140,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AuthUi.accent.withValues(alpha: 0.35),
                    width: 2,
                  ),
                  color: AuthUi.accent.withValues(alpha: 0.06),
                ),
              ),
              PageView.builder(
                controller: _controller,
                itemCount: widget.items.length,
                onPageChanged: (index) {
                  HapticFeedback.selectionClick();
                  widget.onSelected(index);
                },
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  final isSelected = index == widget.selectedIndex;
                  return AnimatedScale(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    scale: isSelected ? 1.0 : 0.82,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 280),
                      opacity: isSelected ? 1.0 : 0.45,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item.icon,
                            size: isSelected ? 40 : 30,
                            color: isSelected ? AuthUi.accent : cs.onSurface,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.label,
                            style: TextStyle(
                              fontSize: isSelected ? 22 : 17,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? AuthUi.accent : cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: Text(
            widget.items[widget.selectedIndex].subtitle,
            key: ValueKey(widget.selectedIndex),
            textAlign: TextAlign.center,
            style: AuthUi.pageSubtitle(context),
          ),
        ),
      ],
    );
  }
}

/// Horizontal wheel picker — same gradient style as DOB columns, scrolls sideways.
class AuthSidewaysWheelPicker extends StatefulWidget {
  final List<String> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double height;
  final double itemExtent;
  final double selectedFontSize;
  final double unselectedFontSize;

  const AuthSidewaysWheelPicker({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.height = 80,
    this.itemExtent = 72,
    this.selectedFontSize = 17,
    this.unselectedFontSize = 14,
  });

  @override
  State<AuthSidewaysWheelPicker> createState() => _AuthSidewaysWheelPickerState();
}

class _AuthSidewaysWheelPickerState extends State<AuthSidewaysWheelPicker> {
  late FixedExtentScrollController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
    _controller = FixedExtentScrollController(initialItem: widget.selectedIndex);
  }

  @override
  void didUpdateWidget(covariant AuthSidewaysWheelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex &&
        _controller.hasClients) {
      _currentIndex = widget.selectedIndex;
      _controller.animateToItem(
        widget.selectedIndex,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).colorScheme.onSurface;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: widget.height,
          width: constraints.maxWidth,
          child: RotatedBox(
            quarterTurns: -1,
            child: SizedBox(
              width: widget.height,
              height: constraints.maxWidth,
              child: CupertinoPicker(
                scrollController: _controller,
                itemExtent: widget.itemExtent,
                diameterRatio: 2.4,
                onSelectedItemChanged: (index) {
                  setState(() => _currentIndex = index);
                  HapticFeedback.selectionClick();
                  widget.onSelected(index);
                },
                children: List.generate(widget.items.length, (index) {
                  final text = widget.items[index];
                  final isSelected = index == _currentIndex;

                  return RotatedBox(
                    quarterTurns: 1,
                    child: Center(
                      child: isSelected
                          ? ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Color(0xFFFF8A00),
                                  Color(0xFFFFD93D),
                                ],
                              ).createShader(bounds),
                              child: Text(
                                text,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: widget.selectedFontSize,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : Text(
                              text,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textPrimary.withValues(alpha: 0.45),
                                fontSize: widget.unselectedFontSize,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Edge fade mask for wheel pickers (matches DOB picker look).
class AuthPickerFadeMask extends StatelessWidget {
  final Widget child;

  const AuthPickerFadeMask({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        stops: [0.0, 0.1, 0.9, 1.0],
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}

/// Text field that only opens the keyboard after an explicit tap.
class AuthTapToTypeField extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final TextStyle? style;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onFieldSubmitted;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;

  const AuthTapToTypeField({
    super.key,
    required this.controller,
    required this.decoration,
    this.style,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.validator,
    this.textInputAction,
    this.onEditingComplete,
    this.onFieldSubmitted,
    this.autofillHints,
    this.focusNode,
  });

  @override
  State<AuthTapToTypeField> createState() => _AuthTapToTypeFieldState();
}

class _AuthTapToTypeFieldState extends State<AuthTapToTypeField> {
  FocusNode? _ownedFocus;
  FocusNode get _focusNode => widget.focusNode ?? _ownedFocus!;
  bool _keyboardEnabled = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _ownedFocus = FocusNode();
    }
  }

  @override
  void dispose() {
    _ownedFocus?.dispose();
    super.dispose();
  }

  void _enableKeyboard() {
    if (_keyboardEnabled) return;
    setState(() => _keyboardEnabled = true);
    Future.microtask(() => _focusNode.requestFocus());
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      readOnly: !_keyboardEnabled,
      showCursor: _keyboardEnabled,
      enableInteractiveSelection: _keyboardEnabled,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      validator: widget.validator,
      onChanged: widget.onChanged,
      style: widget.style,
      onTap: _enableKeyboard,
      textInputAction: widget.textInputAction,
      onEditingComplete: widget.onEditingComplete,
      onFieldSubmitted: widget.onFieldSubmitted,
      autofillHints: widget.autofillHints,
      decoration: widget.decoration.copyWith(
        hintText: _keyboardEnabled
            ? widget.decoration.hintText
            : (widget.decoration.hintText != null
                ? '${widget.decoration.hintText} · tap to type'
                : 'Tap to type'),
      ),
    );
  }
}

class AuthStepTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const AuthStepTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );
    final slide = Tween<Offset>(
      begin: const Offset(0.03, 0.025),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    ));
    final scale = Tween<double>(begin: 0.985, end: 1).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: ScaleTransition(scale: scale, child: child),
      ),
    );
  }
}
