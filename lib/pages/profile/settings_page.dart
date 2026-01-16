import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/theme_mode_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _privateAccount = false;
  bool _showLocation = true;
  bool _pushNotifications = true;
  bool _communityNotifications = true;
  bool _reminderNotifications = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: colorScheme.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onBackground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colorScheme.onBackground,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SettingsGroup(
            title: 'Account',
            children: [
              _SettingsRow(
                icon: Icons.edit,
                title: 'Edit Profile',
                onTap: () => HapticFeedback.lightImpact(),
              ),
              _SettingsRow(
                icon: Icons.email_outlined,
                title: 'Change Email',
                onTap: () => HapticFeedback.lightImpact(),
              ),
              _SettingsRow(
                icon: Icons.lock_outline,
                title: 'Change Password',
                onTap: () => HapticFeedback.lightImpact(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: 'Appearance',
            children: [
              _SegmentRow(
                title: 'Theme Mode',
                options: const ['System', 'Light', 'Dark'],
                selectedIndex: _themeIndexFromMode(themeMode),
                onChanged: (value) {
                  ref.read(themeModeProvider.notifier).state =
                      _themeModeFromIndex(value);
                },
              ),
              _SettingsRow(
                icon: Icons.color_lens_outlined,
                title: 'Accent Preview',
                trailing: Container(
                  width: 48,
                  height: 20,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF7A00), Color(0xFFFF4F9A)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: 'Profile Media',
            children: [
              _SettingsRow(
                icon: Icons.person_outline,
                title: 'Change Profile Photo',
                onTap: () => HapticFeedback.lightImpact(),
              ),
              _SettingsRow(
                icon: Icons.image_outlined,
                title: 'Change Cover Photo',
                onTap: () => HapticFeedback.lightImpact(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: 'Privacy',
            children: [
              _ToggleRow(
                icon: Icons.lock_outline,
                title: 'Private Account',
                value: _privateAccount,
                onChanged: (value) => setState(() => _privateAccount = value),
              ),
              _ToggleRow(
                icon: Icons.location_on_outlined,
                title: 'Show Location',
                value: _showLocation,
                onChanged: (value) => setState(() => _showLocation = value),
              ),
              _SettingsRow(
                icon: Icons.block,
                title: 'Block List',
                onTap: () => HapticFeedback.lightImpact(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: 'Notifications',
            children: [
              _ToggleRow(
                icon: Icons.notifications_none,
                title: 'Push Notifications',
                value: _pushNotifications,
                onChanged: (value) =>
                    setState(() => _pushNotifications = value),
              ),
              _ToggleRow(
                icon: Icons.people_outline,
                title: 'Community',
                value: _communityNotifications,
                onChanged: (value) =>
                    setState(() => _communityNotifications = value),
              ),
              _ToggleRow(
                icon: Icons.alarm_outlined,
                title: 'Reminders',
                value: _reminderNotifications,
                onChanged: (value) =>
                    setState(() => _reminderNotifications = value),
              ),
              _SettingsRow(
                icon: Icons.nightlight_outlined,
                title: 'Quiet Hours',
                onTap: () => HapticFeedback.lightImpact(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: 'Support',
            children: [
              _SettingsRow(
                icon: Icons.help_outline,
                title: 'Help Center',
                onTap: () => HapticFeedback.lightImpact(),
              ),
              _SettingsRow(
                icon: Icons.bug_report_outlined,
                title: 'Report Bug',
                onTap: () => HapticFeedback.lightImpact(),
              ),
              _SettingsRow(
                icon: Icons.privacy_tip_outlined,
                title: 'Terms & Privacy',
                onTap: () => HapticFeedback.lightImpact(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => HapticFeedback.mediumImpact(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: colorScheme.error,
              side: BorderSide(color: colorScheme.error.withOpacity(0.6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.logout),
            label: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

int _themeIndexFromMode(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.light:
      return 1;
    case ThemeMode.dark:
      return 2;
    case ThemeMode.system:
      return 0;
  }
}

ThemeMode _themeModeFromIndex(int index) {
  switch (index) {
    case 1:
      return ThemeMode.light;
    case 2:
      return ThemeMode.dark;
    case 0:
    default:
      return ThemeMode.system;
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outline.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color textColor = colorScheme.onSurface;
    final Color iconColor = colorScheme.onSurface.withOpacity(0.7);

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right,
                    color: colorScheme.onSurface.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onSurface.withOpacity(0.7), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _SegmentRow extends StatelessWidget {
  final String title;
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _SegmentRow({
    required this.title,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: List.generate(options.length, (index) {
              final isSelected = index == selectedIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        options[index],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color:
                              isSelected ? Colors.white : colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
