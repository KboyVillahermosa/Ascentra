import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'dart:convert';

class Activity {
  final int? id;
  final int userId;
  final String name;
  final DateTime date;
  final int durationInSeconds;
  final double distance;
  final double elevationGain;
  final String avgPace;
  final List<latlong.LatLng> routePoints;
  final String description;
  final String activityType;
  final String feeling;
  final String privateNotes;
  final Set<String> likedBy;

  Activity({
    this.id,
    required this.userId,
    required this.name,
    required this.date,
    required this.durationInSeconds,
    required this.distance,
    required this.elevationGain,
    required this.avgPace,
    required this.routePoints,
    this.description = '',
    this.activityType = 'Run',
    this.feeling = '',
    this.privateNotes = '',
    Set<String>? likedBy,
  }) : this.likedBy = likedBy ?? {};

  // Calculate pace in minutes per kilometer
  double get pace {
    if (distance <= 0) return 0;
    return durationInSeconds / 60 / distance;
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

    final double hours = durationInSeconds / 3600;
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
      userId: userId,
      name: name,
      date: date,
      durationInSeconds: durationInSeconds,
      distance: distance,
      elevationGain: elevationGain,
      avgPace: avgPace,
      routePoints: routePoints,
      description: description,
      activityType: activityType,
      feeling: feeling,
      privateNotes: privateNotes,
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