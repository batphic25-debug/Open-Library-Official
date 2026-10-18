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
}
