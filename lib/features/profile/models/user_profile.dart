class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.email,
    this.avatarPath,
  });

  final String id;
  final String displayName;
  final String email;
  final String? avatarPath;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    displayName: json['displayName'] as String,
    email: json['email'] as String,
    avatarPath: json['avatarUrl'] as String?,
  );
}
