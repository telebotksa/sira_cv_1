enum HeaderKind { centered, left, banner }

enum TitleKind { ruled, accent, muted, band }

class TemplateDef {
  const TemplateDef({
    required this.id,
    required this.header,
    required this.title,
    this.premium = false,
    this.scale = 1.0,
    this.twoColumnMeta = false,
  });

  final String id;
  final HeaderKind header;
  final TitleKind title;
  final bool premium;

  /// Font scale for the whole document.
  final double scale;

  /// Renders skills and languages as compact inline text instead of chips.
  final bool twoColumnMeta;

  String get nameKey => 'tpl_$id';
}

const templates = <TemplateDef>[
  TemplateDef(id: 'classic', header: HeaderKind.centered, title: TitleKind.ruled),
  TemplateDef(id: 'modern', header: HeaderKind.left, title: TitleKind.accent),
  TemplateDef(id: 'minimal', header: HeaderKind.left, title: TitleKind.muted),
  TemplateDef(
      id: 'banner',
      header: HeaderKind.banner,
      title: TitleKind.accent,
      premium: true),
  TemplateDef(
      id: 'compact',
      header: HeaderKind.left,
      title: TitleKind.band,
      premium: true,
      scale: 0.92,
      twoColumnMeta: true),
  TemplateDef(
      id: 'executive',
      header: HeaderKind.centered,
      title: TitleKind.band,
      premium: true),
];

TemplateDef templateById(String id) =>
    templates.firstWhere((t) => t.id == id, orElse: () => templates.first);

const accentPalette = <int>[
  0xFF0F766E, // teal
  0xFF1D4ED8, // blue
  0xFF6D28D9, // violet
  0xFFBE123C, // rose
  0xFFC2410C, // orange
  0xFF15803D, // green
  0xFF334155, // slate
  0xFF111827, // near black
];
