import 'package:flutter/material.dart';
import '../models/trail.dart';
import '../services/trail_service.dart';  // Add this import
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TrailDetailScreen extends StatefulWidget {
  final Trail trail;
  final Function(Trail updatedTrail)? onTrailUpdated;

  const TrailDetailScreen({
    super.key, 
    required this.trail, 
    this.onTrailUpdated,
  });

  @override
  State<TrailDetailScreen> createState() => _TrailDetailScreenState();
}

class _TrailDetailScreenState extends State<TrailDetailScreen> {
  double _userRating = 0;
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  bool _isSubmitting = false;
  List<Review> _reviews = [];

  @override
  void initState() {
    super.initState();
    _userRating = widget.trail.rating ?? 0;
    
    // Load reviews from the database
    _loadReviews();
    
    _checkUrlLauncherCapability();
  }

  Future<void> _loadReviews() async {
    final reviewsKey = 'trail_reviews_${widget.trail.id}';
    final prefs = await SharedPreferences.getInstance();
    final List<String>? reviewStrings = prefs.getStringList(reviewsKey);
    
    if (reviewStrings != null && reviewStrings.isNotEmpty) {
      setState(() {
        _reviews = reviewStrings
            .map((str) => Review.fromJson(jsonDecode(str)))
            .toList();
      });
    } else if (widget.trail.reviews != null) {
      setState(() {
        _reviews = widget.trail.reviews!.toList();
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _checkUrlLauncherCapability() async {
    final testUri = Uri.parse('https://www.google.com');
    final canLaunch = await canLaunchUrl(testUri);

    print('URL launcher capability check: ${canLaunch ? 'PASSED' : 'FAILED'}');

    if (!canLaunch) {
      print('WARNING: Basic URL launching capability is not available');
    }
  }

  Future<void> _openInGoogleMaps() async {
    try {
      if (widget.trail.latitude == null || widget.trail.longitude == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trail coordinates are not available')),
        );
        return;
      }

      final lat = widget.trail.latitude!;
      final lng = widget.trail.longitude!;

      List<Uri> mapUris = [
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
        Uri.parse('geo:$lat,$lng'),
        Uri.parse('google.navigation:q=$lat,$lng'),
      ];

      bool launched = false;
      Exception? lastError;

      for (var uri in mapUris) {
        try {
          print('Trying to launch: $uri');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            launched = true;
            print('Successfully launched: $uri');
            break;
          }
        } catch (e) {
          lastError = e as Exception;
          print('Failed to launch $uri: $e');
        }
      }

      if (!launched) {
        final webUri = Uri.parse('https://maps.google.com?q=$lat,$lng');

        print('Trying fallback URL: $webUri');
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri);
          launched = true;
        } else {
          throw lastError ?? Exception('Could not launch any map URL');
        }
      }

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open map. Try copying coordinates manually.'),
            duration: Duration(seconds: 4),
          ),
        );

        _showCoordinatesCopyDialog(lat, lng);
      }
    } catch (e) {
      print('Error launching maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showCoordinatesCopyDialog(double lat, double lng) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Map Link Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Copy these coordinates to manually search in Google Maps:'),
            const SizedBox(height: 16),
            SelectableText('$lat, $lng', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  void _updateRating(double rating) {
    setState(() {
      _userRating = rating;
    });
  }

  void _submitRating() {
    String username = _usernameController.text.trim();
    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    if (_userRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final newReview = Review(
      id: const Uuid().v4(),
      userId: 'user-${DateTime.now().millisecondsSinceEpoch}',
      userName: username,
      rating: _userRating,
      comment: _commentController.text.trim(),
      date: DateTime.now(),
    );

    // Save to database
    _saveReviewToDatabase(newReview).then((_) {
      setState(() {
        _reviews.add(newReview);
        _isSubmitting = false;
        _commentController.clear();
      });

      // Update the trail's overall rating
      _updateTrailRating();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Thank you $username for rating this trail ${_userRating.toStringAsFixed(1)} stars!'),
          duration: const Duration(seconds: 2),
        ),
      );
    }).catchError((error) {
      setState(() {
        _isSubmitting = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save review: $error'),
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  Future<void> _saveReviewToDatabase(Review review) async {
    final success = await TrailService.addReview(widget.trail.id, review);
    if (!success) {
      throw Exception('Failed to save review to database');
    }
  }

  void _updateTrailRating() {
    if (_reviews.isEmpty) return;
    
    double sum = _reviews.fold(0, (sum, review) => sum + review.rating);
    double average = sum / _reviews.length;
    
    // Update the trail with new rating
    final updatedTrail = widget.trail.copyWith(rating: average);
    
    // Call the callback if provided
    if (widget.onTrailUpdated != null) {
      widget.onTrailUpdated!(updatedTrail);
    }
    
    // Save the updated trail to the database
    TrailService.updateTrailRating(widget.trail.id);
  }

  @override
  Widget build(BuildContext context) {
    double overallRating = 0;
    if (_reviews.isNotEmpty) {
      double sum = _reviews.fold(0, (sum, review) => sum + review.rating);
      overallRating = sum / _reviews.length;
    } else {
      overallRating = widget.trail.rating ?? 0;
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Modern transparent app bar with image background
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              // Removed the title property to get rid of the text in the header
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Trail image
                  Image.asset(
                    widget.trail.image,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[300],
                        child: const Center(child: Text('Image not available')),
                      );
                    },
                  ),
                  // Gradient overlay for better text readability
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Add trail name as the first widget in the main content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Text(
                widget.trail.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Main content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rating summary card with shadow
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Rating circle
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _getRatingColor(overallRating),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          overallRating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Star rating visualization
                            Row(
                              children: List.generate(5, (index) {
                                return Icon(
                                  index < overallRating.floor()
                                      ? Icons.star
                                      : (index < overallRating ? Icons.star_half : Icons.star_border),
                                  color: Colors.amber,
                                  size: 24,
                                );
                              }),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_reviews.length} ${_reviews.length == 1 ? 'review' : 'reviews'}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Location card with map preview
                if (widget.trail.latitude != null && widget.trail.longitude != null)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Map image
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(
                            'https://maps.geoapify.com/v1/staticmap?style=osm-carto&width=600&height=400&center=lonlat:${widget.trail.longitude},${widget.trail.latitude}&zoom=14&apiKey=1301ee17de954a66be3b50e8ead73e2c',
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey[200],
                                child: const Center(child: CircularProgressIndicator()),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Icon(Icons.map_outlined, size: 50, color: Colors.grey)
                                ),
                              );
                            },
                          ),
                        ),
                        // Location info
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.location_on, color: Colors.red),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      widget.trail.location,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _openInGoogleMaps,
                                icon: const Icon(Icons.map),
                                label: const Text('Open in Google Maps'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 45),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  _buildLocationCard(),

                // Trail details section
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trail Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildModernInfoRow(
                        icon: Icons.trending_up,
                        title: 'Elevation',
                        value: '${widget.trail.elevation} meters above sea level',
                        color: Colors.blueAccent,
                      ),
                      const Divider(height: 24),
                      _buildModernInfoRow(
                        icon: Icons.warning_amber_rounded,
                        title: 'Trail Difficulty',
                        value: widget.trail.difficulty,
                        color: _getDifficultyColor(widget.trail.difficulty),
                      ),
                      const Divider(height: 24),
                      _buildModernInfoRow(
                        icon: Icons.calendar_today,
                        title: 'Best Time to Hike',
                        value: widget.trail.bestTime,
                        color: Colors.green,
                      ),
                      const Divider(height: 24),
                      _buildModernInfoRow(
                        icon: Icons.backpack,
                        title: 'Basic Necessities',
                        value: widget.trail.necessities,
                        color: Colors.deepOrange,
                      ),
                    ],
                  ),
                ),

                // Description section
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'About this Trail',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.trail.description,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: Color(0xFF424242),
                        ),
                        textAlign: TextAlign.justify,
                      ),
                    ],
                  ),
                ),

                // Modern review submission form
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          "Rate This Trail",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Share your experience to help other hikers",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Modern star rating
                        _buildRatingBar(),
                        const SizedBox(height: 20),
                        
                        // Name field
                        TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            hintText: "Your name",
                            labelText: "Name",
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Theme.of(context).primaryColor),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Comment field
                        TextField(
                          controller: _commentController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: "Share your experience with this trail...",
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(bottom: 60),
                              child: Icon(Icons.comment_outlined),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Theme.of(context).primaryColor),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitRating,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.shade300,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Submit Review',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // User reviews
                if (_reviews.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text(
                      'User Reviews (${_reviews.length})',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ..._reviews.map((review) => _buildModernReviewItem(review)).toList(),
                ] else ...[
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text(
                          'No reviews yet. Be the first to review!',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for the new design
  Color _getRatingColor(double rating) {
    if (rating >= 4.5) return Colors.green[700]!;
    if (rating >= 4.0) return Colors.green[500]!;
    if (rating >= 3.5) return Colors.green[300]!;
    if (rating >= 3.0) return Colors.amber[700]!;
    if (rating >= 2.0) return Colors.orange;
    return Colors.red;
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return Colors.green;
      case 'moderate':
        return Colors.amber[700]!;
      case 'hard':
      case 'difficult':
        return Colors.orange[700]!;
      case 'challenging':
      case 'extreme':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  Widget _buildModernInfoRow({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                  color: Color(0xFF616161),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF212121),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernReviewItem(Review review) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // User avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.primaries[review.userName.hashCode % Colors.primaries.length].shade100,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    review.userName[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.primaries[review.userName.hashCode % Colors.primaries.length].shade700,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // User name and date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${review.date.day} ${_getMonthName(review.date.month)} ${review.date.year}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Rating display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getRatingColor(review.rating),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      review.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Review comment
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                review.comment,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Color(0xFF424242),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  Widget _buildRatingBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: () => _updateRating(index + 1.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              index < _userRating.floor()
                  ? Icons.star
                  : (index < _userRating ? Icons.star_half : Icons.star_border),
              color: Colors.amber,
              size: 36,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      height: 250,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.blue.shade300, Colors.blue.shade700],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Trail Location",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.trail.location,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.gps_fixed, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                widget.trail.latitude != null && widget.trail.longitude != null
                    ? "Coordinates: ${widget.trail.latitude!.toStringAsFixed(4)}, ${widget.trail.longitude!.toStringAsFixed(4)}"
                    : "Coordinates not available",
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue.shade700,
              ),
              onPressed: _openInGoogleMaps,
              icon: const Icon(Icons.map),
              label: const Text('View in Google Maps'),
            ),
          ),
        ],
      ),
    );
  }
}