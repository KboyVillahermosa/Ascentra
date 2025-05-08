import 'dart:convert';

class Post {
  final String id;
  final String username;
  final DateTime timestamp;
  final String caption;
  final List<String> mediaUrls;
  final bool isVideo; // true if it's a video, false if it's an image
  final Set<String> likedBy;
  
  Post({
    required this.id,
    required this.username,
    required this.timestamp,
    required this.caption,
    required this.mediaUrls,
    required this.isVideo,
    Set<String>? likedBy,
  }) : this.likedBy = likedBy ?? {};
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'timestamp': timestamp.toIso8601String(),
      'caption': caption,
      'mediaUrls': mediaUrls,
      'isVideo': isVideo,
      'likedBy': likedBy.toList(),
    };
  }
  
  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      username: json['username'],
      timestamp: DateTime.parse(json['timestamp']),
      caption: json['caption'],
      mediaUrls: List<String>.from(json['mediaUrls']),
      isVideo: json['isVideo'],
      likedBy: Set<String>.from(json['likedBy'] ?? []),
    );
  }
  
  // Return a copy of the post with updated likes
  Post toggleLike(String username) {
    final newLikedBy = Set<String>.from(likedBy);
    if (newLikedBy.contains(username)) {
      newLikedBy.remove(username);
    } else {
      newLikedBy.add(username);
    }
    
    return Post(
      id: id,
      username: this.username,
      timestamp: timestamp,
      caption: caption,
      mediaUrls: mediaUrls,
      isVideo: isVideo,
      likedBy: newLikedBy,
    );
  }
  
  bool isLikedBy(String username) => likedBy.contains(username);
  
  int get likesCount => likedBy.length;
}