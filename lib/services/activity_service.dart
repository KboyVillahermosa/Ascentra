import 'dart:convert';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/activity.dart';
import '../database/database_helper.dart';

class ActivityService {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  
  Future<int> saveActivity(Activity activity) async {
    final Database db = await _databaseHelper.database;
    
    // Convert route points to JSON string
    List<Map<String, dynamic>> routePointsJson = activity.routePoints
      .map((point) => {'lat': point.latitude, 'lng': point.longitude})
      .toList();
    
    final String routePointsString = jsonEncode(routePointsJson);
    
    // Convert likes to string if it exists
    String likedByString = '';
    if (activity.likedBy != null && activity.likedBy.isNotEmpty) {
      likedByString = activity.likedBy.toList().join(',');
    }
    
    Map<String, dynamic> row = {
      'user_id': activity.userId,
      'name': activity.name,
      'date': activity.date.toIso8601String(),
      'duration_seconds': activity.durationInSeconds,
      'distance': activity.distance,
      'elevation_gain': activity.elevationGain,
      'avg_pace': activity.avgPace,
      'route_points': routePointsString,
      'description': activity.description,
      'activity_type': activity.activityType,
      'feeling': activity.feeling,
      'private_notes': activity.privateNotes,
      'liked_by': likedByString,
    };
    
    if (activity.id != null) {
      // Update existing
      return await db.update(
        'activities',
        row,
        where: 'id = ?',
        whereArgs: [activity.id],
      );
    } else {
      // Insert new
      return await db.insert('activities', row);
    }
  }
  
  // Method to get all activities
  Future<List<Activity>> getActivities() async {
    final Database db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('activities', orderBy: 'date DESC');
    
    return List.generate(maps.length, (i) {
      final routePointsJson = jsonDecode(maps[i]['route_points']) as List;
      final List<latlong.LatLng> routePoints = routePointsJson
        .map((point) => latlong.LatLng(point['lat'] as double, point['lng'] as double))
        .toList();
      
      final likedBy = maps[i]['liked_by'] != null && maps[i]['liked_by'].isNotEmpty 
          ? Set<String>.from((maps[i]['liked_by'] as String).split(','))
          : <String>{};
      
      return Activity(
        id: maps[i]['id'] as int?,
        userId: maps[i]['user_id'] as int,
        name: maps[i]['name'] as String,
        date: DateTime.parse(maps[i]['date'] as String),
        durationInSeconds: maps[i]['duration_seconds'] as int,
        distance: maps[i]['distance'] as double,
        elevationGain: maps[i]['elevation_gain'] as double,
        avgPace: maps[i]['avg_pace'] as String? ?? '',
        routePoints: routePoints,
        description: maps[i]['description'] as String? ?? '',
        activityType: maps[i]['activity_type'] as String? ?? 'Run',
        feeling: maps[i]['feeling'] as String? ?? '',
        privateNotes: maps[i]['private_notes'] as String? ?? '',
        likedBy: likedBy,
      );
    });
  }
  
  // Method to delete an activity
  Future<int> deleteActivity(int activityId) async {
    final Database db = await _databaseHelper.database;
    return await db.delete(
      'activities',
      where: 'id = ?',
      whereArgs: [activityId],
    );
  }
}