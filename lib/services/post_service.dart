import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../models/post.dart';
import '../models/comment.dart';

class PostService {
  static const String _postsKey = 'social_posts';
  static const String _postCommentsKey = 'post_comments';
  
  // Get all posts
  static Future<List<Post>> getAllPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? postStrings = prefs.getStringList(_postsKey);
    
    if (postStrings == null) return [];
    
    return postStrings
      .map((str) => Post.fromJson(jsonDecode(str)))
      .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first
  }
  
  // Save a new post
  static Future<bool> createPost({
    required String username,
    required String caption,
    required List<XFile> mediaFiles,
    required bool isVideo,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> existingPosts = prefs.getStringList(_postsKey) ?? [];
      
      // Save media files to local storage
      final List<String> mediaUrls = [];
      final directory = await getApplicationDocumentsDirectory();
      
      for (var file in mediaFiles) {
        final fileName = '${Uuid().v4()}_${file.name}';
        final savedFile = File('${directory.path}/$fileName');
        
        // Copy the picked file to app directory
        await savedFile.writeAsBytes(await file.readAsBytes());
        mediaUrls.add(savedFile.path);
      }
      
      final newPost = Post(
        id: Uuid().v4(),
        username: username,
        timestamp: DateTime.now(),
        caption: caption,
        mediaUrls: mediaUrls,
        isVideo: isVideo,
      );
      
      existingPosts.add(jsonEncode(newPost.toJson()));
      
      return await prefs.setStringList(_postsKey, existingPosts);
    } catch (e) {
      print('Error creating post: $e');
      return false;
    }
  }
  
  // Delete a post
  static Future<bool> deletePost(String postId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? postStrings = prefs.getStringList(_postsKey);
      
      if (postStrings == null) return false;
      
      List<String> mediaPathsToDelete = [];
      
      final updatedPosts = postStrings
        .where((str) {
          final post = Post.fromJson(jsonDecode(str));
          if (post.id == postId) {
            mediaPathsToDelete = post.mediaUrls;
            return false;
          }
          return true;
        })
        .toList();
      
      // Delete the media files
      for (var path in mediaPathsToDelete) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
      
      // Also delete any comments associated with this post
      await _deleteCommentsForPost(postId);
      
      return await prefs.setStringList(_postsKey, updatedPosts);
    } catch (e) {
      print('Error deleting post: $e');
      return false;
    }
  }
  
  // Toggle like on a post
  static Future<Post?> toggleLike(String postId, String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? postStrings = prefs.getStringList(_postsKey);
      
      if (postStrings == null) return null;
      
      Post? updatedPost;
      final updatedPosts = postStrings.map((str) {
        final post = Post.fromJson(jsonDecode(str));
        if (post.id == postId) {
          final newPost = post.toggleLike(username);
          updatedPost = newPost;
          return jsonEncode(newPost.toJson());
        }
        return str;
      }).toList();
      
      await prefs.setStringList(_postsKey, updatedPosts);
      return updatedPost;
    } catch (e) {
      print('Error toggling like: $e');
      return null;
    }
  }
  
  // Get comments for a post
  static Future<List<Comment>> getCommentsForPost(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? commentStrings = prefs.getStringList(_postCommentsKey);
    
    if (commentStrings == null) return [];
    
    return commentStrings
      .map((str) => Comment.fromJson(jsonDecode(str)))
      .where((comment) => comment.activityId == postId)
      .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }
  
  // Add a comment to a post
  static Future<bool> addComment(String postId, String text, String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> existingComments = prefs.getStringList(_postCommentsKey) ?? [];
      
      final newComment = Comment(
        id: Uuid().v4(),
        text: text,
        username: username,
        timestamp: DateTime.now(),
        activityId: postId, // We're reusing the Comment model, so activityId here is the postId
      );
      
      existingComments.add(jsonEncode(newComment.toJson()));
      
      return await prefs.setStringList(_postCommentsKey, existingComments);
    } catch (e) {
      print('Error adding comment: $e');
      return false;
    }
  }
  
  // Delete a comment
  static Future<bool> deleteComment(String commentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? commentStrings = prefs.getStringList(_postCommentsKey);
      
      if (commentStrings == null) return false;
      
      final updatedComments = commentStrings
        .where((str) {
          final comment = Comment.fromJson(jsonDecode(str));
          return comment.id != commentId;
        })
        .toList();
        
      return await prefs.setStringList(_postCommentsKey, updatedComments);
    } catch (e) {
      print('Error deleting comment: $e');
      return false;
    }
  }
  
  // Helper method to delete all comments for a post
  static Future<bool> _deleteCommentsForPost(String postId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? commentStrings = prefs.getStringList(_postCommentsKey);
      
      if (commentStrings == null) return true;
      
      final updatedComments = commentStrings
        .where((str) {
          final comment = Comment.fromJson(jsonDecode(str));
          return comment.activityId != postId;
        })
        .toList();
        
      return await prefs.setStringList(_postCommentsKey, updatedComments);
    } catch (e) {
      print('Error deleting post comments: $e');
      return false;
    }
  }
}