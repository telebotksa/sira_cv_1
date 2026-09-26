import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';

import '../services/pdf_builder.dart';
import '../state/app_state.dart';
import 'tr.dart';

/// Live PDF preview with built-in print / share / save actions.
class PreviewPage extends StatelessWidget {
  const PreviewPage({super.key, required this.resumeId});

  final String resumeId;

  @override
  Widget build(BuildContext context) {
    final r = context.read<AppState>().byId(resumeId);
    if (r == null) return const Scaffold(body: SizedBox.shrink());

    final safe = r.displayName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
    final fileName = safe.isEmpty ? 'resume' : safe;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('preview'))),
      body: PdfPreview(
        build: (format) => PdfBuilder.build(r, format),
        pdfFileName: '$fileName.pdf',
        initialPageFormat: PdfPageFormat.a4,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}
