import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotificationsResult {
  final bool push;
  final bool community;
  final bool reminders;

  const NotificationsResult({
    required this.push,
    required this.community,
    required this.reminders,
  });
}

class NotificationsPage extends StatefulWidget {
  final bool pushNotifications;
  final bool communityNotifications;
  final bool reminderNotifications;

  const NotificationsPage({
    super.key,
    required this.pushNotifications,
    required this.communityNotifications,
    required this.reminderNotifications,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late bool _push;
  late bool _community;
  late bool _reminders;

  @override
  void initState() {
    super.initState();
    _push = widget.pushNotifications;
    _community = widget.communityNotifications;
    _reminders = widget.reminderNotifications;
  }

  void _save() {
    HapticFeedback.lightImpact();
    Navigator.pop(
      context,
      NotificationsResult(push: _push, community: _community, reminders: _reminders),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? cs.surface : const Color(0xFFFFF3E0);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Save', style: TextStyle(color: cs.primary)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _SectionCard(
            title: 'Push notifications',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _push,
                  onChanged: (v) => setState(() => _push = v),
                  title: const Text('All notifications'),
                  subtitle: const Text('Master switch for push notifications.'),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _community,
                  onChanged: _push ? (v) => setState(() => _community = v) : null,
                  title: const Text('Community'),
                  subtitle: const Text('Likes, comments, mentions, follows.'),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _reminders,
                  onChanged: _push ? (v) => setState(() => _reminders = v) : null,
                  title: const Text('Reminders'),
                  subtitle: const Text('Habit and meal reminders.'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

