import 'package:flutter/material.dart';
import '../models/trail.dart';
import 'package:url_launcher/url_launcher.dart';

class TrailDetailScreen extends StatefulWidget {
  final Trail trail;

  const TrailDetailScreen({super.key, required this.trail});

  @override
  State<TrailDetailScreen> createState() => _TrailDetailScreenState();
}

class _TrailDetailScreenState extends State<TrailDetailScreen> {
  Future<void> _openInGoogleMaps() async {
    try {
      // Create a proper Uri object with encoded coordinates
      final Uri uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${widget.trail.latitude},${widget.trail.longitude}',
      );
      
      // Use the newer launchUrl method with options
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication, // Forces opening in external app
        );
      } else {
        // Show a user-friendly error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Google Maps')),
          );
        }
      }
    } catch (e) {
      print('Error launching maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trail.name),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image at the top
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
            
            // Map section
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
                  // Location
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
                  
                  // Elevation
                  _buildInfoRow(
                    icon: Icons.trending_up,
                    title: 'Elevation',
                    value: '${widget.trail.elevation} meters above sea level',
                  ),
                  
                  // Difficulty
                  _buildInfoRow(
                    icon: Icons.warning_amber_rounded,
                    title: 'Trail Difficulty',
                    value: widget.trail.difficulty,
                  ),
                  
                  // Best time
                  _buildInfoRow(
                    icon: Icons.calendar_today,
                    title: 'Best Time to Hike',
                    value: widget.trail.bestTime,
                  ),
                  
                  // Necessities
                  _buildInfoRow(
                    icon: Icons.backpack,
                    title: 'Basic Necessities',
                    value: widget.trail.necessities,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Description
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
                  
                  // Button to open in Google Maps
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
                "Coordinates: ${widget.trail.latitude.toStringAsFixed(4)}, ${widget.trail.longitude.toStringAsFixed(4)}",
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