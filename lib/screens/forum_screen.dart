import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/forum_post.dart';
import '../services/forum_service.dart';
import 'create_forum_post_screen.dart';
import 'forum_post_detail_screen.dart';
import '../widgets/forum_widgets.dart';

class ForumScreen extends StatefulWidget {
  final String username;
  
  const ForumScreen({super.key, required this.username});

  @override
  State<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends State<ForumScreen> {
  List<ForumPost> _posts = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadPosts();
  }
  
  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final posts = await ForumService.getAllPosts();
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading posts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _navigateToCreatePost() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateForumPostScreen(username: widget.username)),
    );
    
    if (result == true) {
      _loadPosts();
    }
  }
  
  void _openPostDetail(ForumPost post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ForumPostDetailScreen(
          postId: post.id,
          username: widget.username,
        ),
      ),
    ).then((_) => _loadPosts()); // Refresh when coming back
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discussion Forum'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? EmptyForumState(onCreatePost: _navigateToCreatePost)
              : RefreshIndicator(
                  onRefresh: _loadPosts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _posts.length,
                    itemBuilder: (context, index) => ForumPostCard(
                      post: _posts[index],
                      onTap: () => _openPostDetail(_posts[index]),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreatePost,
        child: const Icon(Icons.add),
        tooltip: 'Create Discussion',
      ),
    );
  }
}