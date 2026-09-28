import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idem/l10n/app_localizations.dart';
import 'package:vcmrtd/vcmrtd.dart' show DocumentType;

export 'package:idem/l10n/app_localizations.dart';

/// The app's UI strings live in lib/l10n/app_{lang}.arb (en is the template,
/// nl the other shipped language), generated into [AppLocalizations] by
/// `flutter gen-l10n` (see l10n.yaml).
///
/// Which language shows: a proofing session's own `language` (resolved by
/// identity-proofing-service from the relying party's choice, else this
/// device's Accept-Language - see [deviceAcceptLanguage]) while one is
/// pinned, else the device locale. The session language sticks after the
/// session ends, so its closing dialog doesn't switch language mid-sentence;
/// the next session (or an app restart) decides again.
extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// The locale forced by the proofing session, or null to follow the device.
class AppLocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() => null;

  /// Switches to the session's language when it's one this app ships;
  /// anything else (null, unshipped) leaves the current choice alone.
  void useSessionLanguage(String? tag) {
    final locale = supportedLocaleFor(tag);
    if (locale == null || locale == state) return;
    _sessionLocale = locale;
    state = locale;
  }
}

final appLocaleProvider = NotifierProvider<AppLocaleNotifier, Locale?>(AppLocaleNotifier.new);

Locale? _sessionLocale;

/// The device's preferred locales. Through the binding when there is one
/// (so tests can override them), straight from the platform otherwise -
/// the session client also runs before/without any widget binding.
List<Locale> get _deviceLocales {
  try {
    return WidgetsBinding.instance.platformDispatcher.locales;
  } on FlutterError {
    return ui.PlatformDispatcher.instance.locales;
  }
}

/// The shipped locale for a BCP 47 [tag] ("nl", "nl-NL", "en_GB"), matched
/// on its language subtag; null when there is none.
Locale? supportedLocaleFor(String? tag) {
  if (tag == null || tag.isEmpty) return null;
  final language = tag.split(RegExp('[-_]')).first.toLowerCase();
  for (final locale in AppLocalizations.supportedLocales) {
    if (locale.languageCode == language) return locale;
  }
  return null;
}

/// The strings for code without a BuildContext (services, enum messages):
/// the same language the UI currently shows.
AppLocalizations get currentL10n {
  final locale =
      _sessionLocale ??
      _deviceLocales.map((l) => supportedLocaleFor(l.toLanguageTag())).nonNulls.firstOrNull ??
      AppLocalizations.supportedLocales.first;
  return lookupAppLocalizations(locale);
}

/// This device's preferred languages as an Accept-Language header value
/// ("nl-NL, en-US;q=0.9"), so a session without a language of its own comes
/// back in the phone's language.
String deviceAcceptLanguage() {
  final tags = _deviceLocales.map((l) => l.toLanguageTag()).toSet().take(10).toList();
  if (tags.isEmpty) return 'en';
  return [
    for (var i = 0; i < tags.length; i++) i == 0 ? tags[i] : '${tags[i]};q=${(1 - i / 10).toStringAsFixed(1)}',
  ].join(', ');
}

/// [DocumentType.displayName] (English, from the vcmrtd library) in the UI's
/// language. For sentences that name the document, add a `select` on the
/// type's [DocumentType.name] to the message instead - Dutch articles and
/// word order depend on the type.
extension DocumentTypeL10n on DocumentType {
  String localizedName(AppLocalizations l10n) => switch (this) {
    DocumentType.passport => l10n.idDocumentPassport,
    DocumentType.identityCard => l10n.idDocumentIdentityCard,
    DocumentType.drivingLicence => l10n.idDocumentDrivingLicence,
  };
}
