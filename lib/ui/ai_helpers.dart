import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/resume.dart';
import '../services/ai_service.dart';
import '../state/app_state.dart';
import 'paywall.dart';
import 'tr.dart';

/// Runs [call] with the AI service: checks the free daily limit for remote
/// calls, shows a progress dialog and reports errors. Returns null on failure.
Future<T?> runAiCall<T>(
  BuildContext context,
  Future<T> Function(AiService service) call,
) async {
  final app = context.read<AppState>();
  final service = app.ai;
  final messenger = ScaffoldMessenger.of(context);
  final nav = Navigator.of(context, rootNavigator: true);
  final quotaText = context.trNow('aiQuotaReached');
  final errorText = context.trNow('aiError');

  if (service.isRemote && !app.tryConsumeAi()) {
    messenger.showSnackBar(SnackBar(content: Text(quotaText)));
    if (context.mounted) await showPaywall(context);
    return null;
  }

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(child: CircularProgressIndicator()),
    ),
  );

  try {
    final result = await call(service);
    nav.pop();
    return result;
  } catch (e) {
    nav.pop();
    if (service.isRemote) app.refundAi();
    final detail = e is AiException ? e.message : '';
    messenger.showSnackBar(
      SnackBar(content: Text(detail.isEmpty ? errorText : '$errorText\n$detail')),
    );
    return null;
  }
}

/// Convenience wrapper around [runAiCall] for a single [AiTask].
Future<AiResult?> runAi(
  BuildContext context,
  AiTask task,
  Resume r, {
  String input = '',
  String target = '',
  String job = '',
}) {
  return runAiCall<AiResult>(
    context,
    (s) => s.run(task, r, input: input, target: target, job: job),
  );
}

/// Shows an AI result with Copy and (optionally) Apply actions.
Future<void> showAiSheet(
  BuildContext context, {
  required String title,
  required AiResult result,
  VoidCallback? onApply,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: SelectableText(result.text),
                  ),
                ),
                if (result.local) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: theme.colorScheme.outline),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ctx.tr('aiOfflineNote'),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 18),
                      label: Text(ctx.tr('copy')),
                      onPressed: () async {
                        final copied = ctx.trNow('copied');
                        final messenger = ScaffoldMessenger.of(ctx);
                        await Clipboard.setData(ClipboardData(text: result.text));
                        messenger.showSnackBar(
                          SnackBar(content: Text(copied)),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    if (onApply != null)
                      FilledButton.icon(
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(ctx.tr('apply')),
                        onPressed: () {
                          onApply();
                          Navigator.of(ctx).pop();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
