import '../models/resume.dart';

/// Offline "smart" helpers: summary drafts, strong action verbs, skill ideas
/// and a completeness score. No network or API key required.
/// To plug in a real AI backend later, replace [draftSummary] with a remote call.
class Suggestions {
  static final _year = RegExp(r'(19|20)\d{2}');

  /// Rough total years of experience, from the earliest start year found.
  static int yearsOfExperience(Resume r, {DateTime? now}) {
    final nowYear = (now ?? DateTime.now()).year;
    int? earliest;
    for (final e in r.experiences) {
      final m = _year.firstMatch(e.start);
      if (m == null) continue;
      final y = int.parse(m.group(0)!);
      if (earliest == null || y < earliest) earliest = y;
    }
    if (earliest == null) return 0;
    final diff = nowYear - earliest;
    return diff < 0 ? 0 : diff;
  }

  static String draftSummary(Resume r, {DateTime? now}) {
    final lang = r.lang;
    final years = yearsOfExperience(r, now: now);
    final job = r.jobTitle.trim().isEmpty ? _fallbackJob[lang]! : r.jobTitle.trim();
    final top = r.skills.take(3).join(', ');
    final withYears = years > 0;
    final withSkills = top.isNotEmpty;

    final tpl = _templates[lang] ?? _templates['en']!;
    var s = withYears ? tpl['years']! : tpl['plain']!;
    if (withSkills) s = '$s ${tpl['skills']!}';
    return s
        .replaceAll('{job}', job)
        .replaceAll('{years}', '$years')
        .replaceAll('{skills}', top);
  }

  static List<String> actionVerbs(String lang) =>
      _verbs[lang] ?? _verbs['en']!;

  /// Skill ideas based on keywords found in the job title.
  static List<String> skillIdeas(Resume r) {
    final t = r.jobTitle.toLowerCase();
    final out = <String>[];
    _skillMap.forEach((keys, skills) {
      if (keys.any(t.contains)) out.addAll(skills);
    });
    if (out.isEmpty) out.addAll(_generalSkills);
    return out.where((s) => !r.skills.contains(s)).take(10).toList();
  }

  /// Returns score in 0..1 and the l10n keys of missing parts.
  static ({double score, List<String> missing}) completeness(Resume r) {
    final checks = <String, bool>{
      'fullName': r.fullName.trim().isNotEmpty,
      'jobTitle': r.jobTitle.trim().isNotEmpty,
      'email': r.email.trim().isNotEmpty,
      'phone': r.phone.trim().isNotEmpty,
      'summary': r.summary.trim().length >= 40,
      'experience': r.experiences.isNotEmpty,
      'education': r.education.isNotEmpty,
      'skills': r.skills.length >= 3,
    };
    final done = checks.values.where((v) => v).length;
    return (
      score: done / checks.length,
      missing: checks.entries.where((e) => !e.value).map((e) => e.key).toList(),
    );
  }

  static const _fallbackJob = {
    'ar': 'محترف',
    'en': 'professional',
    'fr': 'professionnel',
    'es': 'profesional',
    'tr': 'profesyonel',
  };

  static const _templates = {
    'ar': {
      'years': '{job} بخبرة تزيد عن {years} سنوات، أحرص على تحقيق نتائج ملموسة والعمل بروح الفريق.',
      'plain': '{job} طموح وسريع التعلّم، أسعى لتقديم قيمة حقيقية والنمو المهني المستمر.',
      'skills': 'أتميّز في: {skills}.',
    },
    'en': {
      'years': 'Results-driven {job} with {years}+ years of experience, focused on delivering measurable impact and collaborating across teams.',
      'plain': 'Motivated {job} and fast learner, eager to deliver real value and keep growing professionally.',
      'skills': 'Strengths include {skills}.',
    },
    'fr': {
      'years': '{job} orienté résultats avec plus de {years} ans d\'expérience, engagé à produire un impact mesurable et à collaborer efficacement.',
      'plain': '{job} motivé et apprenant rapide, désireux d\'apporter une vraie valeur et de progresser.',
      'skills': 'Points forts : {skills}.',
    },
    'es': {
      'years': '{job} orientado a resultados con más de {years} años de experiencia, enfocado en generar impacto medible y trabajar en equipo.',
      'plain': '{job} motivado y con gran capacidad de aprendizaje, deseoso de aportar valor y seguir creciendo.',
      'skills': 'Fortalezas: {skills}.',
    },
    'tr': {
      'years': '{years}+ yıllık deneyime sahip, sonuç odaklı {job}; ölçülebilir etki yaratmaya ve ekip çalışmasına odaklıdır.',
      'plain': 'Motive ve hızlı öğrenen {job}; gerçek değer katmak ve kendini geliştirmek istiyor.',
      'skills': 'Güçlü yönler: {skills}.',
    },
  };

  static const _verbs = {
    'ar': ['قدت', 'طورت', 'أطلقت', 'حسّنت', 'خفّضت', 'أدرت', 'صممت', 'حققت'],
    'en': ['Led', 'Built', 'Launched', 'Improved', 'Reduced', 'Managed', 'Designed', 'Achieved'],
    'fr': ['Dirigé', 'Développé', 'Lancé', 'Amélioré', 'Réduit', 'Géré', 'Conçu', 'Atteint'],
    'es': ['Lideré', 'Desarrollé', 'Lancé', 'Mejoré', 'Reduje', 'Gestioné', 'Diseñé', 'Logré'],
    'tr': ['Yönettim', 'Geliştirdim', 'Başlattım', 'İyileştirdim', 'Azalttım', 'Tasarladım', 'Sağladım', 'Ulaştım'],
  };

  static const _generalSkills = [
    'Communication',
    'Teamwork',
    'Problem solving',
    'Time management',
    'Microsoft Office',
    'Critical thinking',
  ];

  static const Map<List<String>, List<String>> _skillMap = {
    ['develop', 'engineer', 'programmer', 'مطور', 'مبرمج', 'مهندس']: [
      'Git', 'REST APIs', 'SQL', 'Testing', 'Agile', 'Clean code',
    ],
    ['design', 'ui', 'ux', 'مصمم']: [
      'Figma', 'Adobe Photoshop', 'Prototyping', 'Typography', 'Design systems',
    ],
    ['market', 'seo', 'social', 'تسويق']: [
      'SEO', 'Google Analytics', 'Content strategy', 'Social media', 'Copywriting',
    ],
    ['account', 'financ', 'محاسب']: [
      'Excel', 'Financial reporting', 'Budgeting', 'ERP', 'Auditing',
    ],
    ['sales', 'مبيعات']: [
      'CRM', 'Negotiation', 'Lead generation', 'Account management',
    ],
    ['manager', 'مدير']: [
      'Leadership', 'Planning', 'Stakeholder management', 'KPIs', 'Budgeting',
    ],
    ['teacher', 'مدرس', 'معلم']: [
      'Lesson planning', 'Classroom management', 'Assessment', 'Curriculum design',
    ],
  };
}
