class User {
  final int? id;
  final String username;
  final String email;
  final String? password; // Optional for Google sign-in
  final String? photoUrl;
  final String? authProvider; // 'email' or 'google'

  User({
    this.id,
    required this.username,
    required this.email,
    this.password,
    this.photoUrl,
    this.authProvider = 'email',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'password': password,
      'photoUrl': photoUrl,
      'authProvider': authProvider,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      email: map['email'],
      password: map['password'],
      photoUrl: map['photoUrl'],
      authProvider: map['authProvider'],
    );
  }
}