import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';
import '../state/app_state.dart';

extension TrX on BuildContext {
  /// Translate [key] into the current app language.
  String tr(String key) => L10n.t(Provider.of<AppState>(this).locale, key);
}
