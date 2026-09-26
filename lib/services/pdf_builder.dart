import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/dates.dart';
import '../core/l10n.dart';
import '../core/templates.dart';
import '../models/resume.dart';

class _Fonts {
  const _Fonts(this.regular, this.bold, [this.fallback = const []]);
  final pw.Font regular;
  final pw.Font bold;
  final List<pw.Font> fallback;
}

/// Renders a [Resume] to PDF bytes. One implementation drives every template,
/// so the on-screen preview and the exported file are always identical.
class PdfBuilder {
  static final Map<String, _Fonts> _cache = {};

  /// Fonts come from Google Fonts through the `printing` package and are
  /// fetched once per script (needs internet on first use):
  ///   Arabic -> Cairo, Hindi -> Noto Sans Devanagari, Chinese -> Noto Sans SC,
  ///   everything else (Latin, Vietnamese, Polish, Romanian...) -> Noto Sans.
  /// If the download fails we fall back to Helvetica (basic Latin only).
  /// To work fully offline, bundle font files as assets and load them with
  /// pw.Font.ttf(await rootBundle.load(...)).
  static Future<_Fonts> _loadFonts(String lang) async {
    final key = lang == 'ar' || lang == 'hi' || lang == 'zh' ? lang : 'latin';
    final hit = _cache[key];
    if (hit != null) return hit;
    try {
      _Fonts f;
      switch (key) {
        case 'ar':
          f = _Fonts(await PdfGoogleFonts.cairoRegular(),
              await PdfGoogleFonts.cairoBold());
          break;
        case 'hi':
          f = _Fonts(
            await PdfGoogleFonts.notoSansDevanagariRegular(),
            await PdfGoogleFonts.notoSansDevanagariBold(),
            [await PdfGoogleFonts.notoSansRegular()],
          );
          break;
        case 'zh':
          // The CJK font is large; regular is used for bold as well.
          final regular = await PdfGoogleFonts.notoSansSCRegular();
          f = _Fonts(regular, regular);
          break;
        default:
          f = _Fonts(await PdfGoogleFonts.notoSansRegular(),
              await PdfGoogleFonts.notoSansBold());
      }
      return _cache[key] = f;
    } catch (_) {
      return _Fonts(pw.Font.helvetica(), pw.Font.helveticaBold());
    }
  }

  static Future<Uint8List> build(Resume r, PdfPageFormat format) async {
    final fonts = await _loadFonts(r.lang);
    final doc = pw.Document(
      title: r.displayName,
      author: r.fullName,
      theme: pw.ThemeData.withFont(
        base: fonts.regular,
        bold: fonts.bold,
        fontFallback: fonts.fallback,
      ),
    );
    final b = _Builder(r);
    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(34),
        textDirection: b.rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        build: (context) => b.widgets(),
      ),
    );
    return doc.save();
  }
}

class _Builder {
  _Builder(this.r)
      : tpl = templateById(r.templateId),
        rtl = L10n.isRtl(r.lang),
        accent = PdfColor.fromInt(r.accent);

  final Resume r;
  final TemplateDef tpl;
  final bool rtl;
  final PdfColor accent;

  double get s => tpl.scale;

  String tr(String key) => L10n.t(r.lang, key);

  pw.TextStyle ts(double size, {bool bold = false, PdfColor? color}) =>
      pw.TextStyle(
        fontSize: size * s,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: color ?? PdfColors.grey900,
        lineSpacing: 1.5,
      );

  /// Flat list of widgets: MultiPage can only split between top-level items,
  /// so every heading and every entry is its own item.
  List<pw.Widget> widgets() {
    final out = <pw.Widget>[_header()];

    if (r.summary.trim().isNotEmpty) {
      out.addAll(_section(tr('summary'), [
        pw.Text(r.summary.trim(), style: ts(10.5)),
      ]));
    }

    if (r.experiences.isNotEmpty) {
      out.addAll(_section(tr('experience'), [
        for (final e in r.experiences)
          _entry(
            title: e.title,
            sub: _join([e.company, e.location]),
            dates: _range(e.start, e.end, e.current),
            desc: e.description,
          ),
      ]));
    }

    if (r.education.isNotEmpty) {
      out.addAll(_section(tr('education'), [
        for (final e in r.education)
          _entry(
            title: e.degree,
            sub: _join([e.school, e.location]),
            dates: _range(e.start, e.end, false),
            desc: e.description,
          ),
      ]));
    }

    if (r.projects.isNotEmpty) {
      out.addAll(_section(tr('projects'), [
        for (final p in r.projects)
          _entry(title: p.name, sub: p.link, dates: '', desc: p.description),
      ]));
    }

    if (r.skills.isNotEmpty) {
      out.addAll(_section(tr('skills'), [_skills()]));
    }

    if (r.languages.isNotEmpty) {
      out.addAll(_section(tr('languages'), [_languages()]));
    }

    return out;
  }

  // ---------- header ----------

  pw.Widget _header() {
    final banner = tpl.header == HeaderKind.banner;
    final centered = tpl.header == HeaderKind.centered;

    final nameColor = banner
        ? PdfColors.white
        : (tpl.title == TitleKind.accent ? accent : PdfColors.grey900);
    final subColor = banner ? PdfColors.white : PdfColors.grey700;

    final contacts = [r.email, r.phone, r.city, r.website]
        .where((e) => e.trim().isNotEmpty)
        .toList();

    final textCol = pw.Column(
      crossAxisAlignment:
          centered ? pw.CrossAxisAlignment.center : pw.CrossAxisAlignment.start,
      children: [
        pw.Text(r.fullName.trim().isEmpty ? ' ' : r.fullName.trim(),
            style: ts(26, bold: true, color: nameColor)),
        if (r.jobTitle.trim().isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.Text(r.jobTitle.trim(), style: ts(13, color: subColor)),
        ],
        if (contacts.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text(contacts.join('   •   '), style: ts(9.5, color: subColor)),
        ],
      ],
    );

    final photo = _photo();
    pw.Widget inner = photo == null
        ? textCol
        : pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(child: textCol),
              pw.SizedBox(width: 16),
              photo,
            ],
          );

    if (banner) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(18),
        decoration: pw.BoxDecoration(
          color: accent,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: inner,
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        inner,
        pw.SizedBox(height: 8),
        if (tpl.title == TitleKind.accent)
          pw.Container(height: 3, width: double.infinity, color: accent)
        else if (tpl.header == HeaderKind.centered)
          pw.Divider(thickness: 1, color: PdfColors.grey700),
      ],
    );
  }

  pw.Widget? _photo() {
    final b64 = r.photoB64;
    if (b64 == null || b64.isEmpty) return null;
    try {
      final bytes = base64Decode(b64);
      return pw.ClipOval(
        child: pw.Container(
          width: 72,
          height: 72,
          child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.cover),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // ---------- sections ----------

  List<pw.Widget> _section(String title, List<pw.Widget> body) {
    pw.Widget head;
    switch (tpl.title) {
      case TitleKind.ruled:
        head = pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title.toUpperCase(), style: ts(11.5, bold: true)),
            pw.SizedBox(height: 2),
            pw.Divider(thickness: 0.6, color: PdfColors.grey500),
          ],
        );
        break;
      case TitleKind.accent:
        head = pw.Row(children: [
          pw.Container(width: 4, height: 13 * s, color: accent),
          pw.SizedBox(width: 6),
          pw.Text(title, style: ts(12.5, bold: true, color: accent)),
        ]);
        break;
      case TitleKind.muted:
        head = pw.Text(title.toUpperCase(),
            style: ts(10, bold: true, color: PdfColors.grey600));
        break;
      case TitleKind.band:
        head = pw.Container(
          width: double.infinity,
          color: accent,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: pw.Text(title, style: ts(11, bold: true, color: PdfColors.white)),
        );
        break;
    }

    return [
      pw.Padding(padding: pw.EdgeInsets.only(top: 14 * s, bottom: 6), child: head),
      ...body,
    ];
  }

  pw.Widget _entry({
    required String title,
    required String sub,
    required String dates,
    required String desc,
  }) {
    final lines = desc
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(title.trim().isEmpty ? ' ' : title.trim(),
                    style: ts(11.5, bold: true)),
              ),
              if (dates.isNotEmpty)
                pw.Text(dates, style: ts(9.5, color: PdfColors.grey700)),
            ],
          ),
          if (sub.trim().isNotEmpty)
            pw.Text(sub.trim(), style: ts(10.5, color: accent)),
          if (lines.isNotEmpty) pw.SizedBox(height: 3),
          for (final l in lines)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 1.5),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('•  ', style: ts(10.5, color: accent)),
                  pw.Expanded(child: pw.Text(l, style: ts(10.5))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  pw.Widget _skills() {
    if (tpl.twoColumnMeta) {
      return pw.Text(r.skills.join('  •  '), style: ts(10.5));
    }
    return pw.Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final k in r.skills)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: accent, width: 0.7),
              borderRadius: pw.BorderRadius.circular(9),
            ),
            child: pw.Text(k, style: ts(10)),
          ),
      ],
    );
  }

  pw.Widget _languages() {
    final items = [
      for (final l in r.languages)
        if (l.name.trim().isNotEmpty)
          '${l.name.trim()} (${tr('lv${l.level.clamp(0, 4)}')})',
    ];
    if (tpl.twoColumnMeta) {
      return pw.Text(items.join('  •  '), style: ts(10.5));
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [for (final i in items) pw.Text(i, style: ts(10.5))],
    );
  }

  // ---------- helpers ----------

  String _join(List<String> parts) =>
      parts.where((p) => p.trim().isNotEmpty).map((p) => p.trim()).join(' · ');

  String _range(String start, String end, bool current) {
    final e = current ? tr('present') : Dates.format(end, r.lang);
    final st = Dates.format(start, r.lang);
    if (st.isEmpty && e.isEmpty) return '';
    if (st.isEmpty) return e;
    if (e.isEmpty) return st;
    return '$st – $e';
  }
}
