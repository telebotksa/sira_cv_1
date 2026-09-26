import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../services/pdf_builder.dart';
import '../state/app_state.dart';
import 'tr.dart';

/// Live PDF preview with Share, Save and Print.
class PreviewPage extends StatelessWidget {
  const PreviewPage({super.key, required this.resumeId});

  final String resumeId;

  String _fileName(String raw) {
    final safe = raw.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
    return '${safe.isEmpty ? 'resume' : safe}.pdf';
  }

  @override
  Widget build(BuildContext context) {
    final r = context.read<AppState>().byId(resumeId);
    if (r == null) return const Scaffold(body: SizedBox.shrink());
    final fileName = _fileName(r.displayName);

    Future<Uint8List> render(PdfPageFormat f) => PdfBuilder.build(r, f);

    Future<void> share(BuildContext ctx, LayoutCallback build, PdfPageFormat f) async {
      final bytes = await build(f);
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    }

    Future<void> save(BuildContext ctx, LayoutCallback build, PdfPageFormat f) async {
      final messenger = ScaffoldMessenger.of(ctx);
      final okText = ctx.trNow('saved');
      final failText = ctx.trNow('saveFailed');
      final dialogTitle = ctx.trNow('saveFile');
      try {
        final bytes = await build(f);
        final path = await FilePicker.platform.saveFile(
          dialogTitle: dialogTitle,
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: const ['pdf'],
          bytes: bytes,
        );
        // null means the user closed the dialog: nothing to report.
        if (path != null) messenger.showSnackBar(SnackBar(content: Text(okText)));
      } catch (_) {
        messenger.showSnackBar(SnackBar(content: Text(failText)));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('preview'))),
      body: PdfPreview(
        build: render,
        pdfFileName: fileName,
        initialPageFormat: PdfPageFormat.a4,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: false,
        actions: [
          PdfPreviewAction(
            icon: const Icon(Icons.save_alt),
            onPressed: (ctx, build, f) => save(ctx, build, f),
          ),
          PdfPreviewAction(
            icon: const Icon(Icons.share),
            onPressed: (ctx, build, f) => share(ctx, build, f),
          ),
        ],
      ),
    );
  }
}
