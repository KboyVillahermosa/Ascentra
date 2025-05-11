class Trail {
  final String id;
  final String name;
  final String location;
  final String description;
  final String image;
  final String difficulty;
  final double elevation;
  final String bestTime;
  final String necessities;
  final double? latitude;
  final double? longitude;
  final double? rating;
  final List<Review>? reviews;

  Trail({
    required this.id,
    required this.name,
    required this.location,
    required this.description,
    required this.image,
    required this.difficulty,
    required this.elevation,
    required this.bestTime,
    required this.necessities,
    this.latitude,
    this.longitude,
    this.rating,
    this.reviews,
  });

  factory Trail.fromJson(Map<String, dynamic> json) {
    List<Review>? reviewsList;
    if (json['reviews'] != null) {
      reviewsList = List<Review>.from(
          json['reviews'].map((review) => Review.fromJson(review)));
    }

    return Trail(
      id: json['id'],
      name: json['name'],
      location: json['location'],
      description: json['description'],
      image: json['image'],
      difficulty: json['difficulty'],
      elevation: json['elevation']?.toDouble(),
      bestTime: json['bestTime'],
      necessities: json['necessities'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      rating: json['rating']?.toDouble(),
      reviews: reviewsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'description': description,
      'image': image,
      'difficulty': difficulty,
      'elevation': elevation,
      'bestTime': bestTime,
      'necessities': necessities,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'reviews': reviews?.map((review) => review.toJson()).toList(),
    };
  }

  Trail copyWith({
    String? id,
    String? name,
    String? description,
    String? image,
    String? location,
    double? latitude,
    double? longitude,
    double? elevation,  // Changed from String? to double??
    String? difficulty,
    String? bestTime,
    String? necessities,
    double? rating,
    List<Review>? reviews,
  }) {
    return Trail(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      image: image ?? this.image,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      elevation: elevation ?? this.elevation,
      difficulty: difficulty ?? this.difficulty,
      bestTime: bestTime ?? this.bestTime,
      necessities: necessities ?? this.necessities,
      rating: rating ?? this.rating,
      reviews: reviews ?? this.reviews,
    );
  }
}

class Review {
  final String id;
  final String userId;
  final String userName;
  final double rating;
  final String comment;
  final DateTime date;

  Review({
    required this.id,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.date,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'],
      userId: json['userId'],
      userName: json['userName'],
      rating: json['rating']?.toDouble() ?? 0.0,
      comment: json['comment'] ?? '',
      date: DateTime.parse(json['date']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'date': date.toIso8601String(),
    };
  }
}