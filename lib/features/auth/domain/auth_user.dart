class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    this.profileImage = '',
  });

  final String id;
  final String username;
  final String email;
  final String profileImage;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      profileImage: json['profileImage']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'profileImage': profileImage,
    };
  }
}
