import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'dart:convert';

class Activity {
  final String id; // Add ID for reference
  final DateTime date;
  final double distance; // in kilometers
  final Duration duration;
  final double elevationGain; // in meters
  final double avgSpeed; // in km/h
  final double maxSpeed; // in km/h
  final List<latlong.LatLng> routePoints;
  final String? notes;
  final Set<String> likedBy; // Usernames of users who liked this activity
  final String username; // Who created the activity
  
  Activity({
    required this.id,
    required this.date,
    required this.distance,
    required this.duration,
    required this.elevationGain,
    required this.avgSpeed,
    required this.maxSpeed,
    required this.routePoints,
    required this.username,
    this.notes,
    Set<String>? likedBy,
  }) : this.likedBy = likedBy ?? {};
  
  // Calculate pace in minutes per kilometer
  double get pace {
    if (distance <= 0) return 0;
    return duration.inSeconds / 60 / distance;
  }
  
  // Format pace as string (e.g., "5:30 /km")
  String get paceString {
    if (distance <= 0) return "0:00 /km";
    
    final double paceMinutes = pace;
    final int mins = paceMinutes.floor();
    final int secs = ((paceMinutes - mins) * 60).floor();
    return "$mins:${secs.toString().padLeft(2, '0')} /km";
  }
  
  // Simple calories calculation (approximate)
  int get calories {
    // MET values vary by activity intensity; using 6 for moderate-effort hiking
    const double metValue = 6.0;
    const double weightKg = 70.0; // Assuming average weight
    
    final double hours = duration.inSeconds / 3600;
    return (metValue * weightKg * hours).round();
  }
  
  // Add or remove a like
  Activity toggleLike(String username) {
    final newLikedBy = Set<String>.from(likedBy);
    if (newLikedBy.contains(username)) {
      newLikedBy.remove(username);
    } else {
      newLikedBy.add(username);
    }
    
    return Activity(
      id: id,
      date: date,
      distance: distance,
      duration: duration,
      elevationGain: elevationGain,
      avgSpeed: avgSpeed,
      maxSpeed: maxSpeed,
      routePoints: routePoints,
      username: username,
      notes: notes,
      likedBy: newLikedBy,
    );
  }
  
  // Check if liked by a specific user
  bool isLikedBy(String username) {
    return likedBy.contains(username);
  }
  
  // Get number of likes
  int get likesCount => likedBy.length;
}