import 'package:flutter/material.dart';
import '../data/trails_data.dart';
import '../models/trail.dart';
import '../models/forum_post.dart';
import '../services/forum_service.dart';
import 'trail_detail_screen.dart';
import 'login_screen.dart';
import 'record_screen.dart';
import 'activity_history_screen.dart';
import 'create_post_screen.dart';
import 'social_feed_screen.dart';
import 'profile_screen.dart';
import 'forum_screen.dart';
import 'create_forum_post_screen.dart';
import 'forum_post_detail_screen.dart';
import '../widgets/forum_widgets.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  
  const HomeScreen({super.key, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Trail> trails = []; // Initialize with empty list
  List<ForumPost> _recentForumPosts = [];
  bool _isLoadingForum = true;
  int _selectedIndex = 0;
  
  @override
  void initState() {
    super.initState();
    trails = TrailsData.getTrails(); // Load the data
    _loadRecentForumPosts(); // Load recent forum posts
  }

  Future<void> _loadRecentForumPosts() async {
    setState(() {
      _isLoadingForum = true;
    });
    
    try {
      final posts = await ForumService.getAllPosts();
      setState(() {
        // Get the 5 most recent posts
        _recentForumPosts = posts.take(5).toList();
        _isLoadingForum = false;
      });
    } catch (e) {
      print('Error loading forum posts: $e');
      setState(() {
        _isLoadingForum = false;
      });
    }
  }

  void _navigateToForum() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ForumScreen(username: widget.username)),
    ).then((_) => _loadRecentForumPosts()); // Refresh when coming back
  }

  void _openForumPost(ForumPost post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ForumPostDetailScreen(
          postId: post.id,
          username: widget.username,
        ),
      ),
    ).then((_) => _loadRecentForumPosts()); // Refresh when coming back
  }

  Widget _buildForumSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with "See All" button and new "+" button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Hikers\' Forum',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    // Add new topic button
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'Create New Topic',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateForumPostScreen(username: widget.username),
                          ),
                        ).then((_) => _loadRecentForumPosts());
                      },
                    ),
                    TextButton(
                      onPressed: _navigateToForum,
                      child: const Text('See All'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // List of recent forum posts
          SizedBox(
            height: 200,
            child: _isLoadingForum
              ? const Center(child: CircularProgressIndicator())
              : _recentForumPosts.isEmpty
                  ? EmptyForumState(
                      onCreatePost: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => CreateForumPostScreen(username: widget.username)),
                        ).then((_) => _loadRecentForumPosts());
                      },
                      isCompact: true,
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: _recentForumPosts.length,
                      itemBuilder: (context, index) => ForumPostCard(
                        post: _recentForumPosts[index],
                        onTap: () => _openForumPost(_recentForumPosts[index]),
                        isCompact: true,
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    
    // Navigate to different screens based on the selected tab
    switch (index) {
      case 0: // Home tab - stay on this screen
        setState(() {
          _selectedIndex = 0;
        });
        break;
      case 1: // Record tab
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RecordScreen()),
        ).then((_) => setState(() => _selectedIndex = 0));
        break;
      case 2: // History tab
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ActivityHistoryScreen()),
        ).then((_) => setState(() => _selectedIndex = 0));
        break;
      case 3: // Social Feed tab
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SocialFeedScreen(username: widget.username)),
        ).then((_) => setState(() => _selectedIndex = 0));
        break;
      case 4: // Profile tab - Replace dialog with ProfileScreen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProfileScreen(username: widget.username)),
        ).then((_) => setState(() => _selectedIndex = 0));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Welcome, ${widget.username}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadRecentForumPosts();
        },
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Cebu Hiking Trails',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              // Trails list
              SizedBox(
                height: 350, // Fixed height for trails section
                child: trails.isEmpty 
                  ? const Center(child: Text('No trails available'))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: trails.length,
                      itemBuilder: (context, index) {
                        final trail = trails[index];
                        return SizedBox(
                          width: 300,
                          child: Card(
                            elevation: 3,
                            clipBehavior: Clip.antiAlias, // Ensures content is clipped to card boundaries
                            margin: const EdgeInsets.only(right: 16, bottom: 4),
                            child: ClipRect( // Add ClipRect here to prevent overflow
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min, // Add this to prevent column from expanding too much
                                children: [
                                  // Image container with fixed height
                                  SizedBox(
                                    height: 150,
                                    width: double.infinity,
                                    child: Image.asset(
                                      trail.image,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        print('Error loading image for ${trail.name}: $error');
                                        return Container(
                                          color: Colors.grey[200],
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                const Icon(Icons.terrain, size: 48, color: Colors.grey),
                                                const SizedBox(height: 8),
                                                Text(trail.name, textAlign: TextAlign.center),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  // Card content with limited height
                                  Expanded( // Use Expanded instead of fixed padding
                                    child: SingleChildScrollView( // Add scrolling for overflow content
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              trail.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text('📍 ${trail.location}'),
                                            const SizedBox(height: 4),
                                            Text('🗻 Elevation: ${trail.elevation} meters'),
                                            const SizedBox(height: 4),
                                            Text('⚠️ Difficulty: ${trail.difficulty}'),
                                            const SizedBox(height: 16),
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => TrailDetailScreen(trail: trail),
                                                    ),
                                                  );
                                                },
                                                child: const Text('View Details'),
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
                          ),
                        );
                      },
                    ),
              ),
              
              // Add the forum section
              const Divider(height: 32),
              _buildForumSection(),
              
              const SizedBox(height: 80), // Space at the bottom for FAB and nav bar
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CreatePostScreen(username: widget.username)),
          );
        },
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add_photo_alternate),
        tooltip: 'Create Post',
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Important for 5+ items
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_run),
            label: 'Record',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_library),
            label: 'Social',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}