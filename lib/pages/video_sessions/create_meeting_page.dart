import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../models/video_session_models.dart';
import '../../services/meeting_storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/design_tokens.dart';

class CreateMeetingPage extends StatefulWidget {
  final Role userRole;
  final bool isSchedule;

  const CreateMeetingPage({
    super.key,
    required this.userRole,
    this.isSchedule = false,
  });

  @override
  State<CreateMeetingPage> createState() => _CreateMeetingPageState();
}

class _CreateMeetingPageState extends State<CreateMeetingPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  
  MeetingPrivacy _privacy = MeetingPrivacy.publicCode;
  bool _isInstant = true;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  int? _selectedDuration;
  List<Role> _allowedRoles = [];
  
  String? _generatedMeetingId;
  String? _generatedJoinCode;

  @override
  void initState() {
    super.initState();
    _isInstant = !widget.isSchedule;
    _initializeAllowedRoles();
    _generateMeetingDetails();
  }

  void _initializeAllowedRoles() {
    switch (widget.userRole) {
      case Role.client:
        _allowedRoles = [Role.trainer, Role.nutritionist];
        break;
      case Role.trainer:
      case Role.nutritionist:
        _allowedRoles = [Role.client];
        break;
    }
  }

  void _generateMeetingDetails() {
    final random = Random.secure();
    
    // Generate Meeting ID: 6 digits (example: 483921)
    _generatedMeetingId = random.nextInt(1000000).toString().padLeft(6, '0');
    
    // Generate Meeting Code: 6 uppercase chars excluding O, 0, I, 1 (example: Q7K9M2)
    const codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final codeBuffer = StringBuffer();
    for (var i = 0; i < 6; i++) {
      codeBuffer.write(codeChars[random.nextInt(codeChars.length)]);
    }
    _generatedJoinCode = codeBuffer.toString();
  }

  LinearGradient get _roleGradient {
    // Use purple gradient for all video sessions
    return const LinearGradient(
      colors: [AppColors.purple, Color(0xFFB38CFF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.purple,
              onPrimary: Colors.white,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: AppColors.textPrimaryOf(context),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.purple,
              onPrimary: Colors.white,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: AppColors.textPrimaryOf(context),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _toggleRole(Role role) {
    setState(() {
      if (_allowedRoles.contains(role)) {
        _allowedRoles.remove(role);
      } else {
        _allowedRoles.add(role);
      }
    });
  }

  void _createMeeting() {
    if (!_formKey.currentState!.validate()) return;

    if (!_isInstant) {
      if (_selectedDate == null || _selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select date and time')),
        );
        return;
      }

      final scheduledDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      if (scheduledDateTime.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scheduled time must be at least 5 minutes from now')),
        );
        return;
      }
    }

    if (_allowedRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one allowed role')),
      );
      return;
    }

    // Validate duration is selected
    if (_selectedDuration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a meeting duration')),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    
    // Regenerate meeting details to ensure uniqueness for each meeting
    _generateMeetingDetails();
    
    // Ensure uniqueness by checking against existing meetings
    final storageService = MeetingStorageService();
    int attempts = 0;
    while (attempts < 100) { // Max 100 attempts to find unique ID/code
      final existingMeeting = storageService.getMeetingById(_generatedMeetingId!);
      if (existingMeeting == null) {
        // Check if shareKey is unique
        final shareKey = '${_generatedMeetingId}-${_generatedJoinCode}';
        final hasDuplicate = storageService.allMeetings.any(
          (m) => m.shareKey == shareKey
        );
        if (!hasDuplicate) {
          break; // Unique ID and code found
        }
      }
      // Regenerate if duplicate found
      _generateMeetingDetails();
      attempts++;
    }
    
    // Create meeting object
    final now = DateTime.now();
    final meeting = Meeting(
      meetingId: _generatedMeetingId!,
      title: _titleController.text.trim(),
      hostUserId: 'current_user', // Replace with actual user ID
      hostRole: widget.userRole,
      createdAt: now,
      scheduledFor: !_isInstant ? DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      ) : null,
      startedAt: _isInstant ? now : null, // Set start time for instant meetings
      durationMins: _selectedDuration,
      isInstant: _isInstant,
      joinCode: _generatedJoinCode!,
      privacy: _privacy,
      allowedRoles: _allowedRoles,
      status: _isInstant ? MeetingStatus.live : MeetingStatus.upcoming,
    );

    // Save meeting locally (both instant and scheduled)
    MeetingStorageService().addMeeting(meeting);
    
    // Show success sheet with ShareKey
    _showMeetingDetails(meeting);
    
    // For instant meetings, navigation happens in the success sheet button
  }

  void _showMeetingDetails(Meeting meeting) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Meeting Created!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 20),
            // ShareKey - Primary display
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.purple.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Share Key',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryOf(context),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              meeting.shareKey,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                color: AppColors.purple,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: meeting.shareKey));
                          HapticFeedback.mediumImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Share key copied!')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, color: AppColors.purple, size: 24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Optional: Show ID and Code as small chips
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'ID: ${meeting.meetingId}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.purple,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Code: ${meeting.joinCode}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.purple,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: _roleGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (_isInstant) {
                      // Navigate to meeting room for instant meetings using ShareKey
                      context.push('/video/room/${meeting.shareKey}');
                    } else {
                      context.pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
          'Create Meeting',
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
              // Title Field Card - Separate Box
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: DesignTokens.cardShadowOf(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meeting Title',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [AppColors.purple, Color(0xFFB38CFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: colorScheme.surface,
                        ),
                        child: TextFormField(
                          controller: _titleController,
                          maxLength: 40,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter meeting title';
                            }
                            return null;
                          },
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                            color: AppColors.textPrimaryOf(context),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter meeting title',
                            hintStyle: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w300,
                              color: AppColors.textSecondaryOf(context),
                            ),
                            filled: true,
                            fillColor: Colors.transparent,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _titleController,
                      builder: (context, value, child) {
                        return Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${value.text.length}/40',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondaryOf(context),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Main Form Card
              _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 0),
                    
                    // Privacy Selector
                    Text(
                      'Privacy',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _PrivacyPill(
                            label: 'Invite Only',
                            isSelected: _privacy == MeetingPrivacy.inviteOnly,
                            onTap: () {
                              setState(() => _privacy = MeetingPrivacy.inviteOnly);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PrivacyPill(
                            label: 'Public Code',
                            isSelected: _privacy == MeetingPrivacy.publicCode,
                            onTap: () {
                              setState(() => _privacy = MeetingPrivacy.publicCode);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Instant or Schedule Toggle
                    Row(
                      children: [
                        Expanded(
                          child: _PrivacyPill(
                            label: 'Instant',
                            isSelected: _isInstant,
                            onTap: () {
                              setState(() => _isInstant = true);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PrivacyPill(
                            label: 'Schedule',
                            isSelected: !_isInstant,
                            onTap: () {
                              setState(() => _isInstant = false);
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    // Schedule Fields
                    if (!_isInstant) ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: _DatePickerButton(
                              label: 'Date',
                              date: _selectedDate,
                              onTap: _selectDate,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DatePickerButton(
                              label: 'Time',
                              time: _selectedTime,
                              onTap: _selectTime,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Duration',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [15, 30, 45, 60].map((mins) {
                          return _DurationChip(
                            minutes: mins,
                            isSelected: _selectedDuration == mins,
                            onTap: () {
                              setState(() => _selectedDuration = mins);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 24),
                    
                    // Allowed Roles
                    Text(
                      'Allowed Roles',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (widget.userRole != Role.client)
                          _RoleChipSelector(
                            role: Role.client,
                            isSelected: _allowedRoles.contains(Role.client),
                            onTap: () => _toggleRole(Role.client),
                          ),
                        if (widget.userRole != Role.trainer)
                          _RoleChipSelector(
                            role: Role.trainer,
                            isSelected: _allowedRoles.contains(Role.trainer),
                            onTap: () => _toggleRole(Role.trainer),
                          ),
                        if (widget.userRole != Role.nutritionist)
                          _RoleChipSelector(
                            role: Role.nutritionist,
                            isSelected: _allowedRoles.contains(Role.nutritionist),
                            onTap: () => _toggleRole(Role.nutritionist),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Max Participants: Up to 10',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(
                gradient: _roleGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ElevatedButton(
                onPressed: _createMeeting,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                ),
                child: const Text(
                  'Create Meeting',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: DesignTokens.cardShadowOf(context),
      ),
      child: child,
    );
  }
}

class _PrivacyPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PrivacyPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected ? const LinearGradient(
              colors: [AppColors.purple, Color(0xFFB38CFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ) : null,
            color: isSelected ? null : colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : DesignTokens.borderColorOf(context),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimaryOf(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final TimeOfDay? time;
  final VoidCallback onTap;

  const _DatePickerButton({
    required this.label,
    this.date,
    this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    String displayText = 'Select $label';
    
    if (date != null) {
      displayText = '${date!.day}/${date!.month}/${date!.year}';
    } else if (time != null) {
      displayText = '${time!.hour}:${time!.minute.toString().padLeft(2, '0')}';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (date != null || time != null)
                  ? AppColors.purple
                  : DesignTokens.borderColorOf(context),
              width: (date != null || time != null) ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                label == 'Date' ? Icons.calendar_today_rounded : Icons.access_time_rounded,
                size: 18,
                color: AppColors.purple,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayText,
                  style: TextStyle(
                    color: (date != null || time != null)
                        ? AppColors.purple
                        : AppColors.textPrimaryOf(context),
                    fontSize: 14,
                    fontWeight: (date != null || time != null) ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final int minutes;
  final bool isSelected;
  final VoidCallback onTap;

  const _DurationChip({
    required this.minutes,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected ? const LinearGradient(
              colors: [AppColors.purple, Color(0xFFB38CFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ) : null,
            color: isSelected ? null : colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : DesignTokens.borderColorOf(context),
            ),
          ),
          child: Text(
            '$minutes min',
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textPrimaryOf(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleChipSelector extends StatelessWidget {
  final Role role;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleChipSelector({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = role.name.toUpperCase();
    // Use purple gradient for all roles
    const gradient = LinearGradient(
      colors: [AppColors.purple, Color(0xFFB38CFF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected ? gradient : null,
            color: isSelected ? null : colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : DesignTokens.borderColorOf(context),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textPrimaryOf(context),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onCopy;

  const _PreviewField({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.purple.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: AppColors.purple,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, color: AppColors.purple),
          ),
        ],
      ),
    );
  }
}
