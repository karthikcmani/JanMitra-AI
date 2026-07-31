class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? grievanceRefId;
  final List<String>? suggestedActions;
  final bool isAiThinking;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.grievanceRefId,
    this.suggestedActions,
    this.isAiThinking = false,
  });
}
