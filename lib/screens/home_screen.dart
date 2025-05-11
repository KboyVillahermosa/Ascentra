import 'package:flutter/material.dart';
import 'dart:math' as Math;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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
  // Trail data
  List<Trail> trails = [];
  List<Trail> filteredTrails = [];
  String selectedDifficulty = 'All';
  
  // Forum data
  List<ForumPost> recentForumPosts = [];
  bool isLoadingForum = true;
  
  // Navigation
  int selectedIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  /// Initializes all data sources needed for this screen
  Future<void> _initializeData() async {
    // Load trail data with persisted reviews
    await _loadTrailsWithReviews();
    
    // Load forum data
    await _loadRecentForumPosts();
  }

  Future<void> _loadTrailsWithReviews() async {
    // First get the base trail data
    List<Trail> baseTrails = TrailsData.getTrails();
    List<Trail> updatedTrails = [];
    
    // Get SharedPreferences instance
    final prefs = await SharedPreferences.getInstance();
    
    // For each trail, check if it has reviews and update its rating
    for (var trail in baseTrails) {
      final reviewsKey = 'trail_reviews_${trail.id}';
      final List<String>? reviewStrings = prefs.getStringList(reviewsKey);
      
      if (reviewStrings != null && reviewStrings.isNotEmpty) {
        // Convert the stored review strings to Review objects
        final reviews = reviewStrings
            .map((str) => Review.fromJson(jsonDecode(str)))
            .toList();
        
        // Calculate the average rating
        double sum = reviews.fold(0, (sum, review) => sum + review.rating);
        double average = sum / reviews.length;
        
        // Create updated trail with reviews and rating
        updatedTrails.add(trail.copyWith(
          rating: average,
          reviews: reviews,
        ));
      } else {
        // No reviews, just add the original trail
        updatedTrails.add(trail);
      }
    }
    
    // Update the state with the loaded trails
    setState(() {
      trails = updatedTrails;
      filteredTrails = updatedTrails;
    });
  }

  void _filterTrailsByDifficulty(String difficulty) {
    setState(() {
      selectedDifficulty = difficulty;
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
      isLoadingForum = true;
    });
    
    try {
      final posts = await ForumService.getAllPosts();
      setState(() {
        // Get the 5 most recent posts
        recentForumPosts = posts.take(5).toList();
        isLoadingForum = false;
      });
    } catch (e) {
      print('Error loading forum posts: $e');
      setState(() {
        isLoadingForum = false;
      });
    }
  }

  // Add search functionality
  void _showSearchFilter() {
    // TODO: Implement search and filter functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Search & Filter', style: TextStyle(color: textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Search trails...',
                prefixIcon: Icon(Icons.search, color: primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('More filters coming soon...', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text('Apply'),
          ),
        ],
      ),
    );
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
    final isSelected = selectedDifficulty == difficulty;
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
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.forum, color: primaryColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Hikers\' Forum',
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Material(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      child: IconButton(
                        icon: const Icon(Icons.add, color: primaryColor),
                        tooltip: 'Create New Topic',
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreateForumPostScreen(username: widget.username),
                            ),
                          ).then((_) => _loadRecentForumPosts());
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _navigateToForum,
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('See All'),
                      style: TextButton.styleFrom(
                        foregroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 6),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Join discussions with fellow hikers',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Forum post cards carousel
          SizedBox(
            height: 200, // Increased height for better readability
            child: isLoadingForum
              ? const Center(child: CircularProgressIndicator(color: primaryColor))
              : recentForumPosts.isEmpty
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
                      itemCount: recentForumPosts.length,
                      itemBuilder: (context, index) => ForumPostCard(
                        post: recentForumPosts[index],
                        onTap: () => _openForumPost(recentForumPosts[index]),
                        isCompact: true,
                      ),
                    ),
          ),
          
          if (recentForumPosts.isNotEmpty) ...[
            const SizedBox(height: 16),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  Math.min(recentForumPosts.length, 5),
                  (index) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == 0 ? primaryColor : Colors.grey.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    if (index == selectedIndex) return;
    
    // Navigate to different screens based on the selected tab
    switch (index) {
      case 0: // Home tab - stay on this screen
        setState(() {
          selectedIndex = 0;
        });
        break;
      case 1: // Record tab
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const RecordScreen()),
        ).then((_) => setState(() => selectedIndex = 0));
        break;
      case 2: // History tab
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ActivityHistoryScreen()),
        ).then((_) => setState(() => selectedIndex = 0));
        break;
      case 3: // Social Feed tab
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SocialFeedScreen(username: widget.username)),
        ).then((_) => setState(() => selectedIndex = 0));
        break;
      case 4: // Profile tab - Replace dialog with ProfileScreen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProfileScreen(username: widget.username)),
        ).then((_) => setState(() => selectedIndex = 0));
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
        title: const Text(
          'Ascentra',
          style: TextStyle(
            fontSize: 22,
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: primaryColor),
            tooltip: 'Search & Filter',
            onPressed: _showSearchFilter,
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
              Container(
                height: 420, // Increased height to accommodate new design
                child: filteredTrails.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.terrain, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No ${selectedDifficulty != "All" ? selectedDifficulty : ""} trails available',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Trail navigation indicator
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Row(
                            children: [
                              Text(
                                'Featured Trails',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const Spacer(),
                              const Text(
                                'Swipe to explore',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Icon(Icons.swipe, size: 16, color: Colors.grey),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        
                        // Immersive trail cards
                        Expanded(
                          child: PageView.builder(
                            controller: PageController(viewportFraction: 0.85),
                            itemCount: filteredTrails.length,
                            itemBuilder: (context, index) {
                              final trail = filteredTrails[index];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TrailDetailScreen(
                                        trail: trail,
                                        onTrailUpdated: (updatedTrail) {
                                          // This callback will be called when the trail is updated
                                          setState(() {
                                            // Update the trail in our lists
                                            final index = trails.indexWhere((t) => t.id == updatedTrail.id);
                                            if (index != -1) {
                                              trails[index] = updatedTrail;
                                            }
                                            
                                            final filteredIndex = filteredTrails.indexWhere((t) => t.id == updatedTrail.id);
                                            if (filteredIndex != -1) {
                                              filteredTrails[filteredIndex] = updatedTrail;
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ).then((_) => _loadTrailsWithReviews()); // Refresh when returning
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(24),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          // Background image
                                          Image.asset(
                                            trail.image,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.grey[200],
                                                child: Icon(Icons.terrain, size: 64, color: Colors.grey[400]),
                                              );
                                            },
                                          ),
                                          
                                          // Gradient overlay for readability
                                          Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.transparent,
                                                  Colors.black.withOpacity(0.3),
                                                  Colors.black.withOpacity(0.7),
                                                ],
                                                stops: const [0.4, 0.7, 1.0],
                                              ),
                                            ),
                                          ),
                                          
                                          // Content overlay
                                          Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Difficulty badge
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: trail.difficulty.toLowerCase().contains('easy')
                                                        ? primaryColor
                                                        : trail.difficulty.toLowerCase().contains('moderate')
                                                            ? secondaryColor
                                                            : accentColor,
                                                    borderRadius: BorderRadius.circular(20),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withOpacity(0.2),
                                                        blurRadius: 4,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Text(
                                                    trail.difficulty,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ),
                                                
                                                const Spacer(),
                                                
                                                // Trail information at bottom
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      trail.name,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 24,
                                                        color: Colors.white,
                                                        shadows: [
                                                          Shadow(
                                                            offset: Offset(0, 1),
                                                            blurRadius: 3.0,
                                                            color: Color.fromARGB(150, 0, 0, 0),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    
                                                    // Trail details
                                                    Row(
                                                      children: [
                                                        Icon(Icons.location_on, size: 16, color: Colors.white.withOpacity(0.9)),
                                                        const SizedBox(width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            trail.location,
                                                            style: TextStyle(
                                                              color: Colors.white.withOpacity(0.9),
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Row(
                                                      children: [
                                                        Icon(Icons.height, size: 16, color: Colors.white.withOpacity(0.9)),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          '${trail.elevation}m elevation',
                                                          style: TextStyle(
                                                            color: Colors.white.withOpacity(0.9),
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Row(
                                                      children: [
                                                        Icon(Icons.star_rate_rounded, size: 16, color: Colors.amber),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          '${trail.rating?.toStringAsFixed(1) ?? "0.0"} / 5.0',
                                                          style: TextStyle(
                                                            color: Colors.white.withOpacity(0.9),
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          '${trail.reviews?.length ?? 0} reviews',
                                                          style: TextStyle(
                                                            color: Colors.white.withOpacity(0.7),
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 16),
                                                    
                                                    // Call-to-action
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius: BorderRadius.circular(30),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black.withOpacity(0.1),
                                                            blurRadius: 4,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Text(
                                                            'Explore Now',
                                                            style: TextStyle(
                                                              color: primaryColor,
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Icon(Icons.arrow_forward, size: 16, color: primaryColor),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        
                        // Page indicator
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                Math.min(filteredTrails.length, 5),
                                (index) => Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: index == 0 ? primaryColor : Colors.grey.withOpacity(0.3),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
          currentIndex: selectedIndex,
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