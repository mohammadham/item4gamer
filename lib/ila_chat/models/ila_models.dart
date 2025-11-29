class IlaMessage {
  final String id;
  final bool isBot;
  final String? createdAt;
  final String? message;
  final List<String> images;
  final List<String> videos;
  final List<String> files;
  final List<String> voices;
  final List<String> links;

  IlaMessage({
    required this.id,
    required this.isBot,
    this.createdAt,
    this.message,
    this.images = const [],
    this.videos = const [],
    this.files = const [],
    this.voices = const [],
    this.links = const [],
  });

  factory IlaMessage.fromJson(Map<String, dynamic> json) {
    return IlaMessage(
      createdAt: json['created_at'], // ممکن است null باشد
      id: json['id'] as String,
      isBot: json['bot'] == true,
      message: json['message'] as String?,
      images: List<String>.from(json['images'] ?? []),
      videos: List<String>.from(json['videos'] ?? []),
      files: List<String>.from(json['files'] ?? []),
      voices: List<String>.from(json['voices'] ?? []),
      links: List<String>.from(json['links'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bot': isBot,
      'message': message,
      'images': images,
      'videos': videos,
      'files': files,
      'voices': voices,
      'links': links,
    };
  }
}

class IlaConversation {
  final String id;
  final String service;
  final String? name;
  final String? email;
  final String? phone;
  final String? title;
  final bool botAnswersStatus;
  final int messagesCount;

  IlaConversation({
    required this.id,
    required this.service,
    this.name,
    this.email,
    this.phone,
    this.title,
    required this.botAnswersStatus,
    required this.messagesCount,
  });

  factory IlaConversation.fromJson(Map<String, dynamic> json) {
    return IlaConversation(
      id: json['id'] as String,
      service: json['service'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      title: json['title'] as String?,
      botAnswersStatus: json['bot_answers_status'] as bool,
      messagesCount: json['messages_count'] as int,
    );
  }
}
