import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  static const _cocircleGradient = LinearGradient(
    colors: [Color(0xFF4DA3FF), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  Future<void> _openTermsWebsite() async {
    final url = Uri.parse('https://www.cotrainr.com/terms');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF1A2335)
        : const Color(0xFFE3F2FD);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => _cocircleGradient.createShader(bounds),
          child: const Text(
            'Terms of Service',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cotrainr Terms of Service',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Last Updated: ${DateTime.now().year}',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Please read these Terms of Service carefully before using the Cotrainr application.',
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurface,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      context,
                      title: '1. Acceptance of Terms',
                      content:
                          'By accessing and using Cotrainr, you accept and agree to be bound by the terms and provision of this agreement.',
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      context,
                      title: '2. Use License',
                      content:
                          'Permission is granted to temporarily download one copy of Cotrainr for personal, non-commercial transitory viewing only.',
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      context,
                      title: '3. User Account',
                      content:
                          'You are responsible for maintaining the confidentiality of your account and password. You agree to accept responsibility for all activities that occur under your account.',
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      context,
                      title: '4. Privacy',
                      content:
                          'Your use of Cotrainr is also governed by our Privacy Policy. Please review our Privacy Policy to understand our practices.',
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      context,
                      title: '5. Limitation of Liability',
                      content:
                          'In no event shall Cotrainr or its suppliers be liable for any damages arising out of the use or inability to use the application.',
                    ),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: _openTermsWebsite,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Full Terms of Service',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ShaderMask(
                                    shaderCallback: (bounds) =>
                                        _cocircleGradient.createShader(bounds),
                                    child: const Text(
                                      'www.cotrainr.com/terms',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.white,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.open_in_new,
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: TextStyle(
            fontSize: 16,
            color: colorScheme.onSurface.withValues(alpha: 0.8),
            height: 1.6,
          ),
        ),
      ],
    );
  }
}
