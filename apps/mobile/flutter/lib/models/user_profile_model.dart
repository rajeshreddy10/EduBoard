/// User Profile model with Name, Address, Organization, Phone, Location, Bio, and Profile Pic
library;

class UserProfileModel {
  final String id;
  final String email;
  final String name;
  final String address;
  final String organization;
  final String phone;
  final String location;
  final String bio;
  final String? avatarUrl;
  final String? _role;
  final List<String>? _subjects;

  const UserProfileModel({
    required this.id,
    required this.email,
    required this.name,
    this.address = '',
    this.organization = '',
    this.phone = '',
    this.location = '',
    this.bio = '',
    this.avatarUrl,
    String? role,
    List<String>? subjects,
  })  : _role = role,
        _subjects = subjects;

  // Backward-compatibility getters
  String get institution => organization;
  String get role => _role ?? 'teacher';
  String get department => '';
  String get teachingPhilosophy => '';
  List<String> get subjects => _subjects ?? const [];

  UserProfileModel copyWith({
    String? id,
    String? email,
    String? name,
    String? address,
    String? organization,
    String? phone,
    String? location,
    String? bio,
    String? avatarUrl,
    String? role,
    List<String>? subjects,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      address: address ?? this.address,
      organization: organization ?? this.organization,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? _role,
      subjects: subjects ?? _subjects,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'uid': id,
    'name': name,
    'full_name': name,
    'email': email,
    'address': address,
    'organization': organization,
    'institution': organization,
    'phone': phone,
    'phoneNumber': phone,
    'phone_number': phone,
    'location': location,
    'bio': bio,
    'avatar': avatarUrl,
    'avatarUrl': avatarUrl,
    'photoURL': avatarUrl,
    if (_role != null) 'role': _role,
  };

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    final email = (json['email'] ?? '').toString();
    final name = (json['name'] ?? json['full_name'] ?? (email.isNotEmpty ? email.split('@').first : 'EduBoard User')).toString();
    final address = (json['address'] ?? '').toString();
    final organization = (json['organization'] ?? json['institution'] ?? '').toString();
    final phone = (json['phone'] ?? json['phoneNumber'] ?? json['phone_number'] ?? '').toString();
    final location = (json['location'] ?? '').toString();
    final bio = (json['bio'] ?? '').toString();

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
    }

    return UserProfileModel(
      id: (json['id'] ?? json['uid'] ?? '').toString(),
      email: email,
      name: name,
      address: address,
      organization: organization,
      phone: phone,
      location: location,
      bio: bio,
      avatarUrl: avatarUrl,
      role: json['role']?.toString(),
      subjects: subjects,
    );
  }

  static UserProfileModel empty() {
    return const UserProfileModel(
      id: '',
      email: '',
      name: '',
      address: '',
      organization: '',
      phone: '',
      location: '',
      bio: '',
    );
  }
}
