/// User Profile model with academic and pedagogical metadata
library;

class UserProfileModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String institution;
  final String department;
  final String bio;
  final String teachingPhilosophy;
  final String? avatarUrl;
  final List<String> subjects;

  const UserProfileModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.institution,
    required this.department,
    required this.bio,
    required this.teachingPhilosophy,
    this.avatarUrl,
    required this.subjects,
  });

  UserProfileModel copyWith({
    String? id,
    String? name,
    String? email,
    String? role,
    String? institution,
    String? department,
    String? bio,
    String? teachingPhilosophy,
    String? avatarUrl,
    List<String>? subjects,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      institution: institution ?? this.institution,
      department: department ?? this.department,
      bio: bio ?? this.bio,
      teachingPhilosophy: teachingPhilosophy ?? this.teachingPhilosophy,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      subjects: subjects ?? this.subjects,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'uid': id,
    'name': name,
    'full_name': name,
    'email': email,
    'role': role,
    'institution': institution,
    'department': department,
    'bio': bio,
    'teachingPhilosophy': teachingPhilosophy,
    'avatar': avatarUrl,
    'avatarUrl': avatarUrl,
    'subjects': subjects,
  };

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final email = (json['email'] ?? '').toString();
    final name = (json['name'] ?? json['full_name'] ?? (email.isNotEmpty ? email.split('@').first : 'EduBoard User')).toString();

    // Avatar may arrive as a string URL/Base64, an object {url:...} from some
    // backend conventions, or something unexpected — normalize to a resolvable
    // string or null so EduImage never receives garbage.
    dynamic rawAvatar = json['avatar'] ?? json['avatarUrl'] ?? json['photoURL'];
    String? avatarUrl;
    if (rawAvatar is Map) {
      final dynamic urlVal = rawAvatar['url'] ?? rawAvatar['avatarUrl'] ?? rawAvatar['photoUrl'];
      if (urlVal is String && urlVal.trim().isNotEmpty) avatarUrl = urlVal;
    } else if (rawAvatar is String && rawAvatar.trim().isNotEmpty) {
      avatarUrl = rawAvatar;
    }

    final rawSubjects = json['subjects'];
    List<String>? subjects;
    if (rawSubjects is List) {
      subjects = rawSubjects.whereType<Object>().map((e) => e.toString()).toList();
    } else if (rawSubjects is String && rawSubjects.trim().isNotEmpty) {
      // Tolerate comma-separated single-string conventions.
      subjects = rawSubjects.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }

    return UserProfileModel(
      id: (json['id'] ?? json['uid'] ?? '').toString(),
      name: name,
      email: email,
      role: (json['role'] ?? 'teacher').toString(),
      institution: (json['institution'] ?? 'EduBoard Academic Institute').toString(),
      department: (json['department'] ?? 'Department of Sciences').toString(),
      bio: (json['bio'] ?? '').toString(),
      teachingPhilosophy: (json['teachingPhilosophy'] ?? '').toString(),
      avatarUrl: avatarUrl,
      subjects: subjects ?? ['Mathematics', 'Science'],
    );
  }

  static UserProfileModel empty() {
    return const UserProfileModel(
      id: '',
      name: 'EduBoard Instructor',
      email: '',
      role: 'teacher',
      institution: 'EduBoard Academic Institute',
      department: 'Department of Sciences',
      bio: '',
      teachingPhilosophy: '',
      subjects: ['General STEM'],
    );
  }
}
