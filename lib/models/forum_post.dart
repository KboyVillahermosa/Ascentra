import 'dart:convert';

class ForumPost {
  final String id;
  final String title;
  final String content;
  final String authorUsername;
  final DateTime timestamp;
  final List<ForumComment> comments;
  final int viewCount;
  final List<MediaAttachment> attachments;
  
  ForumPost({
    required this.id,
    required this.title,
    required this.content,
    required this.authorUsername,
    required this.timestamp,
    this.comments = const [],
    this.viewCount = 0,
    this.attachments = const [],
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'authorUsername': authorUsername,
      'timestamp': timestamp.toIso8601String(),
      'comments': comments.map((comment) => comment.toJson()).toList(),
      'viewCount': viewCount,
      'attachments': attachments.map((attachment) => attachment.toJson()).toList(),
    };
  }
  
  factory ForumPost.fromJson(Map<String, dynamic> json) {
    return ForumPost(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      authorUsername: json['authorUsername'],
      timestamp: DateTime.parse(json['timestamp']),
      comments: (json['comments'] as List?)
          ?.map((comment) => ForumComment.fromJson(comment))
          .toList() ?? [],
      viewCount: json['viewCount'] ?? 0,
      attachments: (json['attachments'] as List?)
          ?.map((attachment) => MediaAttachment.fromJson(attachment))
          .toList() ?? [],
    );
  }
  
  ForumPost copyWith({
    String? title,
    String? content,
    List<ForumComment>? comments,
    int? viewCount,
    List<MediaAttachment>? attachments,
  }) {
    return ForumPost(
      id: this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      authorUsername: this.authorUsername,
      timestamp: this.timestamp,
      comments: comments ?? this.comments,
      viewCount: viewCount ?? this.viewCount,
      attachments: attachments ?? this.attachments,
    );
  }
}

class ForumComment {
  final String id;
  final String content;
  final String authorUsername;
  final DateTime timestamp;
  
  ForumComment({
    required this.id,
    required this.content,
    required this.authorUsername,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'authorUsername': authorUsername,
      'timestamp': timestamp.toIso8601String(),
    };
  }
  
  factory ForumComment.fromJson(Map<String, dynamic> json) {
    return ForumComment(
      id: json['id'],
      content: json['content'],
      authorUsername: json['authorUsername'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class MediaAttachment {
  final String id;
  final String path;
  final MediaType type;
  final String? caption;
  
  MediaAttachment({
    required this.id,
    required this.path,
    required this.type,
    this.caption,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
      'type': type.toString().split('.').last,
      'caption': caption,
    };
  }
  
  factory MediaAttachment.fromJson(Map<String, dynamic> json) {
    return MediaAttachment(
      id: json['id'],
      path: json['path'],
      type: _mediaTypeFromString(json['type']),
      caption: json['caption'],
    );
  }
  
  static MediaType _mediaTypeFromString(String? typeStr) {
    if (typeStr == 'image') return MediaType.image;
    if (typeStr == 'video') return MediaType.video;
    return MediaType.image;
  }
}

enum MediaType {
  image,
  video,
}