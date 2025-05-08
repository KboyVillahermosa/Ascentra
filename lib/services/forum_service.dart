import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../models/forum_post.dart';

class ForumService {
  static const String _forumPostsKey = 'forum_posts';
  
  // Get all forum posts
  static Future<List<ForumPost>> getAllPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? postStrings = prefs.getStringList(_forumPostsKey);
    
    if (postStrings == null) return [];
    
    return postStrings
      .map((str) => ForumPost.fromJson(jsonDecode(str)))
      .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first
  }
  
  // Get a specific post by ID
  static Future<ForumPost?> getPostById(String id) async {
    final posts = await getAllPosts();
    return posts.firstWhere((post) => post.id == id, orElse: () => throw Exception('Post not found'));
  }
  
  // Create a new post
  static Future<bool> createPost(
    String title,
    String content,
    String username,
    {List<MediaAttachment> attachments = const []}
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> existingPosts = prefs.getStringList(_forumPostsKey) ?? [];
      
      final newPost = ForumPost(
        id: Uuid().v4(),
        title: title,
        content: content,
        authorUsername: username,
        timestamp: DateTime.now(),
        attachments: attachments,
      );
      
      existingPosts.add(jsonEncode(newPost.toJson()));
      
      return await prefs.setStringList(_forumPostsKey, existingPosts);
    } catch (e) {
      print('Error creating post: $e');
      return false;
    }
  }
  
  // Add a comment to a post
  static Future<bool> addComment(String postId, String content, String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? postStrings = prefs.getStringList(_forumPostsKey);
      
      if (postStrings == null) return false;
      
      final List<String> updatedPosts = [];
      bool found = false;
      
      for (var postString in postStrings) {
        final post = ForumPost.fromJson(jsonDecode(postString));
        
        if (post.id == postId) {
          // Add comment to this post
          final newComment = ForumComment(
            id: Uuid().v4(),
            content: content,
            authorUsername: username,
            timestamp: DateTime.now(),
          );
          
          final updatedComments = List<ForumComment>.from(post.comments)..add(newComment);
          final updatedPost = post.copyWith(comments: updatedComments);
          
          updatedPosts.add(jsonEncode(updatedPost.toJson()));
          found = true;
        } else {
          updatedPosts.add(postString);
        }
      }
      
      if (!found) return false;
      
      return await prefs.setStringList(_forumPostsKey, updatedPosts);
    } catch (e) {
      print('Error adding comment: $e');
      return false;
    }
  }
  
  // Increment view count for a post
  static Future<bool> incrementViewCount(String postId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? postStrings = prefs.getStringList(_forumPostsKey);
      
      if (postStrings == null) return false;
      
      final List<String> updatedPosts = [];
      bool found = false;
      
      for (var postString in postStrings) {
        final post = ForumPost.fromJson(jsonDecode(postString));
        
        if (post.id == postId) {
          // Increment view count
          final updatedPost = post.copyWith(viewCount: post.viewCount + 1);
          updatedPosts.add(jsonEncode(updatedPost.toJson()));
          found = true;
        } else {
          updatedPosts.add(postString);
        }
      }
      
      if (!found) return false;
      
      return await prefs.setStringList(_forumPostsKey, updatedPosts);
    } catch (e) {
      print('Error incrementing view count: $e');
      return false;
    }
  }
  
  // Delete a post
  static Future<bool> deletePost(String postId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? postStrings = prefs.getStringList(_forumPostsKey);
      
      if (postStrings == null) return false;
      
      final updatedPosts = postStrings
        .where((str) {
          final post = ForumPost.fromJson(jsonDecode(str));
          return post.id != postId;
        })
        .toList();
      
      return await prefs.setStringList(_forumPostsKey, updatedPosts);
    } catch (e) {
      print('Error deleting forum post: $e');
      return false;
    }
  }
  
  // Add method to delete a comment from a post
  static Future<bool> deleteComment(String postId, String commentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? postStrings = prefs.getStringList(_forumPostsKey);
      
      if (postStrings == null) return false;
      
      final List<String> updatedPosts = [];
      bool found = false;
      
      for (var postString in postStrings) {
        final post = ForumPost.fromJson(jsonDecode(postString));
        
        if (post.id == postId) {
          // Filter out the comment to delete
          final updatedComments = post.comments
              .where((comment) => comment.id != commentId)
              .toList();
          
          final updatedPost = post.copyWith(comments: updatedComments);
          updatedPosts.add(jsonEncode(updatedPost.toJson()));
          found = true;
        } else {
          updatedPosts.add(postString);
        }
      }
      
      if (!found) return false;
      
      return await prefs.setStringList(_forumPostsKey, updatedPosts);
    } catch (e) {
      print('Error deleting comment: $e');
      return false;
    }
  }
  
  // Save media file
  static Future<MediaAttachment?> saveMediaFile(XFile file, MediaType type, {String? caption}) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'forum_${DateTime.now().millisecondsSinceEpoch}_${Uuid().v4()}${_getFileExtension(file.path)}';
      final savedFile = File('${directory.path}/$fileName');
      
      // Copy file to app directory
      await savedFile.writeAsBytes(await file.readAsBytes());
      
      return MediaAttachment(
        id: Uuid().v4(),
        path: savedFile.path,
        type: type,
        caption: caption,
      );
    } catch (e) {
      print('Error saving media file: $e');
      return null;
    }
  }
  
  // Helper to get file extension
  static String _getFileExtension(String path) {
    return path.contains('.') ? path.substring(path.lastIndexOf('.')) : '';
  }
}