class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.email,
    this.fullName = '',
    this.country = '',
    this.phoneNumber = '',
    this.signupType = '',
    this.profileImage = '',
    this.role = '',
  });

  final String id;
  final String username;
  final String email;
  final String fullName;
  final String country;
  final String phoneNumber;
  final String signupType;
  final String profileImage;
  final String role;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id:
          json['user_id']?.toString() ??
          json['id']?.toString() ??
          json['_id']?.toString() ??
          '',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName:
          json['full_name']?.toString() ?? json['fullName']?.toString() ?? '',
      country:
          json['country']?.toString() ?? json['location']?.toString() ?? '',
      phoneNumber:
          json['phone_number']?.toString() ??
          json['phoneNumber']?.toString() ??
          json['phone']?.toString() ??
          '',
      signupType:
          json['signup_type']?.toString() ??
          json['signupType']?.toString() ??
          '',
      profileImage:
          json['profile_image']?.toString() ??
          json['profileImage']?.toString() ??
          '',
      role: json['role']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': id,
      'username': username,
      'email': email,
      'full_name': fullName,
      'country': country,
      'phone_number': phoneNumber,
      'signup_type': signupType,
      'profile_image': profileImage,
      'role': role,
    };
  }
}
