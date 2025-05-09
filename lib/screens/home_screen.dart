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

// App theme colors
const Color textColor = Color(0xFF071511); // Very dark green
const Color backgroundColor = Color(0xFFF8FDFC); // Very light mint
const Color primaryColor = Color(0xFF4FC3A1); // Teal/mint green
const Color secondaryColor = Color(0xFF9999DC); // Lavender/light purple
const Color accentColor = Color(0xFF9F74CF); // Medium purple

class HomeScreen extends StatefulWidget {
  final String username;
  
  const HomeScreen({super.key, required this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Trail> trails = []; // Initialize with empty list
  List<Trail> filteredTrails = []; // For filtered trails
  List<ForumPost> _recentForumPosts = [];
  bool _isLoadingForum = true;
  int _selectedIndex = 0;
  String _selectedDifficulty = 'All'; // Default filter
  
  @override
  void initState() {
    super.initState();
    trails = TrailsData.getTrails(); // Load the data
    filteredTrails = trails; // Initially show all trails
    _loadRecentForumPosts(); // Load recent forum posts
  }

  void _filterTrailsByDifficulty(String difficulty) {
    setState(() {
      _selectedDifficulty = difficulty;
      if (difficulty == 'All') {
        filteredTrails = trails;
      } else {
        filteredTrails = trails.where((trail) => 
          trail.difficulty == difficulty).toList();
      }
    });
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

  Widget _buildDifficultyTabs() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildDifficultyTab('All'),
          _buildDifficultyTab('Easy to Moderate'),
          _buildDifficultyTab('Moderate'),
          _buildDifficultyTab('Moderate to Challenging'),
        ],
      ),
    );
  }

  Widget _buildDifficultyTab(String difficulty) {
    final isSelected = _selectedDifficulty == difficulty;
    return GestureDetector(
      onTap: () => _filterTrailsByDifficulty(difficulty),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: isSelected ? [
            BoxShadow(
              color: primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ] : [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 1),
            )
          ],
        ),
        child: Text(
          difficulty,
          style: TextStyle(
            color: isSelected ? Colors.white : textColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildForumSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Hikers\' Forum',
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add, color: primaryColor),
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
                      child: const Text(
                        'See All',
                        style: TextStyle(color: primaryColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          SizedBox(
            height: 180,
            child: _isLoadingForum
              ? const Center(child: CircularProgressIndicator(color: primaryColor))
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
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: textColor,
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Hi, ',
                style: TextStyle(
                  fontSize: 20,
                  color: textColor.withOpacity(0.7),
                  fontWeight: FontWeight.normal,
                ),
              ),
              TextSpan(
                text: widget.username,
                style: const TextStyle(
                  fontSize: 20,
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: primaryColor),
            onPressed: () {
              // TODO: Add notification functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: accentColor),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: primaryColor,
        onRefresh: () async {
          await _loadRecentForumPosts();
        },
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'Discover Cebu Trails',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Difficulty filter tabs
              _buildDifficultyTabs(),
              
              // Trails list
              SizedBox(
                height: 340,
                child: filteredTrails.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.terrain, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No ${_selectedDifficulty != "All" ? _selectedDifficulty : ""} trails available',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: filteredTrails.length,
                      itemBuilder: (context, index) {
                        final trail = filteredTrails[index];
                        return SizedBox(
                          width: 280,
                          child: Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            clipBehavior: Clip.antiAlias,
                            margin: const EdgeInsets.only(right: 16, bottom: 8, top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Image with difficulty badge
                                Stack(
                                  children: [
                                    SizedBox(
                                      height: 160,
                                      width: double.infinity,
                                      child: Image.asset(
                                        trail.image,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey[200],
                                            child: Center(
                                              child: Icon(Icons.terrain, size: 48, color: Colors.grey[400]),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    // Difficulty badge
                                    Positioned(
                                      top: 12,
                                      left: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: trail.difficulty.toLowerCase() == 'easy'
                                              ? primaryColor
                                              : trail.difficulty.toLowerCase() == 'moderate'
                                                  ? secondaryColor
                                                  : accentColor,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          trail.difficulty,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                // Card content
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          trail.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on, size: 16, color: primaryColor),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                trail.location,
                                                style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 14),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.height, size: 16, color: secondaryColor),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${trail.elevation}m',
                                              style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 14),
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
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
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryColor,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                            ),
                                            child: const Text('Explore'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              ),
              
              const SizedBox(height: 24),
              _buildForumSection(),
              
              const SizedBox(height: 80),
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
        backgroundColor: primaryColor,
        child: const Icon(Icons.add_photo_alternate, color: Colors.white),
        tooltip: 'Create Post',
        elevation: 4,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
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
      ),
    );
  }
}