/// The public marketing/legal site (`docs/landing_page/65-web-landing-page-plan.md`)
/// — real per-locale URLs, same domain the app's own download-page invite
/// links point at.
abstract final class WebLinks {
  static const _baseUrl = 'https://lifey.hu';

  static String terms(String languageCode) => '$_baseUrl/${_locale(languageCode)}/legal/terms';
  static String privacy(String languageCode) => '$_baseUrl/${_locale(languageCode)}/legal/privacy';

  /// `docs/landing_page/66-trainer-billing-web-plan.md` §3 — the `(admin)`
  /// route group isn't locale-prefixed like the marketing tree. Where a
  /// mobile client's own entitlement resolves through a Stripe subscription
  /// or a trainer trial (`63` §3 resolution order), this is where it's
  /// actually managed — there is no trainer purchase UI on mobile and there
  /// will not be one (`63` D-M1).
  static const adminBilling = '$_baseUrl/admin/billing';

  /// Only `hu`/`en` exist on the web app; anything else falls back to `hu`,
  /// the site's default locale (`65` D-W1).
  static String _locale(String languageCode) => languageCode == 'en' ? 'en' : 'hu';
}
