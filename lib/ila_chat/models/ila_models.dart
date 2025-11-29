class IlaMessage {
  final String id;
  final String? message;
  final bool isBot;
  final String? createdAt;
  final List<String> files;

  IlaMessage({
    required this.id,
    this.message,
    required this.isBot,
    this.createdAt,
    this.files = const [],
  });

  factory IlaMessage.fromJson(Map<String, dynamic> json) {
    return IlaMessage(
      id: json['id'] ?? '',
      message: json['message'],
      isBot: json['bot'] == true, // اگر bot true باشد یعنی پیام از طرف ربات است
      createdAt: json['created_at'], // ممکن است null باشد
      files: json['files'] != null
          ? List<String>.from(json['files'].map((x) => x.toString()))
          : [],
    );
  }
}

class IlaConversation {
  final String id;
  final String? title;
  final int messagesCount;

  IlaConversation({
    required this.id,
    this.title,
    required this.messagesCount,
  });

  factory IlaConversation.fromJson(Map<String, dynamic> json) {
    return IlaConversation(
      id: json['id'],
      title: json['title'],
      messagesCount: json['messages_count'] ?? 0,
    );
  }
}
