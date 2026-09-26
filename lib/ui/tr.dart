import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';
import '../state/app_state.dart';

extension TrX on BuildContext {
  /// Translate [key] into the current app language. Rebuilds the widget when
  /// the language changes, so call it from `build`.
  String tr(String key) => L10n.t(Provider.of<AppState>(this).locale, key);

  /// Same as [tr] but without subscribing to changes. Use inside callbacks
  /// (onPressed, after an await, ...).
  String trNow(String key) =>
      L10n.t(Provider.of<AppState>(this, listen: false).locale, key);
}
