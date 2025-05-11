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

  Widget _buildRatingBar() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return IconButton(
          icon: Icon(
            index < _userRating.floor()
                ? Icons.star
                : (index < _userRating ? Icons.star_half : Icons.star_border),
            color: Colors.amber,
            size: 30,
          ),
          onPressed: () => _updateRating(index + 1.0),
          splashRadius: 24,
        );
      }),
    );
  }

  Widget _buildReviewItem(Review review) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: Colors.purple.shade100,
                  child: Text(
                    review.userName[0],
                    style: TextStyle(color: Colors.purple.shade800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < review.rating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 16,
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(review.comment),
                    ],
                  ),
                ),
                Text(
                  '${review.date.day}/${review.date.month}/${review.date.year}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
      appBar: AppBar(
        title: Text(widget.trail.name),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              widget.trail.image,
              height: 250,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 250,
                  color: Colors.grey[300],
                  child: const Center(child: Text('Image not available')),
                );
              },
            ),
            widget.trail.latitude != null && widget.trail.longitude != null
                ? Image.network(
                    'https://maps.geoapify.com/v1/staticmap?style=osm-carto&width=600&height=400&center=lonlat:${widget.trail.longitude},${widget.trail.latitude}&zoom=14&apiKey=1301ee17de954a66be3b50e8ead73e2c',
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 250,
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      print("Map error details: $error");
                      return _buildLocationCard();
                    },
                  )
                : _buildLocationCard(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_rate_rounded, color: Colors.amber, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        '${overallRating.toStringAsFixed(1)} / 5.0',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${_reviews.length} reviews)',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        widget.trail.location,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    icon: Icons.trending_up,
                    title: 'Elevation',
                    value: '${widget.trail.elevation} meters above sea level',
                  ),
                  _buildInfoRow(
                    icon: Icons.warning_amber_rounded,
                    title: 'Trail Difficulty',
                    value: widget.trail.difficulty,
                  ),
                  _buildInfoRow(
                    icon: Icons.calendar_today,
                    title: 'Best Time to Hike',
                    value: widget.trail.bestTime,
                  ),
                  _buildInfoRow(
                    icon: Icons.backpack,
                    title: 'Basic Necessities',
                    value: widget.trail.necessities,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.trail.description,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.justify,
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            "Rate & Review This Trail",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildRatingBar(),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              hintText: "Your name",
                              labelText: "Name",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _commentController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: "Share your experience with this trail...",
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitRating,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Submit Review'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_reviews.isNotEmpty) ...[
                    const Text(
                      'User Reviews',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._reviews.map((review) => _buildReviewItem(review)).toList(),
                  ] else ...[
                    const Center(
                      child: Text(
                        'No reviews yet. Be the first to review!',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openInGoogleMaps,
                      icon: const Icon(Icons.map),
                      label: const Text('Open in Google Maps'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.deepPurple),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
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