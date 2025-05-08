import 'dart:convert';

class Comment {
  final String id;
  final String text;
  final String username;
  final DateTime timestamp;
  final String activityId; // This is used as postId in the social context
  
  Comment({
    required this.id,
    required this.text,
    required this.username,
    required this.timestamp,
    required this.activityId,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'username': username,
      'timestamp': timestamp.toIso8601String(),
      'activityId': activityId,
    };
  }
  
  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      text: json['text'],
      username: json['username'],
      timestamp: DateTime.parse(json['timestamp']),
      activityId: json['activityId'],
    );
  }
}