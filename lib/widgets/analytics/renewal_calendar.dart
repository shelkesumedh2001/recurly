import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/credit_card.dart';
import '../../models/subscription.dart';
import '../../providers/credit_card_providers.dart';
import '../../providers/currency_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/card_dates.dart';

/// A calendar widget showing subscription renewals as a heatmap
class RenewalCalendar extends ConsumerStatefulWidget {
  const RenewalCalendar({super.key});

  @override
  ConsumerState<RenewalCalendar> createState() => _RenewalCalendarState();
}

class _RenewalCalendarState extends ConsumerState<RenewalCalendar> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = clock.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscriptionsAsync = ref.watch(subscriptionProvider);

    final cards = ref.watch(creditCardsProvider);

    return subscriptionsAsync.when(
      data: (subscriptions) {
        // Build renewal map for the calendar
        final renewalMap = _buildRenewalMap(subscriptions);
        final cardDueMap = _buildCardDueMap(cards);
        final selectedDayRenewals = _selectedDay != null
            ? _getRenewalsForDay(_selectedDay!, subscriptions)
            : <Subscription>[];
        final selectedDayCardsDue = _selectedDay != null
            ? cardDueMap[DateTime(
                  _selectedDay!.year,
                  _selectedDay!.month,
                  _selectedDay!.day,
                )] ??
                const <CreditCardInfo>[]
            : const <CreditCardInfo>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Calendar
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              child: TableCalendar(
                firstDay: clock.now().subtract(const Duration(days: 365)),
                lastDay: clock.now().add(const Duration(days: 365)),
                // TableCalendar defaults "today" to its own DateTime.now(),
                // bypassing the injectable clock — pin it or goldens rot.
                currentDay: clock.now(),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                calendarStyle: CalendarStyle(
                  // Today styling
                  todayDecoration: BoxDecoration(
                    color: AppTheme.primaryCoral.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  // Selected day styling
                  selectedDecoration: BoxDecoration(
                    color: AppTheme.primaryCoral,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: TextStyle(
                    color: theme.colorScheme.surface,
                    fontWeight: FontWeight.bold,
                  ),
                  // Default day styling
                  defaultTextStyle: TextStyle(
                    color: theme.colorScheme.onSurface,
                  ),
                  weekendTextStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  outsideTextStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                  // Markers
                  markersMaxCount: 1,
                  markerDecoration: BoxDecoration(
                    color: AppTheme.expenseColor,
                    shape: BoxShape.circle,
                  ),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: theme.textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left,
                    color: theme.colorScheme.onSurface,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: theme.textTheme.labelSmall!.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                  ),
                  weekendStyle: theme.textTheme.labelSmall!.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                calendarBuilders: CalendarBuilders(
                  // Custom day builder with heatmap
                  defaultBuilder: (context, day, focusedDay) {
                    return _buildDayCell(context, day, renewalMap, cardDueMap, false, false);
                  },
                  todayBuilder: (context, day, focusedDay) {
                    return _buildDayCell(context, day, renewalMap, cardDueMap, true, false);
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    return _buildDayCell(context, day, renewalMap, cardDueMap, false, true);
                  },
                  outsideBuilder: (context, day, focusedDay) {
                    return _buildDayCell(context, day, renewalMap, cardDueMap, false, false, isOutside: true);
                  },
                ),
              ),
            ),

            // Selected day: card payments due + renewals
            if (_selectedDay != null && selectedDayCardsDue.isNotEmpty) ...[
              const SizedBox(height: 20),
              ...selectedDayCardsDue
                  .map((card) => _buildCardDueTile(context, card)),
            ],
            if (_selectedDay != null && selectedDayRenewals.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Renewals on ${DateFormat.yMMMd().format(_selectedDay!)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...selectedDayRenewals.map((sub) => _buildRenewalTile(context, sub)),
            ] else if (_selectedDay != null &&
                selectedDayCardsDue.isEmpty) ...[
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'No renewals on ${DateFormat.yMMMd().format(_selectedDay!)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],

            // Legend
            const SizedBox(height: 20),
            _buildLegend(context),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error loading calendar')),
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime day,
    Map<DateTime, double> renewalMap,
    Map<DateTime, List<CreditCardInfo>> cardDueMap,
    bool isToday,
    bool isSelected, {
    bool isOutside = false,
  }) {
    final theme = Theme.of(context);
    final heatmapColors = AppTheme.getCalendarHeatmapColors(context);
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final amount = renewalMap[normalizedDay] ?? 0;
    final hasCardDue = cardDueMap.containsKey(normalizedDay);

    // Determine heatmap intensity (0-4 based on amount)
    int intensity = 0;
    if (amount > 0) {
      if (amount < 10) {
        intensity = 1;
      } else if (amount < 25) {
        intensity = 2;
      } else if (amount < 50) {
        intensity = 3;
      } else {
        intensity = 4;
      }
    }

    final bgColor = isSelected
        ? AppTheme.primaryCoral
        : isToday
            ? AppTheme.primaryCoral.withValues(alpha: 0.3)
            : intensity > 0
                ? heatmapColors[intensity]
                : Colors.transparent;

    final textColor = isSelected
        ? theme.colorScheme.surface
        : isOutside
            ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
            : intensity >= 3
                ? Colors.white
                : theme.colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: isToday && !isSelected
            ? Border.all(color: AppTheme.primaryCoral, width: 2)
            : null,
      ),
      child: Stack(
        children: [
          // Center expands to fill the cell, so the heatmap decoration
          // keeps its full size (a shrink-wrapping Stack collapses it).
          Center(
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: textColor,
                fontWeight: isToday || isSelected || intensity > 0
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
          // Card payment-due marker
          if (hasCardDue)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.surface
                        : theme.colorScheme.tertiary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCardDueTile(BuildContext context, CreditCardInfo card) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.credit_card, color: theme.colorScheme.tertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${card.name} payment due',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.tertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRenewalTile(BuildContext context, Subscription sub) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.expenseColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: sub.logoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      sub.logoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          sub.name[0].toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.expenseColor,
                          ),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      sub.name[0].toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.expenseColor,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sub.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  sub.billingCycle.displayName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Text(
            sub.formattedPrice,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.expenseColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    final theme = Theme.of(context);
    final heatmapColors = AppTheme.getCalendarHeatmapColors(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Less',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(width: 8),
        ...List.generate(5, (index) {
          return Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: heatmapColors[index],
              borderRadius: BorderRadius.circular(4),
              border: index == 0
                  ? Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    )
                  : null,
            ),
          );
        }),
        const SizedBox(width: 8),
        Text(
          'More',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: theme.colorScheme.tertiary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'Card due',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  /// Build a map of dates to total renewal amounts for the next 12 months.
  /// Uses the model's cycle-accurate projection (custom cycles advance by
  /// their customDays, not by "+1 month"). Amounts are converted to the
  /// display currency so the heatmap intensity thresholds mean one thing —
  /// raw mixed-currency sums made a ₹649 sub look like a $649 spike.
  Map<DateTime, double> _buildRenewalMap(List<Subscription> subscriptions) {
    final Map<DateTime, double> renewalMap = {};
    final endDate = clock.now().add(const Duration(days: 365));
    final displayCurrency = ref.read(displayCurrencyProvider);
    final rates = ref.read(exchangeRatesProvider).value;
    final currencyService = ref.read(currencyServiceProvider);

    for (final sub in subscriptions) {
      final converted = currencyService.convert(
        amount: sub.price,
        from: sub.currency,
        to: displayCurrency,
        rates: rates,
      );
      for (final renewal in sub.upcomingRenewals(endDate)) {
        final normalizedDate =
            DateTime(renewal.year, renewal.month, renewal.day);
        renewalMap[normalizedDate] =
            (renewalMap[normalizedDate] ?? 0) + converted;
      }
    }

    return renewalMap;
  }

  /// Map each card's projected payment-due dates over the next year to the
  /// cards due that day. Days past a short month's end clamp to its last
  /// day, matching the card's own due-date math.
  Map<DateTime, List<CreditCardInfo>> _buildCardDueMap(
    List<CreditCardInfo> cards,
  ) {
    final map = <DateTime, List<CreditCardInfo>>{};
    final now = clock.now();
    final endDate = now.add(const Duration(days: 365));

    for (final card in cards) {
      for (final due in occurrencesInRange(card.dueDay, now, endDate)) {
        (map[due] ??= []).add(card);
      }
    }
    return map;
  }

  /// Get renewals for a specific day
  List<Subscription> _getRenewalsForDay(DateTime day, List<Subscription> subscriptions) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final endDate = clock.now().add(const Duration(days: 365));

    return subscriptions.where((sub) {
      return sub.upcomingRenewals(endDate).any(
            (renewal) =>
                DateTime(renewal.year, renewal.month, renewal.day) ==
                normalizedDay,
          );
    }).toList();
  }
}
