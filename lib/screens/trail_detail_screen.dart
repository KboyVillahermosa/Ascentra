import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import for clipboard
import '../models/trail.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart'; // For sharing

class TrailDetailScreen extends StatefulWidget {
  final Trail trail;

  const TrailDetailScreen({super.key, required this.trail});

  @override
  State<TrailDetailScreen> createState() => _TrailDetailScreenState();
}

class _TrailDetailScreenState extends State<TrailDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Pre-check URL launcher capability to identify issues early
    _checkUrlLauncherCapability();
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
      
      // Try multiple map URL formats for maximum compatibility
      List<Uri> mapUris = [
        // Format 1: Web URL (works on most browsers)
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
        
        // Format 2: Native geo URI (works on many map apps)
        Uri.parse('geo:$lat,$lng'),
        
        // Format 3: Direct Google Maps app URL for Android
        Uri.parse('google.navigation:q=$lat,$lng'),
      ];
      
      bool launched = false;
      Exception? lastError;
      
      // Try each URI format until one works
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
        // Fallback: Open in browser
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
        
        // Add clipboard functionality
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

  // Add this method to show a dialog with coordinates
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
            onPressed: () {
              // Copy to clipboard using built-in Flutter clipboard
              Clipboard.setData(ClipboardData(text: '$lat, $lng'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coordinates copied to clipboard')),
              );
              Navigator.of(context).pop();
            },
            child: const Text('COPY & CLOSE'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  // Add this method to share trail location
  void _shareTrailLocation() {
    if (widget.trail.latitude == null || widget.trail.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trail coordinates are not available')),
      );
      return;
    }
    
    final lat = widget.trail.latitude!;
    final lng = widget.trail.longitude!;
    
    // Create message with coordinates and a Google Maps link
    final String message = 
      '${widget.trail.name} - ${widget.trail.location}\n' +
      'Coordinates: $lat, $lng\n' +
      'View on Google Maps: https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    
    // Share using share_plus package
    Share.share(message, subject: 'Check out this hiking trail');
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
                  const SizedBox(height: 12),
                  
                  // Button to share trail information
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _shareTrailLocation,
                      icon: const Icon(Icons.share),
                      label: const Text('Share Trail'),
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