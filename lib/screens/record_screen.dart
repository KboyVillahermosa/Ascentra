import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong; // Different LatLng class from flutter_map
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import './save_activity_screen.dart';
import '../models/activity.dart';
import '../services/activity_service.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> with WidgetsBindingObserver {
  // Map controller
  final MapController _mapController = MapController();
  
  // Tracking state
  bool _isTracking = false;
  bool _isPaused = false;
  DateTime? _startTime;
  Duration _elapsedTime = Duration.zero;
  Timer? _timer;
  
  // Location data
  Position? _currentPosition;
  List<latlong.LatLng> _routePoints = [];
  StreamSubscription<Position>? _positionStream;
  
  // Activity metrics
  double _distance = 0.0;  // in km
  double _currentElevation = 0.0;  // in meters
  double _elevationGain = 0.0;  // in meters
  double _currentSpeed = 0.0;  // in km/h
  String _pace = "0:00 /km";  // min:sec per km
  double _locationAccuracy = 0.0; // in meters
  
  // Default position (Cebu City)
  final latlong.LatLng _defaultPosition = latlong.LatLng(10.3157, 123.8854);

  // Loading state for location
  bool _isGettingLocation = false;

  // Map type state
  String _currentMapType = 'streets';
  Map<String, String> _mapSources = {
    'streets': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', // Removed the {s} subdomain
    'satellite': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    'terrain': 'https://stamen-tiles-{s}.a.ssl.fastly.net/terrain/{z}/{x}/{y}.png', // Stamen still uses subdomains
  };

  // Add this controller to your class variables
  final _activityNameController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLocationPermission();
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    _positionStream?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _isTracking && !_isPaused) {
      _pauseTracking();
    }
  }
  
  Future<void> _checkLocationPermission() async {
    final locationStatus = await Permission.location.request();
    final backgroundStatus = await Permission.locationAlways.request();
    
    if (locationStatus.isGranted) {
      _getCurrentLocation();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission is required to track your activity'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
  
  Future<void> _getCurrentLocation() async {
    setState(() {
      // Show a loading indicator while getting location
      _isGettingLocation = true;
    });
    
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 5),
      );
      
      setState(() {
        _currentPosition = position;
        _currentElevation = position.altitude;
        _isGettingLocation = false;
      });
      
      // Move map to current location with higher zoom
      _mapController.move(
        latlong.LatLng(position.latitude, position.longitude),
        18.0, // Higher zoom level for better visibility
      );
      
      // Provide feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location found!'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      setState(() {
        _isGettingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
      print('Error getting current location: $e');
    }
  }
  
  Future<void> _calibrateLocation() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calibrating GPS...')),
    );
    
    // First try to get a very high accuracy single location
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 10),
      );
      
      setState(() {
        _currentPosition = position;
        _locationAccuracy = position.accuracy;
      });
      
      // Move map to this location
      _mapController.move(
        latlong.LatLng(position.latitude, position.longitude),
        18.0,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPS calibrated (±${position.accuracy.toStringAsFixed(0)}m)')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calibration failed: $e')),
      );
    }
  }
  
  void _startTracking() {
    setState(() {
      _isTracking = true;
      _startTime = DateTime.now();
      _routePoints = [];
      _distance = 0.0;
      _elevationGain = 0.0;
    });
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime != null) {
        setState(() {
          _elapsedTime = DateTime.now().difference(_startTime!);
        });
      }
    });
    
    _startPositionTracking();
  }
  
  void _startPositionTracking() {
    final LocationSettings locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 2, // Update every 2 meters
      forceLocationManager: true,
      intervalDuration: const Duration(seconds: 1),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: "Ascentra is tracking your location",
        notificationTitle: "Location Tracking",
        enableWakeLock: true,
      )
    );
    
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
      .listen((Position position) {
        // Add this debug line to confirm data is coming in
        print('New position: ${position.latitude}, ${position.longitude}, accuracy: ${position.accuracy}m, altitude: ${position.altitude}m, speed: ${position.speed}');
        
        final newPoint = latlong.LatLng(position.latitude, position.longitude);
        
          // IMPROVED: Less strict filtering and better distance calculation
        if (position.accuracy <= 20) { // More strict filtering for better accuracy
          // Check if this is a real movement before adding to route
          bool isValidMovement = true;
          
          if (_routePoints.isNotEmpty) {
            final lastPoint = _routePoints.last;
            final distanceFromLastPoint = Geolocator.distanceBetween(
              lastPoint.latitude, lastPoint.longitude,
              newPoint.latitude, newPoint.longitude
            );
            
            // Filter out jitter (less than 0.5m movement is likely GPS noise)
            if (distanceFromLastPoint < 0.5) {
              isValidMovement = false;
              print('Skipping point - too close to previous point: ${distanceFromLastPoint}m');
            }
          }
          
          if (isValidMovement) {
            setState(() {
              _routePoints.add(newPoint);
              _currentPosition = position;
              _currentSpeed = position.speed * 3.6; // Convert m/s to km/h
              _locationAccuracy = position.accuracy;
              
              // CHANGE: Better elevation handling with sanity check
              if (position.altitude != 0) { // Only process if altitude is not zero
                final double prevElevation = _currentElevation;
                _currentElevation = position.altitude;
                final elevationDiff = _currentElevation - prevElevation;
                // Only count reasonable elevation changes (less than 20m in one update)
                if (elevationDiff > 0 && elevationDiff < 20) {
                  _elevationGain += elevationDiff;
                }
              }
              
              if (_routePoints.length > 1) {
                // Distance calculation - improved
                final prevPoint = _routePoints[_routePoints.length - 2];
                final distanceInMeters = Geolocator.distanceBetween(
                  prevPoint.latitude, prevPoint.longitude,
                  newPoint.latitude, newPoint.longitude
                );
                
                // Lower threshold to 0.5 meter to capture smaller movements
                if (distanceInMeters > 0.5) {
                  _distance += distanceInMeters / 1000;
                  _updatePace();
                  // Enhanced debug to track calculations
                  print('Distance updated: $_distance km, Added: ${distanceInMeters}m, Pace: $_pace');
                }
              }
            });
            
            // Move map to follow user
            _mapController.move(newPoint, _mapController.zoom);
          }
        } else {
          print('Skipping low accuracy point: ${position.accuracy}m');
        }
      },
      onError: (e) {
        // Add error handling
        print('Position stream error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location error: $e')),
        );
      });
  }
  
  // Add this method after _startPositionTracking()
  void _updatePace() {
    // More reliable pace calculation - any movement counts
    if (_distance > 0.001 && _elapsedTime.inSeconds > 0) { // Lowered threshold to 1 meter
      final secondsPerKm = _elapsedTime.inSeconds / _distance;
      final mins = (secondsPerKm / 60).floor();
      final secs = (secondsPerKm % 60).floor();
      
      // Ensure pace is reasonable (between 2-60 min/km)
      if (mins >= 2 && mins <= 60) {
        setState(() {
          _pace = "$mins:${secs.toString().padLeft(2, '0')} /km";
        });
        print('Pace calculated: $_pace (${secondsPerKm.toStringAsFixed(1)} sec/km)');
      } else {
        print('Pace calculation produced unusual value: $mins:$secs min/km');
      }
    } else {
      setState(() {
        _pace = "0:00 /km"; // Default pace when not moving
      });
    }
  }
  
  void _pauseTracking() {
    setState(() {
      _isPaused = true;
    });
    _timer?.cancel();
    _positionStream?.pause();
  }
  
  void _resumeTracking() {
    setState(() {
      _isPaused = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime != null) {
        setState(() {
          _elapsedTime = DateTime.now().difference(_startTime!);
        });
      }
    });
    _positionStream?.resume();
  }
  
  void _stopTracking() {
    _timer?.cancel();
    _positionStream?.cancel();
    
    setState(() {
      _isTracking = false;
      _isPaused = false;
    });
    
    // Always navigate to save activity screen, regardless of activity length
    _navigateToSaveActivity();
  }
  
  // New method to navigate to save activity screen
  void _navigateToSaveActivity() {
    // Ensure we have at least one route point
    if (_routePoints.isEmpty && _currentPosition != null) {
      _routePoints.add(latlong.LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
    }
    
    // Create activity object with initial data
    final activity = Activity(
      userId: 1, // Replace with actual user ID when available
      name: '', // Will be filled in SaveActivityScreen
      date: DateTime.now(),
      durationInSeconds: _elapsedTime.inSeconds,
      distance: _distance,
      elevationGain: _elevationGain,
      avgPace: _pace,
      routePoints: _routePoints,
      description: '',
      activityType: 'Run', // Default
      feeling: '',
      privateNotes: '',
    );
    
    // Navigate to SaveActivityScreen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SaveActivityScreen(activity: activity),
      ),
    );
  }
  
  void _showActivitySummary() {
    // Reset activity name controller
    _activityNameController.text = '';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activity Summary'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Activity map thumbnail would go here in a real app
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(child: Text('Activity Map')),
              ),
              const SizedBox(height: 24),
              
              // Stats in Strava style
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryItem('Distance', '${_distance.toStringAsFixed(2)} km'),
                  _buildSummaryItem('Duration', _formatDuration(_elapsedTime)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryItem('Avg Pace', _pace),
                  _buildSummaryItem('Elev Gain', '${_elevationGain.toStringAsFixed(0)} m'),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Activity name field like Strava
              TextField(
                controller: _activityNameController,
                decoration: const InputDecoration(
                  labelText: 'Activity Name',
                  border: OutlineInputBorder(),
                  hintText: 'Morning Run',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('DISCARD'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                // Get activity name from controller
                final activityName = _activityNameController.text.trim();
                final defaultName = 'Activity ${DateTime.now().toString().substring(0, 16)}';
                
                // Debug the data before saving
                print('Saving activity with: Distance: $_distance km, ElevGain: $_elevationGain m, Points: ${_routePoints.length}');
                
                final activity = Activity(
                  userId: 1, // Replace with actual user ID when available
                  name: activityName.isEmpty ? defaultName : activityName,
                  date: DateTime.now(),
                  durationInSeconds: _elapsedTime.inSeconds,
                  distance: _distance,
                  elevationGain: _elevationGain,
                  avgPace: _pace,
                  routePoints: _routePoints,
                );
                
                // Save to database
                final activityService = ActivityService();
                final result = await activityService.saveActivity(activity);
                
                print('Save result: $result'); // Debug output
                
                Navigator.pop(context);
                
                if (result > 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Activity saved successfully!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to save activity - database error')),
                  );
                }
              } catch (e) {
                print('Error saving activity: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ],
    );
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours:$minutes:$seconds";
  }

  void _cycleMapType() {
    setState(() {
      if (_currentMapType == 'streets') {
        _currentMapType = 'satellite';
      } else if (_currentMapType == 'satellite') {
        _currentMapType = 'terrain';
      } else {
        _currentMapType = 'streets';
      }
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Map type: ${_currentMapType.toUpperCase()}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map takes full screen like in Strava
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition != null
                  ? latlong.LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                  : _defaultPosition,
              initialZoom: 15.0,
              minZoom: 5.0,
              maxZoom: 18.0,
              keepAlive: true,
            ),
            children: [
              // Base map layer
              TileLayer(
                urlTemplate: _mapSources[_currentMapType],
                userAgentPackageName: 'com.example.ascentra',
                // Only use subdomains for map types that support them
                subdomains: _currentMapType == 'terrain' ? const ['a', 'b', 'c'] : const [],
                maxZoom: 19,
                // Add additional error handling
                errorImage: const NetworkImage('https://tile.openstreetmap.org/15/0/0.png'),
              ),
              
              // Route polyline with enhanced visibility
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.blue,
                      strokeWidth: 5.0,
                      isDotted: false,
                    ),
                  ],
                ),
                
              // Current location marker
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: latlong.LatLng(
                        _currentPosition!.latitude, 
                        _currentPosition!.longitude
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Blue circle background
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.3),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.blue,
                                width: 2,
                              ),
                            ),
                          ),
                          // Center dot
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Top stats bar - Strava-like
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () {
                            if (_isTracking) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('End Activity?'),
                                  content: const Text('Your current activity will be lost.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('CANCEL'),
                                    ),
                                    FilledButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        Navigator.pop(context);
                                      },
                                      child: const Text('END'),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              Navigator.pop(context);
                            }
                          },
                        ),
                        Text(
                          'RECORDING',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isTracking ? Colors.green : Colors.grey,
                          ),
                        ),
                        // GPS accuracy indicator - Strava style
                        Row(
                          children: [
                            Icon(
                              Icons.gps_fixed,
                              size: 16,
                              color: _locationAccuracy < 10 ? Colors.green : 
                                    _locationAccuracy < 30 ? Colors.orange : Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '±${_locationAccuracy.toStringAsFixed(0)}m',
                              style: TextStyle(
                                fontSize: 12,
                                color: _locationAccuracy < 10 ? Colors.green : 
                                      _locationAccuracy < 30 ? Colors.orange : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Strava-like stats display (bigger numbers, smaller labels)
                        _buildStravasStatDisplay('DISTANCE', '${_distance.toStringAsFixed(2)}', 'km'),
                        _buildVerticalDivider(),
                        _buildStravasStatDisplay('TIME', _formatDuration(_elapsedTime), ''),
                        _buildVerticalDivider(),
                        _buildStravasStatDisplay('PACE', _pace, ''),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Strava-style map control buttons (right side)
          Positioned(
            right: 16,
            bottom: 130,
            child: Column(
              children: [
                // Layer toggle button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _cycleMapType,
                    icon: Icon(
                      _currentMapType == 'streets' ? Icons.map : 
                      _currentMapType == 'satellite' ? Icons.satellite : 
                      Icons.terrain,
                    ),
                    tooltip: 'Change map type',
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Location button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () {
                      if (_currentPosition != null) {
                        _mapController.move(
                          latlong.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                          18.0,
                        );
                      } else {
                        _getCurrentLocation();
                      }
                    },
                    icon: const Icon(Icons.my_location),
                    tooltip: 'Find my location',
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Calibrate GPS button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: _calibrateLocation,
                    icon: const Icon(Icons.gps_fixed),
                    tooltip: 'Calibrate GPS',
                  ),
                ),
              ],
            ),
          ),
          
          // Strava-like bottom control panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -3),
                  ),
                ],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: _buildTrackingControls(),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStravasStatDisplay(String label, String value, String unit) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (unit.isNotEmpty)
              Text(
                ' $unit',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey.withOpacity(0.3),
    );
  }
  
  Widget _buildTrackingControls() {
    if (!_isTracking) {
      // Start button (large centered button like Strava)
      return Center(
        child: SizedBox(
          width: 160,
          height: 56,
          child: ElevatedButton(
            onPressed: _startTracking,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text(
              'START',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    } else if (_isPaused) {
      // Resume and stop buttons
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Stop button
          ElevatedButton(
            onPressed: _stopTracking,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(16),
            ),
            child: const Icon(Icons.stop, size: 32),
          ),
          // Resume button
          ElevatedButton(
            onPressed: _resumeTracking,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(16),
            ),
            child: const Icon(Icons.play_arrow, size: 32),
          ),
        ],
      );
    } else {
      // Pause and stop buttons
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Stop button
          ElevatedButton(
            onPressed: _stopTracking,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(16),
            ),
            child: const Icon(Icons.stop, size: 32),
          ),
          // Pause button
          ElevatedButton(
            onPressed: _pauseTracking,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(16),
            ),
            child: const Icon(Icons.pause, size: 32),
          ),
        ],
      );
    }
  }
}