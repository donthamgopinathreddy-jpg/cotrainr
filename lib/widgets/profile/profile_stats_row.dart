import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import '../../theme/text_styles.dart';

class ProfileStatsRow extends StatelessWidget {
  final int posts;
  final int followers;
  final int following;

  const ProfileStatsRow({
    super.key,
    required this.posts,
    required this.followers,
    required this.following,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: DesignTokens.spacing16),
      padding: const EdgeInsets.symmetric(vertical: DesignTokens.spacing24),
      decoration: BoxDecoration(
        color: DesignTokens.surfaceOf(context),
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        boxShadow: DesignTokens.cardShadowOf(context),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat(context, 'Posts', posts),
          _buildStat(context, 'Followers', followers),
          _buildStat(context, 'Following', following),
        ],
      ),
    );
  }

  Widget _buildStat(BuildContext context, String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: AppTextStyles.h1(context),
        ),
        const SizedBox(height: DesignTokens.spacing4),
        Text(
          label,
          style: AppTextStyles.secondary(context),
        ),
      ],
    );
  }
}

