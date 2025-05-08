import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong; // Different LatLng class from flutter_map
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

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
    'streets': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
    'satellite': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    'terrain': 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
  };

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
    final status = await Permission.location.request();
    
    if (status.isGranted) {
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
      forceLocationManager: true, // This forces the use of the Android LocationManager, which might be more accurate in some regions
      intervalDuration: const Duration(seconds: 1),
      //(Optional) Set if your app targets Android 11 or higher
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationText: "Ascentra is tracking your location",
        notificationTitle: "Location Tracking",
        enableWakeLock: true,
      )
    );
    
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
      .listen((Position position) {
        final newPoint = latlong.LatLng(position.latitude, position.longitude);
        
        setState(() {
          _currentPosition = position;
          _currentSpeed = position.speed * 3.6; // Convert m/s to km/h
          _locationAccuracy = position.accuracy;
          
          _routePoints.add(newPoint);
          
          final double prevElevation = _currentElevation;
          _currentElevation = position.altitude;
          final elevationDiff = _currentElevation - prevElevation;
          if (elevationDiff > 0) {
            _elevationGain += elevationDiff;
          }
          
          if (_routePoints.length > 1) {
            final prevPoint = _routePoints[_routePoints.length - 2];
            final distanceInMeters = Geolocator.distanceBetween(
              prevPoint.latitude, prevPoint.longitude,
              newPoint.latitude, newPoint.longitude
            );
            _distance += distanceInMeters / 1000;
            
            if (_distance > 0) {
              final secondsPerKm = _elapsedTime.inSeconds / _distance;
              final mins = (secondsPerKm / 60).floor();
              final secs = (secondsPerKm % 60).floor();
              _pace = "$mins:${secs.toString().padLeft(2, '0')} /km";
            }
          }
        });
        
        // Move map to follow user
        _mapController.move(newPoint, _mapController.zoom);
    });
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
    
    if (_routePoints.length > 1) {
      _showActivitySummary();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough data to save activity')),
      );
    }
  }
  
  void _showActivitySummary() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Activity Summary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Distance: ${_distance.toStringAsFixed(2)} km'),
            Text('Duration: ${_formatDuration(_elapsedTime)}'),
            Text('Elevation Gain: ${_elevationGain.toStringAsFixed(0)} m'),
            Text('Avg Pace: $_pace'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('DISCARD'),
          ),
          FilledButton(
            onPressed: () {
              // Save activity to database
              Navigator.pop(context);
              Navigator.pop(context); // Return to previous screen
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
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
      appBar: AppBar(
        title: const Text('Activity Tracker'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Stats panel at top
          Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('Distance', '${_distance.toStringAsFixed(2)} km'),
                      _buildStatColumn('Time', _formatDuration(_elapsedTime)),
                      _buildStatColumn('Pace', _pace),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatColumn('Elevation', '${_currentElevation.toStringAsFixed(0)} m'),
                      _buildStatColumn('Elev. Gain', '+${_elevationGain.toStringAsFixed(0)} m'),
                      _buildStatColumn('Speed', '${_currentSpeed.toStringAsFixed(1)} km/h'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.gps_fixed, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'GPS: ${_locationAccuracy < 10 ? "High" : _locationAccuracy < 30 ? "Medium" : "Low"} (±${_locationAccuracy.toStringAsFixed(0)}m)',
                        style: TextStyle(
                          fontSize: 12,
                          color: _locationAccuracy < 10 ? Colors.green : _locationAccuracy < 30 ? Colors.orange : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // OpenStreetMap using flutter_map
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentPosition != null
                    ? latlong.LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                    : _defaultPosition,
                initialZoom: 15.0,
              ),
              children: [
                // Base map layer
                TileLayer(
                  urlTemplate: _mapSources[_currentMapType],
                  userAgentPackageName: 'com.example.app',
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
                
                // Route polyline
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        color: Colors.blue,
                        strokeWidth: 4.0,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
      
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // "Calibrate GPS" button
          FloatingActionButton(
            heroTag: 'calibrate',
            mini: true,
            onPressed: _calibrateLocation,
            backgroundColor: Colors.orange,
            child: const Icon(Icons.gps_fixed),
          ),
          const SizedBox(height: 8),
          
          // "Find My Location" button
          FloatingActionButton(
            heroTag: 'findMe',
            mini: true,
            onPressed: () {
              if (_currentPosition != null) {
                _mapController.move(
                  latlong.LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                  18.0, // Zoom in more for better visibility
                );
              } else {
                _getCurrentLocation();
              }
            },
            child: const Icon(Icons.my_location),
          ),
          
          const SizedBox(height: 8),
          
          // "Change Map Type" button
          FloatingActionButton(
            heroTag: 'mapType',
            mini: true,
            onPressed: _cycleMapType,
            child: Icon(
              _currentMapType == 'streets' ? Icons.map : 
              _currentMapType == 'satellite' ? Icons.satellite : 
              Icons.terrain,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Your existing tracking buttons
          if (!_isTracking)
            FloatingActionButton.extended(
              onPressed: _startTracking,
              icon: const Icon(Icons.play_arrow),
              label: const Text('START'),
              backgroundColor: Colors.green,
            )
          else if (_isPaused)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  onPressed: _resumeTracking,
                  backgroundColor: Colors.green,
                  heroTag: 'resume',
                  child: const Icon(Icons.play_arrow),
                ),
                const SizedBox(width: 16),
                FloatingActionButton(
                  onPressed: _stopTracking,
                  backgroundColor: Colors.red,
                  heroTag: 'stop',
                  child: const Icon(Icons.stop),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  onPressed: _pauseTracking,
                  backgroundColor: Colors.orange,
                  heroTag: 'pause',
                  child: const Icon(Icons.pause),
                ),
                const SizedBox(width: 16),
                FloatingActionButton(
                  onPressed: _stopTracking,
                  backgroundColor: Colors.red,
                  heroTag: 'stop',
                  child: const Icon(Icons.stop),
                ),
              ],
            ),
        ],
      ),
    );
  }
  
  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}