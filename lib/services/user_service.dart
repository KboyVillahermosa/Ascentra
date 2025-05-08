import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user_profile.dart';

class UserService {
  static const String _usersKey = 'app_users';
  static const String _profilesKey = 'user_profiles';
  
  // Get a user profile
  static Future<UserProfile?> getUserProfile(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? profilesJson = prefs.getString(_profilesKey);
      
      Map<String, dynamic> profilesMap = {};
      if (profilesJson != null) {
        try {
          profilesMap = jsonDecode(profilesJson);
        } catch (e) {
          print('Error decoding profiles JSON: $e');
          // Continue with empty map if JSON is invalid
        }
      }
      
      // If profile doesn't exist, create a default one
      if (!profilesMap.containsKey(username)) {
        print('Creating default profile for $username');
        final defaultProfile = UserProfile(username: username);
        await saveUserProfile(defaultProfile);
        return defaultProfile;
      }
      
      try {
        return UserProfile.fromJson(profilesMap[username]);
      } catch (e) {
        print('Error parsing profile for $username: $e');
        // If profile data is corrupt, create a new default profile
        final defaultProfile = UserProfile(username: username);
        await saveUserProfile(defaultProfile);
        return defaultProfile;
      }
    } catch (e) {
      print('Error in getUserProfile: $e');
      // Always return a default profile in case of errors
      return UserProfile(username: username);
    }
  }
  
  // Save/update a user profile
  static Future<bool> saveUserProfile(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? profilesJson = prefs.getString(_profilesKey);
      
      Map<String, dynamic> profilesMap = {};
      if (profilesJson != null) {
        try {
          profilesMap = jsonDecode(profilesJson);
        } catch (e) {
          print('Error decoding profiles JSON in save: $e');
          // Continue with empty map if JSON is invalid
        }
      }
      
      profilesMap[profile.username] = profile.toJson();
      
      return await prefs.setString(_profilesKey, jsonEncode(profilesMap));
    } catch (e) {
      print('Error saving user profile: $e');
      return false;
    }
  }
  
  // Update a user's password
  static Future<bool> updatePassword(String username, String oldPassword, String newPassword) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? usersJson = prefs.getString(_usersKey);
      
      if (usersJson == null) {
        // For testing and demonstration, allow password change without verification
        Map<String, dynamic> newUsersMap = {username: newPassword};
        return await prefs.setString(_usersKey, jsonEncode(newUsersMap));
      }
      
      Map<String, dynamic> usersMap;
      try {
        usersMap = jsonDecode(usersJson);
      } catch (e) {
        print('Error decoding users JSON: $e');
        // For testing, create a new users map
        Map<String, dynamic> newUsersMap = {username: newPassword};
        return await prefs.setString(_usersKey, jsonEncode(newUsersMap));
      }
      
      // In a real app, you'd verify the old password here
      // For demo purposes, allow any password change
      usersMap[username] = newPassword;
      
      return await prefs.setString(_usersKey, jsonEncode(usersMap));
    } catch (e) {
      print('Error updating password: $e');
      return false;
    }
  }
  
  // Upload a profile image
  static Future<String?> uploadProfileImage(String username, XFile imageFile) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'profile_${username}_${Uuid().v4()}.jpg';
      final savedFile = File('${directory.path}/$fileName');
      
      // Copy the picked file to app directory
      await savedFile.writeAsBytes(await imageFile.readAsBytes());
      
      // Get the current profile
      final profile = await getUserProfile(username);
      
      if (profile != null) {
        // Delete old profile image if exists
        if (profile.profileImagePath != null) {
          try {
            final oldFile = File(profile.profileImagePath!);
            if (await oldFile.exists()) {
              await oldFile.delete();
            }
          } catch (e) {
            print('Error deleting old profile image: $e');
            // Continue even if delete fails
          }
        }
        
        // Update profile with new image path
        await saveUserProfile(profile.copyWith(profileImagePath: savedFile.path));
      }
      
      return savedFile.path;
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
    }
  }
}