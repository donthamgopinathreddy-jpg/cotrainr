import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/design_tokens.dart';

class ProfileTabs extends StatelessWidget {
  final TabController controller;
  final ValueChanged<int>? onTabChanged;

  const ProfileTabs({
    super.key,
    required this.controller,
    this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacing16,
        vertical: DesignTokens.spacing16,
      ),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceOf(context),
        borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
      ),
      child: TabBar(
        controller: controller,
        onTap: onTabChanged,
        indicator: BoxDecoration(
          gradient: DesignTokens.primaryGradient,
          borderRadius: BorderRadius.circular(DesignTokens.radiusChip),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: DesignTokens.textSecondaryOf(context),
        labelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: DesignTokens.fontSizeBody,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          fontSize: DesignTokens.fontSizeBody,
        ),
        tabs: const [
          Tab(text: 'Posts'),
          Tab(text: 'Achievements'),
          Tab(text: 'Activity'),
        ],
      ),
    );
  }
}

