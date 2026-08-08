/// Stable report reason IDs stored in `user_reports.reason`.
class UserReportReasons {
  UserReportReasons._();

  static const harassment = 'harassment';
  static const inappropriateContent = 'inappropriate_content';
  static const spam = 'spam';
  static const fraud = 'fraud';
  static const sexualContent = 'sexual_content';
  static const hateAbuse = 'hate_abuse';
  static const impersonation = 'impersonation';
  static const unsafeCoaching = 'unsafe_coaching';
  static const other = 'other';

  static const List<({String id, String label})> options = [
    (id: harassment, label: 'Harassment or bullying'),
    (id: inappropriateContent, label: 'Inappropriate content'),
    (id: spam, label: 'Spam'),
    (id: fraud, label: 'Scam or fraud'),
    (id: sexualContent, label: 'Sexual/inappropriate behaviour'),
    (id: hateAbuse, label: 'Hate or abusive behaviour'),
    (id: impersonation, label: 'Impersonation'),
    (id: unsafeCoaching, label: 'Unsafe coaching/advice'),
    (id: other, label: 'Other'),
  ];

  static String labelFor(String id) {
    for (final o in options) {
      if (o.id == id) return o.label;
    }
    return id;
  }
}

class BlockState {
  final bool iBlocked;
  final bool theyBlocked;

  const BlockState({
    required this.iBlocked,
    required this.theyBlocked,
  });

  bool get eitherBlocked => iBlocked || theyBlocked;

  factory BlockState.fromJson(Map<String, dynamic> json) {
    return BlockState(
      iBlocked: json['i_blocked'] == true,
      theyBlocked: json['they_blocked'] == true,
    );
  }

  static const none = BlockState(iBlocked: false, theyBlocked: false);
}
