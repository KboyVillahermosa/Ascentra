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

class _SocialFeedScreenState extends State<SocialFeedScreen> with SingleTickerProviderStateMixin {
  List<Post> _posts = [];
  bool _isLoading = true;
  AnimationController? _refreshIconController;
  
  @override
  void initState() {
    super.initState();
    _refreshIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _loadPosts();
  }
  
  @override
  void dispose() {
    _refreshIconController?.dispose();
    super.dispose();
  }
  
  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
    });
    
    _refreshIconController?.repeat();
    
    try {
      final posts = await PostService.getAllPosts();
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
        _refreshIconController?.stop();
      }
    } catch (e) {
      print('Error loading posts: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _refreshIconController?.stop();
      }
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
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Social Feed',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          if (_refreshIconController != null)
            RotationTransition(
              turns: Tween(begin: 0.0, end: 1.0).animate(_refreshIconController!),
              child: IconButton(
                icon: Icon(Icons.refresh, color: colorScheme.primary),
                onPressed: _loadPosts,
                tooltip: 'Refresh',
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading posts...',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          : _posts.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadPosts,
                  color: colorScheme.primary,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: _posts.length,
                    itemBuilder: (context, index) => _buildPostCard(_posts[index]),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreatePost,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        child: const Icon(Icons.add_photo_alternate),
        tooltip: 'Create Post',
      ),
    );
  }
  
  Widget _buildEmptyState() {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_album,
            size: 80,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'No posts yet',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Be the first to share a post!',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _navigateToCreatePost,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('CREATE POST'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPostCard(Post post) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    
    return FutureBuilder<String?>(
      future: _getProfileImagePath(post.username),
      builder: (context, snapshot) {
        final profileImagePath = snapshot.data;
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: colorScheme.outlineVariant.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: colorScheme.primaryContainer,
                      backgroundImage: profileImagePath != null
                          ? FileImage(File(profileImagePath))
                          : null,
                      child: profileImagePath == null
                          ? Icon(Icons.person, color: colorScheme.onPrimaryContainer)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.username,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            DateFormat('MMM d, y • h:mm a').format(post.timestamp),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (post.username == widget.username)
                      IconButton(
                        icon: Icon(
                          Icons.more_vert,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            builder: (context) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.delete_outline),
                                    title: const Text('Delete post'),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _deletePost(post);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              if (post.mediaUrls.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                  child: _MediaGridWidget(
                    mediaUrls: post.mediaUrls,
                    isVideo: post.isVideo,
                  ),
                ),
              if (post.caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    post.caption,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => _toggleLike(post),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                post.isLikedBy(widget.username)
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: post.isLikedBy(widget.username)
                                    ? Colors.red
                                    : colorScheme.onSurfaceVariant,
                                size: 22,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${post.likesCount}',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: post.isLikedBy(widget.username)
                                      ? Colors.red
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => _showCommentsDialog(post),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                color: colorScheme.onSurfaceVariant,
                                size: 22,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Comments',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
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
        widget.onCommentAdded();
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
    final double screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.8;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Text(
                  'Comments',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: widget.comments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 56,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No comments yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to comment on this post',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: widget.comments.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      final comment = widget.comments[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colorScheme.primaryContainer,
                            child: Icon(Icons.person, color: colorScheme.onPrimaryContainer, size: 20),
                          ),
                          title: Row(
                            children: [
                              Text(
                                comment.username,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                timeAgo(comment.timestamp),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(comment.text),
                          ),
                          trailing: comment.username == widget.currentUsername
                              ? IconButton(
                                  icon: Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: colorScheme.error,
                                  ),
                                  onPressed: () => _deleteComment(comment),
                                )
                              : null,
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(Icons.person, color: colorScheme.onPrimaryContainer, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: colorScheme.outline,
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: colorScheme.outline.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      isDense: true,
                    ),
                    maxLines: 3,
                    minLines: 1,
                    style: theme.textTheme.bodyMedium,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 12),
                _isSubmitting
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                        ),
                      )
                    : Material(
                        color: colorScheme.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: _addComment,
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(
                              Icons.send,
                              color: colorScheme.onPrimary,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String timeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    
    if (difference.inDays > 8) {
      return DateFormat('MMM d').format(dateTime);
    } else if (difference.inDays > 1) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inHours >= 1) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes >= 1) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
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

class _MediaGridWidget extends StatelessWidget {
  final List<String> mediaUrls;
  final bool isVideo;

  const _MediaGridWidget({
    required this.mediaUrls,
    required this.isVideo,
  });

  @override
  Widget build(BuildContext context) {
    if (mediaUrls.length == 1) {
      return GestureDetector(
        onTap: () => _openMediaViewer(context, 0),
        child: isVideo
            ? _VideoPlayerWidget(videoPath: mediaUrls.first)
            : Image.file(
                File(mediaUrls.first),
                fit: BoxFit.cover,
                width: double.infinity,
                height: 300,
              ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final visibleCount = mediaUrls.length > 4 ? 4 : mediaUrls.length;
        final hasMore = mediaUrls.length > 4;
        
        switch (visibleCount) {
          case 2:
            return SizedBox(
              height: 200,
              child: Row(
                children: [
                  _buildMediaItem(context, 0, width / 2, 200),
                  const SizedBox(width: 2),
                  _buildMediaItem(context, 1, width / 2, 200),
                ],
              ),
            );
          case 3:
            return SizedBox(
              height: 300,
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: _buildMediaItem(context, 0, constraints.maxWidth / 2, 300),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        _buildMediaItem(context, 1, constraints.maxWidth / 2, 149),
                        const SizedBox(height: 2),
                        _buildMediaItem(context, 2, constraints.maxWidth / 2, 149),
                      ],
                    ),
                  ),
                ],
              ),
            );
          case 4:
            return SizedBox(
              height: 300,
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        _buildMediaItem(context, 0, constraints.maxWidth / 2, 149),
                        const SizedBox(height: 2),
                        _buildMediaItem(context, 2, constraints.maxWidth / 2, 149),
                      ],
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        _buildMediaItem(context, 1, constraints.maxWidth / 2, 149),
                        const SizedBox(height: 2),
                        Stack(
                          children: [
                            _buildMediaItem(context, 3, constraints.maxWidth / 2, 149),
                            if (hasMore)
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black.withOpacity(0.5),
                                  child: Center(
                                    child: Text(
                                      '+${mediaUrls.length - 4}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          default:
            return const SizedBox();
        }
      },
    );
  }

  Widget _buildMediaItem(BuildContext context, int index, double width, double height) {
    if (index >= mediaUrls.length) return const SizedBox();
    
    final mediaPath = mediaUrls[index];
    final isVideoItem = isVideo || mediaPath.toLowerCase().endsWith('.mp4');
    
    return GestureDetector(
      onTap: () => _openMediaViewer(context, index),
      child: SizedBox(
        width: width,
        height: height,
        child: isVideoItem
          ? Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: width,
                  height: height,
                  color: Colors.black,
                  child: const Center(child: Icon(Icons.play_circle_filled, color: Colors.white, size: 50)),
                ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
                ),
              ],
            )
          : Image.file(
              File(mediaPath),
              fit: BoxFit.cover,
              width: width,
              height: height,
            ),
      ),
    );
  }

  void _openMediaViewer(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _MediaViewerModal(
          mediaUrls: mediaUrls,
          isVideo: isVideo,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _MediaViewerModal extends StatefulWidget {
  final List<String> mediaUrls;
  final bool isVideo;
  final int initialIndex;

  const _MediaViewerModal({
    required this.mediaUrls,
    required this.isVideo,
    required this.initialIndex,
  });

  @override
  State<_MediaViewerModal> createState() => _MediaViewerModalState();
}

class _MediaViewerModalState extends State<_MediaViewerModal> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${_currentIndex + 1}/${widget.mediaUrls.length}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Media content
          PageView.builder(
            controller: _pageController,
            itemCount: widget.mediaUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final mediaPath = widget.mediaUrls[index];
              final isVideoItem = widget.isVideo || mediaPath.toLowerCase().endsWith('.mp4');
              
              return isVideoItem
                ? _VideoPlayerWidget(videoPath: mediaPath)
                : Center(
                    child: GestureDetector(
                      onTap: () {
                        // Tap to exit
                      },
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Image.file(
                          File(mediaPath),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.broken_image,
                                    color: Colors.white70,
                                    size: 64,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Failed to load image',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
            },
          ),
          
          // Page indicator
          if (widget.mediaUrls.length > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.mediaUrls.length,
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}