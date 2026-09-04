/// Store product ids for Lifey Pro (`docs/landing_page/67-mobile-free-pro-plan.md`
/// §4.1) — configured in App Store Connect / Google Play Console, referenced
/// here by id only. Never hardcode a price alongside these; that always
/// comes from the store at query time.
const monthlySubscriptionProductId = 'lifey.pro.monthly';
const yearlySubscriptionProductId = 'lifey.pro.yearly';
const subscriptionProductIds = {monthlySubscriptionProductId, yearlySubscriptionProductId};

enum SubscriptionPeriod { monthly, yearly }

/// A purchasable Lifey Pro product, built from the store's own
/// `ProductDetails` (`67` §4.1: prices are rendered from the store's
/// localized strings, never a constant in the app). Deliberately plain — the
/// `in_app_purchase` plugin type this is built from stays in
/// `data/purchase_repository.dart`, since [buy] needs the original object
/// back, not just what's reproduced here.
class SubscriptionProduct {
  const SubscriptionProduct({
    required this.id,
    required this.period,
    required this.formattedPrice,
    required this.rawPrice,
    required this.currencyCode,
  });

  final String id;
  final SubscriptionPeriod period;

  /// Store-formatted, locale-appropriate price string (e.g. "$4.99" or
  /// "1 490 Ft") — render this, never [rawPrice] reformatted by hand.
  final String formattedPrice;

  final double rawPrice;
  final String currencyCode;
}
