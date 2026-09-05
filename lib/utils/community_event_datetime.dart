/// Local display helpers for community event date/time.
library;

import '../models/community_event.dart';

abstract final class CommunityEventDateTime {
  /// Compact Home/details schedule line.
  static String scheduleLabel(CommunityEvent event, {DateTime? now}) {
    final n = now ?? DateTime.now();
    if (event.isHappeningNow) return 'Happening now';

    final start = event.startsAt;
    final time = _formatTime(start);
    final today = DateTime(n.year, n.month, n.day);
    final startDay = DateTime(start.year, start.month, start.day);
    final tomorrow = today.add(const Duration(days: 1));

    if (startDay == today) return 'Today • $time';
    if (startDay == tomorrow) return 'Tomorrow • $time';
    return '${_weekdayShort(start)}, ${_dayMonth(start)} • $time';
  }

  /// Two-line date badge (SEP / 20).
  static (String month, String day) dateBadge(DateTime startsAt) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return (months[startsAt.month - 1], '${startsAt.day}');
  }

  static String _formatTime(DateTime dt) {
    final h24 = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h24 >= 12 ? 'PM' : 'AM';
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return '$h12:$m $period';
  }

  static String _weekdayShort(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  }

  static String _dayMonth(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }
}
