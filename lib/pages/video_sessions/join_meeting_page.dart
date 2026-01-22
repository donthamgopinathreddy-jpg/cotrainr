import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';

class JoinMeetingPage extends StatefulWidget {
  const JoinMeetingPage({super.key});

  @override
  State<JoinMeetingPage> createState() => _JoinMeetingPageState();
}

class _JoinMeetingPageState extends State<JoinMeetingPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _meetingIdController = TextEditingController();
  final _joinCodeController = TextEditingController();
  final _nameController = TextEditingController(text: 'John Doe');
  
  late AnimationController _shakeController;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _meetingIdController.dispose();
    _joinCodeController.dispose();
    _nameController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _joinMeeting() {
    if (!_formKey.currentState!.validate()) {
      _shakeAnimation();
      return;
    }

    final meetingId = _meetingIdController.text.trim();
    final joinCode = _joinCodeController.text.trim().toUpperCase();
    
    // Validate meeting ID format (6 digits)
    if (meetingId.length != 6 || !RegExp(r'^[0-9]+$').hasMatch(meetingId)) {
      _shakeAnimation();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid meeting ID format (must be 6 digits)'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    // Validate join code format (6 uppercase chars, excluding O, 0, I, 1)
    if (joinCode.length != 6 || !RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]+$').hasMatch(joinCode)) {
      _shakeAnimation();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid join code format (6 uppercase chars, excluding O, 0, I, 1)'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    // Create ShareKey format: "MeetingID-MeetingCode"
    final shareKey = '$meetingId-$joinCode';

    setState(() => _isJoining = true);
    HapticFeedback.mediumImpact();

    // Simulate join delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _isJoining = false);
        context.push('/video/room/$shareKey');
      }
    });
  }

  void _shakeAnimation() {
    HapticFeedback.lightImpact();
    _shakeController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF1A0F2E) // Purple-black mix background (not too dark)
          : const Color(0xFFF0EBFF), // More vibrant light purple background
      appBar: AppBar(
        title: const Text(
          'Join Meeting',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              // Header
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.purple, Color(0xFFB38CFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.videocam_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Enter Meeting Details',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter meeting ID or join code',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              
              // Meeting ID/Code Input
              AnimatedBuilder(
                animation: _shakeController,
                builder: (context, child) {
                  final offset = Offset(
                    _shakeController.value * 10 * (1 - _shakeController.value),
                    0,
                  );
                  return Transform.translate(
                    offset: offset,
                    child: child,
                  );
                },
                child: TextFormField(
                  controller: _meetingIdController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter meeting ID';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Meeting ID',
                    hintText: 'Enter 6-digit ID',
                    prefixIcon: const Icon(Icons.badge_rounded, color: AppColors.purple),
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                      borderSide: BorderSide(
                        color: DesignTokens.borderColorOf(context),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                      borderSide: BorderSide(
                        color: DesignTokens.borderColorOf(context),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                      borderSide: const BorderSide(
                        color: AppColors.purple,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                      borderSide: const BorderSide(
                        color: AppColors.red,
                        width: 1,
                      ),
                    ),
                  ),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Join Code Input
              AnimatedBuilder(
                animation: _shakeController,
                builder: (context, child) {
                  final offset = Offset(
                    _shakeController.value * 10 * (1 - _shakeController.value),
                    0,
                  );
                  return Transform.translate(
                    offset: offset,
                    child: child,
                  );
                },
                child: TextFormField(
                  controller: _joinCodeController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter join code';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Join Code',
                    hintText: 'Enter 6-character code',
                    prefixIcon: const Icon(Icons.key_rounded, color: AppColors.purple),
                    filled: true,
                    fillColor: colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                      borderSide: BorderSide(
                        color: DesignTokens.borderColorOf(context),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                      borderSide: BorderSide(
                        color: DesignTokens.borderColorOf(context),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                      borderSide: const BorderSide(
                        color: AppColors.purple,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                      borderSide: const BorderSide(
                        color: AppColors.red,
                        width: 1,
                      ),
                    ),
                  ),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 18,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Optional Name Field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Your Name (Optional)',
                  hintText: 'Enter your name',
                  prefixIcon: const Icon(Icons.person_rounded, color: AppColors.purple),
                  filled: true,
                  fillColor: colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                    borderSide: BorderSide(
                      color: DesignTokens.borderColorOf(context),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                    borderSide: BorderSide(
                      color: DesignTokens.borderColorOf(context),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                    borderSide: const BorderSide(
                      color: AppColors.purple,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              // Join Button
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.purple, Color(0xFFB38CFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ElevatedButton(
                  onPressed: _isJoining ? null : _joinMeeting,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                  ),
                  child: _isJoining
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Join Meeting',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
