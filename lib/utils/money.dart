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
double roundMoney(double amount) => (amount * 100).roundToDouble() / 100;
