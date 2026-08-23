/// Tracks which conversation chat screen is currently open (foreground).
/// Used to suppress message push banners while viewing that thread.
class ActiveConversationTracker {
  ActiveConversationTracker._();
  static final ActiveConversationTracker instance = ActiveConversationTracker._();

  String? activeConversationId;

  void setActive(String? id) {
    activeConversationId = id;
  }

  void clear() {
    activeConversationId = null;
  }

  bool isActive(String conversationId) =>
      activeConversationId != null && activeConversationId == conversationId;
}
