import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'tr.dart';

/// Demo paywall. Replace the activate button with a real purchase flow
/// (in_app_purchase / RevenueCat) before publishing.
Future<bool> showPaywall(BuildContext context) async {
  final app = context.read<AppState>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.workspace_premium, size: 36),
      title: Text(ctx.tr('premiumTitle')),
      content: Text(ctx.tr('premiumBody')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.tr('cancel')),
        ),
        FilledButton(
          onPressed: () {
            app.setPremium(true);
            Navigator.pop(ctx, true);
          },
          child: Text(ctx.tr('activateDemo')),
        ),
      ],
    ),
  );
  return ok ?? false;
}
