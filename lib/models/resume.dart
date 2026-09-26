int _seq = 0;

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${(_seq++).toRadixString(36)}';

String _s(Map<String, dynamic> m, String k) => (m[k] as String?) ?? '';

class Experience {
  Experience({
    String? id,
    this.title = '',
    this.company = '',
    this.location = '',
    this.start = '',
    this.end = '',
    this.current = false,
    this.description = '',
  }) : id = id ?? newId();

  final String id;
  String title, company, location, start, end, description;
  bool current;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'company': company,
        'location': location,
        'start': start,
        'end': end,
        'current': current,
        'description': description,
      };

  factory Experience.fromJson(Map<String, dynamic> j) => Experience(
        id: _s(j, 'id'),
        title: _s(j, 'title'),
        company: _s(j, 'company'),
        location: _s(j, 'location'),
        start: _s(j, 'start'),
        end: _s(j, 'end'),
        current: (j['current'] as bool?) ?? false,
        description: _s(j, 'description'),
      );
}

class Education {
  Education({
    String? id,
    this.degree = '',
    this.school = '',
    this.location = '',
    this.start = '',
    this.end = '',
    this.description = '',
  }) : id = id ?? newId();

  final String id;
  String degree, school, location, start, end, description;

  Map<String, dynamic> toJson() => {
        'id': id,
        'degree': degree,
        'school': school,
        'location': location,
        'start': start,
        'end': end,
        'description': description,
      };

  factory Education.fromJson(Map<String, dynamic> j) => Education(
        id: _s(j, 'id'),
        degree: _s(j, 'degree'),
        school: _s(j, 'school'),
        location: _s(j, 'location'),
        start: _s(j, 'start'),
        end: _s(j, 'end'),
        description: _s(j, 'description'),
      );
}

class Project {
  Project({String? id, this.name = '', this.link = '', this.description = ''})
      : id = id ?? newId();

  final String id;
  String name, link, description;

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'link': link, 'description': description};

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: _s(j, 'id'),
        name: _s(j, 'name'),
        link: _s(j, 'link'),
        description: _s(j, 'description'),
      );
}

class LangSkill {
  LangSkill({String? id, this.name = '', this.level = 2}) : id = id ?? newId();

  final String id;
  String name;

  /// 0 basic .. 4 native
  int level;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'level': level};

  factory LangSkill.fromJson(Map<String, dynamic> j) => LangSkill(
        id: _s(j, 'id'),
        name: _s(j, 'name'),
        level: (j['level'] as int?) ?? 2,
      );
}

class Resume {
  Resume({
    String? id,
    this.fileName = '',
    this.templateId = 'classic',
    this.lang = 'en',
    this.accent = 0xFF0F766E,
    this.fullName = '',
    this.jobTitle = '',
    this.email = '',
    this.phone = '',
    this.city = '',
    this.website = '',
    this.summary = '',
    this.photoB64,
    List<Experience>? experiences,
    List<Education>? education,
    List<String>? skills,
    List<LangSkill>? languages,
    List<Project>? projects,
    DateTime? updatedAt,
  })  : id = id ?? newId(),
        experiences = experiences ?? [],
        education = education ?? [],
        skills = skills ?? [],
        languages = languages ?? [],
        projects = projects ?? [],
        updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String fileName, templateId, lang;
  int accent;
  String fullName, jobTitle, email, phone, city, website, summary;
  String? photoB64;
  List<Experience> experiences;
  List<Education> education;
  List<String> skills;
  List<LangSkill> languages;
  List<Project> projects;
  DateTime updatedAt;

  String get displayName {
    if (fileName.trim().isNotEmpty) return fileName.trim();
    if (fullName.trim().isNotEmpty) return fullName.trim();
    return '';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'templateId': templateId,
        'lang': lang,
        'accent': accent,
        'fullName': fullName,
        'jobTitle': jobTitle,
        'email': email,
        'phone': phone,
        'city': city,
        'website': website,
        'summary': summary,
        'photoB64': photoB64,
        'experiences': experiences.map((e) => e.toJson()).toList(),
        'education': education.map((e) => e.toJson()).toList(),
        'skills': skills,
        'languages': languages.map((e) => e.toJson()).toList(),
        'projects': projects.map((e) => e.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Resume.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((j[k] as List?) ?? [])
            .map((e) => f(Map<String, dynamic>.from(e as Map)))
            .toList();

    return Resume(
      id: _s(j, 'id'),
      fileName: _s(j, 'fileName'),
      templateId: _s(j, 'templateId').isEmpty ? 'classic' : _s(j, 'templateId'),
      lang: _s(j, 'lang').isEmpty ? 'en' : _s(j, 'lang'),
      accent: (j['accent'] as int?) ?? 0xFF0F766E,
      fullName: _s(j, 'fullName'),
      jobTitle: _s(j, 'jobTitle'),
      email: _s(j, 'email'),
      phone: _s(j, 'phone'),
      city: _s(j, 'city'),
      website: _s(j, 'website'),
      summary: _s(j, 'summary'),
      photoB64: j['photoB64'] as String?,
      experiences: list('experiences', Experience.fromJson),
      education: list('education', Education.fromJson),
      skills: ((j['skills'] as List?) ?? []).map((e) => '$e').toList(),
      languages: list('languages', LangSkill.fromJson),
      projects: list('projects', Project.fromJson),
      updatedAt: DateTime.tryParse(_s(j, 'updatedAt')) ?? DateTime.now(),
    );
  }
}
