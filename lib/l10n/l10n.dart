import 'package:flutter/widgets.dart';

import 'generated/app_l10n.dart';

export 'generated/app_l10n.dart';

/// ZT Clock's own strings, in English and Hebrew (`app_en.arb`,
/// `app_he.arb`). The language is the one picked under Settings →
/// Appearance → Language (`ztLanguageProvider` in the core). The ring
/// screen and the notifications are native and keep their texts in
/// `android/app/src/main/res/values*/strings.xml`.
extension AppL10nContext on BuildContext {
  AppL10n get l10n => AppL10n.of(this);
}
