import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/trail.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

class TrailDetailScreen extends StatefulWidget {
  final Trail trail;

  const TrailDetailScreen({super.key, required this.trail});

  @override
  State<TrailDetailScreen> createState() => _TrailDetailScreenState();
}

class _TrailDetailScreenState extends State<TrailDetailScreen> {
  late WebViewController controller;
  bool isMapLoading = true;

  @override
  void initState() {
    super.initState();
    // Create the map URL
    final mapUrl = 'https://www.google.com/maps/embed/v1/place?q=${widget.trail.latitude},${widget.trail.longitude}&zoom=13&key=';
    
    // Initialize controller
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            setState(() {
              isMapLoading = false;
            });
          },
        ),
      )
      ..loadRequest(
        Uri.parse(mapUrl),
      );
  }

  Future<void> _openInGoogleMaps() async {
    final url = 'https://www.google.com/maps/search/?api=1&query=${widget.trail.latitude},${widget.trail.longitude}';
    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else {
      throw 'Could not open the map.';
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
            // Map section using WebView
            Stack(
              children: [
                SizedBox(
                  height: 250,
                  width: double.infinity,
                  child: WebViewWidget(controller: controller),
                ),
                if (isMapLoading)
                  const SizedBox(
                    height: 250,
                    width: double.infinity,
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
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
}