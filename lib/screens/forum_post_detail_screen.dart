import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/forum_post.dart';
import '../services/forum_service.dart';
import '../services/user_service.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';

class ForumPostDetailScreen extends StatefulWidget {
  final String postId;
  final String username;
  
  const ForumPostDetailScreen({
    super.key,
    required this.postId,
    required this.username,
  });

  @override
  State<ForumPostDetailScreen> createState() => _ForumPostDetailScreenState();
}

class _ForumPostDetailScreenState extends State<ForumPostDetailScreen> {
  ForumPost? _post;
  bool _isLoading = true;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;
  
  @override
  void initState() {
    super.initState();
    _loadPost();
  }
  
  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
  
  Future<void> _loadPost() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Increment view count
      await ForumService.incrementViewCount(widget.postId);
      
      // Get updated post
      final post = await ForumService.getPostById(widget.postId);
      setState(() {
        _post = post;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading post: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
  
  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;
    
    setState(() {
      _isSubmittingComment = true;
    });
    
    try {
      final success = await ForumService.addComment(
        widget.postId,
        _commentController.text.trim(),
        widget.username,
      );
      
      if (success) {
        _commentController.clear();
        await _loadPost(); // Reload post to show new comment
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add comment')),
        );
      }
    } catch (e) {
      print('Error adding comment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingComment = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discussion'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_post != null && _post!.authorUsername == widget.username)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _showDeleteConfirmation();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Post', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _post == null
              ? const Center(child: Text('Post not found'))
              : Column(
                  children: [
                    // Post content section (scrollable)
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Post title
                            Text(
                              _post!.title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // Post metadata
                            Row(
                              children: [
                                _buildAuthorAvatar(_post!.authorUsername),
                                const SizedBox(width: 8),
                                Text(
                                  _post!.authorUsername,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 16),
                                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('MMM d, y').format(_post!.timestamp),
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                                const Spacer(),
                                Icon(Icons.visibility, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  '${_post!.viewCount}',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                            
                            const Divider(height: 24),
                            
                            // Post content
                            Text(
                              _post!.content,
                              style: const TextStyle(fontSize: 16),
                            ),
                            
                            // Media attachments
                            if (_post!.attachments.isNotEmpty)
                              _buildMediaAttachments(_post!.attachments),
                            
                            const SizedBox(height: 32),
                            
                            // Comments section
                            Row(
                              children: [
                                const Icon(Icons.comment),
                                const SizedBox(width: 8),
                                Text(
                                  'Comments (${_post!.comments.length})',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            
                            const Divider(height: 24),
                            
                            // Comments list
                            if (_post!.comments.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(
                                  child: Text(
                                    'No comments yet. Be the first to comment!',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              _buildCommentsSection(_post!.comments),
                          ],
                        ),
                      ),
                    ),
                    
                    // Comment input section (fixed at bottom)
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, -1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
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
                          IconButton(
                            icon: _isSubmittingComment
                                ? const CircularProgressIndicator()
                                : const Icon(Icons.send),
                            onPressed: _isSubmittingComment ? null : _addComment,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
  
  Widget _buildAuthorAvatar(String username) {
    return FutureBuilder<String?>(
      future: _getProfileImagePath(username),
      builder: (context, snapshot) {
        final profileImagePath = snapshot.data;
        
        return CircleAvatar(
          radius: 16,
          backgroundImage: profileImagePath != null
              ? FileImage(File(profileImagePath))
              : null,
          child: profileImagePath == null
              ? const Icon(Icons.person, size: 16)
              : null,
        );
      },
    );
  }
  
  Future<String?> _getProfileImagePath(String username) async {
    final userProfile = await UserService.getUserProfile(username);
    return userProfile?.profileImagePath;
  }
  
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Discussion'),
        content: const Text(
          'Are you sure you want to delete this discussion? This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close the dialog
              
              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext context) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                },
              );
              
              try {
                final success = await ForumService.deletePost(widget.postId);
                
                Navigator.pop(context); // Close loading dialog
                
                if (success) {
                  Navigator.pop(context, true); // Go back to forum list with success flag
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Discussion deleted successfully')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete discussion')),
                  );
                }
              } catch (e) {
                Navigator.pop(context); // Close loading dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCommentsSection(List<ForumComment> comments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final comment = comments[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 14,
                          child: Icon(Icons.person, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          comment.authorUsername,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat('MMM d, y • h:mm a').format(comment.timestamp),
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        // Add delete button if comment belongs to current user
                        if (comment.authorUsername == widget.username)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            onPressed: () => _showDeleteCommentConfirmation(comment.id),
                            tooltip: 'Delete comment',
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(comment.content),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showDeleteCommentConfirmation(String commentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              
              try {
                // Implement comment deletion in ForumService
                final success = await ForumService.deleteComment(_post!.id, commentId);
                
                if (success) {
                  _loadPost(); // Refresh post to update comments
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Comment deleted')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete comment')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  // Add this to the ForumPostDetailScreen to display media attachments
  Widget _buildMediaAttachments(List<MediaAttachment> attachments) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          'Attachments',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        
        if (attachments.length == 1)
          // Display single attachment in larger format
          _buildSingleAttachment(attachments[0])
        else
          // Display grid for multiple attachments
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: attachments.length,
            itemBuilder: (context, index) {
              final attachment = attachments[index];
              return GestureDetector(
                onTap: () => _showFullScreenMedia(attachment),
                child: _buildMediaThumbnail(attachment),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSingleAttachment(MediaAttachment attachment) {
    return GestureDetector(
      onTap: () => _showFullScreenMedia(attachment),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: attachment.type == MediaType.image
                ? Image.file(
                    File(attachment.path),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 250,
                  )
                : Container(
                    width: double.infinity,
                    height: 250,
                    color: Colors.black,
                    child: const Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        color: Colors.white,
                        size: 64,
                      ),
                    ),
                  ),
          ),
          if (attachment.caption != null && attachment.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                attachment.caption!,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaThumbnail(MediaAttachment attachment) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: attachment.type == MediaType.image
              ? Image.file(
                  File(attachment.path),
                  fit: BoxFit.cover,
                )
              : Container(
                  color: Colors.black,
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
        ),
        // Type indicator
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black54,
            ),
            child: Icon(
              attachment.type == MediaType.image ? Icons.image : Icons.videocam,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        // Caption indicator
        if (attachment.caption != null && attachment.caption!.isNotEmpty)
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black54,
              ),
              child: const Icon(
                Icons.comment,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
      ],
    );
  }

  void _showFullScreenMedia(MediaAttachment attachment) {
    if (attachment.type == MediaType.image) {
      // Show full screen image
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.black,
              iconTheme: const IconThemeData(color: Colors.white),
              title: attachment.caption != null
                  ? Text(
                      attachment.caption!,
                      style: const TextStyle(color: Colors.white),
                    )
                  : null,
            ),
            backgroundColor: Colors.black,
            body: Center(
              child: InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4,
                child: Image.file(File(attachment.path)),
              ),
            ),
          ),
        ),
      );
    } else {
      // Show full screen video
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => _VideoPlayerScreen(
            videoPath: attachment.path,
            caption: attachment.caption,
          ),
        ),
      );
    }
  }
}

class _VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  final String? caption;
  
  const _VideoPlayerScreen({
    required this.videoPath,
    this.caption,
  });

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;
  
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.videoPath))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
        setState(() {
          _isPlaying = true;
        });
      });
      
    _controller.addListener(() {
      if (!_controller.value.isPlaying && _isPlaying) {
        setState(() {
          _isPlaying = false;
        });
      } else if (_controller.value.isPlaying && !_isPlaying) {
        setState(() {
          _isPlaying = true;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: widget.caption != null
            ? Text(
                widget.caption!,
                style: const TextStyle(color: Colors.white),
              )
            : null,
      ),
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_controller.value.isPlaying) {
                            _controller.pause();
                          } else {
                            _controller.play();
                          }
                        });
                      },
                      child: Container(
                        color: Colors.transparent,
                        child: Center(
                          child: _isPlaying
                              ? const SizedBox.shrink()
                              : Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Icon(
                                      Icons.play_arrow,
                                      size: 80.0,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    // Add video controls at bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.black38,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  if (_controller.value.isPlaying) {
                                    _controller.pause();
                                  } else {
                                    _controller.play();
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}