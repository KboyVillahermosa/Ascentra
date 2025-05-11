import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trail.dart';

class TrailService {
  static const String _trailsKey = 'trails';
  static const String _reviewsKey = 'trail_reviews';
  
  // Get all trails
  static Future<List<Trail>> getAllTrails() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? trailStrings = prefs.getStringList(_trailsKey);
    
    if (trailStrings == null) return [];
    
    return trailStrings
        .map((str) => Trail.fromJson(jsonDecode(str)))
        .toList();
  }
  
  // Add a review to a trail
  static Future<bool> addReview(String trailId, Review review) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String reviewsKey = '${_reviewsKey}_$trailId';
      
      final List<String>? reviewStrings = prefs.getStringList(reviewsKey);
      final List<String> updatedReviews = reviewStrings?.toList() ?? [];
      
      updatedReviews.add(jsonEncode(review.toJson()));
      
      // Save the review
      final success = await prefs.setStringList(reviewsKey, updatedReviews);
      
      if (success) {
        // Update the trail's rating
        await updateTrailRating(trailId);
      }
      
      return success;
    } catch (e) {
      print('Error adding review: $e');
      return false;
    }
  }
  
  // Update trail rating based on reviews
  static Future<bool> updateTrailRating(String trailId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? trailStrings = prefs.getStringList(_trailsKey);
      
      if (trailStrings == null) return false;
      
      // Get all reviews for this trail
      final String reviewsKey = '${_reviewsKey}_$trailId';
      final List<String>? reviewStrings = prefs.getStringList(reviewsKey);
      
      if (reviewStrings == null || reviewStrings.isEmpty) return false;
      
      // Calculate average rating
      final reviews = reviewStrings
          .map((str) => Review.fromJson(jsonDecode(str)))
          .toList();
          
      double sum = reviews.fold(0, (sum, review) => sum + review.rating);
      double average = sum / reviews.length;
      
      // Update the trail
      final List<String> updatedTrails = [];
      bool found = false;
      
      for (var trailString in trailStrings) {
        final trail = Trail.fromJson(jsonDecode(trailString));
        
        if (trail.id == trailId) {
          final updatedTrail = trail.copyWith(rating: average);
          updatedTrails.add(jsonEncode(updatedTrail.toJson()));
          found = true;
        } else {
          updatedTrails.add(trailString);
        }
      }
      
      if (!found) return false;
      
      return await prefs.setStringList(_trailsKey, updatedTrails);
    } catch (e) {
      print('Error updating trail rating: $e');
      return false;
    }
  }
}