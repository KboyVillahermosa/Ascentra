import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import 'create_post_screen.dart';
import 'package:video_player/video_player.dart';

class SocialFeedScreen extends StatefulWidget {
  final String username;
  
  const SocialFeedScreen({super.key, required this.username});

  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  List<Post> _posts = [];
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
      final posts = await PostService.getAllPosts();
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
      MaterialPageRoute(builder: (context) => CreatePostScreen(username: widget.username)),
    );
    
    if (result == true) {
      _loadPosts();
    }
  }
  
  Future<void> _toggleLike(Post post) async {
    final updatedPost = await PostService.toggleLike(post.id, widget.username);
    if (updatedPost != null) {
      setState(() {
        final index = _posts.indexWhere((p) => p.id == post.id);
        if (index >= 0) {
          _posts[index] = updatedPost;
        }
      });
    }
  }
  
  Future<void> _showCommentsDialog(Post post) async {
    final comments = await PostService.getCommentsForPost(post.id);
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _CommentsSheet(
        post: post,
        comments: comments,
        currentUsername: widget.username,
        onCommentAdded: () {
          // Refresh comments
          _showCommentsDialog(post);
        },
      ),
    );
  }
  
  Future<void> _deletePost(Post post) async {
    // Only allow the post owner to delete
    if (post.username != widget.username) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only delete your own posts')),
      );
      return;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final success = await PostService.deletePost(post.id);
      if (success) {
        setState(() {
          _posts.removeWhere((p) => p.id == post.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post deleted')),
          );
        }
      }
    }
  }
  
  Future<String?> _getProfileImagePath(String username) async {
    final userProfile = await UserService.getUserProfile(username);
    return userProfile?.profileImagePath;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Social Feed'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadPosts,
                  child: ListView.builder(
                    itemCount: _posts.length,
                    itemBuilder: (context, index) => _buildPostCard(_posts[index]),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreatePost,
        child: const Icon(Icons.add_photo_alternate),
        tooltip: 'Create Post',
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.photo_album, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No posts yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Be the first to share a post!',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToCreatePost,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('CREATE POST'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPostCard(Post post) {
    return FutureBuilder<String?>(
      future: _getProfileImagePath(post.username),
      builder: (context, snapshot) {
        final profileImagePath = snapshot.data;
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Post header with user info
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: profileImagePath != null
                      ? FileImage(File(profileImagePath))
                      : null,
                  child: profileImagePath == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(post.username),
                subtitle: Text(DateFormat('MMM d, y • h:mm a').format(post.timestamp)),
                trailing: post.username == widget.username
                    ? PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deletePost(post);
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      )
                    : null,
              ),
              
              // Post media (image or video)
              if (post.mediaUrls.isNotEmpty)
                post.isVideo
                    ? _VideoPlayerWidget(videoPath: post.mediaUrls.first)
                    : Image.file(
                        File(post.mediaUrls.first),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 300,
                      ),
              
              // Post caption
              if (post.caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(post.caption),
                ),
              
              // Divider
              const Divider(height: 0),
              
              // Like and comment buttons
              Row(
                children: [
                  // Like button
                  IconButton(
                    icon: Icon(
                      post.isLikedBy(widget.username) ? Icons.favorite : Icons.favorite_border,
                      color: post.isLikedBy(widget.username) ? Colors.red : null,
                    ),
                    onPressed: () => _toggleLike(post),
                  ),
                  Text('${post.likesCount}'),
                  const SizedBox(width: 16),
                  
                  // Comment button
                  IconButton(
                    icon: const Icon(Icons.comment_outlined),
                    onPressed: () => _showCommentsDialog(post),
                  ),
                  const Text('Comments'),
                ],
              ),
            ],
          ),
        );
      }
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final Post post;
  final List<Comment> comments;
  final String currentUsername;
  final VoidCallback onCommentAdded;
  
  const _CommentsSheet({
    required this.post,
    required this.comments,
    required this.currentUsername,
    required this.onCommentAdded,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  
  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
  
  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) return;
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      final success = await PostService.addComment(
        widget.post.id,
        _commentController.text,
        widget.currentUsername,
      );
      
      if (success) {
        _commentController.clear();
        widget.onCommentAdded();
      }
    } catch (e) {
      print('Error adding comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
  
  Future<void> _deleteComment(Comment comment) async {
    if (comment.username != widget.currentUsername) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can only delete your own comments')),
      );
      return;
    }
    
    try {
      final success = await PostService.deleteComment(comment.id);
      if (success) {
        widget.onCommentAdded(); // Refresh comments
      }
    } catch (e) {
      print('Error deleting comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Calculate the height to take up to 80% of the screen
    final double screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.8;
    
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Text(
                  'Comments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          const Divider(height: 0),
          
          // Comments list
          Expanded(
            child: widget.comments.isEmpty
                ? const Center(child: Text('No comments yet'))
                : ListView.builder(
                    itemCount: widget.comments.length,
                    itemBuilder: (context, index) {
                      final comment = widget.comments[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person, size: 20),
                        ),
                        title: Text(
                          comment.username,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(comment.text),
                        trailing: comment.username == widget.currentUsername
                            ? IconButton(
                                icon: const Icon(Icons.delete, size: 20),
                                onPressed: () => _deleteComment(comment),
                              )
                            : null,
                      );
                    },
                  ),
          ),
          
          // Comment input
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                const CircleAvatar(
                  child: Icon(Icons.person, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                _isSubmitting
                    ? const CircularProgressIndicator()
                    : IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: _addComment,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPlayerWidget extends StatefulWidget {
  final String videoPath;
  
  const _VideoPlayerWidget({required this.videoPath});
  
  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
      });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      width: double.infinity,
      color: Colors.black,
      child: _isInitialized
          ? Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                ),
                IconButton(
                  icon: Icon(
                    _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 50,
                  ),
                  onPressed: () {
                    setState(() {
                      _controller.value.isPlaying
                          ? _controller.pause()
                          : _controller.play();
                    });
                  },
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}