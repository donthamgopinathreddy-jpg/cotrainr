import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../models/video_session_models.dart';
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
    final random = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    _generatedMeetingId = String.fromCharCodes(
      Iterable.generate(8, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
    const digits = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    _generatedJoinCode = String.fromCharCodes(
      Iterable.generate(6, (_) => digits.codeUnitAt(random.nextInt(digits.length))),
    );
  }

  LinearGradient get _roleGradient {
    switch (widget.userRole) {
      case Role.client:
        return AppColors.clientVideoGradient;
      case Role.trainer:
        return AppColors.trainerVideoGradient;
      case Role.nutritionist:
        return AppColors.nutritionistVideoGradient;
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
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

      if (scheduledDateTime.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
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

    HapticFeedback.mediumImpact();
    
    // Navigate to meeting room
    context.push('/video/room/${_generatedMeetingId}');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
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
              // Meeting Basics Card
              _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meeting Basics',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Title
                    TextFormField(
                      controller: _titleController,
                      maxLength: 40,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter meeting title';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        labelText: 'Title',
                        hintText: 'Enter meeting title',
                        prefixIcon: const Icon(Icons.title_rounded, color: AppColors.orange),
                        filled: true,
                        fillColor: colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
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
              const SizedBox(height: 20),
              
              // Preview Card
              _GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _PreviewField(
                      label: 'Meeting ID',
                      value: _generatedMeetingId ?? '',
                      onCopy: () {
                        Clipboard.setData(ClipboardData(text: _generatedMeetingId ?? ''));
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Meeting ID copied!')),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    _PreviewField(
                      label: 'Join Code',
                      value: _generatedJoinCode ?? '',
                      onCopy: () {
                        Clipboard.setData(ClipboardData(text: _generatedJoinCode ?? ''));
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Join code copied!')),
                        );
                      },
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
        color: colorScheme.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(22),
        boxShadow: DesignTokens.cardShadowOf(context),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: child,
        ),
      ),
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
            gradient: isSelected ? AppColors.stepsGradient : null,
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
              color: DesignTokens.borderColorOf(context),
            ),
          ),
          child: Row(
            children: [
              Icon(
                label == 'Date' ? Icons.calendar_today_rounded : Icons.access_time_rounded,
                size: 18,
                color: AppColors.orange,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayText,
                  style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontSize: 14,
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
            gradient: isSelected ? AppColors.stepsGradient : null,
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
    LinearGradient gradient;
    switch (role) {
      case Role.trainer:
        gradient = AppColors.trainerVideoGradient;
        break;
      case Role.nutritionist:
        gradient = AppColors.nutritionistVideoGradient;
        break;
      default:
        gradient = AppColors.clientVideoGradient;
    }

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
          color: AppColors.orange.withOpacity(0.3),
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
                    color: AppColors.orange,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, color: AppColors.orange),
          ),
        ],
      ),
    );
  }
}
