import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/enums.dart';
import '../models/exchange_rate.dart';
import '../models/subscription.dart';
import '../models/subscription_template.dart';
import '../providers/category_providers.dart';
import '../providers/credit_card_providers.dart';
import '../providers/currency_providers.dart';
import '../providers/subscription_providers.dart';
import '../providers/template_providers.dart';
import '../theme/app_tokens.dart';
import '../utils/billing_cycle.dart';
import '../utils/constants.dart';

class AddSubscriptionSheet extends ConsumerStatefulWidget { // Null for add, populated for edit

  const AddSubscriptionSheet({
    super.key,
    this.subscription,
  });
  final Subscription? subscription;

  @override
  ConsumerState<AddSubscriptionSheet> createState() => _AddSubscriptionSheetState();
}

class _AddSubscriptionSheetState extends ConsumerState<AddSubscriptionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();

  BillingCycle _selectedBillingCycle = BillingCycle.monthly;
  SubscriptionCategory _selectedCategory = SubscriptionCategory.entertainment;
  /// The NEXT bill date, which is what users actually know ("it bills on
  /// the 22nd"). Deliberately null until they say so: this used to default
  /// to today and be silently accepted, which made `nextBillDate` land one
  /// cycle from install — wrong by ~two weeks on average, and wrong in a
  /// way nobody noticed until a reminder failed to arrive a month later.
  /// Stored as `firstBillDate - one cycle` on save.
  DateTime? _nextBillDate;
  String? _selectedCurrency;
  bool _isLoading = false;
  bool _showTemplates = true;
  String? _logoUrl;
  String? _templateColor;
  String? _selectedCardId;

  // Custom billing cycle (only used when _selectedBillingCycle == custom)
  final _customDaysController = TextEditingController(text: '30');

  // Free trial fields
  bool _isFreeTrial = false;
  DateTime? _trialEndDate;
  final _priceAfterTrialController = TextEditingController();
  // Convenience trial-duration inputs that drive [_trialEndDate]. The
  // date picker stays the source of truth; this just lets users say
  // "7 days" or "1 month" without doing date math.
  int _trialDurationValue = 7;
  _TrialDurationUnit _trialDurationUnit = _TrialDurationUnit.days;
  final _trialDurationController = TextEditingController(text: '7');

  bool get _isEditMode => widget.subscription != null;

  @override
  void initState() {
    super.initState();
    // Populate form if editing
    if (_isEditMode) {
      final sub = widget.subscription!;
      _nameController.text = sub.name;
      _priceController.text = sub.price.toString();
      _selectedBillingCycle = sub.billingCycle;
      _selectedCategory = sub.category;
      // Show what the field now means — the next bill, derived from the
      // stored anchor — rather than the anchor itself.
      _nextBillDate = sub.nextBillDate;
      _selectedCurrency = sub.currency;
      _logoUrl = sub.logoUrl;
      _templateColor = sub.color;
      _selectedCardId = sub.cardId;
      _showTemplates = false; // Don't show templates when editing
      // Trial fields
      _isFreeTrial = sub.isFreeTrial;
      _trialEndDate = sub.trialEndDate;
      if (sub.priceAfterTrial != null) {
        _priceAfterTrialController.text = sub.priceAfterTrial.toString();
      }
      if (sub.customDays != null) {
        _customDaysController.text = sub.customDays.toString();
      }
    }
  }


  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _priceAfterTrialController.dispose();
    _customDaysController.dispose();
    _trialDurationController.dispose();
    super.dispose();
  }

  /// Compute the trial end date from the current duration value + unit
  /// and apply it to [_trialEndDate]. Anchored on today.
  void _applyTrialDuration() {
    if (_trialDurationValue <= 0) return;
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime end;
    switch (_trialDurationUnit) {
      case _TrialDurationUnit.days:
        end = DateTime(today.year, today.month, today.day + _trialDurationValue);
        break;
      case _TrialDurationUnit.months:
        end = DateTime(today.year, today.month + _trialDurationValue, today.day);
        break;
      case _TrialDurationUnit.years:
        end = DateTime(today.year + _trialDurationValue, today.month, today.day);
        break;
    }
    setState(() {
      _trialEndDate = end;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    // Initialize currency from display currency if not set (and not in edit mode)
    _selectedCurrency ??= ref.read(displayCurrencyProvider);

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: mediaQuery.viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    _isEditMode ? 'Edit Subscription' : 'Add Subscription',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Template Picker Section (only show when adding new)
                  if (!_isEditMode && _showTemplates) ...[
                    _buildTemplateSection(context, theme),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: Divider(color: theme.colorScheme.outline.withValues(alpha: 0.3))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Or create custom',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: theme.colorScheme.outline.withValues(alpha: 0.3))),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Toggle back to templates button
                  if (!_isEditMode && !_showTemplates) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _showTemplates = true;
                          _nameController.clear();
                          _priceController.clear();
                          _logoUrl = null;
                          _templateColor = null;
                        });
                      },
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Choose from templates'),
                    ),
                    const SizedBox(height: 16),
                  ],

                // Service Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Service Name',
                    hintText: 'e.g., Netflix, Spotify',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                  maxLength: 50,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a service name';
                    }
                    if (value.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppConstants.spacing16),

                // Price and Currency Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _priceController,
                        decoration: InputDecoration(
                          labelText: _isFreeTrial ? 'Price during trial' : 'Price',
                          hintText: _isFreeTrial ? 'Usually 0' : '0.00',
                          prefixIcon: const Icon(Icons.payments_outlined),
                          prefixText: '${CurrencyInfo.getSymbol(_selectedCurrency!)} ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        validator: (value) {
                          // During a free trial, the trial price can be 0 / blank
                          // since the recurring amount lives in priceAfterTrial.
                          if (value == null || value.trim().isEmpty) {
                            if (_isFreeTrial) return null;
                            return 'Please enter a price';
                          }
                          final price = double.tryParse(value);
                          if (price == null) {
                            return 'Please enter a valid number';
                          }
                          if (price < 0) {
                            return 'Price cannot be negative';
                          }
                          if (!_isFreeTrial && price <= 0) {
                            return 'Price must be greater than 0';
                          }
                          if (price > 10000000) {
                            return 'Price seems too high';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Currency Selector
                    Expanded(
                      flex: 2,
                      child: _buildCurrencySelector(theme),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacing16),

                // Billing Cycle
                DropdownButtonFormField<BillingCycle>(
                  initialValue: _selectedBillingCycle,
                  decoration: const InputDecoration(
                    labelText: 'Billing Cycle',
                    prefixIcon: Icon(Icons.sync),
                  ),
                  items: BillingCycle.values.map((cycle) {
                    return DropdownMenuItem(
                      value: cycle,
                      child: Text(cycle.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedBillingCycle = value;
                        // The selectable window is one cycle wide, so it
                        // just moved — a date chosen under the old cycle
                        // may no longer be representable.
                        _dropBillDateIfOutOfRange();
                      });
                    }
                  },
                ),

                // Custom-days input — visible only when Custom is selected
                if (_selectedBillingCycle == BillingCycle.custom) ...[
                  const SizedBox(height: AppConstants.spacing16),
                  TextFormField(
                    controller: _customDaysController,
                    decoration: const InputDecoration(
                      labelText: 'Bill every (days)',
                      hintText: 'e.g., 14',
                      prefixIcon: Icon(Icons.repeat),
                      helperText: 'How many days between bills (1–365)',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    // Cycle length sets the width of the selectable bill-date
                    // window, so shortening it can strand an existing choice.
                    onChanged: (_) =>
                        setState(_dropBillDateIfOutOfRange),
                    validator: (value) {
                      if (_selectedBillingCycle != BillingCycle.custom) {
                        return null;
                      }
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter the cycle length in days';
                      }
                      final days = int.tryParse(value);
                      if (days == null || days < 1 || days > 365) {
                        return 'Must be between 1 and 365';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: AppConstants.spacing16),

                // Category
                DropdownButtonFormField<SubscriptionCategory>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: ref.watch(categoriesByUsageProvider).map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Text(category.icon),
                          const SizedBox(width: 8),
                          Text(category.displayName),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: AppConstants.spacing16),

                // Payment card (only shown when the user tracks cards)
                if (ref.watch(creditCardsProvider).isNotEmpty) ...[
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedCardId,
                    decoration: const InputDecoration(
                      labelText: 'Payment card',
                      prefixIcon: Icon(Icons.credit_card_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('None'),
                      ),
                      ...ref.watch(creditCardsProvider).map(
                            (card) => DropdownMenuItem<String?>(
                              value: card.id,
                              child: Text(card.name),
                            ),
                          ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCardId = value;
                      });
                    },
                  ),
                  const SizedBox(height: AppConstants.spacing16),
                ],

                // Next bill date. Hidden for free trials: billing there
                // starts when the trial ends, so the trial section below
                // already carries the first charge date and this field
                // would be a second, contradictory answer.
                if (!_isFreeTrial) ...[
                  _buildNextBillDateField(context, theme),
                  const SizedBox(height: AppConstants.spacing16),
                ],

                // Free Trial Section
                _buildTrialSection(context, theme),
                const SizedBox(height: AppConstants.spacing16),

                // Save Button
                FilledButton(
                  onPressed: _isLoading ? null : _saveSubscription,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppConstants.spacing16,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Save'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The next-bill-date field: quick day-of-month chips for monthly subs
  /// (how people actually hold this — "it bills on the 22nd"), plus a
  /// picker for everything else. A FormField so "required" runs through
  /// the form's own validation rather than a bespoke check at save time.
  Widget _buildNextBillDateField(BuildContext context, ThemeData theme) {
    return FormField<DateTime>(
      initialValue: _nextBillDate,
      // Without this the error survives the fix: didChange doesn't
      // re-validate on its own, so picking a date would leave the
      // complaint on screen (and keep hiding the helper line) until the
      // next SAVE.
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (_) {
        final date = _nextBillDate;
        if (date == null) {
          return 'Pick when this bills next so reminders land on the right day';
        }
        // Backstop. `_dropBillDateIfOutOfRange` is called from each place
        // that can move the window, and missing one is easy — that's how a
        // stale trial-end date reached this field. Out-of-range dates save
        // an anchor that resolves a cycle early, so refuse rather than
        // silently store the wrong day.
        if (!_isSelectableBillDate(date)) {
          return 'That is more than one billing cycle away — pick the very '
              'next bill';
        }
        return null;
      },
      builder: (field) {
        final date = _nextBillDate;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () async {
                await _selectDate(context);
                field.didChange(_nextBillDate);
              },
              borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Next bill date',
                  helperText: date == null
                      ? 'The day the money actually leaves'
                      : '${_relativeBillDescription(date)} · repeats '
                          '${_selectedBillingCycle.displayName.toLowerCase()}',
                  prefixIcon: const Icon(Icons.event_outlined),
                  errorText: field.errorText,
                ),
                child: Text(
                  date == null
                      ? 'Select date'
                      : DateFormat('EEE, MMM d, yyyy').format(date),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: date == null
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                        : null,
                  ),
                ),
              ),
            ),
            if (_selectedBillingCycle == BillingCycle.monthly) ...[
              const SizedBox(height: 10),
              _buildDayOfMonthChips(theme, field),
            ],
          ],
        );
      },
    );
  }

  /// One-tap day-of-month picker for monthly subs. Resolves to the next
  /// time that day comes around, so tapping "22" on the 16th means this
  /// month, but tapping "3" means next month.
  Widget _buildDayOfMonthChips(ThemeData theme, FormFieldState<DateTime> field) {
    final selectedDay = _nextBillDate?.day;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'BILLS ON THE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 31,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              final day = index + 1;
              final isSelected = selectedDay == day;
              return _DayChip(
                day: day,
                isSelected: isSelected,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _nextBillDate = _nextOccurrenceOfDay(day);
                  });
                  field.didChange(_nextBillDate);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// "in 6 days" / "tomorrow" — turns an abstract date into the thing the
  /// user is checking for.
  String _relativeBillDescription(DateTime date) {
    final days = DateTime(date.year, date.month, date.day)
        .difference(_today)
        .inDays;
    if (days <= 1) return 'Bills tomorrow';
    return 'Bills in $days days';
  }

  /// Custom-cycle length as currently typed, or null when not applicable.
  int? get _currentCustomDays => _selectedBillingCycle == BillingCycle.custom
      ? int.tryParse(_customDaysController.text.trim())
      : null;

  DateTime get _today {
    final now = clock.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// The selectable window for a next bill date: from tomorrow through one
  /// full cycle out. This isn't cosmetic — it's exactly the set of dates
  /// the anchor maths can represent.
  ///
  /// `nextBillDate` walks the anchor forward until it's strictly after
  /// today, so anchoring at `picked - one cycle` only reproduces `picked`
  /// while `picked - one cycle <= today` — i.e. `picked <= today + one
  /// cycle`. Past that, the anchor is itself still in the future and gets
  /// returned as-is, landing a cycle early. Below tomorrow, the walk
  /// overshoots past today. Both bounds are pinned in billing_cycle_test.
  DateTime get _earliestBillDate => _today.add(const Duration(days: 1));

  DateTime get _latestBillDate => addOneCycle(
        _selectedBillingCycle,
        _today,
        customDays: _currentCustomDays,
      );

  bool _isSelectableBillDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(_earliestBillDate) && !day.isAfter(_latestBillDate);
  }

  /// Drops a chosen date that the current cycle can no longer represent —
  /// switching monthly → weekly shrinks the window, and a stale date would
  /// otherwise be saved with an anchor that resolves to the wrong day.
  void _dropBillDateIfOutOfRange() {
    final date = _nextBillDate;
    if (date != null && !_isSelectableBillDate(date)) {
      _nextBillDate = null;
    }
  }

  /// The next time day-of-month [day] comes around, clamped into short
  /// months (the 31st in February means the 28th/29th). Always lands in
  /// the selectable window.
  DateTime _nextOccurrenceOfDay(int day) {
    final today = _today;
    final thisMonth = _clampedDate(today.year, today.month, day);
    if (thisMonth.isAfter(today)) return thisMonth;
    return _clampedDate(today.year, today.month + 1, day);
  }

  DateTime _clampedDate(int year, int month, int day) {
    // Day 0 of the following month is the last day of this one.
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > lastDayOfMonth ? lastDayOfMonth : day);
  }

  /// Show date picker
  Future<void> _selectDate(BuildContext context) async {
    final current = _nextBillDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null && _isSelectableBillDate(current)
          ? current
          : _earliestBillDate,
      firstDate: _earliestBillDate,
      lastDate: _latestBillDate,
      helpText: 'When does it bill next?',
    );

    if (picked != null) {
      setState(() {
        _nextBillDate = picked;
      });
    }
  }

  /// Save subscription (create or update)
  Future<void> _saveSubscription() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Only once the form is known good — a buzz on a rejected tap reads as
    // confirmation of something that didn't happen. Not awaited: the save
    // shouldn't wait on the vibrator.
    unawaited(HapticFeedback.mediumImpact());

    setState(() {
      _isLoading = true;
    });

    try {
      // Parse price after trial if provided
      double? priceAfterTrial;
      if (_isFreeTrial && _priceAfterTrialController.text.trim().isNotEmpty) {
        priceAfterTrial = double.tryParse(_priceAfterTrialController.text.trim());
      }

      // Parse customDays only when Custom cycle is selected
      int? customDays;
      if (_selectedBillingCycle == BillingCycle.custom) {
        customDays = int.tryParse(_customDaysController.text.trim());
      }

      // Trial subs may have a blank price (interpreted as $0 during trial).
      final priceText = _priceController.text.trim();
      final newPrice = priceText.isEmpty ? 0.0 : double.parse(priceText);

      // The user tells us the NEXT bill date; the model stores an anchor it
      // walks forward from. Anchoring one cycle back makes `nextBillDate`
      // resolve to exactly the date they picked, and leaves this month's
      // already-happened charge visible to the budget forecast (the only
      // consumer of `renewalsInRange`). For trials the anchor is unused —
      // `nextBillDate` runs off `trialEndDate` — so park it on the trial
      // end, which is where billing genuinely starts.
      final DateTime anchorDate;
      if (_isFreeTrial) {
        anchorDate = _trialEndDate ?? clock.now();
      } else {
        anchorDate = subtractOneCycle(
          _selectedBillingCycle,
          _nextBillDate!,
          customDays: customDays,
        );
      }

      late final Subscription subscription;
      if (_isEditMode) {
        final existing = widget.subscription!;

        // Detect price change and record history
        List<Map<String, dynamic>>? updatedPriceHistory = existing.priceHistory;
        if (existing.price != newPrice) {
          updatedPriceHistory = [
            ...?existing.priceHistory,
            {
              'price': existing.price,
              'currency': existing.currency,
              'date': clock.now().toIso8601String(),
            },
          ];
        }

        subscription = existing.copyWith(
          name: _nameController.text.trim(),
          price: newPrice,
          currency: _selectedCurrency,
          billingCycle: _selectedBillingCycle,
          firstBillDate: anchorDate,
          category: _selectedCategory,
          logoUrl: _logoUrl,
          color: _templateColor,
          isFreeTrial: _isFreeTrial,
          trialEndDate: _isFreeTrial ? _trialEndDate : null,
          clearTrialEndDate: !_isFreeTrial,
          priceAfterTrial: priceAfterTrial,
          updatedAt: clock.now(),
          priceHistory: updatedPriceHistory,
          customDays: customDays,
          clearCustomDays: _selectedBillingCycle != BillingCycle.custom,
          cardId: _selectedCardId,
          clearCardId: _selectedCardId == null,
        );
      } else {
        subscription = Subscription(
          id: const Uuid().v4(),
          name: _nameController.text.trim(),
          price: newPrice,
          currency: _selectedCurrency!,
          billingCycle: _selectedBillingCycle,
          firstBillDate: anchorDate,
          category: _selectedCategory,
          logoUrl: _logoUrl,
          color: _templateColor,
          createdAt: clock.now(),
          isFreeTrial: _isFreeTrial,
          trialEndDate: _isFreeTrial ? _trialEndDate : null,
          priceAfterTrial: priceAfterTrial,
          customDays: customDays,
          cardId: _selectedCardId,
        );
      }

      if (_isEditMode) {
        await ref.read(subscriptionProvider.notifier).updateSubscription(subscription);
      } else {
        await ref.read(subscriptionProvider.notifier).addSubscription(subscription);
      }

      if (mounted) {
        // Hand the saved subscription back on add (null on edit) so Home
        // can offer the notification primer against a real bill date.
        Navigator.pop(context, _isEditMode ? null : subscription);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode
                  ? '${subscription.name} updated'
                  : '${subscription.name} added',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Build free trial section
  Widget _buildTrialSection(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isFreeTrial
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trial toggle
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                color: _isFreeTrial
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Free Trial',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Track trial period and get reminded before it ends',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _isFreeTrial,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _isFreeTrial = value;
                    if (value && _trialEndDate == null) {
                      // Default to 7 days from now
                      _trialEndDate = clock.now().add(const Duration(days: 7));
                    }
                    // Switching a trial OFF un-hides the next-bill field,
                    // which for an edited trial was seeded from the trial
                    // end — often months out and unreachable for the cycle.
                    _dropBillDateIfOutOfRange();
                  });
                },
              ),
            ],
          ),

          // Trial details (shown when trial is enabled)
          if (_isFreeTrial) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Trial duration — convenience input that drives the end date
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _trialDurationController,
                    decoration: const InputDecoration(
                      labelText: 'Trial Length',
                      hintText: '7',
                      prefixIcon: Icon(Icons.hourglass_empty),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null && parsed > 0) {
                        _trialDurationValue = parsed;
                        _applyTrialDuration();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<_TrialDurationUnit>(
                    initialValue: _trialDurationUnit,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: _TrialDurationUnit.days,
                        child: Text('Days'),
                      ),
                      DropdownMenuItem(
                        value: _TrialDurationUnit.months,
                        child: Text('Months'),
                      ),
                      DropdownMenuItem(
                        value: _TrialDurationUnit.years,
                        child: Text('Years'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _trialDurationUnit = value;
                        _applyTrialDuration();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Trial end date — manual override / display, syncs with the
            // duration row above. User can tap to pick a custom date.
            InkWell(
              onTap: () => _selectTrialEndDate(context),
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Trial End Date',
                  helperText: 'Tap to pick a custom date',
                  prefixIcon: Icon(Icons.event),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Text(
                  _trialEndDate != null
                      ? DateFormat('MMM dd, yyyy').format(_trialEndDate!)
                      : 'Select date',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Price after trial — required when free trial is on, since
            // the trial period itself is free and this is the recurring
            // amount that will start charging after trialEndDate.
            TextFormField(
              controller: _priceAfterTrialController,
              decoration: InputDecoration(
                labelText: 'Price After Trial',
                hintText: 'e.g., 9.99',
                prefixIcon: const Icon(Icons.payments_outlined),
                prefixText: '${CurrencyInfo.getSymbol(_selectedCurrency!)} ',
                helperText: 'The price you\'ll pay after the trial ends',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (!_isFreeTrial) return null;
                if (value == null || value.trim().isEmpty) {
                  return 'Required for free trials';
                }
                final price = double.tryParse(value);
                if (price == null) {
                  return 'Please enter a valid number';
                }
                if (price <= 0) {
                  return 'Must be greater than 0';
                }
                if (price > 10000000) {
                  return 'Price seems too high';
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Select trial end date
  Future<void> _selectTrialEndDate(BuildContext context) async {
    final now = clock.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _trialEndDate ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'When does the trial end?',
    );

    if (picked != null) {
      setState(() {
        _trialEndDate = picked;
      });
    }
  }

  /// Build template section with categories
  Widget _buildTemplateSection(BuildContext context, ThemeData theme) {
    final templates = ref.watch(allTemplatesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Popular Services',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),

        // Show templates by category
        ...templates.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
                child: Text(
                  '${entry.key.icon} ${entry.key.displayName}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: entry.value.length,
                  itemBuilder: (context, index) {
                    final template = entry.value[index];
                    return _buildTemplateChip(context, theme, template);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          );
        }),
      ],
    );
  }

  /// Fill the form from a tapped template. Applied directly (not via a
  /// provider) so re-picking the same service after dismissing the sheet
  /// still works.
  void _applyTemplate(SubscriptionTemplate template) {
    HapticFeedback.selectionClick();
    setState(() {
      _nameController.text = template.name;
      _selectedCategory = template.category;
      _selectedBillingCycle = template.defaultBillingCycle;
      // Don't pre-fill price - let user enter their plan price
      _priceController.clear();
      _logoUrl = template.logoUrl;
      _templateColor = template.color;
      _showTemplates = false;
      // A template carries its own cycle, so the bill-date window may have
      // just moved. Every template ships monthly today, but this is one of
      // the places that can strand a chosen date.
      _dropBillDateIfOutOfRange();
    });
  }

  /// Build individual template chip
  Widget _buildTemplateChip(BuildContext context, ThemeData theme, SubscriptionTemplate template) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () => _applyTemplate(template),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 70,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Image.asset(
                      template.logoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.image_not_supported,
                          size: 24,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Name
              Text(
                template.name,
                style: theme.textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build currency selector dropdown
  Widget _buildCurrencySelector(ThemeData theme) {
    final currencyInfo = CurrencyInfo.getByCode(_selectedCurrency!);

    return InkWell(
      onTap: () => _showCurrencyPicker(theme),
      borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Currency',
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                currencyInfo != null
                    ? '${currencyInfo.flag} ${currencyInfo.code}'
                    : _selectedCurrency!,
                style: theme.textTheme.bodyLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  /// Show currency picker bottom sheet
  void _showCurrencyPicker(ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Select Currency',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Divider(height: 1),
                // Currency list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: CurrencyInfo.all.length,
                    itemBuilder: (context, index) {
                      final currency = CurrencyInfo.all[index];
                      final isSelected = currency.code == _selectedCurrency!;

                      return ListTile(
                        leading: Text(
                          currency.flag ?? '',
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(
                          currency.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text('${currency.code} • ${currency.symbol}'),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedCurrency = currency.code;
                          });
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// A single day-of-month chip in the "bills on the" row.
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.isSelected,
    required this.onTap,
  });

  final int day;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Bills on day $day of the month',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: AnimatedContainer(
          duration: AppMotion.of(context, AppMotion.fast),
          curve: AppMotion.curve,
          width: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            '$day',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ),
      ),
    );
  }
}

/// Units for the trial-duration convenience input. Not persisted —
/// the only persisted trial field is [Subscription.trialEndDate].
enum _TrialDurationUnit { days, months, years }
