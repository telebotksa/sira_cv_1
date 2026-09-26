import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';
import '../models/resume.dart';
import '../services/ai_service.dart';
import '../state/app_state.dart';
import 'ai_helpers.dart';
import 'tr.dart';

/// AI tools that work on the whole resume: review, job match, cover letter,
/// tailored summary and translation.
class AiTab extends StatefulWidget {
  const AiTab({
    super.key,
    required this.r,
    required this.onChanged,
    required this.onOpenResume,
  });

  final Resume r;

  /// Called after the resume was changed by an AI action (rebuild + save).
  final VoidCallback onChanged;

  /// Opens another resume (used after a translation creates a copy).
  final ValueChanged<String> onOpenResume;

  @override
  State<AiTab> createState() => _AiTabState();
}

class _AiTabState extends State<AiTab> {
  final _job = TextEditingController();
  late String _target;

  @override
  void initState() {
    super.initState();
    // Default: the first language that differs from the resume language.
    _target = L10n.supported.firstWhere(
      (c) => c != widget.r.lang,
      orElse: () => 'en',
    );
  }

  @override
  void dispose() {
    _job.dispose();
    super.dispose();
  }

  Future<void> _review() async {
    final title = context.trNow('aiReview');
    final res = await runAi(context, AiTask.review, widget.r);
    if (res == null || !mounted) return;
    await showAiSheet(context, title: title, result: res);
  }

  bool _needJob() {
    if (_job.text.trim().isNotEmpty) return true;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.trNow('aiJobField'))));
    return false;
  }

  Future<void> _analyze() async {
    if (!_needJob()) return;
    final title = context.trNow('aiJobMatch');
    final res = await runAi(context, AiTask.jobMatch, widget.r, job: _job.text);
    if (res == null || !mounted) return;
    await showAiSheet(context, title: title, result: res);
  }

  Future<void> _cover() async {
    final title = context.trNow('aiCoverLetter');
    final res =
        await runAi(context, AiTask.coverLetter, widget.r, job: _job.text);
    if (res == null || !mounted) return;
    await showAiSheet(context, title: title, result: res);
  }

  Future<void> _tailorSummary() async {
    if (!_needJob()) return;
    final title = context.trNow('summary');
    final res = await runAi(context, AiTask.summary, widget.r,
        input: widget.r.summary, job: _job.text);
    if (res == null || !mounted) return;
    await showAiSheet(
      context,
      title: title,
      result: res,
      onApply: () {
        widget.r.summary = res.text;
        widget.onChanged();
      },
    );
  }

  Future<void> _translate() async {
    final done = context.trNow('aiTranslated');
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final copy = await runAiCall<Resume>(
      context,
      (s) => s.translateResume(widget.r, _target),
    );
    if (copy == null) return;
    app.save(copy);
    messenger.showSnackBar(SnackBar(content: Text(done)));
    widget.onOpenResume(copy.id);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);

    Widget tile(IconData icon, String title, String hint, VoidCallback onTap) {
      return Card(
        child: ListTile(
          leading: Icon(icon, color: theme.colorScheme.primary),
          title: Text(title),
          subtitle: Text(hint),
          onTap: onTap,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: theme.colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    app.ai.isRemote
                        ? (app.premium
                            ? context.tr('premiumActive')
                            : '${context.tr('aiFreeLeft')}: ${app.aiLeft}')
                        : context.tr('aiOfflineNote'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        tile(Icons.fact_check_outlined, context.tr('aiReview'),
            context.tr('aiReviewHint'), _review),
        const SizedBox(height: 16),
        Text(context.tr('aiJobMatch'), style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(context.tr('aiJobHint'), style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        TextField(
          controller: _job,
          minLines: 4,
          maxLines: 10,
          decoration: InputDecoration(labelText: context.tr('aiJobField')),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _analyze,
              icon: const Icon(Icons.compare_arrows),
              label: Text(context.tr('aiAnalyze')),
            ),
            FilledButton.tonalIcon(
              onPressed: _tailorSummary,
              icon: const Icon(Icons.auto_awesome),
              label: Text(context.tr('aiGenerate')),
            ),
            FilledButton.tonalIcon(
              onPressed: _cover,
              icon: const Icon(Icons.mail_outline),
              label: Text(context.tr('aiCoverLetter')),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(context.tr('aiTranslate'), style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(context.tr('aiTranslateHint'), style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        DropdownMenu<String>(
          initialSelection: _target,
          expandedInsets: EdgeInsets.zero,
          label: Text(context.tr('targetLanguage')),
          dropdownMenuEntries: [
            for (final c in L10n.supported)
              if (c != widget.r.lang)
                DropdownMenuEntry(value: c, label: L10n.names[c]!),
          ],
          onSelected: (v) {
            if (v != null) _target = v;
          },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.icon(
            onPressed: _translate,
            icon: const Icon(Icons.translate),
            label: Text(context.tr('aiTranslate')),
          ),
        ),
      ],
    );
  }
}
