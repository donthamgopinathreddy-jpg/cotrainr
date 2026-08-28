import 'package:flutter/widgets.dart';

import '../../services/water_intake_service.dart';
import '../../services/water_reminder_service.dart';

/// Reloads hydration after notification quick-logs while the app was backgrounded.
class HydrationLifecycleRefresher extends StatefulWidget {
  const HydrationLifecycleRefresher({super.key, required this.child});

  final Widget child;

  @override
  State<HydrationLifecycleRefresher> createState() =>
      _HydrationLifecycleRefresherState();
}

class _HydrationLifecycleRefresherState
    extends State<HydrationLifecycleRefresher> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    try {
      // Apply notification taps first so the flush below pushes them remotely
      // in the same pass — otherwise the water card shows a stale total.
      await WaterIntakeService.instance.drainNativeQuickLogs();
      await WaterIntakeService.instance.flushPendingRemoteSync();
      await WaterReminderService.instance.syncHydrationSnapshot();
      // Heal the alarm chain if the OS dropped it while we were away.
      await WaterReminderService.instance.ensureScheduleAlive();
      // Notify home / insights listeners even if totals were local-only.
      WaterIntakeService.revision.value++;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
