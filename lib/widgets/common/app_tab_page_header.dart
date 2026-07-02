import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/design_tokens.dart';

/// Tab-page title row — accent icon + neutral title text.
class AppTabPageHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final LinearGradient gradient;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const AppTabPageHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.gradient,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
  });

  /// Messages tab icon gradient.
  static const messagesGradient = LinearGradient(
    colors: [Color(0xFF4DA3FF), Color(0xFF00C9C8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Meals tab icon gradient.
  static const mealsGradient = LinearGradient(
    colors: [Color(0xFF3ED598), Color(0xFF65E6B3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    final titleColor = DesignTokens.textPrimaryOf(context);

    return Padding(
      padding: padding,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            ShaderMask(
              shaderCallback: (rect) => gradient.createShader(rect),
              child: Icon(icon, size: 26, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title.toUpperCase(),
                  style: GoogleFonts.montserrat(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: titleColor,
                  ),
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
