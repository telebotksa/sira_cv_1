import '../core/l10n.dart';
import '../models/resume.dart';

class _Field {
  const _Field({
    required this.keys,
    required this.tools,
    required this.en,
    required this.ar,
  });

  /// Lower-case fragments matched against the job title and skills.
  final List<String> keys;

  /// Tool and product names: the same in every language.
  final List<String> tools;

  /// Field-specific skills, written out in the languages we ship a catalog for.
  final List<String> en;
  final List<String> ar;
}

/// Offline helpers: summary drafts, action verbs, skill ideas and a
/// completeness score. No network needed. See AiService for the AI layer.
class Suggestions {
  static final _year = RegExp(r'(19|20)\d{2}');

  // -------------------------------------------------------------- experience

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
    final job = r.jobTitle.trim().isEmpty
        ? L10n.t(lang, 'fallbackJob')
        : r.jobTitle.trim();
    final top = r.skills.take(3).join(', ');

    var s = L10n.t(lang, years > 0 ? 'sumYears' : 'sumPlain');
    if (top.isNotEmpty) s = '$s ${L10n.t(lang, 'sumSkills')}';
    return L10n.fill(s, {'job': job, 'years': '$years', 'skills': top});
  }

  static List<String> actionVerbs(String lang) =>
      L10n.t(lang, 'verbs').split('|');

  // ------------------------------------------------------------------ skills

  static const _latinLangs = {
    'en', 'fr', 'es', 'es_MX', 'tr', 'id', 'de', 'it', 'nl', 'nb', 'pl', 'pt',
    'pt_BR', 'ro', 'vi',
  };

  /// The language the user is actually typing in, judged by script.
  /// Falls back to the resume language when nothing has been typed yet.
  static String detectLang(Resume r) {
    final text = '${r.jobTitle} ${r.skills.join(' ')} ${r.summary}';
    var ar = 0, hi = 0, zh = 0, latin = 0;
    for (final c in text.runes) {
      if ((c >= 0x0600 && c <= 0x06FF) || (c >= 0x0750 && c <= 0x077F)) {
        ar++;
      } else if (c >= 0x0900 && c <= 0x097F) {
        hi++;
      } else if (c >= 0x4E00 && c <= 0x9FFF) {
        zh++;
      } else if ((c >= 0x41 && c <= 0x5A) ||
          (c >= 0x61 && c <= 0x7A) ||
          (c >= 0xC0 && c <= 0x24F)) {
        latin++;
      }
    }
    final total = ar + hi + zh + latin;
    if (total == 0) return r.lang;
    if (ar >= hi && ar >= zh && ar >= latin) return 'ar';
    if (hi >= zh && hi >= latin) return 'hi';
    if (zh >= latin) return 'zh';
    return _latinLangs.contains(r.lang) ? r.lang : 'en';
  }

  /// Skill ideas for the user's field, in the language they are typing in.
  /// Tool names are language-neutral. Field-specific and soft skills are
  /// translated; languages without a translated field catalog get tools and
  /// soft skills (the AI service can add more).
  static List<String> skillIdeas(Resume r, {int limit = 40}) {
    final lang = detectLang(r);
    final text = '${r.jobTitle} ${r.skills.join(' ')}'.toLowerCase();

    final fieldSkills = <String>[];
    final tools = <String>[];
    for (final f in _fields) {
      if (f.keys.any((k) => _matches(text, k))) {
        if (lang == 'ar') {
          fieldSkills.addAll(f.ar);
        } else if (lang == 'en') {
          fieldSkills.addAll(f.en);
        }
        tools.addAll(f.tools);
      }
    }
    if (tools.isEmpty) tools.addAll(_generalTools);

    final soft = L10n.t(lang, 'softSkills').split('|');
    final have = r.skills.map((s) => s.trim().toLowerCase()).toSet();

    final out = <String>[];
    final seen = <String>{};
    for (final s in [...fieldSkills, ...tools, ...soft]) {
      final k = s.toLowerCase();
      if (have.contains(k) || !seen.add(k)) continue;
      out.add(s);
      if (out.length >= limit) break;
    }
    return out;
  }

  /// Short ASCII keys (ui, ux, hr, ads) must match whole words to avoid
  /// false hits such as "quality" or "three".
  static bool _matches(String text, String key) {
    final ascii = key.codeUnits.every((c) => c < 128);
    if (ascii && key.length <= 3) {
      return RegExp('(^|[^a-z])${RegExp.escape(key)}([^a-z]|\$)').hasMatch(text);
    }
    return text.contains(key);
  }

  // ------------------------------------------------------------ completeness

  /// Score in 0..1 and the l10n keys of missing parts.
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

  // ----------------------------------------------------------------- catalog

  static const _generalTools = [
    'Microsoft Excel',
    'Microsoft Word',
    'PowerPoint',
    'Google Workspace',
    'Email management',
  ];

  static const _fields = <_Field>[
    _Field(
      keys: ['develop', 'engineer', 'programmer', 'software', 'backend', 'frontend', 'fullstack', 'mobile', 'flutter', 'مطور', 'مبرمج', 'برمج', 'مهندس برمجيات'],
      tools: ['Git', 'SQL', 'REST APIs', 'Docker', 'Linux', 'JavaScript', 'TypeScript', 'Python', 'Java', 'Dart', 'Flutter', 'React', 'Node.js', 'CI/CD', 'AWS', 'Firebase'],
      en: ['Problem solving', 'Clean code', 'Code review', 'Agile', 'Unit testing', 'System design', 'Debugging'],
      ar: ['حل المشكلات', 'كتابة كود نظيف', 'مراجعة الكود', 'منهجية أجايل', 'اختبار الوحدات', 'تصميم الأنظمة', 'تصحيح الأخطاء'],
    ),
    _Field(
      keys: ['data', 'analyst', 'machine learning', 'محلل', 'بيانات'],
      tools: ['Excel', 'SQL', 'Python', 'R', 'Power BI', 'Tableau', 'Pandas', 'TensorFlow', 'Google Sheets', 'ETL'],
      en: ['Data analysis', 'Statistics', 'Data visualization', 'Reporting', 'Forecasting'],
      ar: ['تحليل البيانات', 'الإحصاء', 'تصور البيانات', 'إعداد التقارير', 'التنبؤ'],
    ),
    _Field(
      keys: ['design', 'ui', 'ux', 'graphic', 'مصمم', 'تصميم', 'جرافيك'],
      tools: ['Figma', 'Adobe Photoshop', 'Adobe Illustrator', 'Adobe XD', 'InDesign', 'Canva', 'After Effects', 'Sketch'],
      en: ['Prototyping', 'Typography', 'Branding', 'Wireframing', 'User research', 'Design systems', 'Color theory'],
      ar: ['النماذج الأولية', 'الطباعة والخطوط', 'الهوية البصرية', 'تصميم الواجهات', 'أبحاث المستخدم', 'أنظمة التصميم', 'نظرية الألوان'],
    ),
    _Field(
      keys: ['market', 'seo', 'social media', 'content', 'brand', 'ads', 'تسويق', 'سوشيال', 'محتوى'],
      tools: ['Google Analytics', 'Google Ads', 'Meta Ads', 'SEO', 'Mailchimp', 'HubSpot', 'Canva', 'Semrush'],
      en: ['Content strategy', 'Copywriting', 'Campaign management', 'Social media management', 'Market research', 'Email marketing', 'Brand strategy'],
      ar: ['استراتيجية المحتوى', 'كتابة الإعلانات', 'إدارة الحملات', 'إدارة السوشيال ميديا', 'أبحاث السوق', 'التسويق بالبريد', 'استراتيجية العلامة التجارية'],
    ),
    _Field(
      keys: ['sales', 'business development', 'account manager', 'مبيعات', 'مندوب', 'تطوير الأعمال'],
      tools: ['CRM', 'Salesforce', 'HubSpot', 'Excel'],
      en: ['Negotiation', 'Lead generation', 'Account management', 'Cold calling', 'Closing deals', 'Sales forecasting', 'Customer relationship management'],
      ar: ['التفاوض', 'توليد العملاء المحتملين', 'إدارة الحسابات', 'الاتصال البارد', 'إغلاق الصفقات', 'توقع المبيعات', 'إدارة علاقات العملاء'],
    ),
    _Field(
      keys: ['accountant', 'accounting', 'financ', 'audit', 'bookkeep', 'محاسب', 'مالي', 'مراجع'],
      tools: ['Excel', 'QuickBooks', 'SAP', 'Oracle', 'Power BI', 'Odoo'],
      en: ['Financial reporting', 'Budgeting', 'Auditing', 'Tax preparation', 'Accounts payable', 'Accounts receivable', 'Financial analysis', 'IFRS'],
      ar: ['التقارير المالية', 'إعداد الميزانيات', 'المراجعة', 'الإقرار الضريبي', 'الحسابات الدائنة', 'الحسابات المدينة', 'التحليل المالي', 'المعايير الدولية IFRS'],
    ),
    _Field(
      keys: ['hr', 'human resources', 'recruit', 'talent', 'موارد بشرية', 'توظيف'],
      tools: ['Excel', 'LinkedIn Recruiter', 'SAP SuccessFactors', 'Workday'],
      en: ['Recruitment', 'Onboarding', 'Employee relations', 'Performance management', 'Payroll', 'Labor law', 'Talent acquisition'],
      ar: ['التوظيف', 'تهيئة الموظفين', 'علاقات الموظفين', 'إدارة الأداء', 'الرواتب', 'نظام العمل', 'استقطاب الكفاءات'],
    ),
    _Field(
      keys: ['manager', 'project', 'operations', 'product', 'director', 'مدير', 'مشروع', 'عمليات', 'منتج'],
      tools: ['Jira', 'Trello', 'Asana', 'MS Project', 'Excel', 'Notion'],
      en: ['Leadership', 'Project planning', 'Stakeholder management', 'Risk management', 'Budgeting', 'KPIs', 'Agile', 'Team management'],
      ar: ['القيادة', 'تخطيط المشاريع', 'إدارة أصحاب المصلحة', 'إدارة المخاطر', 'إعداد الميزانيات', 'مؤشرات الأداء', 'منهجية أجايل', 'إدارة الفرق'],
    ),
    _Field(
      keys: ['teacher', 'tutor', 'instructor', 'lecturer', 'professor', 'معلم', 'مدرس', 'محاضر', 'مدرب'],
      tools: ['Google Classroom', 'Zoom', 'Microsoft Teams', 'PowerPoint'],
      en: ['Lesson planning', 'Classroom management', 'Assessment', 'Curriculum design', 'Differentiated instruction', 'Student engagement'],
      ar: ['تخطيط الدروس', 'إدارة الصف', 'التقييم', 'تصميم المناهج', 'التعليم المتمايز', 'تحفيز الطلاب'],
    ),
    _Field(
      keys: ['nurse', 'doctor', 'physician', 'pharmac', 'medical', 'dental', 'health', 'ممرض', 'طبيب', 'صيدل', 'طبي', 'أسنان', 'صحي'],
      tools: ['Epic', 'Cerner', 'Microsoft Office'],
      en: ['Patient care', 'Clinical assessment', 'Medical records', 'Infection control', 'CPR/BLS', 'Patient education', 'Medication administration'],
      ar: ['رعاية المرضى', 'التقييم السريري', 'السجلات الطبية', 'مكافحة العدوى', 'الإنعاش القلبي الرئوي', 'تثقيف المرضى', 'إعطاء الأدوية'],
    ),
    _Field(
      keys: ['civil', 'mechanical', 'electrical', 'architect', 'construction', 'site engineer', 'مهندس مدني', 'ميكانيك', 'كهرباء', 'معماري', 'إنشاءات', 'موقع'],
      tools: ['AutoCAD', 'Revit', 'SolidWorks', 'Primavera P6', 'MS Project', 'ETABS', 'SAP2000', 'MATLAB'],
      en: ['Technical drawing', 'Site supervision', 'Quantity surveying', 'Safety compliance', 'Project scheduling', 'Quality control', 'Cost estimation'],
      ar: ['الرسم الهندسي', 'الإشراف على المواقع', 'حصر الكميات', 'الالتزام بالسلامة', 'جدولة المشاريع', 'ضبط الجودة', 'تقدير التكاليف'],
    ),
    _Field(
      keys: ['customer', 'support', 'service', 'call center', 'reception', 'عميل', 'خدمة العملاء', 'دعم', 'استقبال'],
      tools: ['Zendesk', 'Freshdesk', 'CRM', 'Microsoft Office'],
      en: ['Customer support', 'Complaint handling', 'Active listening', 'Conflict resolution', 'Ticketing systems', 'Phone etiquette'],
      ar: ['دعم العملاء', 'معالجة الشكاوى', 'الاستماع الفعّال', 'حل النزاعات', 'أنظمة التذاكر', 'آداب المحادثة الهاتفية'],
    ),
    _Field(
      keys: ['admin', 'secretary', 'assistant', 'coordinator', 'clerk', 'إداري', 'سكرتير', 'مساعد', 'منسق', 'موظف'],
      tools: ['Microsoft Office', 'Excel', 'Word', 'Outlook', 'Google Workspace'],
      en: ['Scheduling', 'Filing and documentation', 'Correspondence', 'Office management', 'Data entry', 'Travel coordination', 'Minute taking'],
      ar: ['جدولة المواعيد', 'الأرشفة والتوثيق', 'المراسلات', 'إدارة المكتب', 'إدخال البيانات', 'تنسيق السفر', 'كتابة المحاضر'],
    ),
    _Field(
      keys: ['logistic', 'supply', 'warehouse', 'procurement', 'driver', 'لوجست', 'سلاسل', 'مستودع', 'مشتريات', 'سائق'],
      tools: ['SAP', 'Oracle', 'Excel', 'WMS', 'ERP'],
      en: ['Inventory control', 'Procurement', 'Supplier management', 'Shipping and receiving', 'Route planning', 'Demand planning'],
      ar: ['مراقبة المخزون', 'المشتريات', 'إدارة الموردين', 'الشحن والاستلام', 'تخطيط المسارات', 'تخطيط الطلب'],
    ),
    _Field(
      keys: ['it support', 'network', 'system admin', 'security', 'cyber', 'devops', 'cloud', 'تقنية المعلومات', 'شبكات', 'أمن', 'سيبراني', 'دعم فني'],
      tools: ['Linux', 'Windows Server', 'Cisco', 'AWS', 'Azure', 'Docker', 'Kubernetes', 'Active Directory', 'Wireshark', 'Python'],
      en: ['Troubleshooting', 'Network security', 'Incident response', 'System administration', 'Monitoring', 'Backup and recovery'],
      ar: ['استكشاف الأخطاء', 'أمن الشبكات', 'الاستجابة للحوادث', 'إدارة الأنظمة', 'المراقبة', 'النسخ الاحتياطي والاسترجاع'],
    ),
    _Field(
      keys: ['chef', 'cook', 'barista', 'waiter', 'hotel', 'hospitality', 'retail', 'cashier', 'طباخ', 'شيف', 'باريستا', 'فندق', 'كاشير', 'ضيافة'],
      tools: ['POS systems', 'Microsoft Office'],
      en: ['Food safety', 'Customer service', 'Cash handling', 'Inventory management', 'Upselling', 'Teamwork under pressure'],
      ar: ['سلامة الغذاء', 'خدمة العملاء', 'التعامل مع النقد', 'إدارة المخزون', 'البيع الإضافي', 'العمل تحت الضغط'],
    ),
    _Field(
      keys: ['writer', 'editor', 'journalist', 'translator', 'video', 'photograph', 'مترجم', 'كاتب', 'محرر', 'صحفي', 'مصور', 'مونتاج'],
      tools: ['Adobe Premiere Pro', 'Final Cut Pro', 'DaVinci Resolve', 'Adobe Lightroom', 'Adobe Photoshop', 'WordPress', 'Canva'],
      en: ['Writing and editing', 'Proofreading', 'Storytelling', 'Research', 'Video editing', 'Photography', 'Translation'],
      ar: ['الكتابة والتحرير', 'التدقيق اللغوي', 'السرد القصصي', 'البحث', 'المونتاج', 'التصوير', 'الترجمة'],
    ),
    _Field(
      keys: ['lawyer', 'legal', 'attorney', 'paralegal', 'محام', 'قانون', 'مستشار قانوني'],
      tools: ['Microsoft Office', 'Westlaw', 'LexisNexis'],
      en: ['Legal research', 'Contract drafting', 'Litigation', 'Compliance', 'Negotiation', 'Case management', 'Legal writing'],
      ar: ['البحث القانوني', 'صياغة العقود', 'التقاضي', 'الامتثال', 'التفاوض', 'إدارة القضايا', 'الصياغة القانونية'],
    ),
  ];
}
