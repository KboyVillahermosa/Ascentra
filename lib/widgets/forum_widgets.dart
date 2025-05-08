import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/forum_post.dart';

class ForumPostCard extends StatelessWidget {
  final ForumPost post;
  final VoidCallback onTap;
  final bool isCompact;
  
  const ForumPostCard({
    Key? key,
    required this.post,
    required this.onTap,
    this.isCompact = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(
        right: isCompact ? 16 : 0, 
        bottom: isCompact ? 4 : 8,
        left: isCompact ? 0 : 8,
        top: isCompact ? 0 : 8,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: isCompact ? 250 : double.infinity,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                maxLines: isCompact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                post.content,
                maxLines: isCompact ? 3 : 4,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: isCompact ? 0 : 8),
              if (isCompact) const Spacer(),
              // Post metadata
              Row(
                children: [
                  const Icon(Icons.person, size: 14),
                  const SizedBox(width: 4),
                  Text(post.authorUsername, style: const TextStyle(fontSize: 12)),
                  if (!isCompact) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d').format(post.timestamp),
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                  const Spacer(),
                  // Comment count
                  const Icon(Icons.comment, size: 14),
                  const SizedBox(width: 4),
                  Text('${post.comments.length}', style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  // View count
                  const Icon(Icons.visibility, size: 14),
                  const SizedBox(width: 4),
                  Text('${post.viewCount}', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyForumState extends StatelessWidget {
  final VoidCallback onCreatePost;
  final bool isCompact;
  
  const EmptyForumState({
    Key? key,
    required this.onCreatePost,
    this.isCompact = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum, size: isCompact ? 40 : 80, color: Colors.grey),
          const SizedBox(height: 8),
          const Text(
            'No discussions yet',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onCreatePost,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Start a Discussion'),
          ),
        ],
      ),
    );
  }
}