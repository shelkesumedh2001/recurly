/// Money helpers.
///
/// Prices are stored and computed as `double`, which accumulates binary
/// floating-point drift under multiplication (currency conversion, split
/// percentages, monthly-equivalent factors) and summation. That drift is
/// normally hidden by `toStringAsFixed(2)` on display, but it can surface in
/// numeric comparisons — e.g. a spend of `30.0000000001` reading as
/// over-budget against a limit of `30`. Rounding aggregate money values to
/// whole cents at the boundary keeps comparisons and displays honest.
library;

/// Rounds a monetary [amount] to 2 decimal places (whole cents), removing
/// floating-point drift such as `4.995000000001` → `5.0` / `29.999999` → `30`.
double roundMoney(double amount) => roundCents(amount);

/// Like [roundMoney] but half-cents round up even when the double sits a
/// hair below the half: 50% of 15.49 is 7.745, stored as 7.744999…, which
/// [roundMoney] and `toStringAsFixed(2)` both turn into 7.74 while a sum
/// elsewhere lands on 7.75 — the "one cent different on another screen"
/// of BUG-14. Snapping to 6 decimals first removes the representation
/// error without touching real fractions of a cent.
double roundCents(double amount) {
  final cents = ((amount * 100) * 1e6).roundToDouble() / 1e6;
  return cents.roundToDouble() / 100;
}

/// The one way money is shown: [roundCents], two decimals (none for
/// JPY/KRW) and thousands separators, e.g. `formatMoney(1500, '₹')` →
/// `₹1,500.00` (BUG-14, BUG-22).
String formatMoney(double amount, String symbol, {String? currencyCode}) {
  final noDecimals = currencyCode == 'JPY' || currencyCode == 'KRW';
  final rounded = noDecimals ? amount.roundToDouble() : roundCents(amount);
  final negative = rounded < 0;
  final fixed = rounded.abs().toStringAsFixed(noDecimals ? 0 : 2);
  final parts = fixed.split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  final body = parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  return '${negative ? '-' : ''}$symbol$body';
}
