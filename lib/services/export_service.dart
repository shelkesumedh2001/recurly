import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/enums.dart';
import '../models/exchange_rate.dart';
import '../models/subscription.dart';
import 'currency_service.dart';

/// Service for exporting subscription data to various formats
class ExportService {
  // Singleton pattern
  factory ExportService() => _instance;
  ExportService._internal();
  static final ExportService _instance = ExportService._internal();

  /// Get ASCII-safe currency symbol for PDF (fallback for fonts without Unicode support)
  String _getPdfSafeSymbol(String currencyCode) {
    switch (currencyCode) {
      case 'USD':
      case 'CAD':
      case 'AUD':
      case 'SGD':
      case 'HKD':
      case 'MXN':
        return '\$';
      case 'EUR':
        return 'EUR ';
      case 'GBP':
        return 'GBP ';
      case 'INR':
        return 'INR ';
      case 'JPY':
      case 'CNY':
        return 'JPY ';
      case 'KRW':
        return 'KRW ';
      case 'CHF':
        return 'CHF ';
      case 'BRL':
        return 'R\$';
      case 'SEK':
      case 'NOK':
      case 'DKK':
        return 'kr ';
      case 'PLN':
        return 'PLN ';
      case 'THB':
        return 'THB ';
      case 'MYR':
        return 'RM ';
      default:
        return '$currencyCode ';
    }
  }

  /// Format amount for PDF with safe symbols
  String _formatPdfAmount(double amount, String currencyCode) {
    final symbol = _getPdfSafeSymbol(currencyCode);
    if (currencyCode == 'JPY' || currencyCode == 'KRW') {
      return '$symbol${amount.round()}';
    }
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  /// Export subscriptions to CSV and share
  Future<void> exportToCsv(
    List<Subscription> subscriptions, {
    required String displayCurrency,
    required CurrencyService currencyService,
    ExchangeRateCache? exchangeRates,
  }) async {
    try {
      final csvData = _generateCsvData(
        subscriptions,
        displayCurrency: displayCurrency,
        currencyService: currencyService,
        exchangeRates: exchangeRates,
      );
      final csv = const ListToCsvConverter().convert(csvData);

      final directory = await getTemporaryDirectory();
      final fileName = 'recurly_subscriptions_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csv);

      // Share without text parameter to avoid the text file issue
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Recurly Subscriptions',
      );

      debugPrint('CSV exported: ${file.path}');
    } catch (e) {
      debugPrint('Failed to export CSV: $e');
      rethrow;
    }
  }

  /// Export subscriptions to PDF and share
  Future<void> exportToPdf(
    List<Subscription> subscriptions, {
    required double totalMonthlySpend,
    required Map<SubscriptionCategory, double> categorySpend,
    required String displayCurrency,
    required CurrencyService currencyService,
    ExchangeRateCache? exchangeRates,
  }) async {
    try {
      final pdf = pw.Document();

      // Sort subscriptions by monthly equivalent (highest first)
      final sortedSubs = List<Subscription>.from(subscriptions)
        ..sort((a, b) => b.monthlyEquivalent.compareTo(a.monthlyEquivalent));

      // Calculate additional analytics
      final upcomingRenewals = _getUpcomingRenewals(subscriptions, 30);
      final billingBreakdown = _getBillingCycleBreakdown(subscriptions, displayCurrency, currencyService, exchangeRates);
      final avgCost = subscriptions.isEmpty
          ? 0.0
          : totalMonthlySpend / subscriptions.length;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => [
            // Header
            _buildPdfHeader(totalMonthlySpend, subscriptions.length, displayCurrency),
            pw.SizedBox(height: 24),

            // Key metrics
            _buildPdfKeyMetrics(totalMonthlySpend, subscriptions.length, avgCost, displayCurrency),
            pw.SizedBox(height: 24),

            // Upcoming renewals (next 30 days)
            if (upcomingRenewals.isNotEmpty) ...[
              _buildPdfUpcomingRenewals(upcomingRenewals, displayCurrency, currencyService, exchangeRates),
              pw.SizedBox(height: 24),
            ],

            // Billing cycle breakdown
            _buildPdfBillingBreakdown(billingBreakdown, displayCurrency),
            pw.SizedBox(height: 24),

            // Category breakdown
            _buildPdfCategoryBreakdown(categorySpend, totalMonthlySpend, displayCurrency),
            pw.SizedBox(height: 24),

            // All subscriptions table
            _buildPdfSubscriptionsTable(sortedSubs, displayCurrency, currencyService, exchangeRates),
          ],
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Text(
              'Generated by Recurly • ${DateFormat.yMMMd().format(DateTime.now())}',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey600,
              ),
            ),
          ),
        ),
      );

      final directory = await getTemporaryDirectory();
      final fileName = 'recurly_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Recurly Subscription Report',
      );

      debugPrint('PDF exported: ${file.path}');
    } catch (e) {
      debugPrint('Failed to export PDF: $e');
      rethrow;
    }
  }

  /// Get subscriptions renewing in the next N days
  List<MapEntry<Subscription, int>> _getUpcomingRenewals(
    List<Subscription> subscriptions,
    int days,
  ) {
    final upcoming = <MapEntry<Subscription, int>>[];

    for (final sub in subscriptions) {
      final daysUntil = sub.daysUntilRenewal;
      if (daysUntil >= 0 && daysUntil <= days) {
        upcoming.add(MapEntry(sub, daysUntil));
      }
    }

    upcoming.sort((a, b) => a.value.compareTo(b.value));
    return upcoming;
  }

  /// Get breakdown by billing cycle
  Map<BillingCycle, _BillingStats> _getBillingCycleBreakdown(
    List<Subscription> subscriptions,
    String displayCurrency,
    CurrencyService currencyService,
    ExchangeRateCache? exchangeRates,
  ) {
    final breakdown = <BillingCycle, _BillingStats>{};

    for (final sub in subscriptions) {
      // Convert to display currency
      final convertedMonthly = currencyService.convert(
        amount: sub.monthlyEquivalent,
        from: sub.currency,
        to: displayCurrency,
        rates: exchangeRates,
      );

      final existing = breakdown[sub.billingCycle];
      if (existing != null) {
        breakdown[sub.billingCycle] = _BillingStats(
          count: existing.count + 1,
          totalMonthly: existing.totalMonthly + convertedMonthly,
        );
      } else {
        breakdown[sub.billingCycle] = _BillingStats(
          count: 1,
          totalMonthly: convertedMonthly,
        );
      }
    }

    return breakdown;
  }

  /// Generate CSV data rows
  List<List<dynamic>> _generateCsvData(
    List<Subscription> subscriptions, {
    required String displayCurrency,
    required CurrencyService currencyService,
    ExchangeRateCache? exchangeRates,
  }) {
    final List<List<dynamic>> rows = [];
    final symbol = CurrencyInfo.getSymbol(displayCurrency);

    // Header row
    rows.add([
      'Name',
      'Price',
      'Currency',
      'Billing Cycle',
      'Monthly Equivalent ($displayCurrency)',
      'Category',
      'Next Renewal',
      'Days Until Renewal',
      'First Bill Date',
      'Notes',
    ]);

    double totalMonthly = 0;

    // Data rows
    for (final sub in subscriptions) {
      final convertedMonthly = currencyService.convert(
        amount: sub.monthlyEquivalent,
        from: sub.currency,
        to: displayCurrency,
        rates: exchangeRates,
      );
      totalMonthly += convertedMonthly;

      rows.add([
        sub.name,
        sub.price.toStringAsFixed(2),
        sub.currency,
        sub.billingCycle.displayName,
        convertedMonthly.toStringAsFixed(2),
        sub.category.displayName,
        DateFormat('yyyy-MM-dd').format(sub.nextBillDate),
        sub.daysUntilRenewal,
        DateFormat('yyyy-MM-dd').format(sub.firstBillDate),
        sub.notes ?? '',
      ]);
    }

    // Empty row before summary
    rows.add([]);
    rows.add(['--- SUMMARY ---']);
    rows.add([
      'Total Subscriptions',
      subscriptions.length,
    ]);
    rows.add([
      'Total Monthly Spend',
      '$symbol${totalMonthly.toStringAsFixed(2)}',
    ]);
    rows.add([
      'Total Yearly Spend',
      '$symbol${(totalMonthly * 12).toStringAsFixed(2)}',
    ]);

    return rows;
  }

  /// Build PDF header
  pw.Widget _buildPdfHeader(double totalMonthlySpend, int count, String displayCurrency) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#2B2625'),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Subscription Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '$count active subscriptions',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColor.fromHex('#9A9A9A'),
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                _formatPdfAmount(totalMonthlySpend, displayCurrency),
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#E74C3C'),
                ),
              ),
              pw.Text(
                'per month',
                style: pw.TextStyle(
                  fontSize: 11,
                  color: PdfColor.fromHex('#9A9A9A'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build key metrics section
  pw.Widget _buildPdfKeyMetrics(double monthly, int count, double avgCost, String displayCurrency) {
    final yearly = monthly * 12;
    final daily = monthly / 30;

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        _buildMetricBox('Yearly Cost', _formatPdfAmount(yearly, displayCurrency), PdfColor.fromHex('#48A868')),
        _buildMetricBox('Daily Cost', _formatPdfAmount(daily, displayCurrency), PdfColor.fromHex('#F4A089')),
        _buildMetricBox('Avg per Sub', _formatPdfAmount(avgCost, displayCurrency), PdfColor.fromHex('#9B59B6')),
      ],
    );
  }

  pw.Widget _buildMetricBox(String label, String value, PdfColor color) {
    return pw.Container(
      width: 140,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  /// Build upcoming renewals section
  pw.Widget _buildPdfUpcomingRenewals(
    List<MapEntry<Subscription, int>> renewals,
    String displayCurrency,
    CurrencyService currencyService,
    ExchangeRateCache? exchangeRates,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(
              width: 4,
              height: 16,
              color: PdfColor.fromHex('#E74C3C'),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              'Upcoming Renewals (Next 30 Days)',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildTableCell('Subscription', isHeader: true),
                _buildTableCell('Amount', isHeader: true),
                _buildTableCell('Renews In', isHeader: true),
              ],
            ),
            ...renewals.take(10).map((entry) {
              final sub = entry.key;
              final days = entry.value;
              final daysText = days == 0 ? 'Today' : days == 1 ? 'Tomorrow' : '$days days';

              // Convert to display currency
              final convertedPrice = currencyService.convert(
                amount: sub.price,
                from: sub.currency,
                to: displayCurrency,
                rates: exchangeRates,
              );

              return pw.TableRow(
                children: [
                  _buildTableCell(sub.name),
                  _buildTableCell(_formatPdfAmount(convertedPrice, displayCurrency)),
                  _buildTableCell(daysText),
                ],
              );
            }),
          ],
        ),
        if (renewals.length > 10)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              '+ ${renewals.length - 10} more renewals',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ),
      ],
    );
  }

  /// Build billing cycle breakdown
  pw.Widget _buildPdfBillingBreakdown(Map<BillingCycle, _BillingStats> breakdown, String displayCurrency) {
    if (breakdown.isEmpty) return pw.SizedBox();

    final sortedEntries = breakdown.entries.toList()
      ..sort((a, b) => b.value.count.compareTo(a.value.count));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(
              width: 4,
              height: 16,
              color: PdfColor.fromHex('#9B59B6'),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              'By Billing Cycle',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.start,
          children: sortedEntries.map((entry) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(right: 16),
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    '${entry.value.count}',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    entry.key.displayName,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.Text(
                    '${_formatPdfAmount(entry.value.totalMonthly, displayCurrency)}/mo',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Build PDF category breakdown
  pw.Widget _buildPdfCategoryBreakdown(
    Map<SubscriptionCategory, double> categorySpend,
    double total,
    String displayCurrency,
  ) {
    if (categorySpend.isEmpty) return pw.SizedBox();

    final sortedCategories = categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(
              width: 4,
              height: 16,
              color: PdfColor.fromHex('#00BCD4'),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              'By Category',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        ...sortedCategories.map((entry) {
          final percentage = (entry.value / total * 100);
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 100,
                  child: pw.Text(
                    entry.key.displayName,
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ),
                pw.Expanded(
                  child: pw.Stack(
                    children: [
                      pw.Container(
                        height: 14,
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey200,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                      ),
                      pw.Container(
                        height: 14,
                        width: 250 * (entry.value / total),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#E74C3C'),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.SizedBox(
                  width: 110,
                  child: pw.Text(
                    '${_formatPdfAmount(entry.value, displayCurrency)} (${percentage.toStringAsFixed(0)}%)',
                    style: const pw.TextStyle(fontSize: 10),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// Build PDF subscriptions table
  pw.Widget _buildPdfSubscriptionsTable(
    List<Subscription> subscriptions,
    String displayCurrency,
    CurrencyService currencyService,
    ExchangeRateCache? exchangeRates,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(
              width: 4,
              height: 16,
              color: PdfColor.fromHex('#F4A089'),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              'All Subscriptions',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildTableCell('Name', isHeader: true),
                _buildTableCell('Price', isHeader: true),
                _buildTableCell('Cycle', isHeader: true),
                _buildTableCell('Category', isHeader: true),
                _buildTableCell('Next Bill', isHeader: true),
              ],
            ),
            ...subscriptions.map((sub) {
              // Convert to display currency
              final convertedPrice = currencyService.convert(
                amount: sub.price,
                from: sub.currency,
                to: displayCurrency,
                rates: exchangeRates,
              );

              return pw.TableRow(
                children: [
                  _buildTableCell(sub.name),
                  _buildTableCell(_formatPdfAmount(convertedPrice, displayCurrency)),
                  _buildTableCell(sub.billingCycle.displayName),
                  _buildTableCell(sub.category.displayName),
                  _buildTableCell(DateFormat.MMMd().format(sub.nextBillDate)),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}

/// Helper class for billing stats
class _BillingStats {
  final int count;
  final double totalMonthly;

  _BillingStats({required this.count, required this.totalMonthly});
}
