class UserProfile {
  final String username;
  final String? bio;
  final String? profileImagePath;
  final DateTime joinedDate;
  
  UserProfile({
    required this.username,
    this.bio,
    this.profileImagePath,
    DateTime? joinedDate,
  }) : this.joinedDate = joinedDate ?? DateTime.now();
  
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'bio': bio,
      'profileImagePath': profileImagePath,
      'joinedDate': joinedDate.toIso8601String(),
    };
  }
  
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      username: json['username'],
      bio: json['bio'],
      profileImagePath: json['profileImagePath'],
      joinedDate: json['joinedDate'] != null
          ? DateTime.parse(json['joinedDate'])
          : null,
    );
  }
  
  UserProfile copyWith({
    String? bio,
    String? profileImagePath,
  }) {
    return UserProfile(
      username: this.username,
      bio: bio ?? this.bio,
      profileImagePath: profileImagePath ?? this.profileImagePath,
      joinedDate: this.joinedDate,
    );
  }
}